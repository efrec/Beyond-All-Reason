function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Custom behavior for projectiles that explode and split on impact.',
        author  = 'efrec',
        version = '1.1',
        date    = '2024-07-15',
        license = 'GNU GPL, v2 or later',
        layer   = 10, -- Preempt any g:Explosion handlers that return `true`.
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

-- General settings ------------------------------------------------------------

local maxSpawnNumber  = 24                 -- hard-cap on moddable value
local minUnitBounces  = "armpw"            -- smallest unit that partly reflects
local minUnitTerrain  = "armthor"          -- smallest unit that fully reflects
local minBulkTerrain  = 64000              -- for consistent full reflection
local deepWaterDepth  = -40                -- for deflection on water/"water"

-- Customparam defaults --------------------------------------------------------

local defaultSpawnDef = "cluster_munition" -- weapon name used when `def` is nil
local defaultSpawnNum = 5                  -- fallback values for your screwups
local defaultSpawnTtl = 10                 -- fallback values for your screwups
local defaultVelocity = 240                -- fallback values for your screwups

-- CustomParams setup ----------------------------------------------------------

--    primary_weapon = {
--        customparams = {
--            cluster        = true,
--            cluster_def    = <string> | default weapon name,
--            cluster_number = <number> | default spawn count,
--        },
--    },
--    cluster_def = {
--        maxvelocity = <number>, -- Each of these will decide the total area
--        range       = <number>, -- where cluster munitions will be scattered.
--    }

--------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------

local DirectionsUtil = VFS.Include("LuaRules/Gadgets/Include/DirectionsUtil.lua")

local max   = math.max
local rand  = math.random
local sqrt  = math.sqrt
local cos   = math.cos
local sin   = math.sin
local atan2 = math.atan2

local spGetGroundHeight  = Spring.GetGroundHeight
local spGetGroundNormal  = Spring.GetGroundNormal
local spGetUnitDefID     = Spring.GetUnitDefID
local spGetUnitPosition  = Spring.GetUnitPosition
local spSpawnProjectile  = Spring.SpawnProjectile
local spTraceRayUnits    = Spring.TraceRayUnits
local spTraceRayGround   = Spring.TraceRayGround

local gameSpeed          = Game.gameSpeed
local mapGravity         = Game.gravity / gameSpeed / gameSpeed * -1

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

defaultSpawnTtl = defaultSpawnTtl * gameSpeed

-- Information table for cluster triggers

local clusterWeapons = {}

local spawnableTypes = {
    Cannon    = true,
    EMGCannon = true,
}

for unitDefID, unitDef in pairs(UnitDefs) do
    for index, unitWeapon in ipairs(unitDef.weapons or {}) do
        local wdef = WeaponDefs[unitWeapon.weaponDef]
        if wdef.customParams.cluster then
            clusterWeapons[wdid] = {
                def    = wdef.customParams.def or (unitDef.name.."_"..defaultSpawnDef)
                number = math.min(
                    tonumber(wdef.customParams.number or defaultSpawnNum),
                    maxSpawnNumber
                )
            }
        end
    end
end

-- Information for cluster munitions

for weaponDefID, cluster in pairs(clusterWeapons) do
    local cmdid = WeaponDefNames[cluster.def].id
    local cmdef = WeaponDefs[cmdid]

    clusterWeapons[weaponDefID].projDef = cmdid
    clusterWeapons[weaponDefID].projTtl = cmdef.flighttime or defaultSpawnTtl

    -- Range and velocity are closely related so may be in disagreement.
    -- Average them (more or less) to create a consistent area of effect.
    local projVel = cmdef.startvelocity or cmdef.projectilespeed
    projVel = ((projVel and projVel) or defaultVelocity) / gameSpeed
    if cmdef.range > 10 then
        -- range -> velocity calculation for a launch @ 45deg:
        local rangeVel = sqrt(cmdef.range * math.abs(mapGravity))
        clusterWeapons[weaponDefID].projVel = (projVel + rangeVel) / 2
    else
        clusterWeapons[weaponDefID].projVel = projVel
    end
end

-- Remove invalid cluster weapons

for weaponDefID, cluster in pairs(clusterWeapons) do
    if clusterWeapons[cmdid] ~= nil then
        Spring.Echo('[clustermun] [warn] Preventing recursive explosions: ' .. cmdid)
        clusterWeapons[cmdid] = nil
    end

    if spawnableTypes[cmdef.type] ~= true then
        Spring.Echo('[clustermun] [warn] Invalid spawned weapon type: ' ..
            clusterWeapons[weaponDefID].def .. ' is not spawnable (' .. (cmdef.type or 'nil!') .. ')')
        clusterWeapons[weaponDefID] = nil
    end

    if cluster.number == nil or cluster.number <= 1 then
        Spring.Echo('[clusermun] [warn] Removing low-count cluster weapon: ' .. weaponDefID)
        clusterWeapons[weaponDefID] = nil
    end
end

-- Information table for hit units

local unitBulk = {} -- How sturdy the unit is. Projectiles scatter less with lower bulk values.

do
    ---Unit mass is mass-ively overloaded with additional connotations; we need something simple.
    ---It has to apply to all units, treat them equally, and be relatively insensitive to change.
    ---@param unitDef table
    ---@return number bulk value from 0 to 1, inclusive
    local function getUnitBulk(unitDef)
        if not unitDef then return end
        return math.min(
            1.0,
            ((  udef.health ^ 0.5 +                         -- HP is log2-ish but that feels too tryhard
                udef.metalCost ^ 0.5 *                      -- Steel (metal) is heavier than feathers (energy)
                udef.xsize * udef.zsize * udef.radius ^ 0.5 -- People see 'bigger thing' as 'more solid'
            ) / minBulkTerrain)                             -- Scaled against some large-ish bulk rating
        ) ^ 0.33                                            -- Raised to a low power to curve up the results
    end

    -- This mechanic is based on the units you pass into it. If game balance shifts substantially,
    -- you might need to re-evaluate how much metal is "a lot of metal" or how big is "a big unit".
    local bulkMin = getUnitBulk(UnitDefNames[minUnitBounces]) or 0
    local bulkMax = getUnitBulk(UnitDefNames[minUnitTerrain]) or minBulkTerrain
    minBulkTerrain = max(minBulkTerrain, bulkMax)

    for unitDefID, unitDef in pairs(UnitDefs) do
        local bulk = getUnitBulk(unitDef)
        unitBulk[unitDefID] = (bulk > bulkMin and bulk) or nil

        -- There may be other, weirder exceptions for bulk-iness:
        if unitDef.armorType == Game.armorTypes.wall or unitDef.armorType == Game.armorTypes.indestructible then
            unitBulk[unitDefID] = (unitBulk[unitDefID] + 1) / 2
        elseif unitDef.customParams.neutral_when_closed then -- Dragon turrets
            unitBulk[unitDefID] = (unitBulk[unitDefID] + 1) / 2
        end
    end
end

-- Spring.Debug.TableEcho(
--     {
--         ['Tick bulk']     = unitBulk[ UnitDefNames["armflea"].id  ],
--         ['Pawn bulk']     = unitBulk[ UnitDefNames["armpw"].id    ],
--         ['Gauntlet bulk'] = unitBulk[ UnitDefNames["armguard"].id ],
--         ['Pulsar bulk']   = unitBulk[ UnitDefNames["armanni"].id  ],
--         ['Thor bulk']     = unitBulk[ UnitDefNames["armthor"].id  ],
--     }
-- )

-- Reusable table for reducing garbage

local spawnCache  = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    owner   = 0,
    ttl     = defaultSpawnTtl,
    gravity = mapGravity,
}

-- Set up preset direction vectors for scattering cluster projectiles.

local directions = DirectionsUtil.Directions
local maxDataNum = 2
for _, data in pairs(clusterWeapons) do
    if data.number > maxDataNum then maxDataNum = data.number end
end
DirectionsUtil.ProvisionDirections(maxDataNum)

--------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------

---Deflect the net force of an explosion away from terrain.
---Used to scatter shrapnel, etc. from an explosive source.
---@param ex number
---@param ey number
---@param ez number
---@param projectileID number
---@param count number
---@param speed number
---@return number response_x
---@return number response_y
---@return number response_z
local function getTerrainDeflection(ex, ey, ez, projectileID, count, speed)
    -- Get the shortest distance to a hard surface and the response direction.
    local distance, dx, dy, dz, slope
    local elevation = spGetGroundHeight(ex, ez)
    distance = ey - elevation
    dx, dy, dz, slope = spGetGroundNormal(ex, ez, true) -- Smooth normal, not raw.

    -- Follow slopes upward, toward the shortest distance to ground.
    -- Note: Walls, cliffs, etc. on flatter maps might be overlooked.
    if slope > 0 and distance > 8 then
        local rayDistance = spTraceRayGround(ex, ey, ez, -dx, -dy, -dz, distance)
        if rayDistance then
            distance = rayDistance
            elevation = spGetGroundHeight(ex + dx * distance, ez + dz * distance)
            dx, dy, dz,_ = spGetGroundNormal(ex + dx * distance, ez + dz * distance, true)
        end
    end

    if elevation < deepWaterDepth then
        -- Guess an equivalent hard-surface distance, given that water is dense.
        -- The response is always directly upward, pending any changes to water.
        distance = ey - deepWaterDepth * 0.5
        dx, dy, dz  = 0, 1, 0
    elseif elevation <= 0 then
        -- The reponse is averaged against the upward direction.
        distance = ey - elevation * 0.5
        dx, dy, dz = dx * 0.5, (dy + 1) * 0.5, dz * 0.5
    end

    -- Scale the response direction by the response strength,
    -- plus extra to deal with the jitter that will be added,
    -- plus a small shift from the parent projectile's speed.
    local vx, vy, vz, vw = Spring.GetProjectileVelocity(projectileID)
    local response = 1 / sqrt(max(1, distance))
    local increase = (math.pi * 0.5) + (1 / (1 + count))
    local momentum = max(0, (vw - speed) * 0.25) / speed
    Spring.Echo('[clustermun] vw and speed: ' .. vw .. ', ' .. speed) -- !

    -- Momentum is halved again to average v-terms and d-terms.
    -- The intended effect is to add ricochet alongside inertia:
    return (dx * response * increase) + momentum * (vx/vw + dx),
           (dy * response * increase) + momentum * (vy/vw + dy),
           (dz * response * increase) + momentum * (vz/vw + dz)
end

---Spawn sub-munitions that are flung outward from an explosive source.
---New projectiles that are in immediate contact with bulky units are deflected away.
---@param ex number
---@param ey number
---@param ez number
---@param ownerID number|nil
---@param projectileID number
---@param count number
---@param speed number
---@param timeToLive number|nil
local function spawnClusterProjectiles(ex, ey, ez, ownerID, projectileID, count, speed, timeToLive)
    -- Initial direction vectors are evenly spaced.
    local vecs = directions[count]

    -- These are redirected away from nearby terrain and nudged away from nearby units.
    local dx, dy, dz = getTerrainDeflection(ex, ey, ez, projectileID, count, speed)
    local scanNearby = speed * (0.1 * gameSpeed)

    Spring.Echo('[clustermun] scan length = ' .. scanNearby) -- !

    local vx, vy, vz, vw
    for ii = 0, (count - 1) do
        -- Avoid shooting into terrain by adding deflection.
        -- Since the initial directions are fixed, add some jitter.
        vx = vecs[3*ii+1] + dx + (rand() * 6 - 3) / count
        vy = vecs[3*ii+2] + dy + (rand() * 6 - 3) / count
        vz = vecs[3*ii+3] + dz + (rand() * 6 - 3) / count
        vw = sqrt(vx*vx + vy*vy + vz*vz)

        -- Find units along this trajectory, if any, and deflect away.
        local unitImpacted = spTraceRayUnits(ex, ey, ez, vx, vy, vz, scanNearby / vw)
        local nudge = 0.33
        for length, unitID in pairs(unitImpacted) do
            local bounce = unitBulk[spGetUnitDefID(unitID)]
            if bounce ~= nil then
                nudge = nudge - bounce -- real programming hours
                bounce = bounce / (scanNearby / vw / max(1, length))
                local _,_,_, ux, uy, uz = spGetUnitPosition(unitID, true)
                local dx, dy, dz = (ex + vx / vw * length) - ux,
                                   (ey + vy / vw * length) - uy,
                                   (ez + vz / vw * length) - uz
                local th_z = atan2(dx, dz)
                local ph_y = atan2(dy, sqrt(dx*dx + dz*dz))
                local cosy = cos(ph_y)
                vx = dx + bounce * sin(th_z) * cosy
                vy = dy + bounce * sin(ph_y)
                vz = dz + bounce * cos(th_z) * cosy
                vw = sqrt(vx*vx + vy*vy + vz*vz)
                -- Let's not keep going tbh:
                if nudge <= 0 then
                    break
                end
            end
        end

        -- Trace end position.
        Spring.MarkerAddPoint(
            ex + vx / vw * length,
            ey + vy / vw * length,
            ez + vz / vw * length
        )

        vx = (vx / vw) * speed
        vy = (vy / vw) * speed
        vz = (vz / vw) * speed

        spawnCache.owner = ownerID
        spawnCache.pos = {
            ex + vx * gameSpeed / 2,
            ey + vy * gameSpeed / 2,
            ez + vz * gameSpeed / 2,
        }
        spawnCache.speed = { vx, vy, vz }
        spawnCache.ttl = timeToLive

        spSpawnProjectile(data.projDef, spawnCache)
    end
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

function gadget:Initialize()
    if not next(clusterWeapons) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO,
            "No cluster weapons found. Removing gadget.")
        gadgetHandler:RemoveGadget(self)
        return
    end

    for wdid, _ in pairs(clusterWeapons) do
        Script.SetWatchExplosion(wdid, true)
    end
end

function gadget:ShutDown()
    -- Deref tables from VFS.Include so the GC will collect them.
    directions = nil
    for key, _ in pairs(DirectionsUtil) do
        DirectionsUtil[key] = nil
    end
    DirectionsUtil = nil
end

function gadget:Explosion(weaponDefID, ex, ey, ez, attackID, projID)
    if clusterWeapons[weaponDefID] then
        local data = clusterWeapons[weaponDefID]
        spawnClusterProjectiles(
            ex, ey, ez,
            attackID,
            projID,
            data.projNum,
            data.projVel,
            data.projTtl
        )
    end
end

function gadget:GetInfo()
    return {
        name    = 'Cluster Munitions',
        desc    = 'Custom behavior for projectiles that explode and split on impact.',
        author  = 'efrec',
        version = '1.1',
        date    = '2024-07-15',
        license = 'GNU GPL, v2 or later',
        layer   = 10, -- preempt :Explosion handlers like fx_watersplash.lua that return `true` (not pure fx)
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

--------------------------------------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------------------------------------

-- General settings ------------------------------------------------------------------------------------------

local maxSpawnNumber  = 24                         -- protect game performance against stupid ideas
local minUnitBounces  = "armpw"                    -- smallest unit (name) that bounces projectiles at all
local minBulkReflect  = 64000                      -- smallest unit bulk that causes reflection as if terrain
local deepWaterDepth  = -40                        -- used for the surface deflection on water, lava, ...

-- Customparam defaults --------------------------------------------------------------------------------------

local defaultSpawnDef = "cluster_munition"         -- def used, by default
local defaultSpawnNum = 5                          -- number of spawned projectiles, by default
local defaultSpawnTtl = 300                        -- detonate projectiles after time = ttl, by default
local defaultVelocity = 240                        -- speed of spawned projectiles, by default

-- CustomParams setup ----------------------------------------------------------------------------------------

--    primary_weapon = {
--        customparams = {
--            cluster  = true,
--           [def      = <string>,]
--           [number   = <integer>,]
--        },
--    },
--    cluster_munition | <def> = {
--       [maxvelocity = <number>,]
--       [range       = <number>,]
--    }

--------------------------------------------------------------------------------------------------------------
-- Localize --------------------------------------------------------------------------------------------------

local DirectionsUtil = VFS.Include("LuaRules/Gadgets/Include/DirectionsUtil.lua")

local abs   = math.abs
local max   = math.max
local min   = math.min
local rand  = math.random
local sqrt  = math.sqrt
local cos   = math.cos
local sin   = math.sin
local atan2 = math.atan2

local spGetGroundHeight  = Spring.GetGroundHeight
local spGetGroundNormal  = Spring.GetGroundNormal
local spGetUnitDefID     = Spring.GetUnitDefID
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitRadius    = Spring.GetUnitRadius
local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spSpawnProjectile  = Spring.SpawnProjectile
local spTraceRayUnits    = Spring.TraceRayUnits
local spTraceRayGround   = Spring.TraceRayGround

local gameSpeed          = Game.gameSpeed
local mapGravity         = Game.gravity / gameSpeed / gameSpeed * -1

local SetWatchExplosion  = Script.SetWatchExplosion

--------------------------------------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------------------------------------

-- Information table for cluster weapons

local spawnableTypes = {
    Cannon          = true  ,
    EMGCannon       = true  ,
    Fire            = false , -- but possible
    LightningCannon = false , -- but possible
    MissileLauncher = false , -- but possible
}

local dataTable      = {} -- Info on each cluster weapon
local wDefNamesToIDs = {} -- Says it on the tin

for wdid, wdef in pairs(WeaponDefs) do
    wDefNamesToIDs[wdef.name] = wdid

    if wdef.customParams.cluster then
        dataTable[wdid] = {}
        dataTable[wdid].number  = tonumber(wdef.customParams.number) or defaultSpawnNum
        dataTable[wdid].def     = wdef.customParams.def
        dataTable[wdid].projDef = -1
        dataTable[wdid].projTtl = -1
        dataTable[wdid].projVel = -1

        -- Enforce limits, eg the projectile count, at init.
        dataTable[wdid].number  = min(dataTable[wdid].number, maxSpawnNumber)

        -- When the cluster munition name isn't specified, search for the default.
        if dataTable[wdid].def == nil then
            local search = ''
            for word in string.gmatch(wdef.name, '([^_]+)') do
                search = search == '' and word or search .. '_' .. word
                if UnitDefNames[search] ~= nil then
                    dataTable[wdid].def = search .. '_' .. defaultSpawnDef
                end
            end
            -- There's still the chance we haven't found anything, so:
            if dataTable[wdid].def == nil then
                Spring.Echo('[clustermun] [warn] Did not find cluster munition for weapon id ' .. wdid)
                dataTable[wdid] = nil
            end
        end
    end
end

-- Information for cluster munitions

for wdid, data in pairs(dataTable) do
    local cmdid = wDefNamesToIDs[data.def]
    local cmdef = WeaponDefs[cmdid]

    dataTable[wdid].projDef = cmdid
    dataTable[wdid].projTtl = cmdef.flighttime or defaultSpawnTtl

    -- Range and velocity are closely related so may be in disagreement. Average them (more or less):
    local projVel = cmdef.projectilespeed or cmdef.startvelocity
    projVel = ((projVel and projVel) or defaultVelocity) / gameSpeed
    if cmdef.range > 10 then
        local rangeVel = sqrt(cmdef.range * abs(mapGravity)) -- inverse range calc for launch @ 45deg
        dataTable[wdid].projVel = (projVel + rangeVel) / 2
    else
        dataTable[wdid].projVel = projVel
    end

    -- Prevent the grenade apocalypse:
    if dataTable[cmdid] ~= nil then
        Spring.Echo('[clustermun] [warn] Preventing recursive explosions: ' .. cmdid)
        dataTable[cmdid] = nil
    end

    -- Remove unspawnable projectiles:
    if spawnableTypes[cmdef.type] ~= true then
        Spring.Echo('[clustermun] [warn] Invalid spawned weapon type: ' ..
            dataTable[wdid].def .. ' is not spawnable (' .. (cmdef.type or 'nil!') .. ')')
        dataTable[wdid] = nil
    end

    -- Remove invalid spawn counts:
    if data.number == nil or data.number <= 1 then
        Spring.Echo('[clusermun] [warn] Removing low-count cluster weapon: ' .. wdid)
        dataTable[wdid] = nil
    end
end
wDefNamesToIDs = nil

-- Information on units

local unitBulk = {} -- How sturdy the unit is. Projectiles scatter less with lower bulk values.

for udid, udef in pairs(UnitDefs) do
    -- Set the unit bulk values.
    if udef.armorType == Game.armorTypes.wall or udef.armorType == Game.armorTypes.indestructible then
        unitBulk[udid] = 0.9
    elseif udef.customParams.neutral_when_closed then -- Dragon turrets
        unitBulk[udid] = 0.8
    else
        unitBulk[udid] = min(
            1.0,
            ((  udef.health ^ 0.5 +                         -- HP is log2-ish but that feels too tryhard
                udef.metalCost ^ 0.5 *                      -- Steel (metal) is heavier than feathers (energy)
                udef.xsize * udef.zsize * udef.radius ^ 0.5 -- People see 'bigger thing' as 'more solid'
            ) / minBulkReflect)                             -- Scaled against some large-ish bulk rating
        ) ^ 0.33                                            -- Raised to a low power to curve up the results
    end
end

local bulkMin = unitBulk[UnitDefNames[minUnitBounces].id] or minBulkReflect / 10
for udid, _ in pairs(UnitDefs) do
    if unitBulk[udid] < bulkMin then
        unitBulk[udid] = nil
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
for _, data in pairs(dataTable) do
    if data.number > maxDataNum then maxDataNum = data.number end
end
DirectionsUtil.ProvisionDirections(maxDataNum)

--------------------------------------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------------------------------------

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
    local distance, x, y, z, m
    local elevation = spGetGroundHeight(ex, ez)
    if elevation < deepWaterDepth then
        -- Guess an equivalent hard-surface distance.
        -- The response is directly upward.
        distance = ey - deepWaterDepth / 3 -- Since water is fairly dense.
        x, y, z  = 0, 1, 0
    else
        -- Get the true elevation above a hard surface.
        -- And the true direction of the surface response.
        distance = ey - elevation
        x, y, z, m = spGetGroundNormal(ex, ez, true) -- Smooth normal, not raw.

        -- Follow slopes upward, toward the shortest distance to ground.
        -- Note: Walls, cliffs, etc. on flatter maps might be overlooked.
        local cosm = cos(m)
        local lenxz = sqrt(x*x + z*z)
        if distance * cosm > 1 then
            local dx, dy, dz = cosm * (x / lenxz),
                               cosm * sin(m) * -1,
                               cosm * (z / lenxz)
            local rayDistance = spTraceRayGround(ex, ey, ez, dx, dy, dz, distance)
            if rayDistance then
                distance = rayDistance
                elevation = spGetGroundHeight(ex + dx * distance, ez + dz * distance)
                x, y, z,_ = spGetGroundNormal(ex + dx * distance, ez + dz * distance, true)
            end
        end

        -- Surface responses in shallow water ignore some of the ground normal,
        -- but have a shorter hard-surface distance overall than deep water.
        if elevation <= 0 then
            distance = ey - elevation / 2
            x, y, z = x * 0.87, y / 0.87, z * 0.87
        end
    end

    -- Scale the response direction by the response strength,
    -- plus extra to deal with the jitter that will be added,
    -- plus a small shift from the parent projectile's speed.
    local vx, vy, vz, vw = Spring.GetProjectileVelocity(projectileID)
    local response = (math.pi / 2 + 1 / (1 + count)) / sqrt(max(1, distance))
    local momentum = max(0, vw - speed) / speed -- This ignores a lot, so keep it simple.
    Spring.Echo('[clustermun] vw and speed: ' .. vw .. ', ' .. speed) -- !

    return response * x + momentum * vx,
           response * y + momentum * vy * 0.8,
           response * z + momentum * vz
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
                bounce = bounce / (scanNearby / vw / math.max(1, length))
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

--------------------------------------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------------------------------------

function gadget:Initialize()
    if not next(dataTable) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "No cluster weapons found. Removing gadget.")
        gadgetHandler:RemoveGadget(self)
    end

    for wdid, _ in pairs(dataTable) do
        SetWatchExplosion(wdid, true)
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
    if dataTable[weaponDefID] then
        local data = dataTable[weaponDefID]
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

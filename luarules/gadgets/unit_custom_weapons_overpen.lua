function gadget:GetInfo()
    return {
        name    = 'Target Over-Penetration',
        desc    = 'Allows projectiles to pass through targets with customizable behavior.',
        author  = 'efrec',
        version = 'alpha',
        date    = '2024-07',
        license = 'GNU GPL, v2 or later',
        layer   = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then return false end


--------------------------------------------------------------------------------
--
--  impactonly = true,                         -- << Required.
-- 	customparams = {
-- 		overpen          = true,               -- << Required.
-- 		overpen_decrease = <number> | 0.02,
-- 		overpen_overkill = <number> | 0.2,
-- 		overpen_with_def = <string> | this def,
--      overpen_expl_def = <string> | nil,
-- 	}
--
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold = 0.1      -- A percentage. Minimum damage that can overpen; a tad multipurpose.
local impulseArrested = 1.7      -- A coefficient. Increases impulse when a target stops a penetrator.

-- Customparam defaults --------------------------------------------------------

local overpenDecrease = 0.02     -- A percentage. Additional damage falloff per each over-penetration.
local overpenOverkill = 0.2      -- A percentage. Additional damage to destroyed targets; can be < 0.
local overpenDuration = 3        -- In seconds. Time-to-live or flight time of re-spawned projectiles.


--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local min  = math.min
local max  = math.max
local sqrt = math.sqrt
local cos  = math.cos
local atan = math.atan

local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitRadius           = Spring.GetUnitRadius
local spSpawnExplosion          = Spring.SpawnExplosion
local spSpawnProjectile         = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = -1 * Game.gravity / gameSpeed / gameSpeed


--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
    if weaponDef.customParams.overpen then
        weaponParams[weaponDefID] = {}

        local custom = weaponDef.customParams
        local params = weaponParams[weaponDefID]

        params.damage   = weaponDef.damages[0]
        params.decrease = tonumber(custom.overpen_decrease or overpenDecrease)
        params.overkill = (tonumber(custom.overpen_overkill) or overpenOverkill) + 1

        if custom.overpen_with_def then
            -- The weapon uses separate driver/penetrator projectiles:
            local penDefID = (WeaponDefNames[custom.overpen_with_def] or weaponDef).id
            if penDefID ~= weaponDefID then
                params.penDefID = penDefID

                local driverVelocity = weaponDef.weaponvelocity
                local penDefVelocity = WeaponDefs[penDefID].weaponvelocity
                params.velRatio = penDefVelocity / driverVelocity

                local driverLifetime = weaponDef.flighttime            or overpenDuration * gameSpeed
                local penDefLifetime = WeaponDefs[penDefID].flighttime or overpenDuration * gameSpeed
                params.ttlRatio = penDefLifetime / driverLifetime
            end
        end

        if custom.overpen_expl_def then
            -- When the weapon fails to overpen, it explodes (technically twice):
            local expDefID = (WeaponDefNames[custom.overpen_expl_def] or weaponDef).id
            if expDefID ~= weaponDefID then
                params.expDefID = expDefID
            end
        end
    end
end

-- Diagnose and remove invalid weapon entries.

for weaponDefID, params in ipairs(weaponParams) do
    local weaponDef = WeaponDefs[weaponDefID]
    if not weaponDef.impactOnly then
        weaponParams[weaponDefID] = nil
    end
end

-- Cache the table params for SpawnExplosion.

local explosionCaches = {}

for driverDefID, params in ipairs(weaponParams) do
    if params.expDefID then
        explosionCaches[params.expDefID] = {
            weaponDef = params.expDefID,
            damages   = WeaponDefs[params.expDefID],
            owner     = -1,
        }
    end
end

-- Keep track of penetrators, ignored targets, remaining damage, and waiting spawns.

local penetrators = {}
local spawnFromID = {}

local spawnCache = {
    pos     = { 0, 0, 0 },
    speed   = { 0, 0, 0 },
    owner   = -1,
    ttl     = gameSpeed * 3,
    gravity = mapGravity,
}


--------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------

local function consumeDriver(projID, unitID, damage, attackID)
    local driver = penetrators[projID]
    penetrators[projID] = nil

    local weaponData = driver[1]
    local damageLeft = driver[2]
    damage = damage * damageLeft

    local health, healthMax = spGetUnitHealth(unitID)
    if not health then return end

    -- Outcomes: (1) overpen (2) exhaust (3) arrest explosion (4) arrest impact.
    if (damage >= health and damage >= healthMax * damageThreshold) then
        damage = max(health, damage * weaponData.overkill)
        damageLeft = damageLeft - (health / weaponData.damage + weaponData.decrease)
        if damageLeft > damageThreshold then -- Overpen; else, exhaust.
            driver[2] = damageLeft
            spawnFromID[projID] = driver
        end
    elseif weaponData.expDefID then
        local px, py, pz = spGetProjectilePosition(projID)
        local explosion = explosionCaches[weaponData.expDefID]
        explosion.owner = attackID
        spSpawnExplosion(px, py, pz, 0, 0, 0, explosion)
    else
        -- Enhance the arrest impulse to offset damage decreases:
        return damage,
               damageLeft * (1 + impulseArrested             ) /
                            (1 + impulseArrested * damageLeft)
    end

    return damage
end

local function spawnPenetrator(projID, unitID, attackID, penDefID)
    local penetrator = spawnFromID[projID]
    spawnFromID[projID] = nil

    local px, py, pz = spGetProjectilePosition(projID)
    local timeToLive = spGetProjectileTimeToLive(projID)
    local vx, vy, vz, vw = spGetProjectileVelocity(projID)

    local _,_,_, mx, my, mz = spGetUnitPosition(unitID, true)
    local unitRadius = spGetUnitRadius(unitID)

    -- An exact (raycast-type) solution is expensive in lua; we just estimate.
    -- We also don't want to move an impossible distance in a sub-frame, anyway.
    -- A halfway-decent estimate might use something along the lines of:
    local ex, ey, ez = (mx - px) / unitRadius - vx / vw,
                       (my - py) / unitRadius - vy / vw,
                       (mz - pz) / unitRadius - vz / vw
    -- Move at least a quarter frame and up to two frame's worth (instantly):
    -- Potential enhancement to spawn projectiles from a queue when move >= 1
    local move = unitRadius / vw * (cos(atan(ex)) + cos(atan(ey)) + cos(atan(ez))) * (2/3)
    move = max(0.25, min(2, move))

    -- Spring.MarkerAddPoint(px, py, pz, "point of impact")
    local data = spawnCache
    data.pos[1] = px + move * vx
    data.pos[2] = py + move * vy
    data.pos[3] = pz + move * vz
    data.owner = attackID
    -- Spring.MarkerAddPoint(data.pos[1], data.pos[2], data.pos[3], "point of spawn")

    if penetrator[1].penDefID then
        local driverData = penetrator[1]
        penDefID = driverData.penDefID
        timeToLive = timeToLive * driverData.ttlRatio
        local velRatio = driverData.velRatio
        vx, vy, vz = vx * velRatio, vy * velRatio, vz * velRatio
        penetrator[1] = weaponParams[penDefID]
        penetrator[2] = (1 + penetrator[2]) / 2 -- Reduced damage loss.
    end

    data.speed[1] = vx
    data.speed[2] = vy
    data.speed[3] = vz
    data.ttl = timeToLive

    local spawnID = spSpawnProjectile(penDefID, data)
    penetrators[spawnID] = penetrator
end


--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    if not next(weaponParams) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO,
            "No weapons with over-penetration found. Removing.")
        gadgetHandler:RemoveGadget(self)
    end

    for weaponDefID, params in ipairs(weaponParams) do
        Script.SetWatchProjectile(weaponDefID, true)
    end
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
    if weaponParams[weaponDefID] and not penetrators[projID] then
        penetrators[projID] = { weaponParams[weaponDefID], 1 }
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if penetrators[projID] then
        return consumeDriver(projID, unitID, damage, attackID)
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if spawnFromID[projID] then
        spawnPenetrator(projID, unitID, attackID, weaponDefID)
    end
end

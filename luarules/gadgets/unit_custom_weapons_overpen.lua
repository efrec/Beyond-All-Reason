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


--------------------------------------------------------------------------------------------------------------
--
--  impactonly = true,
-- 	customparams = {
-- 		overpen          = true,               -- << Required.
-- 		overpen_decrease = <number> | 0.02,
-- 		overpen_overkill = <number> | 0.2,
-- 		overpen_with_def = <string> | this def,
-- 	}
--
--------------------------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------------------------------------

local damageThreshold = 0.1              -- A percentage. Minimum damage that can overpen; a tad multipurpose.
local impulseModifier = 1.7              -- A coefficient. Increases impulse when a target stops a penetrator.

-- Customparam defaults --------------------------------------------------------------------------------------

local overpenDecrease = 0.02             -- A percentage. Additional damage falloff per each over-penetration.
local overpenOverkill = 0.2              -- A percentage. Additional damage dealt when destroying targets.
local overpenDuration = 5                -- In seconds. Time-to-live or flight time of re-spawned projectiles.


--------------------------------------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------------------------------------

local max  = math.max
local min  = math.min
local sqrt = math.sqrt

local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitRadius           = Spring.GetUnitRadius
local spDeleteProjectile        = Spring.DeleteProjectile
local spSpawnProjectile         = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = -1 * Game.gravity / gameSpeed / gameSpeed


--------------------------------------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
    if weaponDef.customParams.overpen then
        weaponParams[weaponDefID] = {}

        local custom = weaponDef.customParams
        local params = weaponParams[weaponDefID]

        params.decrease = tonumber(custom.overpen_decrease or overpenDecrease)
        params.overkill = tonumber((custom.overpen_overkill or overpenOverkill) + 1)
        params.damage   = weaponDef.damages[0] or weaponDef.damages[Game.armorTypes.vtol]
        params.lifetime = weaponDef.flighttime or overpenDuration * gameSpeed
        params.penDefID = weaponDefID

        if custom.overpen_with_def then
            local penDefID = (WeaponDefNames[custom.overpen_with_def] or weaponDef).id
            if penDefID ~= weaponDefID then
                params.penDefID = penDefID
                local baseVelocity = weaponDef.weaponvelocity
                local openVelocity = WeaponDefs[penDefID].weaponvelocity
                params.velRatio = openVelocity / baseVelocity
                params.lifetime = WeaponDefs[penDefID].flighttime or weaponDef.flighttime
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


--------------------------------------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------------------------------------

local function consumePenetrator(projID, unitID, damage)
    local params = penetrators[projID]
    if spawnFromID[projID] or params[3][unitID] then
        return 0, 0
    end
    params[3][unitID] = true
    penetrators[projID] = nil

    local health, healthMax = spGetUnitHealth(unitID)
    damage = damage * params[2] -- todo: up-armored units

    if damage >= health and damage >= healthMax * damageThreshold then
        params[2] = params[2] - min(health, damage) / params[1].damage - params[1].decrease
        if params[2] > damageThreshold then
            spawnFromID[projID] = params
        end
        -- Negative overkill can be set to preserve heaps:
        damage = max(health, damage * params[1].overkill)
    else
        local impulse = (1 + impulseModifier) / (1 + params[2] * impulseModifier)
        return damage, impulse
    end

    return damage
end

local function respawnPenetrator(projID, unitID, attackID)
    local params = spawnFromID[projID]
    spawnFromID[projID] = nil

    local px, py, pz = spGetProjectilePosition(projID)
    local vx, vy, vz = spGetProjectileVelocity(projID)
    local timeToLive = spGetProjectileTimeToLive(projID)
    spDeleteProjectile(projID)

    local _,_,_, ux, uy, uz = spGetUnitPosition(unitID, true)
    local unitRadius = spGetUnitRadius(unitID)

    -- We have an equation of a sphere and a direction vector.
    -- Now, we can do a bunch of nerd math, sure, or we can be suave gentlecoders.
    local dx, dy, dz = ux - px + unitRadius / vx / 30,
                       uy - py + unitRadius / vy / 30,
                       uz - pz + unitRadius / vz / 30
    local badmove = sqrt(dx * dx + dy * dy + dz * dz) / 30 -- Close enough. Jk it's bad.

    local data = spawnCache
    data.pos[1] = px + badmove * vx
    data.pos[2] = py + badmove * vy
    data.pos[3] = pz + badmove * vz
    data.owner = attackID or -1

    local penDefID = params[1].penDefID
    if params[1].velRatio then
        vx, vy, vz = vx * params[1].velRatio, vy * params[1].velRatio, vz * params[1].velRatio
        timeToLive = timeToLive / params[1].lifetime
        params[1]  = weaponParams[penDefID]
        params[2]  = (1 + params[2]) / 2 -- Reduces the damage loss when spawning a different weaponDef.
        timeToLive = timeToLive * params[1].lifetime
    end

    data.speed[1] = vx
    data.speed[2] = vy
    data.speed[3] = vz
    data.ttl = timeToLive

    -- BUGGED: Projectile lights not moving with spawned projectiles.
    spSpawnProjectile(penDefID, data)
end


--------------------------------------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------------------------------------

function gadget:Initialize()
    if not next(weaponParams) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons with over-penetration found. Removing.")
        gadgetHandler:RemoveGadget(self)
    end
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
    if weaponParams[weaponDefID] then
        penetrators[projID] = { weaponParams[weaponDefID], 1, {} }
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if penetrators[projID] then
        return consumePenetrator(projID, unitID, damage)
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if spawnFromID[projID] then
        respawnPenetrator(projID, unitID, attackID)
    end
end

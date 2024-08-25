function gadget:GetInfo()
    return {
        name    = 'Impactor Over-Penetration',
        desc    = 'Projectiles punch through targets with custom stop behavior.',
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
-- Configuration ---------------------------------------------------------------

local damageThreshold  = 0.1     -- A percentage. Minimum damage (vs. target health) that can overpen.
local explodeThreshold = 0.2     -- A percentage. Minimum damage that detonates, rather than piercing.
local hardStopIncrease = 2.0     -- A coefficient. Reduces the impulse falloff when damage is reduced.

-- Customparam defaults --------------------------------------------------------

local penaltyDefault  = 0.02     -- A percentage. Additional damage falloff per each over-penetration.

local falloffPerType  = {        -- Whether the projectile deals reduced damage after each hit/pierce.
    DGun              = false ,
    Cannon            = true  ,
    LaserCannon       = true  ,
    BeamLaser         = true  ,
 -- LightningCannon   = false ,  -- Use customparams.spark_forkdamage
 -- Flame             = false ,  -- Use customparams.single_hit_multi
    MissileLauncher   = true  ,
    StarburstLauncher = true  ,
    TorpedoLauncher   = true  ,
    AircraftBomb      = true  ,
}

local slowdownPerType = {        -- Whether penetrators respawn with less velocity after each hit.
    DGun              = false ,  -- Without some damage falloff, this does nothing.
    Cannon            = true  ,
    LaserCannon       = false ,
    BeamLaser         = false ,
 -- LightningCannon   = false ,
 -- Flame             = false ,
    MissileLauncher   = true  ,
    StarburstLauncher = true  ,
    TorpedoLauncher   = true  ,
    AircraftBomb      = true  ,
}

--------------------------------------------------------------------------------
--
--    customparams = {
--        overpen         := true,
--        overpen_falloff := <boolean> | see defaults,
--        overpen_penalty := <number>  | see defaults,
--        overpen_pen_def := <string>  | respawns the same def,
--        overpen_exp_def := <string>  | none,
--    }
--
--
--    ┌────────────────────────────────┐
--    │ Falloff for hardStopIncrease=2 │
--    ├─────────────────────┬──────────┤
--    │  Damage Done / Left │ Inertia  │    Inertia is used as the impact force
--    │               100%  │   100%   │    and as the leftover projectile speed.
--    │                90%  │    96%   │
--    │                75%  │    90%   │
--    │                50%  │    75%   │
--    │                25%  │    50%   │
--    │                10%  │    25%   │
--    │                 0%  │     0%   │
--    └─────────────────────┴──────────┘
--
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local floor = math.floor
local min   = math.min
local max   = math.max
local sqrt  = math.sqrt
local atan  = math.atan
local cos   = math.cos

local spGetProjectileDirection  = Spring.GetProjectileDirection
local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spGetUnitPosition         = Spring.GetUnitPosition
local spGetUnitRadius           = Spring.GetUnitRadius
local spSpawnExplosion          = Spring.SpawnExplosion
local spSpawnProjectile         = Spring.SpawnProjectile

local gameSpeed  = Game.gameSpeed
local mapGravity = Game.gravity / gameSpeed / gameSpeed * -1

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find all weapons with an over-penetration behavior.

local weaponParams = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
    if weaponDef.customParams.overpen ~= nil then
        local custom = weaponDef.customParams
        local params = {}

        if weaponDef.damages[0] > 1 then
            params.damages = weaponDef.damages[0]
        else
            params.damages = weaponDef.damages[Game.armorTypes.vtol]
        end

        if  custom.overpen_falloff == "false" or custom.overpen_falloff == "0" or
            custom.overpen_falloff == nil and falloffPerType[weaponDef.type] == false
        then
            params.falloff = false
        else
            params.slowing = slowdownPerType[weaponDef.type] and true or nil
        end

        params.penalty = tonumber(custom.overpen_penalty) or penaltyDefault

        if custom.overpen_pen_def ~= nil then
            local penDefID = (WeaponDefNames[custom.overpen_pen_def] or weaponDef).id
            if penDefID ~= weaponDefID then
                -- The weapon uses different driver and penetrator definitions.
                params.penDefID = penDefID

                local driverVelocity = weaponDef.weaponvelocity
                local penDefVelocity = WeaponDefs[penDefID].weaponvelocity
                params.velRatio = penDefVelocity / driverVelocity

                local driverLifetime = weaponDef.flighttime            or 3 * gameSpeed
                local penDefLifetime = WeaponDefs[penDefID].flighttime or 3 * gameSpeed
                params.ttlRatio = penDefLifetime / driverLifetime
            end
        end

        if custom.overpen_exp_def ~= nil then
            -- When the weapon fails to overpen, it explodes as this alt weapondef.
            -- This can add damage or just visuals to show the projectile stopping.
            -- Use the overpen penalty and falloff to tune the explosion threshold.
            local expDefID = (WeaponDefNames[custom.overpen_exp_def] or weaponDef).id
            if expDefID ~= weaponDefID then
                params.expDefID = expDefID
            end
        end

        weaponParams[weaponDefID] = params
    end
end

-- Cache the table params for SpawnExplosion.

local explosionCaches = {}

for driverDefID, params in pairs(weaponParams) do
    if params.expDefID ~= nil then
        local expDefID = params.expDefID
        local expDef = WeaponDefs[expDefID]

        explosionCaches[expDefID] = {
            weaponDef          = expDefID,
            damages            = expDef.damages,
            damageAreaOfEffect = expDef.damageAreaOfEffect,
            edgeEffectiveness  = expDef.edgeEffectiveness,
            explosionSpeed     = expDef.explosionSpeed,
            ignoreOwner        = expDef.noSelfDamage,
            damageGround       = true,
            craterAreaOfEffect = expDef.craterAreaOfEffect,
            impactOnly         = expDef.impactOnly,
            hitFeature         = expDef.impactOnly and -1 or nil,
            hitUnit            = expDef.impactOnly and -1 or nil,
            projectileID       = -1,
            owner              = -1,
        }
    end
end

-- Keep track of drivers, penetrators, and remaining damage.

local drivers
local respawn
local waiting

local gameFrame = 0
local deltaTime = (1 / gameSpeed) / 2

--------------------------------------------------------------------------------
-- Functions -------------------------------------------------------------------

---Translate the remaining energy of a projectile to its speed and impulse.
local function inertia(damageLeft)
    return (1 + hardStopIncrease) / (1 + hardStopIncrease * damageLeft)
end

---Create an explosion around the impact point of a driver (with an expDef).
local function explodeDriver(projID, expDefID, attackID, unitID, featureID)
    local px, py, pz = spGetProjectilePosition(projID)
    local dx, dy, dz = spGetProjectileDirection(projID)
    local explosion = explosionCaches[expDefID]
    if explosion.impactOnly then
        explosion.hitFeature = featureID
        explosion.hitUnit = unitID
    end
    explosion.owner = attackID
    explosion.projectileID = projID
    spSpawnExplosion(px, py, pz, dx, dy, dz, explosion)
end

---Remove an impactor from tracking and determine its effect on the target.
local function consumeDriver(projID, damage, attackID, unitID, featureID)
    local driver = drivers[projID]
    drivers[projID] = nil

    local health, healthMax
    if unitID ~= nil then
        health, healthMax = spGetUnitHealth(unitID)
    elseif featureID ~= nil then
        health, healthMax = Spring.GetFeatureHealth(unitID)
    end

    local weaponData = driver[1]
    local damageLeft = driver[2]
    damage = damage * damageLeft

    if weaponData.falloff ~= false then
        -- This amount varies broadly between flanking and falloff. The issue
        -- is whether players will be confused when, only on rare occasions,
        -- units will overpen bulkier targets. I prefer greater consistency:
        local damageLoss = health / min(damage, weaponData.damages)
        damageLeft = damageLeft - damageLoss - weaponData.penalty
    end

    if weaponData.expDefID ~= nil and damageLeft <= explodeThreshold then
        explodeDriver(projID, weaponData.expDefID, attackID, unitID, featureID)
        return damage
    end

    if damage > health and damage >= healthMax * damageThreshold then
        if damageLeft > 0 or weaponData.falloff == false then
            if not weaponData.falloff then
                driver[2] = damageLeft
            end
            respawn[projID] = driver
        end
        return damage
    end

    local damageDone = min(1, damage / weaponData.damages)
    return damage, inertia(damageDone) * damageDone
end

---Simulate the overpen effect by creating a new projectile.
local function spawnPenetrator(projID, attackID, penDefID, unitID, featureID)
    local penetrator = respawn[projID]
    respawn[projID] = nil

    local px, py, pz = spGetProjectilePosition(projID)
    local timeToLive = spGetProjectileTimeToLive(projID)
    local vx, vy, vz, vw = spGetProjectileVelocity(projID)

    local driverData = penetrator[1]
    local explodeID = driverData.expDefID

    if driverData.slowing ~= nil then
        local speedLeft = inertia(penetrator[2])
        vx, vy, vz, vw = vx * speedLeft,
                         vy * speedLeft,
                         vz * speedLeft,
                         vw * speedLeft
    end

    if driverData.penDefID ~= nil then
        -- Spawn an alternative weapondef:
        penDefID = driverData.penDefID
        timeToLive = timeToLive * driverData.ttlRatio
        local velRatio = driverData.velRatio
        vx, vy, vz, vw = vx * velRatio,
                         vy * velRatio,
                         vz * velRatio,
                         vw * velRatio
        -- Penetrators may or may not be drivers, themselves:
        penetrator[1] = weaponParams[penDefID] -- nil if not
    end

    local mx, my, mz, radius
    if unitID ~= nil then
        mx, my, mz = select(4, spGetUnitPosition(unitID, true)) -- skip first 3
        radius = spGetUnitRadius(unitID)
    elseif featureID ~= nil then
        mx, my, mz = select(4, Spring.GetFeaturePosition(featureID, true))
        radius = Spring.GetFeatureRadius(featureID)
    end

    -- Get the time to travel to a position opposite the target's sphere collider.
    local frames = (radius / vw) * (cos(atan((mx - px) / radius - vx / vw)) +
                                    cos(atan((my - py) / radius - vy / vw)) +
                                    cos(atan((mz - pz) / radius - vz / vw))) * 2/3
    local latency = frames / gameSpeed

    if frames < timeToLive and latency < 0.075 then
        local spawnParams = {
            gravity = mapGravity,
            owner   = attackID or penetrator[4],
            pos     = { px + frames * vx, py + frames * vy, pz + frames * vz },
            speed   = { vx, vy, vz },
            ttl     = timeToLive,
        }

        -- Penetrators use ultra-naive prediction error to jump to the next frame,
        -- even when their travel time to the spawn point is miniscule. We have no
        -- other way of preventing a penetrator from tunneling target-to-target,
        -- for as long as there are targets, without passing any frames between.

        local predict = latency + 2 * penetrator[3] -- Cumulative prediction error.

        if predict < deltaTime then
            penetrator[3] = predict -- => Time gain, incr error
            local spawnID = spSpawnProjectile(penDefID, spawnParams)
            if spawnID ~= nil and penetrator[1] ~= nil then
                drivers[spawnID] = penetrator
            end
        else
            spawnParams.ttl = max(0.5 + frames, timeToLive - 1) -- Time loss
            if penetrator[1] then
                penetrator[3] = 0 -- => reset error
                waiting[#waiting+1] = { penDefID, spawnParams, penetrator }
            else
                waiting[#waiting+1] = { penDefID, spawnParams }
            end
        end
    elseif explodeID ~= nil then
        explodeDriver(projID, explodeID, attackID, unitID, featureID)
    end
end


--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    if not next(weaponParams) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO,
            "No weapons with over-penetration found. Removing.")
        gadgetHandler:RemoveGadget(self)
        return
    end

    for weaponDefID, params in ipairs(weaponParams) do
        Script.SetWatchProjectile(weaponDefID, true)
    end

    drivers = {}
    respawn = {}
    waiting = {}
    gameFrame = Spring.GetGameFrame()
end

function gadget:GameFrame(frame)
    for ii = #waiting, 1, -1 do
        local spawnData = waiting[ii]
        local spawnID = spSpawnProjectile(spawnData[1], spawnData[2])
        if spawnData[3] ~= nil and spawnID ~= nil then
            drivers[spawnID] = spawnData[3]
        end
        waiting[ii] = nil
    end
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
    if weaponParams[weaponDefID] ~= nil then
        -- driver infos = { params, damageLeft%, frameError, ownerID }
        drivers[projID] = { weaponParams[weaponDefID], 1, 0, ownerID }
    end
end

function gadget:ProjectileDestroyed(projID)
    -- Explode alternate expl_def on terrain hit, ttl end, etc:
    if drivers[projID] ~= nil then
        local expDefID = drivers[projID].expDefID
        if expDefID ~= nil then
            explodeDriver(projID, expDefID, drivers[projID][4])
            drivers[projID] = nil
        end
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if drivers[projID] ~= nil then
        return consumeDriver(projID, damage, attackID, unitID, nil)
    end
end

function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam,
        damage, weaponDefID, projectileID, attackID, attackDefID, attackTeam)
    if drivers[projID] ~= nil then
        return consumeDriver(projID, damage, attackID, nil, featureID)
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam,
    damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if respawn[projID] ~= nil and damage > 0 then
        spawnPenetrator(projID, attackID, weaponDefID, unitID, nil)
    end
end

function gadget:FeatureDamaged(featureID, featureDefID, featureTeam,
    damage, weaponDefID, projectileID, attackID, attackDefID, attackTeam)
    if respawn[projID] ~= nil and damage > 0 then
        spawnPenetrator(projID, attackID, weaponDefID, nil, featureID)
    end
end

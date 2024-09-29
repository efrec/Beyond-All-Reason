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

-- todo @efrec
-- 1. run code in a test scenario
-- 2. check that projectile lights are deleted when projectiles are consumed
-- 3. check that explosions trigger
-- 4. check the damage and impulse values
-- 5. re-add feature overpen, current behavior will be weird

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local damageThreshold  = 0.1     -- A percentage. Minimum damage (vs. target health) that can overpen.
local explodeThreshold = 0.2     -- A percentage. Minimum damage that detonates, rather than piercing.
local hardStopIncrease = 2.0     -- A coefficient. Reduces the impulse falloff when damage is reduced.

-- Customparam defaults --------------------------------------------------------

local penaltyDefault  = 0.02     -- A percentage. Additional damage loss per hit.

local falloffPerType  = {        -- Whether the projectile loses damage per hit.
    DGun              = false ,
    Cannon            = true  ,
    LaserCannon       = true  ,
    BeamLaser         = true  ,
 -- LightningCannon   = false ,  -- Use customparams.spark_forkdamage instead.
 -- Flame             = false ,  -- Use customparams.single_hit_multi instead.
    MissileLauncher   = true  ,
    StarburstLauncher = true  ,
    TorpedoLauncher   = true  ,
    AircraftBomb      = true  ,
}

local slowdownPerType = {        -- Whether penetrators lose velocity, as well.
    DGun              = false ,
    Cannon            = true  ,
    LaserCannon       = false ,
    BeamLaser         = false ,
 -- LightningCannon   = false ,  -- Use customparams.spark_forkdamage instead.
 -- Flame             = false ,  -- Use customparams.single_hit_multi instead.
    MissileLauncher   = true  ,
    StarburstLauncher = true  ,
    TorpedoLauncher   = true  ,
    AircraftBomb      = true  ,
}

--------------------------------------------------------------------------------
--
--    customparams = {
--        overpen         := true
--        overpen_falloff := <boolean> | nil (see defaults)
--        overpen_slowing := <boolean> | nil (see defaults)
--        overpen_penalty := <number> | nil (see defaults)
--        overpen_corpses := "wrecks" | "heaps" | "none" | nil
--        overpen_exp_def := <string> | nil
--    }
--
--    ┌────────────────────────────────┐
--    │ Falloff for hardStopIncrease=2 │
--    ├─────────────────────┬──────────┤
--    │  Damage Done / Left │ Inertia  │    Inertia is used as the impact force
--    │               100%  │   100%   │    and as the leftover projectile speed.
--    │                90%  │    96%   │
--    │                75%  │    90%   │
--    │                50%  │    75%   │ -- e.g. when a penetrator deals half its
--    │                25%  │    50%   │    max damage, it deals 75% max impulse.
--    │                10%  │    25%   │
--    │                 0%  │     0%   │
--    └─────────────────────┴──────────┘
--
--    If you're motivated to know, this gives a new, effective impulse factor
--    equal to the weapon's base impulse factor * (inertia / damage done). This
--    value increases quickly near 0% damage remaining, so the overpen_penalty
--    should be set > 0.01 or so to keep lightweight targets from going flying.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Locals ----------------------------------------------------------------------

local remove = table.remove
local min = math.min

local spGetProjectileDirection  = Spring.GetProjectileDirection
local spGetProjectilePosition   = Spring.GetProjectilePosition
local spGetProjectileVelocity   = Spring.GetProjectileVelocity
local spGetUnitHealth           = Spring.GetUnitHealth
local spSetProjectileVelocity   = Spring.SetProjectileVelocity
local spSpawnExplosion          = Spring.SpawnExplosion

local gameSpeed  = Game.gameSpeed

--------------------------------------------------------------------------------
-- Setup -----------------------------------------------------------------------

-- Find weapons with over-penetration behaviors and optional alt explosion defs.

local weaponParams
local explosionParams
local unitArmorType

-- Keep track of overpen projectiles and their remaining damage.

local projectiles

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function loadOverpenWeapons()
    local falseSet = { [false] = true, ["false"] = true, ["0"] = true, [0] = true }
    local wreckSet = { wrecks = "wrecks", heaps = "heaps", none = "none" }

    for weaponDefID, weaponDef in ipairs(WeaponDefs) do
        -- ! requires noexplode to work correctly
        if weaponDef.noExplode and weaponDef.customParams.overpen then
            local custom = weaponDef.customParams
            local params = {
                damages = weaponDef.damages,
                falloff = (custom.overpen_falloff == nil and falloffPerType[weaponDef.type]
                    or not falseSet[custom.overpen_falloff]) and true or nil,
                slowing = slowdownPerType[weaponDef.type] and true or nil,
                penalty = tonumber(custom.overpen_penalty) or penaltyDefault,
            }
            if custom.overpen_corpses then
                local corpseType = wreckSet[custom.overpen_corpses]
                params.corpses = corpseType
            end
            if custom.overpen_exp_def then
                local expDefID = (WeaponDefNames[custom.overpen_exp_def] or weaponDef).id
                if expDefID ~= weaponDefID then
                    params.expDefID = expDefID
                end
            end
            weaponParams[weaponDefID] = params
        end
    end

    -- todo: detoured a bit here. ain't none of this matter.
    -- todo: remembering wrong that lua has more values in its damages table?
    local damageKeys = {
        paralyzeDamageTime = true,
        impulseFactor = true,
        impulseBoost = true,
        craterMult = true,
        craterBoost = true,
    }

    local exlosionDefaults = {
        craterAreaOfEffect   = 0,
        damageAreaOfEffect   = 0,
        edgeEffectiveness    = 0,
        explosionSpeed       = 0,
        gfxMod               = 0,
        maxGroundDeformation = 0,
        impactOnly           = false,
        ignoreOwner          = false,
        damageGround         = false,
    }

    -- Cache the explosion params and:
    -- - Remove extra lua keys that SpawnExplosion otherwise iters.
    -- - Pass less data to the engine layer by removing defaults.
    for driverDefID, params in pairs(weaponParams) do
        if params.expDefID ~= nil then
            local expDefID = params.expDefID
            local expDef = WeaponDefs[expDefID]

            local damages = table.copy(weaponDef.damages)
            for key, value in pairs(damages) do
                if type(key) ~= "number" and not damageKeys[key] then
                    damages[key] = nil
                end
            end

            local cached = {
                weaponDef          = expDefID,
                damages            = damages,
                damageAreaOfEffect = expDef.damageAreaOfEffect,
                edgeEffectiveness  = expDef.edgeEffectiveness,
                explosionSpeed     = expDef.explosionSpeed,
                ignoreOwner        = expDef.noSelfDamage and true or nil,
                damageGround       = true,
                craterAreaOfEffect = expDef.craterAreaOfEffect,
                impactOnly         = expDef.impactOnly and true or nil,
                hitFeature         = expDef.impactOnly and -1 or nil,
                hitUnit            = expDef.impactOnly and -1 or nil,
                projectileID       = -1,
                owner              = -1,
            }
            for key, value in pairs(explosionDefaults) do
                if cached[key] == value then
                    cached[key] = nil
                end
            end

            explosionParams[expDefID] = cached
        end
    end

    return (next(weaponParams) ~= nil)
end

---Delete a projectile and its projectile lights.
local function consume(projID)
    -- todo: will this remove projectile lights? no clue
    -- todo: might have to do the ol teleport to the woods. to the woods:
    -- Spring.SetProjectilePosition(projID, 400, -1e9, 400)
    Spring.SetProjectileCollision(projID)
    projectiles[projID] = nil
end

---Detonate (and delete) a penetrator that uses a custom explosion as its arrest behavior.
local function explode(projID, expDefID, attackID, unitID, featureID)
    local px, py, pz = spGetProjectilePosition(projID)
    local dx, dy, dz = spGetProjectileDirection(projID)
    consume(projID)

    local explosion = explosionParams[expDefID]
    if explosion.impactOnly then
        explosion.hitFeature = featureID
        explosion.hitUnit = unitID
    end
    explosion.owner = attackID
    explosion.projectileID = projID

    spSpawnExplosion(px, py, pz, dx, dy, dz, explosion)
end

---Translate between relative velocities with varying leftover projectile inertia.
local function getSpeedDecrease(inertiaBefore, inertiaAfter)
    local mod = hardStopIncrease
    return (1 + mod * inertiaAfter) / (1 + mod * inertiaBefore)
end

---When a penetrator is stopped, it deals this enhanced hard-stop/arrest impulse.
local function getArrestImpulse(inertia)
    local mod = hardStopIncrease
    return (mod + 1) / (mod + 1 / inertia) * inertia
end

---When penetrating a target, try to leave behind a specific type of wreckage.
---I got lazy reading how to do this. This is what I'm going with for now.
local function killUnit(unitID, corpseType)
    if corpseType == "none" then
        Spring.DestroyUnit(unitID, false, true, attackID, false)
    elseif corpseType == "wrecks" then
        Spring.DestroyUnit(unitID, false, false, attackID, false)
    elseif corpseType == "heaps" then
        Spring.AddUnitDamage(unitID, health, nil, attackID, weaponDefID, nil, nil, nil)
    end
end

---Diminish overpen projectiles until they run out of inertia/energy. Then, consume them.
local function getOverpenDamage(unitID, unitDefID, damage, weaponDefID, projID, attackID)
    local projectile = projectiles[projID]
    local params = projectile.params
    local inertia = projectile.inertia
    local health, healthMax = spGetUnitHealth(unitID)
    local damageBase = min(params.damages[unitArmorType[unitDefID]], damage)

    if params.falloff then
        damage = damage * inertia
        damageBase = damageBase * inertia

        if damageBase <= health or damageBase < healthMax * damageThreshold then
            consume(projID)
            return damage, getArrestImpulse(inertia)
        end
        local inertiaLoss = health / damageBase + params.penalty
        local inertiaLeft = inertia - inertiaLoss
        if params.expDefID and inertiaLeft <= explodeThreshold then
            explode(projID, params.expDefID, attackID, unitID, featureID)
            return damage, getArrestImpulse(inertia)
        end

        projectile.inertia = inertiaLeft
        if params.slowing then
            local speedMod = getSpeedDecrease(inertia, inertiaLeft)
            local vx, vy, vz = spGetProjectileVelocity(projID)
            spSetProjectileVelocity(projID, vx*speedMod, vy*speedMod, vz*speedMod)
        end
    elseif damageBase < health or damageBase < healthMax * damageThreshold then
        consume(projID)
        return damage, getArrestImpulse(inertia)
    end

    if params.corpses then
        killUnit(unitID, params.corpses)
        return 0, 0
    else
        return damage, inertia
    end
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    if not loadOverpenWeapons() then
        Spring.Log(gadget:GetInfo().name, LOG.INFO,
            "No weapons with over-penetration found. Removing RemoveGadget.")
        gadgetHandler:RemoveGadget(self)
        return
    end

    for weaponDefID, params in pairs(weaponParams) do
        Script.SetWatchProjectile(weaponDefID, true)
    end

    for unitDefID, unitDef in ipairs(UnitDefs) do
        unitArmorType[unitDefID] = unitDef.armorType
    end

    projectiles = {}
end

function gadget:ProjectileCreated(projID, ownerID, weaponDefID)
    if weaponParams[weaponDefID] then
        projectiles[projID] = {
            inertia = 1,
            ownerID = ownerID,
            params  = weaponParams[weaponDefID],
        }
    end
end

function gadget:ProjectileDestroyed(projID)
    if projectiles[projID] then
        local expDefID = projectiles[projID].params.expDefID
        if expDefID then
            explode(projID, expDefID, projectiles[projID].ownerID)
        else
            consume(projID)
        end
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projID, attackID, attackDefID, attackTeam)
    if projectiles[projID] then
        return getOverpenDamage(unitID, unitDefID, damage, weaponDefID, projID, attackID)
    end
end

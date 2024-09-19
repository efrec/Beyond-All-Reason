function gadget:GetInfo()
    return {
        name    = "Impulse and Collision Controller",
        desc    = "Trims excess impulse and configures unit collision responses",
        author  = "efrec",
        date    = "2024",
        version = "1.0",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Customparams setup ----------------------------------------------------------
--                                                                            --
--    unitdef.customparams = {                                                --
--        collision_ctrl_damage = <number>                                    --
--        collision_ctrl_mass   = <number>                                    --
--    }                                                                       --
--                                                                            --
--    weapondef.customparams = {                                              --
--        impulse_ctrl_excess = true                                          --
--        impulse_ctrl_ignore = true                                          --
--    }                                                                       --
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local velDeltaSoftLimit = 4 -- Number, elmos / frame. Hard limit is twice this.

local collisionVelocityMin = 2.67 -- Number, elmos / frame. Also scales damage.
local collisionStrengthMin = 0.10 -- Number, percentage. A value from 0 to 1.
local collisionVerticalDeg = 55 -- Number, degrees. 90 prevents all collisions.

--------------------------------------------------------------------------------
-- Localized values ------------------------------------------------------------

local abs     = math.abs
local min     = math.min
local sqrt    = math.sqrt

local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitPosition = Spring.GetUnitPosition

local mapGravity           = Game.gravity / Game.gameSpeed / Game.gameSpeed * -1
local objectCollisionDefID = Game.envDamageTypes.ObjectCollision
local groundCollisionDefID = Game.envDamageTypes.GroundCollision

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

-- Track excess impulse from weapons and death explosions.

local weaponIgnore = {}
local weaponExcess = {}
local unitVelocity = {}
local velDeltaSoftLimitSq = velDeltaSoftLimit * velDeltaSoftLimit
local checkFrame = 0

-- Track unit collisions and calculate their damage and impulse.

local unitImpactMass = {}
local unitCannotMove = {}
local unitCollDamage = {}
local unitArmorType = {}
local collReflection = {}
local verticalRatio = collisionVerticalDeg / 90

-- Perform impulse and collision controller duties for other gadgets.

local unitSuspended = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function getGeneralCollisionDamage(damage, unitID, unitDefID)
    damage = damage / unitImpactMass[unitDefID]
    if damage >= collisionStrengthMin then
        local _, uvy, _, uvw = spGetUnitVelocity(unitID)
        if -uvy > collisionVelocityMin then
            return damage * unitCollDamage[unitDefID] * sqrt(-uvy / uvw), 0.123
        end
    end
    return 0
end

local function getUnitUnitCollisionDamage(unitID, unitDefID, attackerID, attackerDefID)
    local collisionVelocityMin = collisionVelocityMin
    local uvx, uvy, uvz, uvw = spGetUnitVelocity(unitID)
    local avx, avy, avz, avw = spGetUnitVelocity(attackerID)
        if uvy < -collisionVelocityMin or avy < -collisionVelocityMin then
        local fallUnit = uvw > 0.1 and uvy / uvw or 0.1
        local fallAtkr = avw > 0.1 and avy / avw or 0.1
        local fallTerm = abs(fallUnit - fallAtkr)
        if fallTerm > verticalRatio then
            local rvx, rvy, rvz = avx - uvx, avy - uvy, avz - uvz
            local _,_,_, apx, apy, apz = spGetUnitPosition(attackerID, true)
            local _,_,_, upx, upy, upz = spGetUnitPosition(unitID, true)
            local dpx, dpy, dpz = upx - apx, upy - apy, upz - apz
            local dpw = sqrt(dpx*dpx + dpy*dpy + dpz*dpz)
            dpx, dpy, dpz = dpx / dpw, dpy / dpw, dpz / dpw

            local speedRel = sqrt(rvx*rvx + rvy*rvy + rvz*rvz) - collisionVelocityMin
            local speedPro = rvx * dpx + rvy * dpy + rvz * dpz -- projection of vel and dir

            -- balance term = 1/8 -- Semi-magical, from game speed, bonus health maximum.
            -- elastic term = 1/2 -- Elasticity and/or damage symmetry and reflection.
            -- average term = 2/3 -- Gets the weighted average of 0.5x + 1x.
            local vrelTerm = (1/8) * (1/2) * (2/3) * (0.5 * speedRel + speedPro)

            local collisionStrength = vrelTerm * fallTerm
            if collisionStrength > collisionStrengthMin then
                local massTerm = unitImpactMass[unitDefID]
                massTerm = massTerm / (massTerm + unitImpactMass[attackerDefID])

                -- Damage the attacker.
                local reflect = math.round(collisionStrength * massTerm * unitCollDamage[attackerDefID])
                if collReflection[attackerID] == nil then
                    collReflection[attackerID] = { [unitID] = reflect }
                else
                    collReflection[attackerID][unitID] = reflect
                end
                Spring.AddUnitDamage(
                    attackerID, reflect, nil,
                    unitID, objectCollisionDefID,
                    reflect * 0.123 * -dpx,
                    reflect * 0.123 * -dpy,
                    reflect * 0.123 * -dpz
                )

                -- Damage this unit.
                return collisionStrength * (1 - massTerm) * unitCollDamage[unitDefID], 0.123
            end
        end
    end
    return 0
end

--------------------------------------------------------------------------------
-- Gadget callins --------------------------------------------------------------

do
    local function suspend(unitID)
        unitVelocity[unitID] = nil
        unitSuspended[unitID] = true
    end

    local function resume(unitID)
        unitSuspended[unitID] = nil
    end

    local function watch(unitID, frames)
        local watchFrame = checkFrame + (frames or 1) - 1
        if unitVelocity[unitID] ~= nil then
            unitVelocity[unitID] = {
                math.max(watchFrame, unitVelocity[unitID][1]),
                spGetUnitVelocity(unitID)
            }
        else
            unitVelocity[unitID] = { watchFrame, spGetUnitVelocity(unitID) }
        end
    end

    local function update(unitID)
        if unitVelocity[unitID] ~= nil then
            unitVelocity[unitID] = {
                math.max(checkFrame, unitVelocity[unitID][1]),
                spGetUnitVelocity(unitID)
            }
        end
    end

    local function setVelocity(unitID, vx, vy, vz)
        local velocity = unitVelocity[unitID]
        if velocity ~= nil then
            velocity[2], velocity[3], velocity[4] = vx, vy, vz
        end
    end

    local function setStationary(unitID)
        unitVelocity[unitID] = { math.huge, 0, 0, 0 }
    end

    local function safeImpulse(unitID, unitDefID, x, y, z, w)
        watch(unitID)
        w = w and w^2 or x*x + y*y + z*z
        local scale = (velDeltaSoftLimitSq * unitImpactMass[unitDefID]^2) / w
        if scale < 1 then
            scale = sqrt(scale)
            x = x * scale
            y = y * scale
            z = z * scale
        end
        Spring.AddUnitImpulse(unitID, x, y, z)
    end

    local function unsafeImpulse(unitID, x, y, z)
        watch(unitID)
        Spring.AddUnitImpulse(unitID, x, y, z)
    end

    function gadget:Initialize()
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_SuspendUnit"   , suspend       )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_ResumeUnit"    , resume        )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_WatchUnit"     , watch         )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_UpdateUnit"    , update        )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_SetVelocity"   , setVelocity   )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_HoldInPlace"   , setStationary )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_SafeImpulse"   , safeImpulse   )
        gadgetHandler:RegisterGlobal( "ImpulseCtrl_UnsafeImpulse" , unsafeImpulse )

        local bonusHealthMax = 3.00 -- Needed to guarantee that fall damage remains lethal.
        for unitDefID, unitDef in ipairs(UnitDefs) do
            unitCollDamage[unitDefID] = unitDef.health * (1 + bonusHealthMax)
            unitImpactMass[unitDefID] = math.max(0.1, unitDef.mass or unitDef.metalCost or 20)
            unitCannotMove[unitDefID] = unitDef.canMove and true or nil
            unitArmorType[unitDefID] = unitDef.armorType

            if unitDef.customParams.collision_ctrl_damage then
                unitCollDamage[unitDefID] = tonumber(unitDef.customParams.collision_ctrl_damage)
            end
            if unitDef.customParams.collision_ctrl_mass then
                unitImpactMass[unitDefID] = tonumber(unitDef.customParams.collision_ctrl_mass)
            end
        end

        -- Add engine pseudo-weapons that use negative weaponDefIDs.
        for weaponDefName, weaponDefID in pairs(Game.envDamageTypes) do
            weaponIgnore[weaponDefID] = true
        end

        -- Ignore all moderate impulse units; 0.123 is considered base impulse.
        -- Weapons with an effective impulse factor over 1 are considered exceptional.
        local gameSpeed = Game.gameSpeed
        local frameTime = 1 / gameSpeed
        local unitMassMin = UnitDefNames.armflea and UnitDefNames.armflea.metalCost or 20
        local meterToElmo = 8
        local weaponDefBaseIndex = 0
        for weaponDefID = weaponDefBaseIndex, #WeaponDefs do
            local weaponDef = WeaponDefs[weaponDefID]
            local damages = weaponDef.damages
            local damage = damages[0]
            for i = 1, #damages do damage = math.max(damages[i], damage) end
            local impulse = damages.impulseFactor * (damage + damages.impulseBoost)
            local impulseMaxPerFrame = impulse * (weaponDef.projectiles or 1) *
                math.ceil(math.max(1, frameTime / (weaponDef.burstRate  or 1)) *
                          math.max(1, frameTime / (weaponDef.reloadTime or 1)))

            if  impulse / damage < 0.125 or
                impulseMaxPerFrame / unitMassMin * gameSpeed < meterToElmo
            then
                weaponIgnore[weaponDefID] = true
            elseif weaponDef.damages[0] <= 1 then
                if weaponDef.damages[Game.armorTypes.vtol or 0] > 1 then
                    weaponIgnore[weaponDefID] = true
                end
            elseif weaponDef.customParams and weaponDef.customParams.impulse_ctrl_ignore then
                weaponIgnore[weaponDefID] = true
            elseif (weaponDef.customParams and weaponDef.customParams.impulse_ctrl_excess) or
                impulse / damage > 1
            then
                weaponExcess[weaponDefID] = weaponDef.damages
            end
        end

        checkFrame = Spring.GetGameFrame() + 1
    end
end

function gadget:GameFrame(frame)
    checkFrame = frame + 1
    collReflection = {}

    for unitID in pairs(unitSuspended) do
        unitVelocity[unitID] = nil
    end

    local velDeltaSoftLimit = velDeltaSoftLimit
    local velDeltaSoftLimitSq = velDeltaSoftLimitSq
    local highGravity = 2 * mapGravity
    for unitID, velocity in pairs(unitVelocity) do
        local vx, vy, vz, vw = spGetUnitVelocity(unitID)
        if vw > velDeltaSoftLimit then 
            local velDeltaSq = (vx-velocity[2])^2 + (vy-velocity[3])^2 + (vz-velocity[4])^2
            if velDeltaSq > velDeltaSoftLimitSq then
                -- Rescale from velDeltaSoftLimit elmos/frame to up to twice that.
                -- Manage vertical speed to prevent juggling & spiking units to the ground.
                local scale = sqrt(velDeltaSoftLimitSq / velDeltaSq)
                vx = velocity[2] + scale * (vx - velocity[2])
                vy = velocity[3] + highGravity
                vz = velocity[4] + scale * (vz - velocity[4])
                spSetUnitVelocity(unitID, vx, vy, vz)
            end
        end
        if velocity[1] <= frame then
            unitVelocity[unitID] = nil
        end
    end
end

function gadget:UnitPreDamaged(unitID, unitDefID, teamID, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID)
    if not weaponIgnore[weaponDefID] then
        if not unitVelocity[unitID] then
            unitVelocity[unitID] = { checkFrame, spGetUnitVelocity(unitID) }
        end

        if weaponExcess[weaponDefID] then
            local damages = weaponExcess[weaponDefID]
            local damageBase = min(damage, damages[unitArmorType[unitDefID]])
            local impulse = damages.impulseFactor * (damageBase + damages.impulseBoost)
            local scale = velDeltaSoftLimit * (unitImpactMass[unitDefID] / impulse)
            if scale < 1 and scale > 0.5 then
                -- Gradually apply scaling up to the delta-v hard limit.
                -- wolframalpha input: plot y = 1 - 1/(1 + 1/(1/x -1)^2), 0.5 < x < 1
                scale = 1 / (1 / scale - 1)
                scale = 1 - 1 / (1 + scale * scale)
            end
            return damage, min(1, scale)
        end

    elseif weaponDefID == objectCollisionDefID then
        if attackerID then
            if collReflection[unitID] and collReflection[unitID][attackerID] then
                return collReflection[unitID][attackerID] == damage and damage or 0
            else
                return getUnitUnitCollisionDamage(unitID, unitDefID, attackerID, attackerDefID)
            end
        end
        return getGeneralCollisionDamage(damage, unitID, unitDefID)

    elseif weaponDefID == groundCollisionDefID then
        return getGeneralCollisionDamage(damage, unitID, unitDefID)
    end
end

function gadget:UnitDestroyed(unitID)
    unitVelocity[unitID] = nil
    unitSuspended[unitID] = nil
end

function gadget:UnitLoaded(unitID)
    unitVelocity[unitID] = nil
end

function gadget:UnitUnloaded(unitID)
    unitVelocity[unitID] = nil
end
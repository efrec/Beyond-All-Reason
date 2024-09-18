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
-- Configuration ---------------------------------------------------------------

local velDeltaSoftLimit = 4 -- Number, elmos / frame. Hard limit is double this.

local collisionVelocityMin = 2.67 -- Number, elmos / frame. Also scales damage.
local collisionStrengthMin = 0.10 -- Number, percentage. A value from 0 to 1.

--------------------------------------------------------------------------------
-- Localized values ------------------------------------------------------------

local abs     = math.abs
local sqrt    = math.sqrt
local bit_and = math.bit_and

local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitPosition = Spring.GetUnitPosition

local gameSpeed            = Game.gameSpeed
local mapGravity           = Game.gravity / gameSpeed / gameSpeed * -1
local objectCollisionDefID = Game.envDamageTypes.ObjectCollision
local groundCollisionDefID = Game.envDamageTypes.GroundCollision

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

-- Track excess impulse from weapons and death explosions.

local weaponIgnore = {}
local unitVelocity = {}
local checkFrame = 0

-- Track unit collisions and calculate their damage and impulse.

local unitImpactMass = {}
local unitCannotMove = {}
local unitCollDamage = {}
local unitCollIgnore = {}

-- Perform impulse and collision controller duties for other gadgets.

local unitSuspended = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function isValidCollision(unitID, attackerID)
    -- See: beyond-all-reason/spring/blob/master/rts/Sim/Objects/SolidObject.h#L61
    -- IN_AIR + FALLING + FLYING => 200
    return bit_and(Spring.GetUnitPhysicalState(unitID),     200) > 0 or
           bit_and(Spring.GetUnitPhysicalState(attackerID), 200) > 0
end

local function getGeneralCollisionDamage(damage, unitID, unitDefID)
    if damage >= 8 then
        local _, uvy, _, uvw = spGetUnitVelocity(unitID)
        if uvy < -collisionVelocityMin and uvy / uvw < (-1/3) then
            return damage * ((1 - uvy / uvw) * 0.5) * unitCollDamage[unitDefID] * 0.008, 0.123
        end
    end
    return 0
end

local function getUnitUnitCollisionDamage(unitID, unitDefID, attackerID, attackerDefID)
    local uvx, uvy, uvz, uvw = spGetUnitVelocity(unitID)
    local avx, avy, avz, avw = spGetUnitVelocity(attackerID)
    if uvy < -collisionVelocityMin or avy < -collisionVelocityMin then
        -- Limit to falling units, or clumped units launched upwards will collide instantly.
        local fallUnit = uvw > 0.01 and uvy / uvw or 0.01
        local fallAtkr = avw > 0.01 and avy / avw or 0.01
        local fallTerm = abs(fallUnit - fallAtkr)
        if fallTerm > (1/2) and (fallUnit < -1/3 or fallAtkr < -1/3) then
            local rvx, rvy, rvz = avx - uvx, avy - uvy, avz - uvz
            local _,_,_, apx, apy, apz = spGetUnitPosition(attackerID, true)
            local _,_,_, upx, upy, upz = spGetUnitPosition(unitID, true)
            local dpx, dpy, dpz = upx - apx, upy - apy, upz - apz
            local dpw = sqrt(dpx*dpx + dpy*dpy + dpz*dpz)
            dpx, dpy, dpz = dpx / dpw, dpy / dpw, dpz / dpw

            local speedRel = sqrt(rvx*rvx + rvy*rvy + rvz*rvz) - collisionVelocityMin
            local speedPro = rvx * dpx + rvy * dpy + rvz * dpz -- projection of vel and dir

            local vrelTerm = (1/3) * (0.5 * speedRel + speedPro) / collisionVelocityMin
            local massTerm = unitImpactMass[attackerDefID] /
                (unitImpactMass[unitDefID] + unitImpactMass[attackerDefID])

            local collisionStrength = vrelTerm * massTerm * fallTerm
            if collisionStrength > collisionStrengthMin then
                -- Damage the attacker.
                if unitCollIgnore[attackerID] == nil then
                    unitCollIgnore[attackerID] = { [unitID] = true }
                else
                    unitCollIgnore[attackerID][unitID] = true
                end
                local reflect = vrelTerm * (1 - massTerm) * fallTerm * unitCollDamage[attackerDefID]
                Spring.AddUnitDamage(
                    attackerID, reflect, nil,
                    unitID, objectCollisionDefID,
                    reflect * 0.123 * -dpx,
                    reflect * 0.123 * -dpy,
                    reflect * 0.123 * -dpz
                )
                -- Damage this unit.
                return collisionStrength * unitCollDamage[unitDefID], 0.123
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

    local function safeImpulse(unitID, x, y, z, w)
        watch(unitID)
        w = w or sqrt(x*x + y*y + z*z)
        local mass = UnitDefs[unitID].mass or UnitDefs[unitID].metalCost or 10
        if w > 4 * mass then
            local scale = 1 / (4 * mass)
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
            if  impulse / damage < 0.123 or
                impulseMaxPerFrame / unitMassMin * gameSpeed < meterToElmo
            then
                weaponIgnore[weaponDefID] = true
            elseif weaponDef.damages[0] <= 1 then
                if weaponDef.damages[Game.armorTypes.vtol or 0] > 1 then
                    weaponIgnore[weaponDefID] = true
                end
            end
        end

        local weaponDefID = weaponDefBaseIndex - 1
        while WeaponDefs[weaponDefID] ~= nil do
            weaponIgnore[weaponDefID] = true
            weaponDefID = weaponDefID - 1
        end
        weaponIgnore[objectCollisionDefID] = nil

        local bonusHealthMax = 3.00
        for unitDefID, unitDef in ipairs(UnitDefs) do
            unitCollDamage[unitDefID] = unitDef.health * (1 + bonusHealthMax)
            unitImpactMass[unitDefID] = math.max(0.1, unitDef.mass or unitDef.metalCost or 20)
            unitCannotMove[unitDefID] = unitDef.canMove and true or nil
        end

        checkFrame = Spring.GetGameFrame() + 1
    end
end

function gadget:GameFrame(frame)
    local velDeltaTriggerSq = velDeltaSoftLimit ^ 2
    for unitID in pairs(unitSuspended) do
        unitVelocity[unitID] = nil
    end
    for unitID, velocity in pairs(unitVelocity) do
        local vx, vy, vz = spGetUnitVelocity(unitID)
        local velDeltaSq = (vx-velocity[2])^2+(vy-velocity[3])^2+(vz-velocity[4])^2
        if velDeltaSq > velDeltaTriggerSq then
            -- Rescale from sqrt(threshold) elmos/frame to up to twice that:
            local scale = sqrt(velDeltaTriggerSq / velDeltaSq)
            spSetUnitVelocity(
                unitID,
                scale * (vx - velocity[2]) + velocity[2],  -- Don't rescale gravity:
                scale * (vy - velocity[3]) + velocity[3] + (1 - scale) * mapGravity,
                scale * (vz - velocity[4]) + velocity[4]
            )
            velocity[1] = velocity[1] + 2
        end
        if velocity[1] == frame then
            unitVelocity[unitID] = nil
        end
    end
    checkFrame = frame + 1
    unitCollIgnore = {}
end

function gadget:UnitPreDamaged(unitID, unitDefID, teamID,
    damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID)
    if not unitVelocity[unitID] and not weaponIgnore[weaponDefID] then
        unitVelocity[unitID] = { checkFrame, spGetUnitVelocity(unitID) }
    end

    if weaponDefID == objectCollisionDefID then
        if attackerID then
            if  (unitCollIgnore[unitID]     and unitCollIgnore[unitID][attackerID]) or
                (unitCollIgnore[attackerID] and unitCollIgnore[attackerID][unitID])
            then
                return damage
            elseif isValidCollision(unitID, attackerID) then
                return getUnitUnitCollisionDamage(unitID, unitDefID, attackerID, attackerDefID)
            else
                return 0
            end
        end
        return getGeneralCollisionDamage(damage, unitID, unitDefID)
    end

    if weaponDefID == groundCollisionDefID then
        return getGeneralCollisionDamage(damage, unitID, unitDefID)
    end
end

function gadget:UnitDestroyed(unitID)
    unitVelocity[unitID] = nil
end

function gadget:UnitLoaded(unitID)
    unitVelocity[unitID] = nil
end

function gadget:UnitUnloaded(unitID)
    unitVelocity[unitID] = nil
end
local gadget = gadget ---@type Gadget

---@class SemiballisticWeapon
---@field heightIntoTurn number
---@field cruiseHeight number
---@field turnRadius number
---@field uptimeMinFrames number
---@field uptimeMaxFrames number
---@field rangeMinimum number
---@field acceleration number
---@field speedMin number
---@field speedMax number
---@field turnRate number
---@field gravity? number
---@field cegtag? string
---@field model? string

---@class SemiballisticProjectile
---@field target xyz
---@field ascendHeight number
---@field cruiseHeight number
---@field turnRadius number
---@field acceleration number
---@field speedMax number
---@field speedMin number
---@field turnRate number
---@field pitch number
---@field chaseFactor number

--------------------------------------------------------------------------------

function gadget:GetInfo()
    return {
        name    = "Semiballistic cruise and verticalize",
        desc    = "Trajectory alchemy for projectiles that must not hit terrain",
        author  = "efrec",
        license = "GNU GPL, v2 or later",
        layer   = -10000, -- before other gadgets can process projectiles
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

--------------------------------------------------------------------------------
-- [1] Cruise altitude is set by the launcher and uptime -----------------------
--                                                                            --
--                             (+ extra height)                               --
-- cruise altitude min x------------------------------x                       --
--                    /                                \                      --
--                   /                                  \                     --
--  end uptime pos  x                                    x   verticalized     --
--                  |                                    |                    --
--                  |                                    |                    --
-- launch position  x                                    |                    --
--                                                       |                    --
--                                                       x   target position  --
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- [2] Cruise altitude is set by the target position ---------------------------
--                                                                            --
--                             (+ extra height)                               --
--                     x------------------------------x  cruise altitude min  --
--                    /                                \                      --
--                   /                                  \                     --
-- ascend position  x                                    x   verticalized     --
--                  |                                    |                    --
--                  |                                    |                    --
--  end uptime pos  x                                    x   target position  --
--                  |                                                         --
--                  |                                                         --
-- launch position  x                                                         --
--                                                                            --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local cruiseHeightFloor = 50      -- note: barely above ground
local cruiseHeightCeiling = 10000 -- note: soaring off-screen

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local math_abs = math.abs
local math_clamp = math.clamp
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local math_asin = math.asin
local math_atan2 = math.atan
local math_pi = math.pi

local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileVelocity = Spring.SetProjectileVelocity
local spSetProjectileTarget   = Spring.SetProjectileTarget

local gravityPerFrame = -Game.gravity / Game.gameSpeed ^ 2

local targetedFeature = string.byte('f')
local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons = {}

local ascending = {}
local cruising = {}
local verticalizing = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
    local success = true

    local cruiseHeightMin, cruiseExtraHeight, uptimeMin, uptimeMax

    if weaponDef.customParams.cruise_altitude_min then
        if weaponDef.customParams.cruise_altitude_min == "auto" then
            cruiseHeightMin = "auto" -- determined from uptime
        else
            cruiseHeightMin = tonumber(cruiseHeightMin)
        end
    end

    if weaponDef.customParams.cruise_extra_height then
        cruiseExtraHeight = tonumber(weaponDef.customParams.cruise_extra_height)
    else
        cruiseExtraHeight = 1.0 -- fallback is okay for now
    end

    if weaponDef.customParams.uptime_max then
        uptimeMin = tonumber(weaponDef.customParams.uptime_min)
    elseif weaponDef.customParams.uptime then
        uptimeMin = tonumber(weaponDef.customParams.uptime)
    end

    if weaponDef.customParams.uptime_max then
        uptimeMax = tonumber(weaponDef.customParams.uptime_max)
    elseif weaponDef.customParams.uptime then
        uptimeMax = tonumber(weaponDef.customParams.uptime)
    end

    if not cruiseHeightMin then
        local message = weaponDef.name .. " needs a cruise_altitude_min value"
        Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

        success = false
    end

    if not cruiseExtraHeight then
        local message = weaponDef.name .. " has a bad cruise_extra_height value"
        Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

        success = false
    end

    if not uptimeMin then
        local message = weaponDef.name .. " needs a uptime_min (or uptime) value"
        Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

        success = false
    end

    if not uptimeMax then
        local message = weaponDef.name .. " needs a uptime_max (or uptime) value"
        Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

        success = false
    end

    if not success then
        return
    end

    -- This uses the engine's motion controls so must derive the extents of that motion:

    local acceleration = weaponDef.weaponAcceleration
    local speedMin = weaponDef.startvelocity
    local speedMax = weaponDef.projectilespeed
    local turnRate = weaponDef.turnRate
    local extraHeight = weaponDef.trajectoryHeight

    local uptimeMinFrames = uptimeMin * Game.gameSpeed
    local uptimeMaxFrames = uptimeMax * Game.gameSpeed

    local accelerationFrames = 0
    if acceleration and acceleration ~= 0 then
        accelerationFrames = math_min((speedMax - speedMin) / acceleration, uptimeMinFrames)
    end

    local turnSpeedMin = speedMin + accelerationFrames * acceleration
    local turnHeightMin = turnSpeedMin * (uptimeMinFrames - accelerationFrames * 0.5)
    local turnRadiusMax = speedMax / turnRate / math_pi

    if cruiseHeightMin == "auto" then
        cruiseHeightMin = turnHeightMin + turnRadiusMax
    end

    cruiseHeightMin = math_clamp(cruiseHeightMin, cruiseHeightFloor, cruiseHeightCeiling)

    local rangeMinimum = 2 * (turnSpeedMin / turnRate / math_pi)

    ---@class SemiballisticWeapon
    local weapon = {
        acceleration      = acceleration,
        speedMax          = speedMax,
        speedMin          = speedMin,
        turnRate          = turnRate,
        extraHeight       = extraHeight,

        heightIntoTurn    = turnHeightMin,
        rangeMinimum      = rangeMinimum,
        uptimeMaxFrames   = uptimeMaxFrames,
        uptimeMinFrames   = uptimeMinFrames,

        cruiseHeight      = cruiseHeightMin,
        cruiseExtraHeight = cruiseExtraHeight,
        turnRadius        = turnRadiusMax,
    }

    if weaponDef.myGravity and weaponDef.myGravity ~= 0 then
        weapon.gravity = weaponDef.myGravity
    end

    if weaponDef.model then
        weapon.model = weaponDef.model
    end

    if weaponDef.cegTag then
        weapon.cegtag = weaponDef.cegTag
    end

    return weapon
end

-- Guidance controls -----------------------------------------------------------
-- We do a lot of work in this section to reuse Recoil's engine motion controls,
-- rather than using Lua's, which incurs about 20x the total performance burden,
-- and still doesn't support weapondefs entirely, e.g. missile dance and wobble.

local position = { 0, 0, 0 }
local velocity = { 0, 0, 0, 0 }

local function getPositionAndVelocity(projectileID)
    local position, velocity = position, velocity
    position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
    velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
    return position, velocity
end

local math_sqrt = math.sqrt
local function distanceXZ(vector1, vector2)
    local dx, dz = vector1[1] - vector2[1], vector1[3] - vector2[3]
    return math_sqrt(dx * dx + dz * dz)
end

local function ping(message)
    local p = position
    Spring.MarkerAddPoint(p[1], p[2], p[3], message)
end

local getUptime -- fix for lexical scope, see below

local function newProjectile(projectileID, weaponDefID)
    if respawning then
        return
    end

    local weapon = weapons[weaponDefID]
    local position, velocity = getPositionAndVelocity(projectileID)
    local targetType, target = Spring.GetProjectileTarget(projectileID)

    if targetType == targetedUnit then
        target = { Spring.GetUnitPosition(target) }
        target[2] = Spring.GetGroundHeight(target[1], target[3])
    end

    if target[2] < 0 then
        target[2] = 0
    end

    local turnRadius = weapon.turnRadius
    local ascentAboveLauncher = position[2] + weapon.heightIntoTurn
    local ascentAboveTarget = target[2] + weapon.cruiseHeight - turnRadius
    local ascendHeight = math_max(ascentAboveLauncher, ascentAboveTarget)

    ---@class SemiballisticProjectile
    local projectile = {
        target       = target,
        ascendHeight = ascendHeight,
        acceleration = weapon.acceleration,
        speedMax     = weapon.speedMax,
        speedMin     = weapon.speedMin,
        turnRate     = weapon.turnRate,
        cruiseHeight = weapon.cruiseHeight,
        extraHeight  = weapon.cruiseExtraHeight,
        turnRadius   = turnRadius,

        -- The guidance factors may be updated over time:
        chaseFactor  = 0.25, -- laziness for drop radius > turn radius
    }

    local cruiseDistance = distanceXZ(position, target) - weapon.rangeMinimum
    local uptime = getUptime(projectile, ascendHeight - position[2])
    local uptimeFrames = math_clamp(uptime, weapon.uptimeMinFrames, weapon.uptimeMaxFrames)

    -- MissileProjectiles move controls are almost free (no early `turnToTarget` end):
    local targetHeight = ascendHeight + weapon.turnRadius
    spSetProjectileTarget(projectileID, position[1], targetHeight, position[3]) -- todo: allow firing angles
    ascending[projectileID] = projectile

    -- ping('new projectile')
end

getUptime = function(projectile, height)
    local speedMin = projectile.speedMin
    local speedMax = projectile.speedMax
    local acceleration = projectile.acceleration
    local height = projectile.ascendHeight - position[2]

    if height < speedMax then
        return 0 -- can't fix anything given less than one frame to do it
    elseif acceleration == 0 or speedMin == speedMax then
        return height / speedMax
    end

    local accelTime = (speedMax - speedMin) / acceleration
    local accelDistance = speedMin * accelTime + 0.5 * acceleration * accelTime * accelTime

    if accelDistance <= height then
        local flatTime = (height - accelDistance) / speedMax
        local speedAvg = (flatTime * speedMax + accelTime * (speedMax - speedMin) * 0.5) / (flatTime + accelTime)

        return height / speedAvg
    else
        -- Solve d = 0.5 a t^2 + v_0 t for time t:
        local a, b, c = 0.5 * acceleration, speedMin, -height
        local discriminant = b * b - 4 * a * c

        if discriminant < 0 then
            return 0 -- borked and cannot be unborked but we will try anyway
        else
            discriminant = math_sqrt(discriminant)

            local t1 = (-b + discriminant) / (2 * a)
            local t2 = (-b - discriminant) / (2 * a)

            return (t1 >= 0 and t2 >= 0) and math_min(t1, t2) or (t1 >= 0 and t1 or t2)
        end
    end
end

---Wait for `uptime`.
-- todo: Could be just that simple, an uptime-timer.
---@param projectileID integer
---@param projectile SemiballisticProjectile
local function ascend(projectileID, projectile)
    local position, velocity = getPositionAndVelocity(projectileID)

    if projectile.ascendHeight - position[2] < velocity[2] then
        local target = projectile.target
        local cruiseDistance = distanceXZ(position, target) - 2 * projectile.turnRadius
        if cruiseDistance < 0 then cruiseDistance = 0 end

        projectile.cruiseHeight = position[2] + projectile.turnRadius
        projectile.extraHeight = cruiseDistance * projectile.extraHeight -- convert
        projectile.cruiseDistance = cruiseDistance + 2 * projectile.turnRadius

        -- Start with shallow-ish turn toward level (extra-extra height):
        local targetHeight = projectile.cruiseHeight + (2 * math_pi) * (2 * math_pi) * projectile.extraHeight
        spSetProjectileTarget(projectileID, target[1], targetHeight, target[3])

        ascending[projectileID] = nil
        cruising[projectileID] = projectile
    end
end

---Continues the semiballistic flight plan up to the drop-turn.
---@param projectileID integer
---@param projectile SemiballisticProjectile
local function cruise(projectileID, projectile)
    local position, velocity = getPositionAndVelocity(projectileID)
    local target = projectile.target

    local speed = velocity[4]
    local level = (velocity[2] / speed) + 1
    -- if level < 1 then level = level * level end
    local radius = (projectile.turnRadius + 4 * speed) * (2 * level)

    local distance = distanceXZ(position, target)

    local targetHeight

    if distance - radius > 0 then
        local extra = 2 * math_pi * (distance / projectile.cruiseDistance - 0.5)
        targetHeight = projectile.cruiseHeight + projectile.extraHeight * extra
    else
        targetHeight = target[2]
        cruising[projectileID] = nil
    end

    spSetProjectileTarget(projectileID, target[1], targetHeight, target[3])
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
    for weaponDefID = 0, #WeaponDefs do
        local weaponDef = WeaponDefs[weaponDefID]

        if weaponDef.customParams.cruise_and_verticalize and (
                weaponDef.type == "MissileLauncher" or
                (weaponDef.type == "TorpedoLauncher" and weaponDef.subMissile)
            ) then
            local weapon = parseCustomParams(weaponDef)
            if weapon then
                weapons[weaponDefID] = weapon
                Script.SetWatchProjectile(weaponDefID, true)
            end
        end
    end

    if not next(weapons) then
        Spring.Log(gadget:GetInfo().name, LOG.INFO, "No weapons found.")
        gadgetHandler:RemoveGadget(self)
        return
    end

    -- todo: obviously do not delete everyone's projectiles in production
    local deleteAll = { -1e9, -1e9, 1e9, 1e9, false, false }
    for _, projectileID in ipairs(Spring.GetProjectilesInRectangle(unpack(deleteAll))) do
        Spring.DeleteProjectile(projectileID)
    end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
    if weapons[weaponDefID] then
        newProjectile(projectileID, weaponDefID)
    end
end

function gadget:ProjectileDestroyed(projectileID, ownerID, weaponDefID)
    ascending[projectileID] = nil
    cruising[projectileID] = nil
    verticalizing[projectileID] = nil
end

function gadget:GameFrame(frame)
    for projectileID, projectile in pairs(ascending) do
        ascend(projectileID, projectile)
    end

    for projectileID, projectile in pairs(cruising) do
        cruise(projectileID, projectile)
    end
end

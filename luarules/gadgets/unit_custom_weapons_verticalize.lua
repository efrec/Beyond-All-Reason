local gadget = gadget ---@type Gadget

---@class VerticalizeWeapon
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

---@class VerticalizeProjectile
---@field target xyz
---@field ascendHeight number
---@field cruiseHeight number
---@field turnRadius number
---@field acceleration number
---@field speedMax number
---@field speedMin number
---@field turnRate number
---@field pitch number
---@field cruiseEndRadius number
---@field chaseFactor number

--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name    = "Starburst cruise and verticalize",
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
--    cruise altitude  x------------------------------x                       --
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
--                     x------------------------------x   cruise altitude     --
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

local cruisePitchMax = 30     -- in degrees
local cruiseHeightMin = 50    -- note: barely above ground
local cruiseHeightMax = 10000 -- note: soaring off-screen

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local vector = VFS.Include("common/springUtilities/vector.lua")

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

local displacement = vector.displacement
local distanceXZ = vector.distanceXZ
local rotateTo = vector.rotateTo
local accelerate = vector.accelerate
local updateGuidance = vector.updateGuidance

local gravityPerFrame = -Game.gravity / Game.gameSpeed ^ 2

local targetedFeature = string.byte('f')
local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local cruisePitchTolerance = math.sin(cruisePitchMax * math_pi / 180)

local weapons = {}

local ascending = {}
local leveling = {}
local cruising = {}
local verticalizing = {}

local respawning = false

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
	local success = true

	local cruiseHeight, uptimeMax

	if weaponDef.customParams.cruise_altitude then
		if weaponDef.customParams.cruise_altitude == "auto" then
			cruiseHeight = "auto" -- determined from uptime
		else
			cruiseHeight = tonumber(cruiseHeight)
		end
	end

	if weaponDef.customParams.uptime_max then
		uptimeMax = tonumber(weaponDef.customParams.uptime_max)
	else
		uptimeMax = weaponDef.uptime
	end

	if not cruiseHeight then
		local message = weaponDef.name .. " needs a cruise_altitude value"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	if not uptimeMax then
		local message = weaponDef.name .. " needs a uptime_max value"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

	-- This uses the engine's motion controls so must derive the extents of that motion:

	local acceleration = weaponDef.weaponAcceleration
	local speedMin = weaponDef.startvelocity
	local speedMax = weaponDef.projectilespeed
	local turnRate = weaponDef.turnRate
	local uptimeMin = weaponDef.uptime

	local uptimeMinFrames = uptimeMin * Game.gameSpeed
	local uptimeMaxFrames = uptimeMax * Game.gameSpeed

	local accelerationFrames = 0
	if acceleration and acceleration ~= 0 then
		accelerationFrames = math_min((speedMax - speedMin) / acceleration, uptimeMinFrames)
	end

	local turnSpeedMin = speedMin + accelerationFrames * acceleration
	local turnHeightMin = turnSpeedMin * (uptimeMinFrames - accelerationFrames * 0.5)
	local turnRadiusMax = speedMax / turnRate / math_pi

	if cruiseHeight == "auto" then
		cruiseHeight = turnHeightMin + turnRadiusMax
	end

	cruiseHeight = math_clamp(cruiseHeight, cruiseHeightMin, cruiseHeightMax)

	local rangeMinimum = 2 * (turnSpeedMin / turnRate / math_pi)

	---@class VerticalizeWeapon
	local weapon = {
		acceleration    = acceleration,
		speedMax        = speedMax,
		speedMin        = speedMin,
		turnRate        = turnRate,

		heightIntoTurn  = turnHeightMin,
		rangeMinimum    = rangeMinimum,
		uptimeMaxFrames = uptimeMaxFrames,
		uptimeMinFrames = uptimeMinFrames,

		cruiseHeight    = cruiseHeight,
		turnRadius      = turnRadiusMax,
	}

	-- Additional properties for SpawnProjectiles:

	if weaponDef.myGravity and weaponDef.myGravity ~= 0 then
		weapon.gravity = weaponDef.myGravity
	end

	if weaponDef.model then
		weapon.model = weaponDef.model
	end

	if weaponDef.cegTag then
		weapon.cegtag = weaponDef.cegTag
	end

	if success then
		return weapon
	end
end

-- Guidance controls -----------------------------------------------------------
-- We do a lot of work in this section to reuse Recoil's engine motion controls,
-- rather than using Lua's, which incurs about 20x the total performance burden,
-- and still doesn't support weapondefs entirely, e.g. missile dance and wobble.

local position = { 0, 0, 0, isInCylinder = vector.isInCylinder }
local velocity = { 0, 0, 0, 0 }

local function getPositionAndVelocity(projectileID)
	local position, velocity = position, velocity
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return position, velocity
end

local getUptime, respawnProjectile -- fix for lexical scope, see below

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

	---@class VerticalizeProjectile
	local projectile = {
		target          = target,
		ascendHeight    = ascendHeight,
		acceleration    = weapon.acceleration,
		speedMax        = weapon.speedMax,
		speedMin        = weapon.speedMin,
		turnRate        = weapon.turnRate,
		cruiseHeight    = weapon.cruiseHeight,
		turnRadius      = turnRadius,

		-- The guidance factors may be updated over time:
		pitch           = 0, -- arbitrary
		cruiseEndRadius = 1e9, -- arbitrary
		chaseFactor     = 0.25, -- laziness for drop radius > turn radius
	}

	local cruiseDistance = distanceXZ(position, target) - weapon.rangeMinimum
	local cruiseHeightTolerance = cruiseDistance * cruisePitchTolerance
	local uptime = getUptime(projectile, ascendHeight - position[2])
	local uptimeFrames = math_clamp(uptime, weapon.uptimeMinFrames, weapon.uptimeMaxFrames)

	if uptimeFrames >= weapon.uptimeMinFrames + 0.5 then
		respawnProjectile(projectileID, projectile, uptime)
		return
	elseif cruiseDistance <= 0 then
		return
	end

	-- We can use StarburstProjectile controls until `turnToTarget` is disabled:
	local targetHeight = ascendHeight + weapon.turnRadius
	Spring.SetProjectileTarget(projectileID, target[1], targetHeight, target[3])
	ascending[projectileID] = projectile
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

---@class ProjectileParams
local projectileParams = {
	pos   = position,
	speed = velocity,
}

respawnProjectile = function(projectileID, projectile, uptime)
	if uptime > 0 then
		local spawnParams = projectileParams
		spawnParams.owner = Spring.GetProjectileOwnerID(projectileID)
		spawnParams.ttl = Spring.GetProjectileTimeToLive(projectileID)
		spawnParams['end'] = projectile.target
		spawnParams.gravity = projectile.gravity
		spawnParams.model = projectile.model
		spawnParams.cegTag = projectile.cegTag
		spawnParams.uptime = uptime
		spawnParams.speed[4] = nil -- need `xyza` => `xyz`

		local weaponDefID = Spring.GetProjectileDefID(projectileID)
		Spring.DeleteProjectile(projectileID)

		-- todo: errors after this point will leave `respawning` as true
		-- todo: which idk how even to handle in lua, so that's nice
		respawning = true

		local respawnID = Spring.SpawnProjectile(weaponDefID, spawnParams)

		respawning = false

		if respawnID then
			ascending[respawnID] = projectile
			return true
		end
	end

	-- Restore default behavior on fallthrough:
	local target = projectile.target
	Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
	return false
end

---Wait for `uptime`.
-- todo: Could be just that simple, an uptime-timer.
---@param projectileID integer
---@param projectile VerticalizeProjectile
local function ascend(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)

	if projectile.ascendHeight - position[2] < velocity[2] then
		ascending[projectileID] = nil
		leveling[projectileID] = projectile
	end
end

---Waits on the `turnToTarget` timeout or short-circuits it with a distance check.
---@param projectileID integer
---@param projectile VerticalizeProjectile
local function turnToLevel(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)
	local speed = velocity[4]
	local pitch = math_clamp(velocity[2] / speed, -1, 1) -- fix for float instability
	local radius = getVerticalizeRadius(projectile.turnRadius, speed, pitch)

	if (math_abs(pitch - projectile.pitch) > 1e-6 and not position:isInCylinder(projectile.target, radius)) then
		projectile.pitch = pitch
	else
		projectile.cruiseEndRadius = radius

		leveling[projectileID] = nil
		cruising[projectileID] = projectile
	end
end

---Continues the level flight plan up to the drop-turn.
-- todo: Can be made into a simple timer, as well.
---@param projectileID integer
---@param projectile VerticalizeProjectile
local function cruise(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)
	local target = projectile.target

	if position:isInCylinder(target, projectile.cruiseEndRadius) then
		Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
		Spring.SetProjectileMoveControl(projectileID, true)

		cruising[projectileID] = nil
		verticalizing[projectileID] = projectile
	end
end

---Uses generalized, simple guidance to track onto the target position.
---The flight plan up until now is high above the target, though, so this
---turns toward the vertical directly above the target, then handles misses.
---@param projectileID integer
---@param projectile VerticalizeProjectile
local function verticalize(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)

	if not updateGuidance(
			position,
			velocity,
			projectile.target,
			projectile.speedMax,
			projectile.acceleration,
			projectile.turnRate,
			projectile.chaseFactor
		)
	then
		-- Projectile is within the minimum path distance from the target.
		accelerate(velocity, projectile.acceleration, projectile.speedMax)
		-- todo: if weapon is not tracking, do not correct course after a miss
		projectile.chaseFactor = 0 -- in case it misses anyway, somehow.
	end

	spSetProjectilePosition(projectileID, position[1], position[2], position[3])
	spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID = 0, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponDefID]
		if weaponDef.type == "StarburstLauncher" and
			weaponDef.customParams.cruise_and_verticalize
		then
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
	leveling[projectileID] = nil
	cruising[projectileID] = nil
	verticalizing[projectileID] = nil
end

function gadget:GameFrame(frame)
	for projectileID, projectile in pairs(ascending) do
		ascend(projectileID, projectile)
	end

	for projectileID, projectile in pairs(leveling) do
		turnToLevel(projectileID, projectile)
	end

	for projectileID, projectile in pairs(cruising) do
		cruise(projectileID, projectile)
	end

	for projectileID, projectile in pairs(verticalizing) do
		verticalize(projectileID, projectile)
	end
end

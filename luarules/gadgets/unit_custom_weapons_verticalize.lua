local gadget = gadget ---@type Gadget

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

local cruisePitchMax = 30
local cruiseHeightMin = 50    -- barely above ground
local cruiseHeightMax = 10000 -- soaring off-screen

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local vector = VFS.Include("common/springUtilities/vector.lua")

local math_abs = math.abs
local math_min = math.min
local math_sqrt = math.sqrt
local math_asin = math.asin
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

cruisePitchMax = cruisePitchMax * math_pi / 180

local weapons = {}

for weaponDefID = 0, #WeaponDefs do
	local weaponDef = WeaponDefs[weaponDefID]

	if weaponDef.customParams.cruise_and_verticalize and weaponDef.type == "StarburstLauncher" then
		local cruiseHeight, uptimeMin, uptimeMax

		if weaponDef.customParams.cruise_altitude then
			if weaponDef.customParams.cruise_altitude == "auto" then
				cruiseHeight = "auto" -- determined from uptime and other stats
			else
				cruiseHeight = tonumber(cruiseHeight)
			end
		end

		if weaponDef.customParams.uptime_min then
			uptimeMin = tonumber(weaponDef.customParams.uptime)
			uptimeMax = weaponDef.uptime
		else
			uptimeMin = weaponDef.uptime
		end

		-- This uses the engine's motion controls so must derive the extents of that motion:

		local speedMin = weaponDef.startvelocity
		local speedMax = weaponDef.projectilespeed
		local acceleration = weaponDef.weaponAcceleration
		local turnRate = weaponDef.turnRate

		local uptimeMinFrames = uptimeMin * Game.gameSpeed

		local accelerationFrames = 0
		if acceleration and acceleration ~= 0 then
			accelerationFrames = math.min(
				(speedMax - speedMin) / acceleration,
				uptimeMinFrames
			)
		end

		local turnSpeedMin = speedMin + accelerationFrames * acceleration

		local turnHeightMin = turnSpeedMin * (uptimeMinFrames - accelerationFrames * 0.5)
		local turnRadiusMax = speedMax / turnRate / math_pi

		if cruiseHeight == "auto" then
			cruiseHeight = turnHeightMin + turnRadiusMax
		end

		cruiseHeight = math.clamp(cruiseHeight, cruiseHeightMin, cruiseHeightMax)

		if not uptimeMax then
			local ttl = weaponDef.flightTime or weaponDef.range / speedMax
			uptimeMax = math.max(uptimeMin, ttl / 3)
		end

		local uptimeMaxFrames = uptimeMax * Game.gameSpeed

		local rangeMinimum = 2 * (turnSpeedMin / turnRate / math_pi)

		local weapon = {
			heightIntoTurn  = turnHeightMin,
			cruiseHeight    = cruiseHeight,
			turnRadius      = turnRadiusMax,

			uptimeMinFrames = uptimeMinFrames,
			uptimeMaxFrames = uptimeMaxFrames,
			rangeMinimum    = rangeMinimum,

			acceleration    = acceleration,
			speedMin        = speedMin,
			speedMax        = speedMax,
			turnRate        = turnRate,
		}

		-- Additional properties for SpawnProjectiles:
		if weaponDef.myGravity then
			weapon.gravity = weaponDef.myGravity
		end

		if weaponDef.model then
			weapon.model = weaponDef.model
		end

		if weaponDef.cegTag then
			weapon.cegtag = weaponDef.cegTag
		end

		weapons[weaponDefID] = weapon
	end
end

local ascending = {}
local leveling = {}
local cruising = {}
local verticalizing = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local position = { 0, 0, 0, isInCylinder = vector.isInCylinder }
local velocity = { 0, 0, 0, 0 }

local function getPositionAndVelocity(projectileID)
	local position, velocity = position, velocity
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return position, velocity
end

local repack3
do
	local float3 = { 0, 0, 0 }
	repack3 = function(x, y, z)
		local float3 = float3
		float3[1], float3[2], float3[3] = x, y, z
		return float3
	end
end

local function getUptime(params, position)
	local speedMin = params.speedMin
	local speedMax = params.speedMax
	local acceleration = params.acceleration

	local heightDifference = params.target[2] - position[2]
	local heightFromWeapon = params.cruiseHeight - params.turnRadius

	-- todo: ascendHeight will change
	local height = math.max(heightDifference + heightFromWeapon, heightFromWeapon)

	if height <= speedMax then
		return 0
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
		-- Solve distance = 0.5 a t^2 + v_0 t for time t:
		-- todo: why did I do this when accel is positive?
		local a, b, c = 0.5 * acceleration, speedMin, -height
		local discriminant = b * b - 4 * a * c

		if discriminant < 0 then
			return 0 -- borked and cannot be unborked but we will try anyway
		else
			discriminant = math_sqrt(discriminant)

			local t1 = (-b + discriminant) / (2 * a)
			local t2 = (-b - discriminant) / (2 * a)

			return (t1 >= 0 and t2 >= 0) and math.min(t1, t2) or (t1 >= 0 and t1 or t2)
		end
	end
end

local respawning = false

local respawnProjectile
do
	local spawnCache = {
		pos   = position,
		speed = velocity,
	}

	respawnProjectile = function(projectileID, params, uptime)
		if uptime then
			local weaponDefID = Spring.GetProjectileDefID(projectileID)

			local _, velocity = getPositionAndVelocity(projectileID)
			velocity[4] = nil -- pass as float3 to ParseProjectileParams

			spawnCache.owner = Spring.GetProjectileOwnerID(projectileID)
			spawnCache.ttl = Spring.GetProjectileTimeToLive(projectileID)
			spawnCache['end'] = params.target
			spawnCache.gravity = params.gravity
			spawnCache.model = params.model
			spawnCache.cegTag = params.cegTag
			spawnCache.uptime = uptime

			Spring.DeleteProjectile(projectileID)

			respawning = true

			local respawnID = Spring.SpawnProjectile(weaponDefID, spawnCache)

			respawning = false

			if respawnID then
				ascending[respawnID] = params
			end
		else
			-- Restore default behavior:
			local target = params.target
			Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
		end
	end
end

local function newProjectile(projectileID, weaponDefID)
	local weapon = weapons[weaponDefID]
	local position, velocity = getPositionAndVelocity(projectileID)
	local targetType, target = Spring.GetProjectileTarget(projectileID)

	if type(target) == "number" then
		if targetType == targetedUnit then
			target = { Spring.GetUnitPosition(target) }
		elseif targetType == targetedFeature then
			target = { Spring.GetFeaturePosition(targets) }
		else
			return
		end
		target[2] = Spring.GetGroundHeight(target[1], target[3])
	end

	if target[2] < 0 then
		target[2] = 0
	end

	if not position:isInCylinder(target, weapon.rangeMinimum) then
		local ascentAboveLauncher = position[2] + weapon.heightIntoTurn
		local ascentAboveTarget = target[2] + weapon.cruiseHeight - weapon.turnRadius

		local ascent = math.max(ascentAboveLauncher, ascentAboveTarget)

		local projectile = {
			target       = target,
			ascendHeight = ascent,
			cruiseHeight = weapon.cruiseHeight,
			turnRadius   = weapon.turnRadius,
			acceleration = weapon.acceleration,
			speedMax     = weapon.speedMax,
			speedMin     = weapon.speedMin,
			turnRate     = weapon.turnRate,
		}

		local cruiseDistance = distanceXZ(position, target) - weapon.rangeMinimum
		local cruiseHeightTolerance = cruiseDistance * math_sin(cruisePitchMax)

		-- todo: a weapon property maybe
		if target[2] - position[2] <= weapon.heightIntoTurn + cruiseHeightTolerance then
			-- This will level out after `uptime` is reached and path toward the target,
			-- then the StarburstProjectile disables its `turnToTarget` extremely early:
			local cruiseHeightTarget = projectile.ascendHeight + weapon.turnRadius
			Spring.SetProjectileTarget(projectileID, target[1], cruiseHeightTarget, target[3])
			ascending[projectileID] = projectile
		else
			-- StarburstProjectile will run out of uptime too soon.
			-- We fix that by respawning them with a larger uptime:
			respawnProjectile(projectileID, projectile, getUptime(projectile, position))
		end
	end
end

local function ascend(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)

	if projectile.ascendHeight - position[2] < velocity[4] then
		ascending[projectileID] = nil
		leveling[projectileID] = projectile
	end
end

---Determines the end of the cruise distance on the horizontal flight plan.
---The expected result is a smoothed-out turn slightly wider than the projectile's `turnRadius`.
---@param turnRadius number
---@param speed number
---@param level number [0, 2] 0: vertical down, 1: level, 2: vertical up
---@return number radius
local function getDropRadiusXZ(turnRadius, speed, level)
	-- Fast projectiles create long smoke trails (per frame) which look very jagged.
	-- On aesthetic grounds, then, smoothing out the turn by widening it looks better.
	return (turnRadius + 5 * speed) * (2 * level)
end

local function turnToLevel(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)
	local speed = velocity[4]

	local pitchLast = projectile.pitch or 0
	local pitch = math.atan2(velocity[2], speed)

	-- todo: It's the responsibility of the uptime min/max ranging to allow for a specific
	-- todo: maximum pitch between the initial ascend height and the final vertical height
	if pitch < math_pi / 8 then -- todo: so we should know what that max angle is
		local level = (1 + math.asin(pitch)) ^ 2
		local radiusXZ = getDropRadiusXZ(projectile.turnRadius, speed, level)

		if not position:isInCylinder(projectile.target, radiusXZ) and
			math_abs(pitch - pitchLast) >= 1e-6
		then
			projectile.pitch = pitch
		else
			projectile.pitch = nil
			projectile.level = level

			leveling[projectileID] = nil
			cruising[projectileID] = projectile
		end
	end
end

local function cruise(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)

	local target = projectile.target
	local radiusXZ = getDropRadiusXZ(projectile.turnRadius, velocity[4], projectile.level)

	if position:isInCylinder(target, radiusXZ) then
		Spring.SetProjectileMoveControl(projectileID, true)
		Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])

		cruising[projectileID] = nil
		verticalizing[projectileID] = projectile
	end
end

local function verticalize(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)

	-- At large distances, make guidance slightly lazier:
	local chaseFactor = 0.25

	local updated = updateGuidance(
		position,
		velocity,
		projectile.target,
		projectile.speedMax,
		projectile.acceleration,
		projectile.turnRate,
		chaseFactor
	)

	if updated then
		spSetProjectilePosition(projectileID, position[1], position[2], position[3])
		spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
	else
		if updated == false then
			-- Projectile is almost directly on top of the target.
			accelerate(velocity, projectile.acceleration, projectile.speedMax)
		else
			-- Guidance failed. That's not good. Try to fix this:
			rotateTo(velocity, repack3(displacement(position, projectile.target)))
		end

		spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
		Spring.SetProjectileMoveControl(projectileID, false)

		verticalizing[projectileID] = nil
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	if not next(weapons) then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "No weapons found.")
		gadgetHandler:RemoveGadget(self)
	else
		for weaponDefID in pairs(weapons) do
			Script.SetWatchProjectile(weaponDefID, true)
		end
	end

	-- todo: obviously do not delete everyone's projectiles in production
	local big = 1e9
	for _, projectileID in ipairs(Spring.GetProjectilesInRectangle(-big, -big, big, big, false, false)) do
		Spring.DeleteProjectile(projectileID)
	end
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weapons[weaponDefID] and not respawning then
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

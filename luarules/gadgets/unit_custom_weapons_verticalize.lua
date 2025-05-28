local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Semiballistic cruise and verticalize",
		desc    = "Trajectory alchemy for projectiles that must not hit terrain",
		author  = "efrec",
		license = "GNU GPL, v2 or later",
		layer   = -10000, -- before other gadgets can process projectiles -- todo: check specifics
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

local cruiseHeightFloor       = 50    -- note: barely above ground
local cruiseHeightCeiling     = 10000 -- note: soaring off-screen

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local spGetGroundHeight       = Spring.GetGroundHeight
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget   = Spring.GetProjectileTarget
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitPosition       = Spring.GetUnitPosition
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget   = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local gravityPerFrame         = -Game.gravity / (Game.gameSpeed ^ 2)

local targetedGround          = string.byte('g')
local targetedUnit            = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons                 = {}

local ascending               = {}
local cruising                = {}
local verticalizing           = {}

local position                = { 0, 0, 0 } ---@type float3
local velocity                = { 0, 0, 0 } ---@type float3

local respawning              = false

---@type ProjectileParams
local projectileParams        = {
	pos   = position,
	speed = velocity,
}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function parseCustomParams(weaponDef)
	local success = true

	local cruiseHeightMin, cruiseExtraHeight, uptimeMin, uptimeMax

	-- StarburstLauncher weapons have an early timeout that we have to handle
	-- and a different set of weapondef properties from missiles (e.g. uptime).
	local isStarburstWeapon = weaponDef.type == "StarburstLauncher"

	if weaponDef.customParams.cruise_altitude_min then
		if weaponDef.customParams.cruise_altitude_min == "auto" then
			cruiseHeightMin = "auto" -- determined from uptime
		else
			cruiseHeightMin = tonumber(weaponDef.customParams.cruise_altitude_min)
		end
	end

	if weaponDef.customParams.cruise_extra_height then
		cruiseExtraHeight = tonumber(weaponDef.customParams.cruise_extra_height)
	elseif weaponDef.trajectoryHeight > 0 then
		cruiseExtraHeight = weaponDef.trajectoryHeight -- does not work quite correctly

		local message = weaponDef.name .. " should not use trajectoryHeight"
		Spring.Log(gadget:GetInfo().name, LOG.NOTICE, message)
	else
		cruiseExtraHeight = 1.0 -- so a fallback value is okay for now
	end

	if isStarburstWeapon then
		uptimeMin = weaponDef.uptime
	elseif weaponDef.customParams.uptime_min then
		uptimeMin = tonumber(weaponDef.customParams.uptime_min)
	elseif weaponDef.customParams.uptime then
		uptimeMin = tonumber(weaponDef.customParams.uptime)
	end

	if weaponDef.customParams.uptime_max then
		uptimeMax = tonumber(weaponDef.customParams.uptime_max)
	elseif weaponDef.customParams.uptime then
		uptimeMax = tonumber(weaponDef.customParams.uptime)
	else
		uptimeMax = uptimeMin
	end

	-- We should yell more often about bad customparams when we can:

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

	-- This gadget uses the engine's motion controls. Derive the extents of that motion:

	local acceleration = weaponDef.weaponAcceleration
	local speedMin = weaponDef.startvelocity
	local speedMax = weaponDef.projectilespeed
	local turnRate = weaponDef.turnRate

	if turnRate == 0 then
		local message = weaponDef.name .. " cannot define a curve without a turnRate"
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)

		success = false
	end

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
	cruiseExtraHeight = math_clamp(cruiseExtraHeight, (isStarburstWeapon and 1 or 0), 4)

	local rangeMinimum = 2 * (turnSpeedMin / turnRate / math_pi) -- maybe overcompensates for slow accel?

	---@class VerticalMissileWeapon
	local weapon = {
		acceleration      = acceleration,
		speedMax          = speedMax,
		speedMin          = speedMin,
		turnRate          = turnRate,

		heightIntoTurn    = turnHeightMin,
		rangeMinimum      = rangeMinimum,
		uptimeMaxFrames   = uptimeMaxFrames,
		uptimeMinFrames   = uptimeMinFrames,
		respawning        = isStarburstWeapon,

		cruiseHeight      = cruiseHeightMin,
		cruiseExtraHeight = cruiseExtraHeight,
		turnRadius        = turnRadiusMax,
	}

	if isStarburstWeapon then
		-- Get the ProjectileParams properties for SpawnProjectile.
		if weaponDef.myGravity and weaponDef.myGravity ~= 0 then
			weapon.gravity = weaponDef.myGravity
		end

		if weaponDef.model then
			weapon.model = weaponDef.model
		end

		if weaponDef.cegTag then
			weapon.cegtag = weaponDef.cegTag
		end
	end

	if success then
		return weapon
	end
end

-- todo: achieve the target curve using only SetProjectileTarget and engine move controls
-- todo: do this by extending the tangent line of the curve to the target axis
-- todo: and, from the first point onward, changing only the height above target

local getPositionAndVelocity, getUptime, respawnWithUptime -- lexical scope fix, see below

local function newProjectile(projectileID, weaponDefID)
	if respawning then
		return
	end

	local weapon = weapons[weaponDefID]

	local position, velocity = getPositionAndVelocity(projectileID)
	local targetType, target = spGetProjectileTarget(projectileID)

	if targetType == targetedUnit then
		target = { spGetUnitPosition(target) }
		target[2] = spGetGroundHeight(target[1], target[3])
	end

	if target[2] < 0 then
		target[2] = 0
	end

	local turnRadius = weapon.turnRadius
	local ascentAboveLauncher = position[2] + weapon.heightIntoTurn
	local ascentAboveTarget = target[2] + weapon.cruiseHeight - turnRadius
	local ascendHeight = math_max(ascentAboveLauncher, ascentAboveTarget)

	---@class VerticalMissileProjectile
	local projectile = {
		acceleration = weapon.acceleration,
		speedMax     = weapon.speedMax,
		speedMin     = weapon.speedMin,
		turnRate     = weapon.turnRate,
		cruiseHeight = weapon.cruiseHeight,
		extraHeight  = weapon.cruiseExtraHeight,
		turnRadius   = turnRadius,

		-- todo: entire flight plan could be set here
		target       = target,
		ascendHeight = ascendHeight,
	}

	local cruiseDistance = distanceXZ(position, target) - weapon.rangeMinimum
	local uptime = getUptime(projectile, ascendHeight - position[2])
	local uptimeFrames = math_clamp(uptime, weapon.uptimeMinFrames, weapon.uptimeMaxFrames)

	if weaponDef.type ~= "StarburstLauncher" or
		uptimeFrames < weapon.uptimeMinFrames + 0.5 or
		not respawnWithUptime(projectileID, projectile, uptime) -- fallback to normal behavior
	then
		local targetHeight = ascendHeight + turnRadius
		spSetProjectileTarget(projectileID, position[1], targetHeight, position[3]) -- todo: allow firing angles
		ascending[projectileID] = projectile
	end
end

getPositionAndVelocity = function(projectileID)
	local p, v, speed = position, velocity
	p[1], p[2], p[3] = spGetProjectilePosition(projectileID)
	v[1], v[2], v[3], speed = spGetProjectileVelocity(projectileID)
	return p, v, speed
end

local function distanceXZ(position1, position2)
	local dx, dz = position1[1] - position2[1], position1[3] - position2[3]
	return math_sqrt(dx * dx + dz * dz)
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

respawnWithUptime = function(projectileID, projectile, uptime)
	if uptime > 0 then
		local weaponDefID = Spring.GetProjectileDefID(projectileID)

		local spawnParams = projectileParams
		spawnParams.owner = Spring.GetProjectileOwnerID(projectileID)
		spawnParams.ttl = Spring.GetProjectileTimeToLive(projectileID)
		spawnParams['end'] = projectile.target
		spawnParams.gravity = projectile.gravity
		spawnParams.model = projectile.model
		spawnParams.cegTag = projectile.cegTag
		spawnParams.uptime = uptime

		-- todo: errors after this point will leave `respawning` as true
		-- todo: which idk how even to handle in lua, so that's nice
		respawning = true

		local respawnID = Spring.SpawnProjectile(weaponDefID, spawnParams)

		respawning = false

		if respawnID then
			ascending[respawnID] = projectile

			-- Late delete means we can fallback to the default behavior
			-- but also means we can fail due to projectile count limit.
			Spring.DeleteProjectile(projectileID)

			return true
		end
	end
	return false
end

local function cruiseStart(projectileID, projectile, position, velocity)
	local extraHeight = projectile.extraHeight -- as percentage
	local target = projectile.target
	local turnRadius = projectile.turnRadius
	local turnRate = projectile.turnRate

	local cruiseHeight = position[2] + turnRadius

	local cruiseDistance = distanceXZ(position, target) - 2 * turnRadius
	if cruiseDistance < 0 then cruiseDistance = 0 end
	cruiseDistance = cruiseDistance + 2 * turnRadius

	extraHeight = extraHeight * cruiseDistance -- as distance

	-- ? method 1
	-- -- The approximate radius of our circular trajectory (exact for extraHeight == 1):
	-- local radius = extraHeight * 0.5 + cruiseDistance * cruiseDistance / (8 * extraHeight)
	-- -- And its approximate chord half-angle that we can use to construct a target height:
	-- local angle = math_asin(cruiseDistance / (2 * radius))
	-- -- StarburstProjectiles need to prevent aligning perfectly to the target:
	-- angle = math_min(angle, math_pi * 0.5 - 1.25 * turnRate)
	-- local targetHeight = position[2] + cruiseDistance * math_sin(angle)
	-- spSetProjectileTarget(projectileID, target[1], targetHeight, target[3])
	-- projectile.cruiseAngle = angle -- updates in increments of turnRate

	-- ? method 2
	-- Start with shallow-ish turn toward level (extra-extra height):
	local targetHeight = cruiseHeight + (2 * math_pi) * (2 * math_pi) * extraHeight
	spSetProjectileTarget(projectileID, target[1], targetHeight, target[3])
	projectile.cruiseDistance = cruiseDistance
	projectile.cruiseHeight = cruiseHeight
	projectile.extraHeight = extraHeight

	ascending[projectileID] = nil
	cruising[projectileID] = projectile
end

local function ascend(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)

	if projectile.ascendHeight - position[2] < velocity[2] then
		cruiseStart(projectileID, projectile, position, velocity)
	end
end

local function cruise(projectileID, projectile)
	local position, velocity, speed = getPositionAndVelocity(projectileID)
	local target = projectile.target

	-- ? method 1
	-- local angle = projectile.cruiseAngle - projectile.turnRate
	-- projectile.cruiseAngle = angle
	-- local distance = distanceXZ(position, target)
	-- local targetHeight = position[2] + math_sin(angle) * projectile.extraHeight

	-- ? method 2
	local level = (velocity[2] / speed) + 1
	local radius = (projectile.turnRadius + 4 * speed) * (2 * level)
	local distance = distanceXZ(position, target)
	local targetHeight
	if distance - radius > 0 then
		local extra = 2 * math_pi * distance / projectile.cruiseDistance
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

		-- Working with missiles and starbursts together is an awkward challenge.
		-- StarburstProjectile uses a strict timeout on its `turnToTarget` value.
		if weaponDef.customParams.cruise_and_verticalize and (
				weaponDef.type == "MissileLauncher" or
				(weaponDef.type == "TorpedoLauncher" and weaponDef.subMissile) or
				weaponDef.type == "StarburstLauncher"
			)
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
	cruising[projectileID] = nil
end

function gadget:GameFrame(frame)
	for projectileID, projectile in pairs(cruising) do
		cruise(projectileID, projectile)
	end

	for projectileID, projectile in pairs(ascending) do
		ascend(projectileID, projectile)
	end
end

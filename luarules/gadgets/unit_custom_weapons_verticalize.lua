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
local rotateTo = vector.rotateTo
local turnDown = vector.turnDown

local gravityPerFrame = -Game.gravity / Game.gameSpeed ^ 2

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons = {}

for weaponDefID = 0, #WeaponDefs do
	local weaponDef = WeaponDefs[weaponDefID]

	if weaponDef.type == "StarburstLauncher" and weaponDef.customParams.cruise_and_verticalize then
		local cruiseHeight = weaponDef.customParams.cruise_altitude

		if cruiseHeight and cruiseHeight ~= "auto" then
			cruiseHeight = tonumber(cruiseHeight)
		end

		if cruiseHeight then
			local speedMin = weaponDef.startvelocity
			local speedMax = weaponDef.projectilespeed
			local acceleration = weaponDef.weaponAcceleration
			local turnRate = weaponDef.turnRate

			local uptimeFrames = weaponDef.uptime * Game.gameSpeed
			local uptimeAccelFrames = 0
			if acceleration and acceleration ~= 0 then
				uptimeAccelFrames = math.min(
					(speedMax - speedMin) / acceleration,
					uptimeFrames
				)
			end
			local speedIntoTurn = speedMin + uptimeAccelFrames * acceleration

			local turnHeight = speedIntoTurn * (uptimeFrames - uptimeAccelFrames * 0.5)
			local turnRadius = speedMax / turnRate / math_pi -- something odd with the scale

			if cruiseHeight == "auto" then
				-- The natural flight level of the weapon:
				cruiseHeight = turnHeight + turnRadius
				-- Spring.Echo('[verticalize] cruiseHeight = ' ..
				-- 	cruiseHeight .. ' for ' .. weaponDef.name .. '(' .. turnHeight .. ',' .. turnRadius .. ')')
			else
				cruiseHeight = tonumber(cruiseHeight)
			end

			-- From scraping the ground to soaring off-screen:
			cruiseHeight = math.clamp(cruiseHeight, 50, 10000)

			local weapon = {
				cruiseHeight   = cruiseHeight,
				turnRadius     = turnRadius,
				uptimeFrames   = uptimeFrames,
				heightIntoTurn = turnHeight,

				acceleration   = acceleration,
				speedMin       = speedMin,
				speedMax       = speedMax,
				turnRate       = turnRate,
			}

			-- SpawnProjectiles properties:
			if weaponDef.myGravity then
				weapon.gravity = weaponDef.myGravity
			end
			if weaponDef.model then
				weapon.model = weaponDef.model
			end
			if weaponDef.cegTag then
				weapon.cegtag = weaponDef.cegTag
			end

			Script.SetWatchProjectile(weaponDefID, true)
			weapons[weaponDefID] = weapon
		else
			Spring.Log(gadget:GetInfo().name, LOG.WARNING, 'Missing cruise_altitude: ' .. weaponDef.names)
		end
	end
end

local ascending = {}
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
	local float3 = {}

	---Fill a reusable helper table rather than create/destroy intermediate tables.
	---@param x number
	---@param y number
	---@param z number
	---@return table float3
	repack3 = function(x, y, z)
		local float3 = float3
		float3[1], float3[2], float3[3] = x, y, z
		return float3
	end
end

-- local function getUptime(params, position)
-- 	local speedMin = params.speedMin
-- 	local speedMax = params.speedMax
-- 	local acceleration = params.acceleration

-- 	local height = (params.target[2] - position[2]) + (params.cruiseHeight - params.turnRadius)

-- 	if height <= 0 then
-- 		return 0 -- precluded by other logic elsewhere
-- 	elseif acceleration == 0 or speedMin == speedMax then
-- 		return height / speedMax
-- 	end

-- 	local accelTime = (speedMax - speedMin) / acceleration
-- 	local accelDistance = speedMin * accelTime + 0.5 * acceleration * accelTime * accelTime

-- 	if accelDistance <= height then
-- 		-- todo: brain tired, there's a better way
-- 		local flatTime = (height - accelDistance) / speedMax
-- 		local speedAvg = (flatTime * speedMax + accelTime * (speedMax - speedMin) * 0.5) / (flatTime + accelTime)

-- 		return height / speedAvg
-- 	else
-- 		-- Solve distance = 0.5 a t^2 + v_0 t for time t:
-- 		local a, b, c = 0.5 * acceleration, speedMin, -height
-- 		local discriminant = b * b - 4 * a * c

-- 		if discriminant < 0 then
-- 			return -- borked and cannot be unborked
-- 		else
-- 			discriminant = math_sqrt(discriminant)
-- 		end

-- 		local t1 = (-b + discriminant) / (2 * a)
-- 		local t2 = (-b - discriminant) / (2 * a)

-- 		return (t1 >= 0 and t2 >= 0) and math.min(t1, t2) or (t1 >= 0 and t1 or t2)
-- 	end
-- end

local respawning = false

-- local respawnProjectile
-- do
-- 	local respawnCache = {
-- 		pos   = position, -- these table refs never change
-- 		speed = velocity, -- LuaUtils::ParseFloatArray needs this to be a float3
-- 	}

-- 	respawnProjectile = function(projectileID, params, uptime)
-- 		if uptime then
-- 			local weaponDefID = Spring.GetProjectileDefID(projectileID)

-- 			local _, velocity = getPositionAndVelocity(projectileID)
-- 			velocity[4] = nil -- to pass float3 check in ParseProjectileParams

-- 			respawnCache.owner = Spring.GetProjectileOwnerID(projectileID)
-- 			respawnCache.ttl = Spring.GetProjectileTimeToLive(projectileID)
-- 			respawnCache['end'] = params.target
-- 			respawnCache.gravity = params.gravity
-- 			respawnCache.model = params.model
-- 			respawnCache.cegTag = params.cegTag
-- 			respawnCache.uptime = uptime

-- 			Spring.DeleteProjectile(projectileID)

-- 			respawning = true
-- 			local respawnID = Spring.SpawnProjectile(weaponDefID, respawnCache)
-- 			respawning = false

-- 			if respawnID then
-- 				ascending[respawnID] = params
-- 			end
-- 		else
-- 			-- Try to restore relatively normal behavior:
-- 			local target = params.target
-- 			Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3])
-- 		end
-- 	end
-- end

local function newProjectile(projectileID, weaponDefID)
	local weapon = weapons[weaponDefID]
	local position, velocity = getPositionAndVelocity(projectileID)
	local targetType, target = Spring.GetProjectileTarget(projectileID)

	if targetType == targetedUnit or target[2] < 0 then
		if targetType == targetedUnit then
			local targetID = target
			target = repack3(Spring.GetUnitPosition(targetID))
			target[2] = Spring.GetGroundHeight(target[1], target[3])
		end
		if target[2] < 0 then
			target[2] = 0
		end
	elseif targetType ~= targetedGround then
		return
	end

	if not position:isInCylinder(target, 2 * weapon.turnRadius) then
		local ascendHeight = target[2] + weapon.cruiseHeight - weapon.turnRadius

		local projectile = {
			target       = target,
			ascendHeight = math.max(ascendHeight, weapon.heightIntoTurn),
			cruiseHeight = weapon.cruiseHeight,
			turnRadius   = weapon.turnRadius,
			acceleration = weapon.acceleration,
			speedMax     = weapon.speedMax,
			speedMin     = weapon.speedMin,
			turnRate     = weapon.turnRate,
		}

		if target[2] - position[2] <= weapon.heightIntoTurn + 1 then
			-- This will level out after `uptime` is reached and path toward the target,
			-- then the StarburstProjectile disables its `turnToTarget` extremely early:
			local cruiseHeightTarget = ascendHeight + weapon.turnRadius
			Spring.SetProjectileTarget(projectileID, target[1], cruiseHeightTarget, target[3])
			ascending[projectileID] = projectile
		else
			-- StarburstProjectile will run out of uptime too soon.
			-- We fix that by respawning them with a larger uptime:
			-- respawnProjectile(projectileID, projectile, getUptime(projectile, position))
			Spring.Echo('[verticalize] position, target, heightIntoTurn:', position, target, heightIntoTurn)
		end
	end
end

local function ascend(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)
	if projectile.ascendHeight - position[2] < velocity[4] then
		ascending[projectileID] = nil
		cruising[projectileID] = projectile
	end
end

local function cruise(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)
	if position:isInCylinder(projectile.target, 1.25 * projectile.turnRadius + velocity[4]) then
		Spring.SetProjectileMoveControl(projectileID, true)
		local target = projectile.target
		Spring.SetProjectileTarget(projectileID, target[1], target[2], target[3]) -- not that it matters
		cruising[projectileID] = nil
		verticalizing[projectileID] = projectile
	end
end

---Controls the projectile in two stages, first diving toward vertically down,
---then tracking exactly onto the target. (Imprecision should be added earlier
---in the initial setup for the weapon when the `target` is first evaluated.)
---@param projectileID integer
---@param projectile table
local function verticalize(projectileID, projectile)
	local position, velocity = getPositionAndVelocity(projectileID)
	local verticalHeight = projectile.target[2] + projectile.cruiseHeight - projectile.turnRadius

	if position[2] + velocity[2] >= verticalHeight then
		local chaseFactor = 1 -- 100% laziness during turn to target
		vector.updateGuidance(
			position, velocity, projectile.target,
			projectile.speedMax, 0, projectile.turnRate / Game.gameSpeed,
			chaseFactor
		)
		spSetProjectilePosition(
			projectileID,
			position[1] + velocity[1],
			position[2] + velocity[2],
			position[3] + velocity[3]
		)
		spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
	else
		rotateTo(velocity, repack3(displacement(position, projectile.target)))
		spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
		Spring.SetProjectileMoveControl(projectileID, false)
		verticalizing[projectileID] = nil
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	if table.count(weapons) == 0 then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "No weapons found.")
		gadgetHandler:RemoveGadget(self)
	end

	-- tired of it:
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

	for projectileID, projectile in pairs(verticalizing) do
		verticalize(projectileID, projectile)
	end
end

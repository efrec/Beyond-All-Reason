local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Custom weapon behaviours",
		desc    = "Handler for special weapon behaviours",
		author  = "Doo",
		date    = "Sept 19th 2017",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local vector = VFS.Include("common/springUtilities/vector.lua")

local math_pi = math.pi

local spGetGroundHeight = Spring.GetGroundHeight
local spGetGroundNormal = Spring.GetGroundNormal
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileTarget = Spring.GetProjectileTarget
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitPosition = Spring.GetUnitPosition
local spSetProjectilePosition = Spring.SetProjectilePosition
local spSetProjectileTarget = Spring.SetProjectileTarget
local spSetProjectileVelocity = Spring.SetProjectileVelocity

local multiply = vector.multiply
local dot = vector.dot
local isInSphere = vector.isInSphere
local randomFromConicXZ = vector.randomFromConicXZ
local randomFrom3D = vector.randomFrom3D

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local specialEffects = {}
local specialEffectKeys = { speceffect_def = true, cegtag = true, model = true }

local weapons = {}

local projectiles = {}
local projectileData = {}

local position = { 0, 0, 0 }
local velocity = { 0, 0, 0, 0 }

local spawnCache = {
	pos     = position,
	speed   = { 0, 0, 0 }, -- not `velocity`; ParseProjectile needs a float3
	ttl     = 3000,
	gravity = -Game.gravity / (Game.gameSpeed ^ 2),
}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local repack3
do
	local float3 = { 0, 0, 0 }

	---Similar to lua `pack`, but provides a reusable vector3 table.
	---@param x number?
	---@param y number?
	---@param z number?
	---@return table float3
	repack3 = function(x, y, z)
		local float3 = float3
		float3[1], float3[2], float3[3] = x, y, z
		return float3
	end
end

local function getPositionAndVelocity(projectileID)
	local position, velocity = position, velocity
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return position, velocity
end

local function getSpawnCache(projectileID, params)
	local spawnCache = spawnCache
	spawnCache.cegTag = params.cegtag
	spawnCache.model = params.model
	spawnCache.owner = Spring.GetProjectileOwnerID(projectileID)
	return spawnCache
end

local function isProjectileFalling(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return velocity[2] < 0
end

local function isProjectileInWater(projectileID)
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	return position[2] <= 0
end

local function isUnitUnderwater(unitID)
	return math.bit_and(Spring.GetUnitPhysicalState(target), 4) ~= 0
end

-- Weapon behaviors ------------------------------------------------------------

-- Cruise

specialEffectKeys.lockon_dist = true
specialEffectKeys.cruise_min_height = true

local function attitudeCorrection(projectileID, position, velocity, cruiseHeight)
	local normal = repack3(spGetGroundNormal(position[1], position[3]))
	local attitude = velocity[2] - dot(velocity, normal) * normal[2]
	spSetProjectilePosition(projectileID, position[1], cruiseHeight, position[3])
	spSetProjectileVelocity(projectileID, velocity[1], attitude, velocity[3])
end

local getUnitAimPosition
do
	local float3 = { 0, 0, 0 }

	---Replaces `select(4, spGetUnitPosition(targetID, false, true))`, which is slow.
	---`select` tables the varargs, which fully defeats the point of a reusable table.
	getUnitAimPosition = function(targetID)
		local _; -- sink for unused args
		local aim = float3
		_, _, _, aim[1], aim[2], aim[3] = spGetUnitPosition(targetID, false, true)
		return aim
	end
end

specialEffects.cruise = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local position, velocity = getPositionAndVelocity(projectileID)
		local targetType, target = spGetProjectileTarget(projectileID)

		if targetType == targetedUnit then
			target = getUnitAimPosition(target) -- replace with table
		end

		if not isInSphere(position, target, params.lockon_dist) then
			local cruiseHeight = spGetGroundHeight(position[1], position[3]) + params.cruise_min_height

			if position[2] < cruiseHeight then
				attitudeCorrection(projectileID, position, velocity, cruiseHeight)
				projectileData[projectileID] = true
			elseif projectileData[projectileID] and
				position[2] > cruiseHeight and
				velocity[2] > velocity[4] * -0.25 -- avoid steep dives after cliffs
			then
				attitudeCorrection(projectileID, position, velocity, cruiseHeight)
			end

			return false
		end
	end
	return true
end

-- Retarget

specialEffects.retarget = function(params, projectileID)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local targetType, target = spGetProjectileTarget(projectileID)

		if targetType == targetedUnit and spGetUnitIsDead(target) ~= false then
			local ownerID = Spring.GetProjectileOwnerID(projectileID)

			-- Hardcoded to retarget only from the primary weapon and only units or ground
			local ownerTargetType, _, ownerTarget = Spring.GetUnitWeaponTarget(ownerID, 1)

			if ownerTargetType then
				if ownerTargetType == 1 then
					spSetProjectileTarget(projectileID, ownerTarget, targetedUnit)
				elseif ownerTargetType == 2 then
					spSetProjectileTarget(projectileID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
				end
				return false
			end
		end
	end
	return true
end

-- Sector fire

specialEffectKeys.max_range_reduction = true
specialEffectKeys.spread_angle = true

specialEffects.sector_fire = function(params, projectileID)
	local velocity = velocity -- upvalue
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)

	-- Using the half-angle (departure from centerline) in radians:
	local angleMax = params.spread_angle * math_pi / 180 * 0.5
	local rangeReductionMax = -1 * params.max_range_reduction

	velocity[1], velocity[3] = randomFromConicXZ(velocity, angleMax, rangeReductionMax)
	spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])

	return true
end

-- Split

specialEffectKeys.splitexplosionceg = true
specialEffectKeys.number = true

local function split(params, projectileID)
	local position, velocity = position, velocity -- upvalues
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)

	local splitParams = getSpawnCache(projectileID, weaponParams)

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnCEG(params.splitexplosionceg, position[1], position[2], position[3])

	local projectileDefID = params.speceffect_def
	local speed = repack3()

	for _ = 1, params.number do
		speed[1], speed[2], speed[3] = randomFrom3D(velocity, 0.088, 0.044, 0.088)
		Spring.SpawnProjectile(projectileDefID, splitParams)
	end
end

specialEffects.split = function(params, projectileID)
	if isProjectileFalling(projectileID) then
		split(projectileID, params)
		return true
	end
end

-- Cannon water penetration

specialEffectKeys.waterpenceg = true

local function cannonWaterPen(params, projectileID)
	local position = position -- upvalue
	local velocity = repack3(spGetProjectileVelocity(projectileID))

	multiply(velocity, 0.5)

	local waterpenParams = getSpawnCache(projectileID, weaponParams)

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnProjectile(params.speceffect_def, waterpenParams)
	Spring.SpawnCEG(params.waterpenceg, position[1], position[2], position[3])
end

specialEffects.cannonwaterpen = function(params, projectileID)
	if isProjectileInWater(projectileID) then
		cannonWaterPen(projectileID, params)
		return true
	end
end

-- Torpedo water penetration

local function torpedoWaterPen(projectileID)
	local velocity = repack3(spGetProjectileVelocity(projectileID))

	multiply(velocity, 1 / 1.3)

	local targetType, target = spGetProjectileTarget(projectileID)

	if targetType == targetedUnit and isUnitUnderwater(target) then
		velocity[2] = velocity[2] / 6
	else
		velocity[2] = 0
	end

	spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
end

specialEffects.torpwaterpen = function(params, projectileID)
	if isProjectileInWater(projectileID) then
		torpedoWaterPen(projectileID)
		return true
	end
end

-- Torpedo water penetration and retarget

do
	local retarget = specialEffects.retarget
	local torpedoWaterPen = specialEffects.torpwaterpen

	specialEffects.torpwaterpenretarget = function(params, projectileID)
		if not projectileData[projectileID] and torpedoWaterPen(projectileID) then
			projectileData[projectileID] = true
		end
		return retarget(projectileID)
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

do
	local metatables = {}

	for effect, method in pairs(specialEffects) do
		-- for `method` to access params as `self`:
		metatables[effect] = { __call = method }
	end

	local function getSpecialEffectKeys(weaponDef)
		local custom = weaponDef.customParams

		local keys = {}

		-- idr how to `table.copy(weaponDef.customParams)`, or if you even can, so:
		for key in pairs(specialEffectKeys) do
			keys[key] = custom[key]
		end

		if custom.def or custom.when then
			-- modders/tweakdefs will keep using these for a while, probably
			local message = "weapondef has deprecated customparams: " .. weaponDef.name
			Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, message)
			custom.speceffect_def, custom.when = custom.def, nil
		end

		-- get customparams as non-strings
		for key, value in pairs(keys) do
			if tonumber(value) then
				keys[key] = tonumber(value)
			end
		end

		return keys
	end

	local function parseCustomEffect(weaponDef)
		local success = true

		local effectName = weaponDef.customParams.speceffect

		if not metatables[effectName] then
			local message = weaponDef.name .. " has unrecognized speceffect: " .. effectName
			Spring.Log(gadget:GetInfo().name, LOG.WARNING, message)
			success = false
		end

		local params = getSpecialEffectKeys(weaponDef)

		local spawnDefName = params.speceffect_def

		if spawnDefName then
			local spawnDef = WeaponDefNames[spawnDefName]

			if not spawnDef then
				local message = weaponDef.name .. " has unrecognized speceffect_def: " .. spawnDefName
				Spring.Log(gadget:GetInfo().name, LOG.WARNING, message)
				success = false
			else
				params.speceffect_def = spawnDef.id
			end
		end

		if success then
			return effectName, params
		end
	end

	function gadget:Initialize()
		for weaponDefID = 0, #WeaponDefs do
			local weaponDef = WeaponDefs[weaponDefID]

			if weaponDef.customParams and weaponDef.customParams.speceffect then
				local effectName, params = parseCustomEffect(weaponDef)

				if effectName and params then
					weapons[weaponDefID] = setmetatable(params, metatables[effectName])
				end
			end
		end

		if not next(weapons) then
			Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found.")
			gadgetHandler:RemoveGadget(self)
			return
		end

		spawnCache.pos = repack3() -- reused table
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	projectiles[projectileID] = weapons[weaponDefID]
end

function gadget:ProjectileDestroyed(projectileID)
	projectiles[projectileID] = nil
	projectileData[projectileID] = nil
end

function gadget:GameFrame(frame)
	for projectileID, effect in pairs(projectiles) do
		if effect(projectileID) then
			projectiles[projectileID] = nil
		end
	end
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Custom weapon behaviours",
		desc    = "Handler for special weapon behaviours",
		author  = "Doo (refactor by efrec)",
		date    = "Sept 19th 2017",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Localization ----------------------------------------------------------------

local vector = VFS.Include("common/springUtilities/vector.lua")

local random = math.random
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local pi = math.pi

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
local randomFromConicXZ = vector.randomFromConicXZ

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

local gameSpeed = Game.gameSpeed
local gravityPerFrame = -Game.gravity / gameSpeed ^ 2

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons = {}

for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.customParams.speceffect then
		local name = weaponDef.customParams.speceffect_def
		if name and not WeaponDefNames[name] then
			local message = "Weapon has bad custom params: " .. weaponDef.name
			message = message .. ' (speceffect_def=' .. name .. ')'
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
		else
			weapons[weaponDefID] = weaponDef.customParams
		end

		-- TODO: Remove deprecate warning once modders have had time to fix.
		if weaponDef.customParams.def or weaponDef.customParams.when then
			local message = "Deprecated speceffect customparams: " .. weaponDef.name
			Spring.Log(gadget:GetInfo().name, LOG.DEPRECATED, message)
		end
	end
end

local specialEffects = {}

local projectiles = {}
local projectileData = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local toFloat3
do
	local float3 = { 0, 0, 0 }

	---Fills a reusable helper table rather than create/destroy intermediate tables.
	---@param x number?
	---@param y number?
	---@param z number?
	---@return table float3
	toFloat3 = function(x, y, z)
		local float3 = float3
		float3[1], float3[2], float3[3] = x, y, z
		return float3
	end
end

local toFloat3a
do
	local float3a = { 0, 0, 0, 0 }

	---Fills a reusable helper table rather than create/destroy intermediate tables.
	---@param x number?
	---@param y number?
	---@param z number?
	---@param a number? the "augment" of a vector generally stores a magnitude term
	---@return table float3
	toFloat3a = function(x, y, z)
		local float3a = float3a
		float3a[1], float3a[2], float3a[3], float3a[4] = x, y, z, a
		return float3a
	end
end

local position = { 0, 0, 0 }
local velocity = { 0, 0, 0, 0 }

function position:isInSphere(target, radius)
	local dx = self[1] - target[1]
	local dy = self[2] - target[2]
	local dz = self[3] - target[3]
	return dx * dx + dy * dy + dz * dz <= radius * radius
end

local function getPositionAndVelocity(projectileID)
	local position, velocity = position, velocity
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)
	return position, velocity
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

--------------------------------------------------------------------------------

local function cruise(projectileID, position, velocity, altitude)
	local normal = toFloat3(spGetGroundNormal(position[1], position[3]))
	local attitude = velocity[2] - dot(velocity, normal) * normal[2]
	spSetProjectilePosition(projectileID, position[1], altitude, position[3])
	spSetProjectileVelocity(projectileID, velocity[1], attitude, velocity[3])
end

specialEffects.cruise = function(projectileID, params)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local position, velocity = getPositionAndVelocity(projectileID)
		local targetType, target = spGetProjectileTarget(projectileID)

		if targetType == targetedUnit then
			local targetID = target
			target = toFloat3(select(4, spGetUnitPosition(targetID, false, true)))
		end

		if not position:isInSphere(target, tonumber(params.lockon_dist)) then
			-- Always correct for ground clearance. Follow terrain after first ground clear.
			-- Then, follow terrain also, but avoid going into steep dives, eg after cliffs.
			local cruiseHeight = spGetGroundHeight(position[1], position[3]) + tonumber(params.cruise_min_height)

			if position[2] < cruiseHeight then
				cruise(projectileID, position, velocity, cruiseHeight)
				projectileData[projectileID] = true
			elseif projectileData[projectileID] and
				position[2] > cruiseHeight and velocity[2] > velocity[4] * -0.25
			then
				cruise(projectileID, position, velocity, cruiseHeight)
			end

			return false
		end
	end
	return true
end

specialEffects.retarget = function(projectileID, params)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local targetType, target = spGetProjectileTarget(projectileID)
		if targetType == targetedUnit and spGetUnitIsDead(target) ~= false then
			local ownerID = Spring.GetProjectileOwnerID(projectileID)
			-- Hardcoded to retarget only from the primary weapon and only units or ground
			local ownerTargetType, _, ownerTarget = Spring.GetUnitWeaponTarget(ownerID, 1)
			if ownerTargetType == 1 then
				spSetProjectileTarget(projectileID, ownerTarget, targetedUnit)
			elseif ownerTargetType == 2 then
				spSetProjectileTarget(projectileID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
			end
			return false
		end
	end
	return true
end

specialEffects.sector_fire = function(projectileID, params)
	local velocity = toFloat3a(spGetProjectileVelocity(projectileID))

	-- Using the half-angle (departure from centerline) in radians:
	local angleMax = tonumber(params.spread_angle) * pi / 180 * 0.5
	local rangeReductionMax = -1 * tonumber(params.max_range_reduction)

	velocity[1], velocity[3] = randomFromConicXZ(velocity, angleMax, rangeReductionMax)
	spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])

	return true
end

local function split(projectileID, params)
	local position, velocity = position, velocity -- upvalues
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)

	local speed = toFloat3()
	local getRandomSpeed = vector.randomFrom3D

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnCEG(params.splitexplosionceg, position[1], position[2], position[3])

	local projectileDefID = WeaponDefNames[params.speceffect_def].id
	local projectileParams = {
		pos     = position,
		speed   = speed,
		owner   = Spring.GetProjectileOwnerID(projectileID),
		ttl     = 3000,
		gravity = gravityPerFrame,
		model   = params.model,
		cegTag  = params.cegtag,
	}

	for _ = 1, tonumber(params.number) do
		speed[1], speed[2], speed[3] = getRandomSpeed(velocity, 0.088, 0.044, 0.088)
		Spring.SpawnProjectile(projectileDefID, projectileParams)
	end
end

specialEffects.split = function(projectileID, params)
	if isProjectileFalling(projectileID) then
		split(projectileID, params)
		return true
	end
end

-- Water penetration behaviors

local function cannonWaterPen(projectileID, params)
	local position, velocity = position, velocity -- upvalues
	velocity[1], velocity[2], velocity[3] = spGetProjectileVelocity(projectileID)

	multiply(velocity, 0.5)

	local projectileParams = {
		pos     = position,
		speed   = velocity,
		owner   = Spring.GetProjectileOwnerID(projectileID),
		ttl     = 3000,
		gravity = gravityPerFrame * 0.5,
		model   = params.model,
		cegTag  = params.cegtag,
	}

	Spring.SpawnProjectile(WeaponDefNames[params.speceffect_def].id, projectileParams)
	Spring.SpawnCEG(params.waterpenceg, position[1], position[2], position[3])
	Spring.DeleteProjectile(projectileID)
end

specialEffects.cannonwaterpen = function(projectileID, params)
	if isProjectileInWater(projectileID) then
		cannonWaterPen(projectileID, params)
		return true
	end
end

local function torpedoWaterPen(projectileID)
	local velocity = toFloat3(spGetProjectileVelocity(projectileID))

	multiply(velocity, 1 / 1.3)

	local targetType, target = spGetProjectileTarget(projectileID)
	if targetType == targetedUnit and isUnitUnderwater(target) then
		velocity[2] = velocity[2] / 6
	else
		velocity[2] = 0
	end

	spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])
end

specialEffects.torpwaterpen = function(projectileID, params)
	if isProjectileInWater(projectileID) then
		torpedoWaterPen(projectileID)
		return true
	end
end

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	if not next(weapons) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found.")
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:ProjectileCreated(projectileID, proOwnerID, weaponDefID)
	if weapons[weaponDefID] then
		projectiles[projectileID] = weapons[weaponDefID]
	end
end

function gadget:ProjectileDestroyed(projectileID)
	projectiles[projectileID] = nil
	projectileData[projectileID] = nil
end

function gadget:GameFrame(f)
	for projectileID, params in pairs(projectiles) do
		if specialEffects[params.speceffect](projectileID, params) then
			projectiles[projectileID] = nil
			projectileData[projectileID] = nil
		end
	end
end

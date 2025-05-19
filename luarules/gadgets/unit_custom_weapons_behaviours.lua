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

local math_random = math.random
local math_sqrt = math.sqrt
local math_cos = math.cos
local math_sin = math.sin
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

local gameSpeed = Game.gameSpeed
local gravityPerFrame = -Game.gravity / gameSpeed ^ 2

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

local weapons = {}
local subweaponDefID = {}

for weaponDefID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.customParams.speceffect then
		local name = weaponDef.customParams.speceffect_def
		if name and not WeaponDefNames[name] then
			local message = "Weapon has bad custom params: " .. weaponDef.name
			message = message .. ' (speceffect_def=' .. name .. ')'
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
		else
			weapons[weaponDefID] = weaponDef.customParams
			if name then
				subweaponDefID[name] = WeaponDefNames[name].id
			end
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

local repack3
do
	local float3 = { 0, 0, 0 }

	---Fills a reusable helper table rather than create/destroy intermediate tables.
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

local position = { 0, 0, 0 }
local velocity = { 0, 0, 0, 0 }

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

-- Weapon behaviors ------------------------------------------------------------

local function attitudeCorrection(projectileID, position, velocity, cruiseHeight)
	local normal = repack3(spGetGroundNormal(position[1], position[3]))
	local attitude = velocity[2] - dot(velocity, normal) * normal[2]
	spSetProjectilePosition(projectileID, position[1], cruiseHeight, position[3])
	spSetProjectileVelocity(projectileID, velocity[1], attitude, velocity[3])
end

specialEffects.cruise = function(projectileID, params)
	if spGetProjectileTimeToLive(projectileID) > 0 then
		local position, velocity = getPositionAndVelocity(projectileID)
		local targetType, target = spGetProjectileTarget(projectileID)

		if targetType == targetedUnit then
			target = repack3(select(4, spGetUnitPosition(target, false, true)))
		end

		if not isInSphere(position, target, tonumber(params.lockon_dist)) then
			local cruiseHeight = spGetGroundHeight(position[1], position[3]) + tonumber(params.cruise_min_height)

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

specialEffects.retarget = function(projectileID, params)
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

specialEffects.sector_fire = function(projectileID, params)
	local velocity = velocity -- upvalue
	velocity[1], velocity[2], velocity[3], velocity[4] = spGetProjectileVelocity(projectileID)

	-- Using the half-angle (departure from centerline) in radians:
	local angleMax = tonumber(params.spread_angle) * pi / 180 * 0.5
	local rangeReductionMax = -1 * tonumber(params.max_range_reduction)

	velocity[1], velocity[3] = randomFromConicXZ(velocity, angleMax, rangeReductionMax)
	spSetProjectileVelocity(projectileID, velocity[1], velocity[2], velocity[3])

	return true
end

local splitParams = {
	pos     = position,
	speed   = repack3(), -- not `velocity`; ParseProjectile needs a float3
	ttl     = 3000,
	gravity = gravityPerFrame,
}

local function split(projectileID, params)
	local position, velocity = position, velocity -- upvalues
	position[1], position[2], position[3] = spGetProjectilePosition(projectileID)

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnCEG(params.splitexplosionceg, position[1], position[2], position[3])

	splitParams.cegTag = params.cegtag
	splitParams.model = params.model

	local projectileDefID = subweaponDefID[params.speceffect_def]
	local speed = repack3()

	for _ = 1, tonumber(params.number) do
		speed[1], speed[2], speed[3] = randomFrom3D(velocity, 0.088, 0.044, 0.088)
		Spring.SpawnProjectile(projectileDefID, splitParams)
	end
end

specialEffects.split = function(projectileID, params)
	if isProjectileFalling(projectileID) then
		split(projectileID, params)
		return true
	end
end

-- Water penetration behaviors

local waterpenParams = {
	pos     = position,
	speed   = repack3(),
	ttl     = 3000,
	gravity = gravityPerFrame * 0.5,
}

local function cannonWaterPen(projectileID, params)
	local position = position -- upvalue
	local velocity = repack3(spGetProjectileVelocity(projectileID))

	multiply(velocity, 0.5)

	waterpenParams.cegTag = params.cegtag
	waterpenParams.model = params.model

	Spring.DeleteProjectile(projectileID)
	Spring.SpawnProjectile(subweaponDefID[params.speceffect_def], waterpenParams)
	Spring.SpawnCEG(params.waterpenceg, position[1], position[2], position[3])
end

specialEffects.cannonwaterpen = function(projectileID, params)
	if isProjectileInWater(projectileID) then
		cannonWaterPen(projectileID, params)
		return true
	end
end

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["ypos<0"] = function(proID)
	local _, py, _ = Spring.GetProjectilePosition(proID)
	if py <= 0 then
		return true
	else
		return false
	end
end
applyingFunctions.torpwaterpen = function(proID)
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	--if target is close under the shooter, however, this resetting makes the torp always miss, unless it has amazing tracking
	--needs special case handling (and there's no point having it visually on top of water for an UW target anyway)

	local bypass = false
	local targetType, targetID = Spring.GetProjectileTarget(proID)

	if (targetType ~= nil) and (targetID ~= nil) and (targetType ~= 103) then --ground attack borks it; skip
		local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(targetID)
		if (unitPosY ~= nil) and unitPosY < -10 then
			bypass = true
			Spring.SetProjectileVelocity(proID, vx / 1.3, vy / 6, vz / 1.3) --apply brake without fully halting, otherwise it will overshoot very close targets before tracking can reorient it
		end
	end

	if not bypass then
		Spring.SetProjectileVelocity(proID, vx, 0, vz)
	end
end

--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
checkingFunctions.torpwaterpenretarget = {}
checkingFunctions.torpwaterpenretarget["ypos<0"] = function(proID)
	checkingFunctions.retarget["always"](proID) --subcontract that part

	local _, py, _ = Spring.GetProjectilePosition(proID)
	if py <= 0 then
		--and delegate that too
		applyingFunctions.torpwaterpen(proID)
	else
		return false
	end
end

--fake function
applyingFunctions.torpwaterpenretarget = function(proID)
	return false
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
	projectiles[projectileID] = weapons[weaponDefID]
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

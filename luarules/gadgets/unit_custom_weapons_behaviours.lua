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

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function(proID)
	-- Might be slightly more optimal to check the unit itself if it changes target,
	-- then tell the in-flight missiles to change target if the unit changes target
	-- instead of checking each in-flight missile
	-- but not sure if there is an easy hook function or callin function
	-- that only runs if a unit changes target

	-- refactor slightly, only do target change if the target the missile
	-- is heading towards is dead
	-- karganeth switches away from alive units a little too often, causing
	-- missiles that would have hit to instead miss
	if SpGetProjectileTimeToLive(proID) <= 0 then
		-- stop missile retargeting when it runs out of fuel
		return true
	end
	local targetTypeInt, targetID = SpGetProjectileTarget(proID)
	-- if the missile is heading towards a unit
	if targetTypeInt == string.byte('u') then
		--check if the target unit is dead or dying
		local dead_state = SpGetUnitIsDead(targetID)
		if dead_state == nil or dead_state == true then
			--hardcoded to assume the retarget weapon is the primary weapon.
			--TODO, make this more general
			local target_type, _, owner_target = SpGetUnitWeaponTarget(SpGetProjectileOwnerID(proID), 1)
			if target_type == 1 then
				--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
				--TODO, make this more general
				SpSetProjectileTarget(proID, owner_target, string.byte('u'))
			end
			if target_type == 2 then
				SpSetProjectileTarget(proID, owner_target[1], owner_target[2], owner_target[3])
			end
		end
	end

	return false
end
applyingFunctions.retarget = function(proID)
	return false
end

checkingFunctions.sector_fire = {}
checkingFunctions.sector_fire["always"] = function(proID)
	-- as soon as the siege projectile is created, pass true on the
	-- checking function, to go to applying function
	-- so the unit state is only checked when the projectile is created
	return true
end
applyingFunctions.sector_fire = function(proID)
	local infos = projectiles[proID]
	local vx, vy, vz = SpGetProjectileVelocity(proID)

	local spread_angle = tonumber(infos.spread_angle)
	local max_range_reduction = tonumber(infos.max_range_reduction)

	local angle_factor = (spread_angle * (math_random() - 0.5)) * mathPi / 180
	local cos_angle = mathCos(angle_factor)
	local sin_angle = mathSin(angle_factor)

	local vx_new = vx * cos_angle - vz * sin_angle
	local vz_new = vx * sin_angle + vz * cos_angle

	local velocity_factor = 1 - (math_random() ^ (1 + max_range_reduction)) * max_range_reduction

	vx = vx_new * velocity_factor
	vz = vz_new * velocity_factor

	SpSetProjectileVelocity(proID, vx, vy, vz)
end

checkingFunctions.split = {}
checkingFunctions.split["yvel<0"] = function(proID)
	local _, vy, _ = Spring.GetProjectileVelocity(proID)
	if vy < 0 then
		return true
	else
		return false
	end
end
applyingFunctions.split = function(proID)
	local px, py, pz = Spring.GetProjectilePosition(proID)
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	local vw = math_sqrt(vx * vx + vy * vy + vz * vz)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	for i = 1, tonumber(infos.number) do
		local projectileParams = {
			pos = { px, py, pz },
			speed = { vx - vw * (math.random(-100, 100) / 880), vy - vw * (math.random(-100, 100) / 440), vz - vw * (math.random(-100, 100) / 880) },
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity / 900,
			model = infos.model,
			cegTag = infos.cegtag,
		}
		Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
	end
	Spring.SpawnCEG(infos.splitexplosionceg, px, py, pz, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["ypos<0"] = function(proID)
	local _, y, _ = Spring.GetProjectilePosition(proID)
	if y <= 0 then
		return true
	else
		return false
	end
end
applyingFunctions.cannonwaterpen = function(proID)
	local px, py, pz = Spring.GetProjectilePosition(proID)
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	local nvx, nvy, nvz = vx * 0.5, vy * 0.5, vz * 0.5
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileParams = {
		pos = { px, py, pz },
		speed = { nvx, nvy, nvz },
		owner = ownerID,
		ttl = 3000,
		gravity = -Game.gravity / 3600,
		model = infos.model,
		cegTag = infos.cegtag,
	}
	Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
	Spring.SpawnCEG(infos.waterpenceg, px, py, pz, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
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

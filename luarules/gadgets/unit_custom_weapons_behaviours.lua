local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Custom weapon behaviours",
		desc      = "Handler for special weapon behaviours",
		author    = "Doo",
		date      = "Sept 19th 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then return false end

-- customparams = {
--     speceffect      := string
--     speceffect_when := string
--     speceffect_def  := string?
-- }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local random = math.random
local math_sqrt = math.sqrt
local mathCos = math.cos
local mathSin = math.sin
local mathPi = math.pi

local SpGetGroundHeight = Spring.GetGroundHeight
local SpGetProjectileTarget = Spring.GetProjectileTarget
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetProjectilePosition = Spring.GetProjectilePosition
local SpGetProjectileVelocity = Spring.GetProjectileVelocity
local SpGetUnitIsDead = Spring.GetUnitIsDead
local SpSetProjectilePosition = Spring.SetProjectilePosition
local SpSetProjectileTarget = Spring.SetProjectileTarget
local SpSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')
local gravityPerFrame = -Game.gravity / (Game.gameSpeed * Game.gameSpeed)

local projectiles = {}
local projectilesData = {}
local checkingFunctions = {}
local applyingFunctions = {}
local weaponCustomParams = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function alwaysTrue()
	return true
end

local function elevationIsNonpositive(proID)
	local _, y = SpGetProjectilePosition(proID)
	return y <= 0
end

local function velocityIsNegative(proID)
	local _, vy = SpGetProjectileVelocity(proID)
	return vy < 0
end

local function doNothing()
	return
end

local defaultApply = doNothing
local defaultCheck = { when = 'always', check = alwaysTrue }

--------------------------------------------------------------------------------

checkingFunctions.cruise = {}
checkingFunctions.cruise["distance>0"] = function(proID)
	if SpGetProjectileTimeToLive(proID) > 0 then
		local targetTypeInt, target = SpGetProjectileTarget(proID)
		local tx, ty, tz
		if targetTypeInt == targetedGround then
			tx, ty, tz = target[1], target[2], target[3]
		elseif targetTypeInt == targetedUnit then
			do
				local _
				_, _, _, _, _, _, tx, ty, tz = Spring.GetUnitPosition(target, true, true)
			end
		end
		local px, py, pz = SpGetProjectilePosition(proID)
		local pvx, pvy, pvz, speed = SpGetProjectileVelocity(proID)
		local infos = projectiles[proID]
		if math_sqrt((px - tx) ^ 2 + (py - ty) ^ 2 + (pz - tz) ^ 2) > tonumber(infos.lockon_dist) then
			local nx, ny, nz = Spring.GetGroundNormal(px, pz)
			local elevation = SpGetGroundHeight(px, pz) + tonumber(infos.cruise_min_height)
			local correction = (pvx * nx + pvy * ny + pvz * nz) * ny
			local pvy2
			-- Always correct for ground clearance. Follow terrain after first ground clear.
			-- Then, follow terrain also, but avoid going into steep dives, eg after cliffs.
			if py < elevation then
				pvy2 = pvy - correction
				projectilesData[proID] = true
			elseif py > elevation and pvy > speed * -0.25 and projectilesData[proID] then
				pvy2 = pvy - correction
			end
			if pvy2 then
				SpSetProjectilePosition(proID, px, elevation, pz)
				SpSetProjectileVelocity(proID, pvx, pvy2, pvz)
			end
			return false
		end
	end
	return true
end

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function (proID)
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
			local target_type,_,owner_target = SpGetUnitWeaponTarget(SpGetProjectileOwnerID(proID),1)
			if target_type == 1 then
				--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
				--TODO, make this more general
					SpSetProjectileTarget(proID,owner_target,string.byte('u'))
			end
			if target_type == 2 then
				SpSetProjectileTarget(proID,owner_target[1],owner_target[2],owner_target[3])
			end
		end
	end

	return false
end

checkingFunctions.sector_fire = {}
applyingFunctions.sector_fire = function (proID)
	local infos = projectiles[proID]
	local vx, vy, vz = SpGetProjectileVelocity(proID)
	
	local spread_angle = tonumber(infos.spread_angle)
	local max_range_reduction = tonumber(infos.max_range_reduction)
	
	local angle_factor = (spread_angle * (random() - 0.5)) * mathPi / 180
	local cos_angle = mathCos(angle_factor)
	local sin_angle = mathSin(angle_factor)
	
	local vx_new = vx * cos_angle - vz * sin_angle
	local vz_new = vx * sin_angle + vz * cos_angle
	
	local velocity_factor = 1 - (random() ^ (1 + max_range_reduction)) * max_range_reduction
	
	vx = vx_new * velocity_factor
	vz = vz_new * velocity_factor
	
	SpSetProjectileVelocity(proID, vx, vy, vz)
end

checkingFunctions.split = {}
checkingFunctions.split["yvel<0"] = velocityIsNegative
applyingFunctions.split = function (proID)
	local px, py, pz = Spring.GetProjectilePosition(proID)
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	local vw = math_sqrt(vx*vx + vy*vy + vz*vz)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	for i = 1, tonumber(infos.number) do
		local projectileParams = {
			pos = {px, py, pz},
			speed = {vx - vw*(math.random(-100,100)/880), vy - vw*(math.random(-100,100)/440), vz - vw*(math.random(-100,100)/880)},
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity/900,
			model = infos.model,
			cegTag = infos.cegtag,
			}
		Spring.SpawnProjectile(WeaponDefNames[infos.def].id, projectileParams)
	end
	Spring.SpawnCEG(infos.splitexplosionceg, px, py, pz,0,0,0,0,0)
	Spring.DeleteProjectile(proID)
end

-- Water penetration behaviors

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["ypos<0"] = elevationIsNonpositive
applyingFunctions.cannonwaterpen = function (proID)
	local px, py, pz = Spring.GetProjectilePosition(proID)
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	local nvx, nvy, nvz = vx * 0.5, vy * 0.5, vz * 0.5
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	local projectileParams = {
		pos = {px, py, pz},
		speed = {nvx, nvy, nvz},
		owner = ownerID,
		ttl = 3000,
		gravity = -Game.gravity/3600,
		model = infos.model,
		cegTag = infos.cegtag,
	}
	Spring.SpawnProjectile(WeaponDefNames[infos.def].id, projectileParams)
	Spring.SpawnCEG(infos.waterpenceg, px, py, pz,0,0,0,0,0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["ypos<0"] = elevationIsNonpositive
applyingFunctions.torpwaterpen = function (proID)
	local vx, vy, vz = Spring.GetProjectileVelocity(proID)
	--if target is close under the shooter, however, this resetting makes the torp always miss, unless it has amazing tracking
	--needs special case handling (and there's no point having it visually on top of water for an UW target anyway)
	
	local bypass = false
	local targetType, targetID = Spring.GetProjectileTarget(proID)
	
	if (targetType ~= nil) and (targetID ~= nil) and (targetType ~= 103) then--ground attack borks it; skip
		local unitPosX, unitPosY, unitPosZ = Spring.GetUnitPosition(targetID)
		if (unitPosY ~= nil) and unitPosY<-10 then
			bypass = true
			Spring.SetProjectileVelocity(proID,vx/1.3,vy/6,vz/1.3)--apply brake without fully halting, otherwise it will overshoot very close targets before tracking can reorient it
		end
	end
	
	if not bypass then
		Spring.SetProjectileVelocity(proID,vx,0,vz)
	end
end

--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
checkingFunctions.torpwaterpenretarget = {}
checkingFunctions.torpwaterpenretarget["ypos<0"] = function (proID)

	checkingFunctions.retarget["always"](proID)--subcontract that part

	local _,py,_ = Spring.GetProjectilePosition(proID)
	if py <= 0 then
		--and delegate that too
		applyingFunctions.torpwaterpen(proID)
	else
		return false
	end
end

--------------------------------------------------------------------------------

for speceffect in pairs(checkingFunctions) do
	if not applyingFunctions[speceffect] then
		applyingFunctions[speceffect] = defaultApply
	end
end

for speceffect in pairs(applyingFunctions) do
	if not checkingFunctions[speceffect] or not next(checkingFunctions[speceffect]) then
		checkingFunctions[speceffect] = checkingFunctions[speceffect] or {}
		checkingFunctions[speceffect][defaultCheck.when] = defaultCheck.check
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local speceffect = weaponDef.customParams.speceffect
			local when = weaponDef.customParams.speceffect_when
			local def = weaponDef.customParams.speceffect_def
			if def and not WeaponDefNames[def] then
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (def=' .. def .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			elseif not checkingFunctions[speceffect][when] or not applyingFunctions[speceffect] then
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect=' .. speceffect .. ',speceffect_when=' .. (when or 'nil') .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			else
				weaponCustomParams[weaponDefID] = weaponDef.customParams
			end
		end
	end
	if not next(weaponCustomParams) then
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, "No custom weapons found. Removing.") -- todo: back to INFO
		gadgetHandler:RemoveGadget(self)
		return
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if weaponCustomParams[weaponDefID] then
		projectiles[proID] = weaponCustomParams[weaponDefID]
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	projectilesData[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if checkingFunctions[infos.speceffect][infos.speceffect_when](proID) then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			projectilesData[proID] = nil
		end
	end
end

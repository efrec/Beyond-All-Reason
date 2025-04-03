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

if not gadgetHandler:IsSyncedCode() then end

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
local SpGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local SpSetProjectileTarget = Spring.SetProjectileTarget
local SpSetProjectileVelocity = Spring.SetProjectileVelocity

local targetedGround = string.byte('g')
local targetedUnit = string.byte('u')

local projectiles = {}
local active_projectiles = {}
local checkingFunctions = {}
local applyingFunctions = {}
local specialWeaponCustomDefs = {}
local weaponDataCache = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function alwaysTrue()
	return true
end

local function elevationIsNonpositive(proID)
	local _, y, _ = SpGetProjectilePosition(proID)
	return y <= 0
end

local function velocityIsNegative(proID)
	local _, vy, _ = SpGetProjectileVelocity(proID)
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
	local stop = true
	if SpGetProjectileTimeToLive(proID) > 0 then
		local targetTypeInt, target = SpGetProjectileTarget(proID)
		local xx, yy, zz
		if targetTypeInt == targetedGround then
			xx = target[1]
			yy = target[2]
			zz = target[3]
		end
		if targetTypeInt == targetedUnit then
			local _
			_, _, _, _, _, _, xx, yy, zz = Spring.GetUnitPosition(target, true, true)
		end
		local xp, yp, zp = SpGetProjectilePosition(proID)
		local vxp, vyp, vzp = SpGetProjectileVelocity(proID)
		local infos = projectiles[proID]
		if math_sqrt((xp - xx) ^ 2 + (yp - yy) ^ 2 + (zp - zz) ^ 2) > tonumber(infos.lockon_dist or 0) then
			stop = false
			local yg = SpGetGroundHeight(xp, zp)
			local nx, ny, nz = Spring.GetGroundNormal(xp, zp)
			local elevation = yg + tonumber(infos.cruise_min_height)
			if yp ~= elevation then
				local yyv
				local norm = (vxp * nx + vyp * ny + vzp * nz)
				if yp < elevation then
					yyv = vyp - norm * ny
					active_projectiles[proID] = true
				elseif active_projectiles[proID] then
					-- do not clamp to max height if
					-- vertical velocity downward is more than 1/4 of current speed
					-- probably just went off lip of steep cliff
					local mag = math_sqrt(vxp * vxp + vyp * vyp + vzp * vzp)
					if vyp > -mag * .25 then
						yyv = vyp - norm * ny
					end
				end
				if yyv then
					Spring.SetProjectilePosition(proID, xp, elevation, zp)
					SpSetProjectileVelocity(proID, vxp, yyv, vzp)
				end
			end
		end
	end
	return stop
end

checkingFunctions.retarget = {}
checkingFunctions.retarget["always"] = function(proID)
	if SpGetProjectileTimeToLive(proID) > 0 then
		-- Seems like intended behavior was to keep seeking a target that's still alive.
		-- So this function retargets only if both 1 target death and 2 owner retargets:
		local targetType, target = SpGetProjectileTarget(proID)
		if targetType == targetedUnit and SpGetUnitIsDead(target) == false then
			return false
		end
		local ownerID = active_projectiles[proID]
		if not ownerID then
			ownerID = Spring.GetProjectileOwnerID(proID) or -1
			active_projectiles[proID] = ownerID
		end
		if ownerID >= 0 and SpGetUnitIsDead(ownerID) == false then
			-- Hardcoded to aim from the primary weapon and target only units or ground.
			local ownerTargetType, _, ownerTarget = SpGetUnitWeaponTarget(ownerID, 1)
			if ownerTargetType == 1 then
				SpSetProjectileTarget(proID, ownerTarget, targetedUnit)
			elseif ownerTargetType == 2 then
				SpSetProjectileTarget(proID, ownerTarget[1], ownerTarget[2], ownerTarget[3])
			else
				-- Since other cases are unhandled, just bail.
				return true
			end
			return false
		end
	end
	return true
end

applyingFunctions.sector_fire = function(proID)
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
checkingFunctions.split["altitude<splitat"] = function(proID)
	-- We want to get the airburst height of a ballistic weapon without allowing early split.
	-- That is, we want the lowest projectile altitude where abs(altitude - splitat) < delta.
	local splitNow = false
	local pvx, pvy, pvz = SpGetProjectileVelocity(proID)
	if pvy and pvy < 0 then
		local infos = projectiles[proID]
		local altitude = infos.splitat
		-- Terrain tends to stay still, but the target location might move, so use a param:
		local frameUpdate = infos.splitat_frames or 8
		local px, py, pz = SpGetProjectilePosition(proID)
		local altitudeCurrent = py - SpGetGroundHeight(px, pz)
		if altitude >= altitudeCurrent then
			splitNow = true
		else
			-- Avoid high-velocity projectiles skipping past the split height:
			local nextY = py + (pvy - g * frameUpdate / 2) * frameUpdate
			local altNext = nextY - SpGetGroundHeight(px + pvx, pz + pvz)
			splitNow = altNext < altitude and math.abs(altitudeCurrent) > math.abs(altNext)
		end
		if splitNow then
			-- Avoid premature split when the point of impact is much lower:
			local targetType, target = SpGetProjectileTarget(proID)
			if targetType == targetedGround then
				splitNow = altitude >= py - target[2]
			elseif active_projectiles[proID] and (Spring.GetGameFrame() + proID) % frameUpdate ~= 0 then
				splitNow = altitude >= py - active_projectiles[proID]
			else
				-- Find the trajectory's ground intercept via bisection search.
				local frameMin = frameUpdate
				local frameMax = frameUpdate * 10
				local pos, hei, mid
				for _ = 1, 20 do
					mid = frameMin + (frameMax - frameMin) / 2
					pos = py + pvy * mid + 0.5 * g * mid * mid
					hei = SpGetGroundHeight(px + pvx * mid, pz + pvz * mid)
					if pos - hei < 0 then frameMax = mid else frameMin = mid end
					if frameMax - frameMin <= 1 then break end
				end
				mid = frameMin + (frameMax - frameMin) / 2
				local impactY = SpGetGroundHeight(px + pvx * mid, pz + pvz * mid)
				if altitude < py - impactY then
					splitNow = false
					active_projectiles[proID] = impactY
				end
			end
		end
	end
	return splitNow
end
applyingFunctions.split = function(proID)
	local px, py, pz = SpGetProjectilePosition(proID)
	local vx, vy, vz, vw = SpGetProjectileVelocity(proID)
	local ownerID = Spring.GetProjectileOwnerID(proID)
	local infos = projectiles[proID]
	for i = 1, tonumber(infos.number) do
		local projectileParams = {
			pos = { px, py, pz },
			speed = { vx - vw * (random(-100, 100) / 880), vy - vw * (random(-100, 100) / 440), vz - vw * (random(-100, 100) / 880) },
			owner = ownerID,
			ttl = 3000,
			gravity = -Game.gravity / 900,
			model = infos.model,
			cegTag = infos.cegtag,
		}
		Spring.SpawnProjectile(WeaponDefNames[infos.def].id, projectileParams)
	end
	Spring.SpawnCEG(infos.splitexplosionceg, px, py, pz, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.cannonwaterpen = {}
checkingFunctions.cannonwaterpen["ypos<0"] = elevationIsNonpositive
applyingFunctions.cannonwaterpen = function(proID)
	local px, py, pz = SpGetProjectilePosition(proID)
	local vx, vy, vz = SpGetProjectileVelocity(proID)
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
	Spring.SpawnProjectile(WeaponDefNames[infos.def].id, projectileParams)
	Spring.SpawnCEG(infos.waterpenceg, px, py, pz, 0, 0, 0, 0, 0)
	Spring.DeleteProjectile(proID)
end

checkingFunctions.torpwaterpen = {}
checkingFunctions.torpwaterpen["ypos<0"] = elevationIsNonpositive
applyingFunctions.torpwaterpen = function(proID)
	local vx, vyOld, vz = SpGetProjectileVelocity(proID)
	local targetType, targetID = SpGetProjectileTarget(proID)
	local vyNew = 0
	-- Only dive below surface if the target is at an appreciable depth.
	if targetType == targetedUnit and targetID then
		local _, unitPosY = Spring.GetUnitPosition(targetID)
		if unitPosY and unitPosY < -10 then
			vyNew = vyOld / 6
		end
	end
	-- Brake without halting, else torpedoes may overshoot close targets.
	SpSetProjectileVelocity(proID, vx / 1.3, vyNew, vz / 1.3)
end

checkingFunctions.torpwaterpenretarget = {}
do
	local checkFunction = checkingFunctions.retarget.always
	local applyFunction = applyingFunctions.torpwaterpen
	checkingFunctions.torpwaterpenretarget["ypos<0"] = function(proID)
		local result = checkFunction(proID)
		local _, py = SpGetProjectilePosition(proID)
		if py <= 0 then applyFunction(proID) end
		return result
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
	for weaponDefID, weaponDef in pairs(WeaponDefs) do
		if weaponDef.customParams.speceffect then
			local speceffect = weaponDef.customParams.speceffect
			local when = weaponDef.customParams.when
			local apply = applyingFunctions[speceffect]
			local checks = checkingFunctions[speceffect]
			if apply or (checks and checks[when]) then
				specialWeaponCustomDefs[weaponDefID] = weaponDef.customParams
				if not apply then
					applyingFunctions[speceffect] = defaultApply
				elseif when == defaultCheck.when and (not checks or not checks[when]) then
					checkingFunctions[speceffect] = checkingFunctions[speceffect] or {}
					checkingFunctions[speceffect][defaultCheck.when] = defaultCheck.check
				end
			else
				local message = "Custom weapon has bad custom params: " .. weaponDef.name
				message = message .. ' (speceffect=' .. speceffect .. ',when=' .. (when or 'nil') .. ')'
				Spring.Log(gadget:GetInfo().name, LOG.ERROR, message)
			end
		end
	end
	if not next(specialWeaponCustomDefs) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO, "No custom weapons found. Removing.")
		gadgetHandler:RemoveGadget(self)
		return
	end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if specialWeaponCustomDefs[weaponDefID] then
		projectiles[proID] = specialWeaponCustomDefs[weaponDefID]
		active_projectiles[proID] = nil
	end
end

function gadget:ProjectileDestroyed(proID)
	projectiles[proID] = nil
	active_projectiles[proID] = nil
end

function gadget:GameFrame(f)
	for proID, infos in pairs(projectiles) do
		if checkingFunctions[infos.speceffect][infos.when](proID) then
			applyingFunctions[infos.speceffect](proID)
			projectiles[proID] = nil
			active_projectiles[proID] = nil
		end
	end
end

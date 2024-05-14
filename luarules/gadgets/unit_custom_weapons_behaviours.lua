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

local tonumber = tonumber

local max    = math.max
local random = math.random
local round  = math.round
local sqrt   = math.sqrt
local cos    = math.cos
local sin    = math.sin
local pi     = math.pi

local SpGetGroundHeight         = Spring.GetGroundHeight
local SpGetGroundNormal         = Spring.GetGroundNormal
local SpGetProjectileOwnerID    = Spring.GetProjectileOwnerID
local SpGetProjectilePosition   = Spring.GetProjectilePosition
local SpGetProjectileTarget     = Spring.GetProjectileTarget
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetProjectileVelocity   = Spring.GetProjectileVelocity
local SpGetUnitIsDead           = Spring.GetUnitIsDead
local SpGetUnitPosition         = Spring.GetUnitPosition
local SpGetUnitStates           = Spring.GetUnitStates
local SpGetUnitWeaponTarget     = Spring.GetUnitWeaponTarget

local SpSetProjectileVelocity = Spring.SetProjectileVelocity
local SpSetProjectileTarget   = Spring.SetProjectileTarget
local SpSetProjectilePosition = Spring.SetProjectilePosition

local SpSpawnCEG         = Spring.SpawnCEG
local SpDeleteProjectile = Spring.DeleteProjectile
local SpSpawnProjectile  = Spring.SpawnProjectile

local targetUnit   = string.byte('u')
local targetGround = string.byte('g')
local gameSpeed    = Game.gameSpeed
local mapG         = Game.gravity

if gadgetHandler:IsSyncedCode() then

	local projectiles = {}
	local active_projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}

	local specialWeaponCustomDefs = {}
	local weaponDefNamesID = {}
	for id, def in pairs(WeaponDefs) do
		weaponDefNamesID[def.name] = id
		if def.customParams.speceffect then
			specialWeaponCustomDefs[id] = def.customParams
		end
	end

	--------------------------------------------------------------------------------------------------------------
	---- Weapon behaviors ----------------------------------------------------------------------------------------

	---- Cruise --------------------------------------------------------------------------------------------------

	checkingFunctions.cruise = {}
	checkingFunctions.cruise["distance>0"] = function (proID)
		if SpGetProjectileTimeToLive(proID) <= 0 then
			return true
		end
		local targetTypeInt,target = SpGetProjectileTarget(proID)
		local xx,yy,zz
		local xxv,yyv,zzv
		if targetTypeInt == targetGround then
			xx = target[1]
			yy = target[2]
			zz = target[3]
		end
		if targetTypeInt == targetUnit then
			_,_,_,_,_,_,xx,yy,zz = SpGetUnitPosition(target,true,true)
		end
		local xp,yp,zp = SpGetProjectilePosition(proID)
		local vxp,vyp,vzp = SpGetProjectileVelocity(proID)
		local mag = sqrt(vxp*vxp+vyp*vyp+vzp*vzp)
		local infos = projectiles[proID]
		if sqrt((xp-xx)^2 + (yp-yy)^2 + (zp-zz)^2) > tonumber(infos.lockon_dist) then
			local yg = SpGetGroundHeight(xp,zp)
			local nx,ny,nz,slope= SpGetGroundNormal(xp,zp)
			if yp < yg + tonumber(infos.cruise_min_height) then
				active_projectiles[proID] = true
				SpSetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_min_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				SpSetProjectileVelocity(proID,xxv,yyv,zzv)
			elseif active_projectiles[proID] and vyp > -mag*.25 then
				-- do not clamp to max height if
				-- vertical velocity downward is more than 1/4 of current speed
				-- probably just went off lip of steep cliff
				SpSetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_max_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				SpSetProjectileVelocity(proID,xxv,yyv,zzv)
			end
			return false
		else
			return true
		end
	end

	applyingFunctions.cruise = function (proID)
		return false
    end

	---- Retargeting ---------------------------------------------------------------------------------------------

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
		if targetTypeInt == targetUnit then
			--check if the target unit is dead or dying
			local dead_state = SpGetUnitIsDead(targetID)
			if dead_state == nil or dead_state == true then
				--hardcoded to assume the retarget weapon is the primary weapon.
				--TODO, make this more general
				local target_type,_,owner_target = SpGetUnitWeaponTarget(SpGetProjectileOwnerID(proID),1)
				if target_type == 1 then
					--hardcoded to assume the retarget weapon does not target features or intercept projectiles, only targets units if not shooting ground.
					--TODO, make this more general
					 SpSetProjectileTarget(proID,owner_target,targetUnit)
				end
				if target_type == 2 then
					SpSetProjectileTarget(proID,owner_target[1],owner_target[2],owner_target[3])
				end
			end
		end

		return false
	end

	applyingFunctions.retarget = function (proID)
		return false
    end

	---- Sector fire ---------------------------------------------------------------------------------------------

	checkingFunctions.sector_fire = {}
	checkingFunctions.sector_fire["always"] = function (proID)
		-- as soon as the siege projectile is created, pass true on the
		-- checking function, to go to applying function
		-- so the unit state is only checked when the projectile is created
		return true
	end

	applyingFunctions.sector_fire = function (proID)
		local ownerID = SpGetProjectileOwnerID(proID)
		local ownerState = SpGetUnitStates(ownerID)
		local infos = projectiles[proID]
		--x' = x cos θ − y sin θ
		--y' = x sin θ + y cos θ
		local vx, vy, vz = SpGetProjectileVelocity(proID)

		local angle_factor = (tonumber(infos.spread_angle)*random()-tonumber(infos.spread_angle)*0.5)*pi/180
		local vx_new = vx*cos(angle_factor) - vz*sin(angle_factor)
		local vz_new = vx*sin(angle_factor) + vz*cos(angle_factor)

		local velocity_factor = 1-(random()) ^(1+tonumber(infos.max_range_reduction))*tonumber(infos.max_range_reduction) 		
		vx = vx_new*velocity_factor
		vz = vz_new*velocity_factor

		SpSetProjectileVelocity(proID,vx,vy,vz)
    end

	---- Split ---------------------------------------------------------------------------------------------------

	checkingFunctions.split = {}
	checkingFunctions.split["yvel<0"] = function (proID)
		local _,vy,_ = SpGetProjectileVelocity(proID)
		return vy < 0
	end

	applyingFunctions.split = function (proID)
		local px, py, pz = SpGetProjectilePosition(proID)
		local vx, vy, vz = SpGetProjectileVelocity(proID)
		local vw = sqrt(vx*vx + vy*vy + vz*vz)
		local ownerID = SpGetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		for i = 1, tonumber(infos.number) do
			local projectileParams = {
				pos = {px, py, pz},
				speed = {vx - vw*(random(-100,100)/880), vy - vw*(random(-100,100)/440), vz - vw*(random(-100,100)/880)},
				owner = ownerID,
				ttl = 3000,
				gravity = -mapG/900,
				model = infos.model,
				cegTag = infos.cegtag,
			}
			SpSpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		end
		SpSpawnCEG(infos.splitexplosionceg, px, py, pz,0,0,0,0,0)
		SpDeleteProjectile(proID)
	end

	---- Water penetration ---------------------------------------------------------------------------------------

	checkingFunctions.cannonwaterpen = {}
	checkingFunctions.cannonwaterpen["ypos<0"] = function (proID)
		local _,py,_ = SpGetProjectilePosition(proID)
		return py < 0
	end

	checkingFunctions.torpwaterpen = {}
    checkingFunctions.torpwaterpen["ypos<0"] = function (proID)
        local _,py,_ = SpGetProjectilePosition(proID)
        return py < 0
    end

	applyingFunctions.cannonwaterpen = function (proID)
		local px, py, pz = SpGetProjectilePosition(proID)
		local vx, vy, vz = SpGetProjectileVelocity(proID)
		local nvx, nvy, nvz = vx * 0.5, vy * 0.5, vz * 0.5
		local ownerID = SpGetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		local projectileParams = {
			pos = {px, py, pz},
			speed = {nvx, nvy, nvz},
			owner = ownerID,
			ttl = 3000,
			gravity = -mapG/3600,
			model = infos.model,
			cegTag = infos.cegtag,
		}
		SpSpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		SpSpawnCEG(infos.waterpenceg, px, py, pz,0,0,0,0,0)
		SpDeleteProjectile(proID)
	end

	applyingFunctions.torpwaterpen = function (proID)
		local vx, vy, vz = SpGetProjectileVelocity(proID)
        SpSetProjectileVelocity(proID,vx,0,vz)
    end

	--------------------------------------------------------------------------------------------------------------
	---- Gadget --------------------------------------------------------------------------------------------------

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
			if checkingFunctions[infos.speceffect][infos.when](proID) == true then
				applyingFunctions[infos.speceffect](proID)
				projectiles[proID] = nil
				active_projectiles[proID] = nil
			end
		end
	end
end

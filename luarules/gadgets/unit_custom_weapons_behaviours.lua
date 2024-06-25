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

local random = math.random

local SpSetProjectileVelocity = Spring.SetProjectileVelocity
local SpSetProjectileTarget = Spring.SetProjectileTarget

local SpGetProjectileVelocity = Spring.GetProjectileVelocity
local SpGetProjectileOwnerID = Spring.GetProjectileOwnerID
local SpGetUnitStates = Spring.GetUnitStates
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
local SpGetProjectileTarget = Spring.GetProjectileTarget
local SpGetUnitIsDead = Spring.GetUnitIsDead

if gadgetHandler:IsSyncedCode() then

	local projectiles = {}
	local active_projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}
	local math_sqrt = math.sqrt

	local specialWeaponCustomDefs = {}
	local weaponDefNamesID = {}
	for id, def in pairs(WeaponDefs) do
		weaponDefNamesID[def.name] = id
		if def.customParams.speceffect then
			specialWeaponCustomDefs[id] = def.customParams
		end
	end

	checkingFunctions.cruise = {}
	checkingFunctions.cruise["distance>0"] = function (proID)
		--Spring.Echo()

		if Spring.GetProjectileTimeToLive(proID) <= 0 then
			return true
		end
		local targetTypeInt,target = Spring.GetProjectileTarget(proID)
		local xx,yy,zz
		local xxv,yyv,zzv
		if targetTypeInt == string.byte('g') then
			xx = target[1]
			yy = target[2]
			zz = target[3]
		end
		if targetTypeInt == string.byte('u') then
			_,_,_,_,_,_,xx,yy,zz = Spring.GetUnitPosition(target,true,true)
		end
		local xp,yp,zp = Spring.GetProjectilePosition(proID)
		local vxp,vyp,vzp = Spring.GetProjectileVelocity(proID)
		local mag = math_sqrt(vxp*vxp+vyp*vyp+vzp*vzp)
		local infos = projectiles[proID]
		if math_sqrt((xp-xx)^2 + (yp-yy)^2 + (zp-zz)^2) > tonumber(infos.lockon_dist) then
			yg = Spring.GetGroundHeight(xp,zp)
			nx,ny,nz,slope= Spring.GetGroundNormal(xp,zp)
			--Spring.Echo(Spring.GetGroundNormal(xp,zp))
			--Spring.Echo(tonumber(infos.cruise_height)*slope)
			if yp < yg + tonumber(infos.cruise_min_height) then
				active_projectiles[proID] = true
				Spring.SetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_min_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				Spring.SetProjectileVelocity(proID,xxv,yyv,zzv)
			end
			if yp > yg + tonumber(infos.cruise_max_height) and active_projectiles[proID] and vyp > -mag*.25 then
				-- do not clamp to max height if
				-- vertical velocity downward is more than 1/4 of current speed
				-- probably just went off lip of steep cliff
				Spring.SetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_max_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				Spring.SetProjectileVelocity(proID,xxv,yyv,zzv)
			end
			return false
		else
			return true
		end
	end

	applyingFunctions.cruise = function (proID)
		return false
    end

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
		--if ownerState.active == true then
		local infos = projectiles[proID]
		--x' = x cos θ − y sin θ
		--y' = x sin θ + y cos θ
		local vx, vy, vz = SpGetProjectileVelocity(proID)

		angle_factor = tonumber(infos.spread_angle)*random()-tonumber(infos.spread_angle)*0.5
		angle_factor = angle_factor*math.pi/180
		vx_new = vx*math.cos(angle_factor) - vz*math.sin(angle_factor)
		vz_new = vx*math.sin(angle_factor) + vz*math.cos(angle_factor)

		--vx_new = vx
		--vz_new = vz
		--velocity_reduction = 1-math.sqrt(1-tonumber(infos.max_range_reduction))
		--velocity_floor = (1-velocity_reduction)^2
		--velocity_factor = random()*(1-velocity_floor)
		--velocity_factor = math.sqrt(velocity_floor+velocity_factor)
		velocity_factor = 1-(random()) ^(1+tonumber(infos.max_range_reduction))*tonumber(infos.max_range_reduction) 		
		vx = vx_new*velocity_factor
		--vy = vy*velocity_factor
		vz = vz_new*velocity_factor

		SpSetProjectileVelocity(proID,vx,vy,vz)
		--end
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

	applyingFunctions.retarget = function (proID)
		return false
    end

	checkingFunctions.cannonwaterpen = {}
	checkingFunctions.cannonwaterpen["ypos<0"] = function (proID)
		local _,y,_ = Spring.GetProjectilePosition(proID)
		if y <= 0 then
			return true
		else
			return false
		end
	end

	checkingFunctions.split = {}
	checkingFunctions.split["yvel<0"] = function (proID)
		local _,vy,_ = Spring.GetProjectileVelocity(proID)
		if vy < 0 then
			return true
		else
			return false
		end
	end

	checkingFunctions.torpwaterpen = {}
    checkingFunctions.torpwaterpen["ypos<0"] = function (proID)
        local _,py,_ = Spring.GetProjectilePosition(proID)
        if py <= 0 then
            return true
        else
            return false
        end
    end

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
			Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		end
		Spring.SpawnCEG(infos.splitexplosionceg, px, py, pz,0,0,0,0,0)
		Spring.DeleteProjectile(proID)
	end

	---- For Legion nukes
	-- Changing out "split" for "disperse", which will spread projectiles evenly.
	-- We want a change in target position equal to a "dispersion radius".
	-- This works very differently for ballistic and non-ballistic projectiles.
	-- And I added an optional middle projectile because you never know.

	checkingFunctions.disperse = {}
	checkingFunctions.disperse["ypos<altitude"] = function (proID)
		local altitude = active_projectiles[proID]

		if not altitude then
			-- Check if the base unit has a MIRV ability command toggle.
			-- todo: Spring.FindUnitCmdDesc(unitID, CMD_SOME_WEAPON_TOGGLE)
			local yesItDoes = true
			local butItIsToggledOff = true
			if yesItDoes and not butItIsToggledOff then
				projectiles[proID] = nil
				return false
			end

			-- Force targeting onto the ground to get a consistent target elevation.
			local elevation
			local targeting, target = Spring.GetProjectileTarget(proID)
			if targeting == string.byte('u') then
				local ux, uy, uz = Spring.GetUnitPosition(target)
				Spring.SetProjectileTarget(proID, ux, uy, uz)
				elevation = uy
			else
				elevation = target[2]
			end
			altitude = math.max(0, elevation) + tonumber(projectiles[proID].disperse_altitude)
			active_projectiles[proID] = altitude
		end

		local _, vy, _ = Spring.GetProjectileVelocity(proID)
		if vy >= 0 then return false end

		local _, py, _ = Spring.GetProjectilePosition(proID)
		return py <= altitude
	end

	-- Momentum sits within a range, the extremes of which are maybe useless.
	-- Rather than restart to test momentum, hardcode a value and /luarules reload.
	-- 0.0: Spawned projectiles mostly ignore parent momentum.
	-- 1.0: Spawned projectiles follow parent path almost exactly.

	applyingFunctions.disperse = function (proID)
		local ownerID = Spring.GetProjectileOwnerID(proID)
		local px, py, pz = Spring.GetProjectilePosition(proID)
		local vx, vy, vz, vw = Spring.GetProjectileVelocity(proID)
		local tx, ty, tz
		do
			local targeting, target = SpGetProjectileTarget(proID)
			if targeting == string.byte('u')
			then tx, ty, tz = Spring.GetUnitPosition(target)
			else tx, ty, tz = target[1], target[2], target[3] end
		end

		local spawnCEG, middleDefID, spawnDefID, spawnType, spawnCount, spawnSpeed, momentum, radius
		do
			local infos = projectiles[proID]
			local weaponDef = WeaponDefNames[tostring(infos.disperse_def)]
			if not weaponDef then
				Spring.Echo('disperse did not find weaponDef named '..infos.disperse_def)
				return
			end
			spawnCEG = infos.disperse_ceg
			middleDefID = infos.disperse_middleDef and WeaponDefNames[tostring(infos.disperse_middleDef)]
			spawnDefID = weaponDef.id
			spawnType = weaponDef.type
			spawnSpeed = weaponDef.startvelocity or 0
			spawnCount = tonumber(infos.disperse_number)
			momentum = tonumber(infos.disperse_momentum)
			radius = tonumber(infos.disperse_radius)

			middleDefID = middleDefID and middleDefID.id or nil
			-- spawnSpeed = math.clamp(spawnSpeed + (vw - spawnSpeed) * momentum, 1, weaponDef.weaponVelocity) -- i dunno the internal name for maxVelocity
			spawnSpeed = spawnSpeed + (vw - spawnSpeed) * momentum
		end

		local spawnParams = {
			pos     = { px, py, pz },
			speed   = { 0, 0, 0 },
			owner   = ownerID,
			ttl     = 300,
			gravity = -Game.gravity/900,
		}

		-- Handle projectiles along the main trajectory.
		if middleDefID then
			spawnParams.speed[1] = vx / vw * spawnSpeed
			spawnParams.speed[2] = vy / vw * spawnSpeed
			spawnParams.speed[3] = vz / vw * spawnSpeed
			local spawnID = Spring.SpawnProjectile(middleDefID, spawnParams) or 0
			Spring.SetProjectileTarget(spawnID, tx, ty, tz)
		end
		Spring.SpawnCEG(spawnCEG, px,py,pz, 0,0,0, 0,0)
		Spring.DeleteProjectile(proID)

		-- Handle projectiles along the dispersion trajectories.
		local interval = 2 * math.pi / spawnCount
		local rotation = interval * math.random()

		if spawnType == "MissileLauncher" then
			-- Constrain the angle between the main and dispersion trajectories.
			local rx, ry, rz = px - tx, py - ty, pz - tz
			local rw = math.sqrt(rx*rx + ry*ry + rz*rz)
			local angleDepartureMin = math.atan2(radius / 2 * (1.001 - momentum*momentum), rw)
			local angleDepartureMax = math.atan2(radius * 2 * (1.001 - momentum*momentum), rw)
			Spring.Echo(string.format('dispersion min/max: %.2f/%.2f', angleDepartureMin, angleDepartureMax))

			-- For each spawned projectile, probe for a trajectory that satisfies our constraints.
			local cosr, sinr, vx2, vy2, vz2, vw2, angle
			for _ = 1, spawnCount do
				-- Target a point along an approximate circle around the target location. -- todo: circle => sphere?
				rotation = rotation + interval
				cosr = math.cos(rotation)
				sinr = math.sin(rotation)
				rx = tx + cosr * radius
				rz = tz + sinr * radius
				ry = math.max(0, Spring.GetGroundHeight(rx, rz))
				-- Determine the angle between the parent and spawn directions.
				vx2, vy2, vz2 = rx - px, ry - py, rz - pz
				vw2 = math.sqrt(vx2*vx2 + vy2*vy2 + vz2*vz2)
				angle = math.acos((vx*vx2 + vy*vy2 + vz*vz2) / vw / vw2)
				-- Reduce undershooting and overshooting of the target ring, as possible.
				-- We shrink toward the center to minimize overshooting, especially, bc it is a range advantage.
				if angle < angleDepartureMin or angle > angleDepartureMax then
					local steps = 1
					repeat
						Spring.Echo('angle before '..steps..' shift: '..angle)
						rx = tx + cosr * (radius * (1.00 - 0.10 * steps)) -- Shave 10% off the radius each step,
						rz = tz + sinr * (radius * (1.00 - 0.10 * steps)) -- and recalculate from the new position.
						ry = math.max(0, Spring.GetGroundHeight(rx, rz))
						vx2, vy2, vz2 = rx - px, ry - py, rz - pz
						vw2 = math.sqrt(vx2*vx2 + vy2*vy2 + vz2*vz2)
						angle = math.acos((vx*vx2 + vy*vy2 + vz*vz2) / vw / vw2)
						steps = steps + 1
					until steps == 5
					   or (angle >= angleDepartureMin and angle <= angleDepartureMax)
				end
				Spring.Echo(string.format('angle/min/max: %.2f/%.2f/%.2f', angle, angleDepartureMin, angleDepartureMax))
				-- Fire ze missiles.
				spawnParams.speed[1] = vx2 / vw2 * spawnSpeed
				spawnParams.speed[2] = vy2 / vw2 * spawnSpeed
				spawnParams.speed[3] = vz2 / vw2 * spawnSpeed
				local spawnID = Spring.SpawnProjectile(spawnDefID, spawnParams) or 0
				Spring.SetProjectileTarget(spawnID, rx, ry, rz) -- todo: test on weapon with a turnRate
			end
		end
	end

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
		Spring.SpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		Spring.SpawnCEG(infos.waterpenceg, px, py, pz,0,0,0,0,0)
		Spring.DeleteProjectile(proID)
	end

	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		local wDefID = Spring.GetProjectileDefID(proID)
		if specialWeaponCustomDefs[wDefID] then
			projectiles[proID] = specialWeaponCustomDefs[wDefID]
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

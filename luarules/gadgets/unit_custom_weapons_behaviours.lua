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
local sqrt   = math.sqrt

local SpGetProjectileOwnerID    = Spring.GetProjectileOwnerID
local SpGetProjectileTarget     = Spring.GetProjectileTarget
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetProjectileVelocity   = Spring.GetProjectileVelocity
local SpGetUnitIsDead           = Spring.GetUnitIsDead
local SpGetUnitStates           = Spring.GetUnitStates
local SpGetUnitWeaponTarget     = Spring.GetUnitWeaponTarget

local SpSetProjectileVelocity   = Spring.SetProjectileVelocity
local SpSetProjectileTarget     = Spring.SetProjectileTarget

if gadgetHandler:IsSyncedCode() then

	local projectiles = {}
	local active_projectiles = {}
	local checkingFunctions = {}
	local applyingFunctions = {}

	local WeaponDefNames = WeaponDefNames
	local specialWeaponCustomDefs = {}
	for id, def in pairs(WeaponDefs) do
		if def.customParams.speceffect then
			specialWeaponCustomDefs[id] = def.customParams
		end
	end


	----------------------------------------------------------------------------------------------------------
	-- Custom weapon behaviours ------------------------------------------------------------------------------

	-- Cruise ------------------------------------------------------------------------------------------------

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
		local mag = sqrt(vxp*vxp+vyp*vyp+vzp*vzp)
		local infos = projectiles[proID]
		if sqrt((xp-xx)^2 + (yp-yy)^2 + (zp-zz)^2) > tonumber(infos.lockon_dist) then
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

	-- Retarget ----------------------------------------------------------------------------------------------

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

	-- Sector fire -------------------------------------------------------------------------------------------

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

	-- Split / multi-projectile ------------------------------------------------------------------------------

	checkingFunctions.split = {}
	checkingFunctions.split["yvel<0"] = function (proID)
		local _,vy,_ = Spring.GetProjectileVelocity(proID)
		if vy < 0 then
			return true
		else
			return false
		end
	end

	applyingFunctions.split = function (proID)
		local px, py, pz = Spring.GetProjectilePosition(proID)
		local vx, vy, vz = Spring.GetProjectileVelocity(proID)
		local vw = sqrt(vx*vx + vy*vy + vz*vz)
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

	---- For Legion nukes
	-- Changing out "split" for "disperse", which will spread projectiles evenly.
	-- We want a change in target position equal to a "dispersion radius".
	-- This works very differently for ballistic and non-ballistic projectiles.
	-- And I added an optional middle projectile because you never know.

	checkingFunctions.disperse = {}
	checkingFunctions.disperse["ypos<altitude"] = function (proID)
		if not active_projectiles[proID] then
			-- Move targeting onto the ground for consistent target elevation.
			local tx, ty, tz
			local targeting, target = Spring.GetProjectileTarget(proID)
			if targeting == string.byte('u') then
				tx, ty, tz = Spring.GetUnitPosition(target)
				Spring.SetProjectileTarget(proID, tx, ty, tz)
			else
				tx, ty, tz = target[1], target[2], target[3]
			end
			local altitude = math.max(0, ty) + tonumber(projectiles[proID].disperse_altitude)
			active_projectiles[proID] = { tx, altitude, tz, false }
		end

		local tx, sy, tz, hasLeveled = unpack(active_projectiles[proID])
		local px, py, pz = Spring.GetProjectilePosition(proID)
		local vx, vy, vz, vw = Spring.GetProjectileVelocity(proID)

		-- Handle the StarburstLauncher vertical launch.
		if hasLeveled == false then
			if vy >= 0 then return false end
			active_projectiles[proID][4] = true
			-- Suspend the engine's control over the missile.
			Spring.SetProjectileMoveControl(proID, true)
		end

		-- Simple high-altitude cruise control program:
		local splitHeight  = tonumber(projectiles[proID].disperse_altitude)
		local cruiseHeight = 200 + splitHeight * 8
		local diveDistance = (px-tx)*(px-tx) + (pz-tz)*(pz-tz)
		if diveDistance <= splitHeight * splitHeight * 2.5 then
			-- Dive when close to target.
			local avel = math.atan2(vy, math.sqrt(vx*vx + vz*vz))
			local apos -- target pitch angle; depends on distance to target.
			if diveDistance > splitHeight * splitHeight then
				apos = math.atan2(sy               - py, math.sqrt(diveDistance))
			else                  -- turn toward ground:
				apos = math.atan2(sy - splitHeight - py, math.sqrt(diveDistance))
			end
			vy = vy + 2 * (apos - avel) / (math.pi/4)
		else
			-- Cruise when far from target.
			vy = vy + (cruiseHeight - py - vy * 10) / cruiseHeight / 30 + Game.gravity / 1800
		end

		local projVelocityMax = 1500 / 30 -- todo
		local norm = math.sqrt(vx*vx + vy*vy + vz*vz)
		vx = vx / norm * projVelocityMax
		vz = vz / norm * projVelocityMax
		Spring.SetProjectilePosition(proID, px + vx, py + vy, pz + vz)
		Spring.SetProjectileVelocity(proID, vx, vy - Game.gravity / 900, vz)

		return py <= sy
	end

	-- Momentum sits within a range, the extremes of which are maybe useless.
	-- Rather than restart to test momentum, hardcode a value and /luarules reload.
	-- 0.0: Spawned projectiles mostly ignore parent momentum.
	-- 1.0: Spawned projectiles follow parent path almost exactly.

	applyingFunctions.disperse = function (proID)
		-- Check if the base unit has a MIRV ability command toggle.
		-- local yesItDoes = true
		-- local butItIsToggledOff = true
		-- if yesItDoes and butItIsToggledOff then
		-- 	projectiles[proID] = nil
		-- 	return
		-- end

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

		local spawnCEG, middleDefID, spawnDefID, spawnType, spawnCount, spawnSpeed, turnRate, momentum, radius
		do
			local infos = projectiles[proID]
			local weaponDef = WeaponDefNames[tostring(infos.disperse_def)]
			if not weaponDef then
				Spring.Echo('disperse did not find weaponDef named '..infos.disperse_def)
				return
			end
			spawnDefID = weaponDef.id
			spawnType = weaponDef.type
			spawnCEG = infos.disperse_ceg
			middleDefID = infos.disperse_middledef and WeaponDefNames[infos.disperse_middledef]
			middleDefID = middleDefID and middleDefID.id or nil
			spawnCount = tonumber(infos.disperse_number)
			radius = tonumber(infos.disperse_radius)

			spawnSpeed = weaponDef.startvelocity or weaponDef.weaponvelocity or 0
			momentum = tonumber(infos.disperse_momentum)
			spawnSpeed = spawnSpeed + (vw - spawnSpeed) * momentum
			turnRate = weaponDef.turnRate or false
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
			local spawnID = Spring.SpawnProjectile(middleDefID, spawnParams)
			if spawnID then Spring.SetProjectileTarget(spawnID, tx, ty, tz) end
		end
		Spring.SpawnCEG(spawnCEG, px,py,pz, 0,0,0, 0,0)
		Spring.DeleteProjectile(proID)

		-- Handle projectiles along the dispersion trajectories.
		local interval = 2 * math.pi / spawnCount
		local rotation = interval * random()

		if spawnType == "MissileLauncher" then
			if turnRate and turnRate > 10 then
				-- Assume the projectile will navigate to the destination independently.
				-- Split along a fixed dispersion angle and target along a fixed circle.
				local rx, ry, rz = tx - px, ty - py, tz - pz
				local rw = sqrt(rx*rx + ry*ry + rz*rz)
				local angleDeparture = math.atan2(radius * (1.001 - momentum*momentum), rw)

				-- Parameterize the departure direction and target location.
				-- (1) Get the main trajectory's direction as a unit vector.
				rx, ry, rz = rx / rw, ry / rw, rz / rw
				-- (2) Get two unit vectors a, b forming an orthogonal basis r, a, b.
				-- For angles φ in (0,π/2) and θ in [0,2π), these give the direction:
				-- d = r + tan(φ) (a cosθ + b sinθ).
				-- (3) By pinning ay, we can reuse θ to find the angle along the dispersion radius.
				local anglePerpendicularInXZ = math.atan2(rz, rx) + math.pi / 2
				local ax = math.cos(anglePerpendicularInXZ)
				local az = math.sin(anglePerpendicularInXZ)
				local bx = ry * az - 0  * rz -- ay == 0
				local by = rx * az - ax * rz
				local bz = rx * 0  - ax * ry -- ay == 0
				local angleTan = math.tan(angleDeparture)
				rotation = rotation + anglePerpendicularInXZ

				local cosr, sinr, dx, dy, dz, cx, cy, cz
				for _ = 1, spawnCount do
					rotation = rotation + interval
					cosr = math.cos(rotation)
					sinr = math.sin(rotation)
					-- Direction along both the rotation and departure angles.
					dx = rx + angleTan * (ax * cosr + bx * sinr)
					dy = ry + angleTan * (            by * sinr) -- ay == 0
					dz = rz + angleTan * (az * cosr + bz * sinr)
					-- Target location is a point along a circle drawn in XZ.
					cx = tx + cosr * radius
					cz = tz + sinr * radius
					cy = math.max(0, Spring.GetGroundHeight(cx, cz))

					spawnParams.speed[1] = dx * spawnSpeed
					spawnParams.speed[2] = dy * spawnSpeed
					spawnParams.speed[3] = dz * spawnSpeed
					local spawnID = Spring.SpawnProjectile(spawnDefID, spawnParams) or 0
					Spring.SetProjectileTarget(spawnID, cx, cy, cz)
				end
			else
				-- We're launching rockets, not missiles, so we do a lot more work.
				-- Constrain the angle between the main and dispersion trajectories.
				local rx, ry, rz = px - tx, py - ty, pz - tz
				local rw = math.sqrt(rx*rx + ry*ry + rz*rz)
				local angleDepartureMin = math.atan2(radius / 2 * (1.001 - momentum*momentum) / 1.001, rw)
				local angleDepartureMax = math.atan2(radius * 2 * (1.001 - momentum*momentum) / 1.001, rw)
				-- Spring.Echo(string.format('dispersion min/max: %.2f/%.2f', angleDepartureMin, angleDepartureMax))

				-- For each spawned projectile, probe for a trajectory that satisfies our constraints.
				local cosr, sinr, vx2, vy2, vz2, vw2, angle
				for _ = 1, spawnCount do
					-- Target a point along an approximate circle around the target location.
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
							-- Spring.Echo('angle before '..steps..' shift: '..angle)
							rx = tx + cosr * (radius * (1.00 - 0.125 * steps)) -- Shave 12.5% off the radius each step,
							rz = tz + sinr * (radius * (1.00 - 0.125 * steps)) -- and recalculate from the new position.
							ry = math.max(0, Spring.GetGroundHeight(rx, rz))
							vx2, vy2, vz2 = rx - px, ry - py, rz - pz
							vw2 = math.sqrt(vx2*vx2 + vy2*vy2 + vz2*vz2)
							angle = math.acos((vx*vx2 + vy*vy2 + vz*vz2) / vw / vw2)
							steps = steps + 1
						until steps == 3
						   or (angle >= angleDepartureMin and angle <= angleDepartureMax)
					end
					-- Spring.Echo(string.format('angle/min/max: %.2f/%.2f/%.2f', angle, angleDepartureMin, angleDepartureMax))
					spawnParams.speed[1] = vx2 / vw2 * spawnSpeed
					spawnParams.speed[2] = vy2 / vw2 * spawnSpeed
					spawnParams.speed[3] = vz2 / vw2 * spawnSpeed
					local spawnID = Spring.SpawnProjectile(spawnDefID, spawnParams) or 0
					Spring.SetProjectileTarget(spawnID, rx, ry, rz)
				end
			end
		end
	end

	-- Water penetration -------------------------------------------------------------------------------------

	checkingFunctions.cannonwaterpen = {}
	checkingFunctions.cannonwaterpen["ypos<0"] = function (proID)
		local _,y,_ = Spring.GetProjectilePosition(proID)
		if y <= 0 then
			return true
		else
			return false
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
		Spring.SpawnProjectile(weaponDefNames[infos.def].id, projectileParams)
		Spring.SpawnCEG(infos.waterpenceg, px, py, pz,0,0,0,0,0)
		Spring.DeleteProjectile(proID)
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
			Spring.SetProjectileVelocity(proID,vx,-0.1,vz) -- set a fixed descent speed
		end
    end

	--a Hornet special, mangle different two things into working as one (they're otherwise mutually exclusive)
	checkingFunctions.torpwaterpenretarget = {}
    checkingFunctions.torpwaterpenretarget["ypos<0"] = function (proID)
		-- Check for waterpen
		if not active_projectiles[proID] then
			local _, py, _ = Spring.GetProjectilePosition(proID)
			if py <= 0 then
				applyingFunctions.torpwaterpen(proID) --and delegate that too
			else
				return false
			end
			active_projectiles[proID] = true
		end

		-- Then, begin retargeting
		checkingFunctions.retarget["always"](proID) --subcontract that part
		return false -- never run the apply function
    end

	applyingFunctions.torpwaterpenretarget = function (proID)
		return false
	end

	----------------------------------------------------------------------------------------------------------
	-- Gadget call-ins ---------------------------------------------------------------------------------------

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

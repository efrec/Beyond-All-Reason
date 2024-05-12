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

local random    = math.random
local max       = math.max
local math_sqrt = math.sqrt
local cos       = math.cos
local sin       = math.sin

local SpGetGameFrame            = Spring.GetGameFrame
local SpGetProjectileDefID      = Spring.GetProjectileDefID
local SpGetProjectileOwnerID    = Spring.GetProjectileOwnerID
local SpGetProjectilePosition   = Spring.GetProjectilePosition
local SpGetProjectileVelocity   = Spring.GetProjectileVelocity
local SpGetProjectileTarget     = Spring.GetProjectileTarget
local SpGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local SpGetUnitIsDead           = Spring.GetUnitIsDead
local SpGetUnitPosition         = Spring.GetUnitPosition
local SpGetUnitStates           = Spring.GetUnitStates
local SpGetUnitWeaponTarget     = Spring.GetUnitWeaponTarget

local SpGetGroundHeight       = Spring.GetGroundHeight
local SpGetGroundNormal       = Spring.GetGroundNormal
local SpSetProjectilePosition = Spring.SetProjectilePosition
local SpSetProjectileTarget   = Spring.SetProjectileTarget
local SpSetProjectileVelocity = Spring.SetProjectileVelocity

local SpDeleteProjectile = Spring.DeleteProjectile
local SpSpawnCEG         = Spring.SpawnCEG
local SpSpawnProjectile  = Spring.SpawnProjectile

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

	local GAME_SPEED   = 30
	local g            = Game.gravity
	local targetGround = string.byte('g')
	local targetUnit   = string.byte('u')

	-- Cruise ----------------------------------------------------------------------------------------------------

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
		local mag = math_sqrt(vxp*vxp+vyp*vyp+vzp*vzp)
		local infos = projectiles[proID]
		if math_sqrt((xp-xx)^2 + (yp-yy)^2 + (zp-zz)^2) > tonumber(infos.lockon_dist) then
			local yg = SpGetGroundHeight(xp,zp)
			local nx,ny,nz,slope= SpGetGroundNormal(xp,zp)
			--SpEcho(SpGetGroundNormal(xp,zp))
			--SpEcho(tonumber(infos.cruise_height)*slope)
			if yp < yg + tonumber(infos.cruise_min_height) then
				active_projectiles[proID] = true
				SpSetProjectilePosition(proID,xp,yg + tonumber(infos.cruise_min_height),zp)
				local norm = (vxp*nx+vyp*ny+vzp*nz)
				xxv = vxp - norm*nx*0
				yyv = vyp - norm*ny
				zzv = vzp - norm*nz*0
				SpSetProjectileVelocity(proID,xxv,yyv,zzv)
			end
			if yp > yg + tonumber(infos.cruise_max_height) and active_projectiles[proID] and vyp > -mag*.25 then
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

	-- Sector Fire -----------------------------------------------------------------------------------------------

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

		local angle_factor = tonumber(infos.spread_angle)*random()-tonumber(infos.spread_angle)*0.5
		angle_factor = angle_factor*math.pi/180
		local vx_new = vx*cos(angle_factor) - vz*sin(angle_factor)
		local vz_new = vx*sin(angle_factor) + vz*cos(angle_factor)
		local velocity_factor = 1-(random()) ^(1+tonumber(infos.max_range_reduction))*tonumber(infos.max_range_reduction) 		
		vx = vx_new*velocity_factor
		vz = vz_new*velocity_factor

		SpSetProjectileVelocity(proID,vx,vy,vz)
	end

	-- Retargeting -----------------------------------------------------------------------------------------------

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

	-- Water Penetration -----------------------------------------------------------------------------------------

	checkingFunctions.cannonwaterpen = {}
	checkingFunctions.cannonwaterpen["ypos<0"] = function (proID)
		local _,py,_ = SpGetProjectilePosition(proID)
		return py <= 0
	end

	checkingFunctions.torpwaterpen = {}
	checkingFunctions.torpwaterpen["ypos<0"] = function (proID)
		local _,py,_ = SpGetProjectilePosition(proID)
		return py <= 0
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
			gravity = -g/3600,
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

	-- Split Projectiles -----------------------------------------------------------------------------------------

	checkingFunctions.split = {}
	checkingFunctions.split["yvel<0"] = function (proID)
		local _,vy,_ = SpGetProjectileVelocity(proID)
		return vy < 0
	end
	checkingFunctions.split["altitude<splitat"] = function (proID)
		-- We want to get the airburst height of a ballistic weapon without allowing early split.
		-- That is, in the case we are firing over a high barrier toward a lower, distant target,
		-- split at the lowest possible ypos where the projectile falls below the splitat height.
		local pvx, pvy, pvz = SpGetProjectileVelocity(proID)
		if pvy > 0 then return false end

		local infos = projectiles[proID]
		local splitat = tonumber(infos.splitat) or 50

		local px, py, pz   = SpGetProjectilePosition(proID)
		local pel          = SpGetGroundHeight(px, pz)
		local ttyp, target = SpGetProjectileTarget(proID)
		local ny, nel, tel

		-- todo: Change to a timed-fuse method by calculating the time-to-impact,
		-- todo: then set the projectile to split on a countdown using GameFrame.
		-- todo: This can also be smoothed out using mod(frame + id, resolution).
		local timed  = infos.timed or false
		local frames = 5

		-- Ground-targeting is ideal since the engine pre-determines the impact site.
		-- Place Target On Ground by Itanthias is a good solution for non-homing airbursts.
		-- To use it, set `customparams={place_target_on_ground=true}` on the weapondef.
		if ttyp == targetGround then
			ny  = py + pvy - 0.5 * g
			nel = max(0, SpGetGroundHeight(px + pvx, pz + pvz))
			tel = max(0, target[2])

		elseif not timed then
			-- Reduce our resolution by some amount.
			if (SpGetGameFrame() + proID) % frames ~= 0 then return false end

			-- Get the next position at exactly time = `frames`.
			ny  = py + (pvy - g * frames / 2) * frames
			nel = max(0, SpGetGroundHeight(px + pvx * frames, pz + pvz * frames))

			-- Estimate the time-to-impact; bisection search for ground-trajectory intercept.
			local ttimin = frames
			local ttimax = frames + 6 * GAME_SPEED
			local mid, pos
			for _ = 1, 8 do
				mid = (ttimin + ttimax) / 2
				pos = py + (pvy + g * mid / 2) * mid
				tel = max(0, SpGetGroundHeight(px + pvx * mid, pz + pvz * mid))
				if pos - tel < 0 then ttimax = mid else ttimin = mid end
				if ttimax - ttimin <= frames then break end -- frames as a tolerance
			end
			-- Our estimate is the projectile position at time = midpoint (which we update).
			mid = (ttimin + ttimax) / 2
			tel = max(0, SpGetGroundHeight(px + pvx * mid, pz + pvz * mid))

		else
			local active = active_projectiles[proID]
			-- In case you launch a thousand projectiles with timed fusing at the same time,
			-- we stagger the trajectory calculations across frames.
			if not active then
				active_projectiles[proID] = {
					seed  = proID % frames,
					fuse = -1
				}
				active = active_projectiles[proID]
			end
			if active.seed ~= 0 then
				active.seed = active.seed - 1
				return false
			end

			-- We use another countdown to detect when to airburst.
			if active.fuse ~= -1 then
				if active.fuse ~= 0 then
					active.fuse = active.fuse - 1
					return false
				end
				return true
			end

			-- Estimate the time to impact and set the timed fusing.
			local ttimin = frames
			local ttimax = frames + 30 * GAME_SPEED -- todo: this lookahead is way too long for many maps
			local mid, pos
			for _ = 1, 10 do
				mid = (ttimin + ttimax) / 2
				pos = py + (pvy + g * mid / 2) * mid
				tel = max(0, SpGetGroundHeight(px + pvx * mid, pz + pvz * mid))
				if pos - tel < 0 then ttimax = mid else ttimin = mid end
				if ttimax - ttimin <= frames then break end -- frames as a tolerance
			end
			mid = (ttimin + ttimax) / 2
			tel = max(0, SpGetGroundHeight(px + pvx * mid, pz + pvz * mid))

			-- By inverse kinematics we have two known quantities:
			-- delta(y) = projectile_y - target_y + splitat, and
			-- delta(y) = velocity_y * time + 0.5 * gravity * time^2, which has zero to two solutions for a given delta(y).
			-- We can assume that zero solutions isn't an issue, so:
			local del = py - tel + splitat
			local tt1 = (math_sqrt(2*g*del + py*py) - py) / g -- I think
			local tt2 = (py - math_sqrt(2*g*del + py*py)) / g
			active.fuse = math.round(max(tt1, tt2))
			return active.fuse == 0
		end

		return splitat > pel - tel           and  -- Terrain is level with the impact site.
		       splitat > py - pel             or  -- Projectile is below the split height.
		       splitat > (py + ny) / 2 - nel      -- Or will be before the next update.
	end

	applyingFunctions.split = function (proID)
		local px, py, pz = SpGetProjectilePosition(proID)
		local vx, vy, vz = SpGetProjectileVelocity(proID)
		local vw = math_sqrt(vx*vx + vy*vy + vz*vz)
		local ownerID = SpGetProjectileOwnerID(proID)
		local infos = projectiles[proID]
		for i = 1, tonumber(infos.number) do
			local projectileParams = {
				pos = {px, py, pz},
				speed = {vx - vw*(random(-100,100)/880), vy - vw*(random(-100,100)/440), vz - vw*(random(-100,100)/880)},
				owner = ownerID,
				ttl = 3000,
				gravity = -g/900,
				model = infos.model,
				cegTag = infos.cegtag,
			}
			SpSpawnProjectile(weaponDefNamesID[infos.def], projectileParams)
		end
		SpSpawnCEG(infos.splitexplosionceg, px, py, pz,0,0,0,0,0)
		SpDeleteProjectile(proID)
	end

	--------------------------------------------------------------------------------------------------------------
	-- Gadget ----------------------------------------------------------------------------------------------------

	function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
		local wDefID = SpGetProjectileDefID(proID)
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

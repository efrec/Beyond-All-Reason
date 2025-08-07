local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Prevent Range Hax",
		desc = "Prevent Range Hax",
		author = "TheFatController",
		date = "Jul 24, 2007",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Configuration

local unitHeightAllowance = 24 ---@type number Ignore some amount of height offset.
local unitTypicalMoveSpeed = 80 ---@type number Determines the weapon speed cutoff.
local areaOfEffectMinimum = 36 ---@type number Only aim splash damage at the ground.

-- Global values

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget

local CMD_ATTACK = CMD.ATTACK
local CMD_INSERT = CMD.INSERT

local PSTATE_GROUND = 1 + 2 + 4 -- ignoring underground pstates
local TARGET_UNIT = string.byte('u')

-- Initialize

local canLandUnitDefs = {}
local groundUnitDefs = {}
local testCommandRange = {}
local testFiringRange = {}

do
	local weaponTypes = {
		Cannon          = true,
		MissileLauncher = true,
		TorpedoLauncher = true,
	}

	-- Some reasonable filter for "slow" projectiles
	-- NB: The original code didn't care about slowness at all.
	-- So e.g. a Pitbull (speed 800) would have been a perfect fit.
	local weaponSpeedMax = unitTypicalMoveSpeed * 5

	local function addGroundUnit(unitDef)
		if unitDef.canFly or unitDef.canSubmerge then
			canLandUnitDefs[unitDef.id] = true
		elseif unitDef.canMove then
			groundUnitDefs[unitDef.id] = true
		end
	end

	local ignore = {}
	local function isBogusWeapon(weaponDef)
		if weaponDef.customParams.bogus then
			return true
		elseif not weaponTypes[weaponDef.type] then
			return true
		elseif weaponDef.waterWeapon then
			return true
		else
			for _, damage in ipairs(weaponDef.damages) do
				if damage > 10 then return false end
			end
		end
		return false
	end

	local function needCommandsCheck(unitDef)
		local count = 0

		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDefID = weapon.weaponDef
			local weaponDef = WeaponDefs[weaponDefID]

			if isBogusWeapon(weaponDef) then
				ignore[weaponDefID] = true
			else
				local hasAirTargeting = false
				for category in pairs(weapon.onlyTargets) do
					if category == "vtol" then
						hasAirTargeting = true
					elseif not hasAirTargeting then
						count = count + 1
					end
				end
			end
		end

		if count > 0 then
			testCommandRange[unitDef.id] = true
			return true
		else
			return false
		end
	end

	local function needWeaponsCheck(unitDef)
		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDefID = weapon.weaponDef
			local weaponDef = WeaponDefs[weaponDefID]

			if not ignore[weaponDefID] and
				(weaponDef.projectilespeed and weaponDef.projectilespeed <= weaponSpeedMax) and
				(weaponDef.damageAreaOfEffect > areaOfEffectMinimum) and
				(not weaponDef.tracks or not weaponDef.turnRate or weaponDef.turnRate < 400)
			then
				testFiringRange[weaponDefID] = true
			end
		end
	end

	for _, unitDef in ipairs(UnitDefs) do
		addGroundUnit(unitDef)
		if needCommandsCheck(unitDef) then
			needWeaponsCheck(unitDef)
		end
	end
end

-- Local functions

local function commandRangeCorrection(unitID, params, options)
	if params[3] then
		local y = spGetGroundHeight(params[1], params[3])
		if params[2] > y and spGetUnitWeaponTestTarget(unitID, params[1], y, params[3]) then
			params[2] = y
			spGiveOrderToUnit(unitID, CMD_ATTACK, params, options)
			return false
		end
	end
	return true
end

local function isOnGround(unitID)
	local physicalState = Spring.GetUnitPhysicalState(unitID)
	return math.bit_and(physicalState, PSTATE_GROUND) > 0
end

local function getTargetPosition(targetID)
	if targetID <= Game.maxUnits then
		local unitDefID = Spring.GetUnitDefID(targetID)
		if groundUnitDefs[unitDefID] or (canLandUnitDefs[unitDefID] and isOnGround(unitID)) then
			local _, _, _, _, _, _, ux, uy, uz = Spring.GetUnitPosition(targetID, true, true)
			return ux, uy, uz
		end
	end
end

local ARC_EPSILON = 1e-6 -- Any certainly small-enough angular epsilon

local function dot(vector1, vector2)
	return vector1[1] * vector2[1] + vector1[2] * vector2[2] + vector1[3] * vector2[3]
end

---Get the coordinates marking the intersection, if colliding, or the nearest point, if not,
---of a ray and a plane. The plane is set by a point (any) in the plane and the planar normal.
---@param pointRay table
---@param direction table
---@param pointPlane table
---@param normal table
---@return number x coordinates
---@return number y
---@return number z
---@return boolean collision `true`: intersection, `false`: nearest point
local function getRayPlaneApproach(pointRay, direction, pointPlane, normal)
	local rx = pointRay[1]
	local ry = pointRay[2]
	local rz = pointRay[3]

	local product = dot(direction, normal)

	if math.abs(product) > ARC_EPSILON then
		local d1 = pointPlane[1] - rx
		local d2 = pointPlane[2] - ry
		local d3 = pointPlane[3] - rz
		local t = (d1 * normal[1] + d2 * normal[2] + d3 * normal[3]) / product

		if t >= 0 then
			return
				rx + t * direction[1],
				ry + t * direction[2],
				rz + t * direction[3],
				true
		else
			return rx, ry, rz, false
		end
	end
end

local origin = { 0, 0, 0 }
local rayDir = { 0, 0, 0, 1 }
local planar = { 0, 0, 0 }
local normal = { 0, 1, 0, 1 }

local function weaponRangeCorrection(projectileID, unitID, weaponDefID)
	local targetType, target = Spring.GetProjectileTarget(projectileID)

	if targetType ~= TARGET_UNIT then
		return
	end

	local px, py, pz = Spring.GetProjectilePosition(projectileID)
	local vx, vy, vz, vw = Spring.GetProjectileVelocity(projectileID)

	if vw == nil or vw == 0 or vy < vw * -0.125 or vy > vw * 0.375 then
		return
	end

	local ux, uy, uz = getTargetPosition(target)

	if ux == nil then
		return
	end

	origin[1], origin[2], origin[3] = px, py, pz
	rayDir[1], rayDir[2], rayDir[3] = math.normalize(vx, vy, vz)
	planar[1], planar[2], planar[3] = ux, uy, uz

	local tx, ty, tz, collision = getRayPlaneApproach(origin, rayDir, planar, normal)

	if not collision then
		return
	end

	local range = WeaponDefs[weaponDefID].range -- todo: cache
	local distance = math.distance3d(px, py, pz, tx, ty, tz)
	local rangeFactor = math.clamp(1 - distance / range, 0, 1)
	local pitchFactor = math.sin((vy / vw) ^ 2)
	local extraHeight = unitHeightAllowance * rangeFactor * pitchFactor
	local elevation = spGetGroundHeight(ux, uz) + extraHeight

	if uy > elevation then
		local timeToXZ = math.distance2d(px, pz, tx, tz) / math.diag(vx, vz)
		local correction = (uy - elevation) / timeToXZ
		Spring.SetProjectileVelocity(projectileID, vx, vy - correction, vz)
	end
end

-- Engine call-ins

function gadget:Initialize()
	if not next(testCommandRange) then
		Spring.Echo('unit_prevent_range_hax has no range haxxors')
	end

	Spring.Echo(testCommandRange)
	Spring.Echo(testFiringRange)

	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
end

local params = { 0, 0, 0 } -- Reusable helper for CMD_INSERT.

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if fromSynced or not testCommandRange[unitDefID] then
		return true
	elseif cmdID == CMD_INSERT then
		if cmdParams[2] ~= CMD_ATTACK then
			return true
		else
			cmdOptions = cmdParams[3]
			local p = params
			p[1], p[2], p[3] = cmdParams[4], cmdParams[5], cmdParams[6]
			cmdParams = p
		end
	else
		cmdOptions = cmdOptions.coded
	end

	return commandRangeCorrection(unitID, cmdParams, cmdOptions)
end

function gadget:ProjectileCreated(projectileID, ownerID, weaponDefID)
	if weaponDefID and testFiringRange[weaponDefID] then
		weaponRangeCorrection(projectileID, ownerID, weaponDefID)
	end
end

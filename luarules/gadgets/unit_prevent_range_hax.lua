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
local testWeaponRange = {}

do
	local weaponTypes = {
		Cannon          = true,
		MissileLauncher = true,
		TorpedoLauncher = true,
	}

	local ignore = {}

	local function addGroundUnit(unitDef)
		if unitDef.canFly or unitDef.canSubmerge then
			canLandUnitDefs[unitDef.id] = true
		else
			groundUnitDefs[unitDef.id] = true
		end
	end

	local function isBogusWeapon(weaponDef)
		if weaponDef.customParams.bogus then
			return true
		elseif not weaponTypes[weaponDef.type] then
			return true
		else
			for _, damage in ipairs(weaponDef.damages) do
				if damage > 10 then
					return true
				end
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

			if not ignore[weaponDefID] and (
				not weaponDef.tracks or not weaponDef.turnRate or weaponDef.turnRate < 400
			) then
				testWeaponRange[weaponDefID] = true
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
	if targetID > Game.maxUnits then
		return Spring.GetFeaturePosition(targetID - Game.maxUnits)
	else
		local unitDefID = Spring.GetUnitDefID(targetID)
		if groundUnitDefs[unitDefID] or (canLandUnitDefs[unitDefID] and isOnGround(unitID)) then
			-- Get the aim point position:
			return select(7, Spring.GetUnitPosition(targetID, true, true))
		end
	end
end

local function weaponRangeCorrection(projectileID, unitID, weaponDefID)
	local targetType, target = Spring.GetProjectileTarget(projectileID)

	if targetType ~= TARGET_UNIT then
		return
	end

	local x, y, z = getTargetPosition(target)

	if x == nil then
		return
	end

	local vx, vy, vz, vw = Spring.GetProjectileVelocity(projectileID)

	if vw == nil or vw == 0 or vy < vw * -0.125 or vy > vw * 0.375 then
		return
	end

	local px, py, pz = Spring.GetProjectilePosition(projectileID)
	local range = WeaponDefs[weaponDefID].range
	local distance = math.distance3d(px, py, pz, x, y, z)
	local rangeFactor = distance / range
	local pitchFactor = math.sin((vy / vw) ^ 2)
	local extraHeight = unitHeightAllowance * (1 + rangeFactor) * pitchFactor
	local elevation = spGetGroundHeight(x, z) + extraHeight

	if y > elevation then
		local timeToXZ = math.distance2d(px, pz, x, z) / math.diag(vx, vz)
		local correction = (y - elevation) / timeToXZ
		Spring.SetProjectileVelocity(projectileID, vx, vy - correction, vz)
	end
end

-- Engine call-ins

function gadget:Initialize()
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
	if weaponDefID and testWeaponRange[weaponDefID] then
		weaponRangeCorrection(projectileID, ownerID, weaponDefID)
	end
end

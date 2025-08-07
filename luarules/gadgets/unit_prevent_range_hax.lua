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

-- Ignore some amount of height offset.
local unitHeightAllowance = 24

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetGroundHeight = Spring.GetGroundHeight
local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget

local CMD_ATTACK = CMD.ATTACK
local CMD_INSERT = CMD.INSERT

local PSTATE_GROUND = 1 + 2 + 4 -- ignoring underground pstates
local TARGET_UNIT = string.byte('u')

local canLandUnitDefs = {}
local groundUnitDefs = {}
local testCommandRange = {}
local testWeaponRange = {}

do
	local ignore = {}
	local weaponTypes = {
		Cannon          = true,
		MissileLauncher = true,
		TorpedoLauncher = true,
	}

	for unitDefID, unitDef in ipairs(UnitDefs) do
		-- Check that unit midpoints aren't allowing hacky over-ranging.
		if unitDef.canFly or unitDef.canSubmerge then
			canLandUnitDefs[unitDefID] = true
		else
			groundUnitDefs[unitDefID] = true
		end

		-- Check only certain weapons for over-ranging.
		local count = 0

		for _, weapon in ipairs(unitDef.weapons) do
			local weaponDefID = weapon.weaponDef
			local weaponDef = WeaponDefs[weaponDefID]

			local hasAirTargeting = false

			if not weaponTypes[weaponDef.type] or weaponDef.customParams.bogus then
				ignore[weaponDefID] = true -- todo: other cases?
			else
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
			testCommandRange[unitDefID] = true

			for _, weapon in ipairs(unitDef.weapons) do
				local weaponDefID = weapon.weaponDef
				local weaponDef = WeaponDefs[weaponDefID]

				if not ignore[weaponDefID] and (
					not weaponDef.tracks or not weaponDef.turnRate or weaponDef.turnRate < 800
				) then
					testWeaponRange[weaponDefID] = true
				end
			end
		end
	end
end

local temp = { 0, 0, 0 }

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
	local angleFactor = math.sin((vy / vw) ^ 2)
	local elevation = spGetGroundHeight(x, z) + unitHeightAllowance * (1 + rangeFactor) * angleFactor

	if y > elevation then
		-- todo: this is mostly made up
		local correction = math.abs((1 + vy / vw) * (y - elevation) / vw)
		Spring.SetProjectileVelocity(vx, vy - correction, vz)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if fromSynced or not testCommandRange[unitDefID] then
		return true
	elseif cmdID == CMD_INSERT then
		if cmdParams[2] ~= CMD_ATTACK then
			return true
		else
			cmdOptions = cmdParams[3]
			local p = temp
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

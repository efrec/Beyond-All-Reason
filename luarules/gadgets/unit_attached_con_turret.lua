local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Attached Construction Turret',
        desc      = 'Attaches a builder to another mobile unit, so builder can repair while moving',
        author    = 'Itanthias',
        version   = 'v1.1',
        date      = 'July 2023',
        license   = 'GNU GPL, v2 or later',
        layer     = 12,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local updateInterval = 0.33 -- in seconds

--------------------------------------------------------------------------------
-- Command introspection -------------------------------------------------------

local PRM_NUL = {} ---@type CommandParamsType Null params set

---Parameter counts => allowed
---@type table<string, CommandParamsType>
local countAllowed = {
	changeState = { [0] = true, [1] = true }, -- [0] option [1] mode
	buildOrder  = { [3] = true, [4] = true }, -- [3] xyz [4] xyz, facing
	buildTarget = { [1] = true, [5] = true }, -- [1] object [4] xyz, area radius [5] object, xyz, leash radius
	mapPosition = { [3] = true, [4] = true }, -- [3] xyz [4] xyz, area radius
	waitCommand = { [0] = true, [1] = true, [2] = true, [6] = true }, -- see WaitCommandsAI.cpp
}

-- Speedups and reverse lookups:

local PRM_BUILD = countAllowed.buildOrder
local PRM_WAIT = countAllowed.waitCommand
local PRMTYPE_COORDS = { [countAllowed.buildOrder] = true, [countAllowed.mapPosition] = true, }
local PRMTYPE_OBJECT = { [countAllowed.buildTarget] = true, }

---The attached turret has the statistics of its base unit
-- but can process only a subset of the base unit's orders:
---@type table<CMD, table<CommandParamsCount, true>>
local commandParamForward = setmetatable({
	-- Engine commands:
	[CMD.WAIT]         = countAllowed.waitCommand,
	[CMD.DEATHWAIT]    = countAllowed.waitCommand,
	[CMD.GATHERWAIT]   = countAllowed.waitCommand,
	[CMD.TIMEWAIT]     = countAllowed.waitCommand,

	[CMD.CAPTURE]      = countAllowed.buildTarget,
	[CMD.RECLAIM]      = countAllowed.buildTarget,
	[CMD.REPAIR]       = countAllowed.buildTarget,
	[CMD.RESURRECT]    = countAllowed.buildTarget,

	[CMD.RESTORE]      = countAllowed.mapPosition,

	-- Game commands:
	[GameCMD.PRIORITY] = countAllowed.noneOrMode,
}, {
	__index = function(self, key)
		return key < 0 and PRM_BUILD or PRM_NUL
	end
})

--------------------------------------------------------------------------------
-- Global values ---------------------------------------------------------------

local remove = table.remove

local CallAsTeam = CallAsTeam

local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureRadius = Spring.GetFeatureRadius
local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
local spGetHeadingFromVector = Spring.GetHeadingFromVector
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitEffectiveBuildRange = Spring.GetUnitEffectiveBuildRange
local spGetUnitFeatureSeparation = Spring.GetUnitFeatureSeparation
local spGetUnitHeading = Spring.GetUnitHeading
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitTeam = Spring.GetUnitTeam

local spAreTeamsAllied = Spring.AreTeamsAllied
local spCallCOBScript = Spring.CallCOBScript
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local resolveCommand = Spring.Utilities.Commands.ResolveCommand
local tryGiveOrder = Spring.Utilities.Commands.TryGiveOrder

local CMD_GUARD = CMD.GUARD
local CMD_CAPTURE = CMD.CAPTURE
local CMD_RECLAIM = CMD.RECLAIM
local CMD_REMOVE = CMD.REMOVE
local CMD_REPAIR = CMD.REPAIR
local CMD_RESURRECT = CMD.RESURRECT
local OPT_ALT = CMD.OPT_ALT
local OPT_INTERNAL = CMD.OPT_INTERNAL
local MOVESTATE_ASSIST = CMD.MOVESTATE_MANEUVER

local FEATURE_BASE_INDEX = Game.maxUnits
local FILTER_ALLY_UNITS = -3
local FILTER_ENEMY_UNITS = -4

local getUnitIsSuspended = GG.GetUnitIsSuspended

--------------------------------------------------------------------------------
-- Initialize ------------------------------------------------------------------

updateInterval = math.floor(updateInterval * Game.gameSpeed + 0.5)
updateInterval = math.clamp(updateInterval, 1, Game.gameSpeed)
local updateOffset = math.round(updateInterval * 0.5)

local baseToTurretDefID = {}
local baseDefAttachIndex = {}
local turretDefAbilities = {}
local repairableDefID = {}
local reclaimableDefID = {}
local capturableDefID = {}
local unitDefRadiusMax = 0

local combatReclaimDefID = {}
local resurrectableDefID = {}

local baseToTurretID = {}
local turretAbilities = {}
local turretBuildRadius = {}

local teamsAreAllied = {}

local function parseBaseUnitDef(unitDef)
	local turretDef = UnitDefNames[unitDef.customParams.attached_con_turret]
	local abilities
	local pieceIndex = tonumber(unitDef.customParams.attached_piece_index)
	local success = true

	if turretDef then
		abilities = {
			[CMD.CAPTURE]   = turretDef.canCapture and turretDef.captureSpeed > 0 or nil,
			[CMD.RECLAIM]   = turretDef.canReclaim and turretDef.reclaimSpeed > 0 or nil,
			[CMD.REPAIR]    = turretDef.canRepair and turretDef.repairSpeed > 0 or nil,
			[CMD.RESTORE]   = turretDef.canRestore and turretDef.terraformSpeed > 0 or nil,
			[CMD.RESURRECT] = turretDef.canResurrect and turretDef.resurrectSpeed > 0 or nil,
			-- We have two other types that complicate the issue.
			-- These depend on move state (assist) and build option (build).
			assist          = turretDef.canAssist and turretDef.buildSpeed > 0 or nil,
			build           = turretDef.buildOptions and next(turretDef.buildOptions) and true or nil,
		}

		if next(abilities) == nil then
			local message = "Con turret def has no builder abilities: "
			Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
			success = false
		end
	else
		local message = "Incorrect or missing attached con def: "
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
		success = false
	end

	if not pieceIndex then
		local message = "Incorrect or missing attach piece index: "
		Spring.Log(gadget:GetInfo().name, LOG.ERROR, message .. unitDef.name)
		success = false
	end

	if success then
		return turretDef.id, abilities, pieceIndex
	end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.attached_con_turret and not (unitDef.extractsMetal > 0) then
		local turretDefID, abilities, pieceNumber = parseBaseUnitDef(unitDef)
		if turretDefID then
			baseToTurretDefID[unitDefID] = turretDefID
			turretDefAbilities[turretDefID] = abilities
			baseDefAttachIndex[unitDefID] = pieceNumber
			GG.addPairedUnitDef(unitDefID, turretDefID)
		end
	end
end

for unitDefID, unitDef in ipairs(UnitDefs) do
	unitDefRadiusMax = math.max(unitDef.radius, unitDefRadiusMax)
	if unitDef.capturable then
		capturableDefID[unitDefID] = true
	end
	if unitDef.reclaimable then
		reclaimableDefID[unitDefID] = true
	end
	if unitDef.repairable then
		repairableDefID[unitDefID] = true
	end
end

for featureDefID, featureDef in ipairs(FeatureDefs) do
	if featureDef.reclaimable and (featureDef.resurrectable == 0 or not featureDef.customParams.fromunit) then
		combatReclaimDefID[featureDefID] = true
	end
	if featureDef.resurrectable and (featureDef.resurrectable ~= 0 and not featureDef.customParams.fromunit) then
		resurrectableDefID[featureDefID] = true
	end
end

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function attachToUnit(baseID, baseDefID, baseTeam)
	local turretDefID = baseToTurretDefID[baseDefID]
	local ux, uy, uz = spGetUnitPosition(baseID)
	local facing = Spring.GetUnitBuildFacing(baseID)
	---@diagnostic disable-next-line: param-type-mismatch -- OK to ignore nil
	local turretID = Spring.CreateUnit(turretDefID, ux, uy, uz, facing, baseTeam)
	if turretID and GG.addPairedUnit(baseID, turretID, baseDefAttachIndex[baseDefID]) then
		baseToTurretID[baseID] = turretID
		turretBuildRadius[turretID] = UnitDefs[turretDefID].buildDistance
		turretAbilities[turretID] = turretDefAbilities[turretDefID]
		return true
	else
		Spring.DestroyUnit(baseID)
	end
end

local function isAlliedUnit(teamID, unitID)
	local teamsAreAllied = teamsAreAllied
	local alliances = teamsAreAllied[teamID]
	if alliances == nil then
		alliances = {}
		teamsAreAllied[teamID] = alliances
	else
		local unitTeam = spGetUnitTeam(unitID)
		local isAllied = alliances[unitTeam]

		if isAllied == nil then
			isAllied = spAreTeamsAllied(teamID, unitTeam)
				and spAreTeamsAllied(unitTeam, teamID)
			alliances[unitTeam] = isAllied
			local mirror = teamsAreAllied[unitTeam]
			if mirror == nil then
				mirror = {}
				teamsAreAllied[unitTeam] = mirror
			end
			mirror[teamID] = isAllied
		end

		return isAllied
	end
end

-- Command helpers -------------------------------------------------------------

local commandParams = table.new(6, 0) -- helper table

---@param unitID integer
---@param index integer?
---@return CMD? command
---@return number[] params
---@return table<CommandParamsCount, true> PRMTYPE
---@return CommandOptionBit? options
local function getCommandInfo(unitID, index)
	local command, options, _, p1, p2, p3, p4, p5, p6 = spGetUnitCurrentCommand(unitID, index)
	local paramsType = command ~= nil and commandParamForward[command] or PRM_NUL
	local p = commandParams
	p[1], p[2], p[3], p[4], p[5], p[6] = p1, p2, p3, p4, p5, p6
	return command, p, paramsType, options
end

local getCallOptions
do
	local callAsTeamOptions = { read = 0 }
	---@param teamID number|integer?
	---@return CallAsTeamOptions
	getCallOptions = function(teamID)
		callAsTeamOptions.read = teamID
		return callAsTeamOptions
	end
end

local function isUnitInBuildRadius(turretID, unitID)
	local separation = spGetUnitSeparation(turretID, unitID, true, true)
	if separation ~= nil then
		local radius = spGetUnitEffectiveBuildRange(turretID, spGetUnitDefID(unitID))
		return radius >= separation
	else
		return false
	end
end

local function isFeatureInBuildRadius(turretID, featureID, radius)
	local separation = spGetUnitFeatureSeparation(turretID, featureID, true)
	if separation ~= nil then
		return radius >= separation - spGetFeatureRadius(featureID)
	else
		return false
	end
end

-- Process commands ------------------------------------------------------------

---OK: CMD/integer are mismatched, and our docs do not support conditional nil.
---@diagnostic disable: param-type-mismatch, return-type-mismatch
---@diagnostic disable: missing-return, redundant-return-value

---@param paramsType table<CommandParamsCount, true>
---@param params number[]
---@param turretID integer
---@param radius number
---@return number dx
---@return number dz
local function tryOrderDirection(paramsType, params, turretID, radius)
	if paramsType[#params] then
		if PRMTYPE_OBJECT[paramsType] then
			local objectID = params[1]
			if objectID < FEATURE_BASE_INDEX then
				if isUnitInBuildRadius(turretID, objectID) then
					local tx, _, tz = spGetUnitPosition(turretID)
					local ux, _, uz = spGetUnitPosition(objectID)
					return ux - tx, uz - tz
				end
			else
				objectID = objectID - FEATURE_BASE_INDEX
				if isFeatureInBuildRadius(turretID, objectID, radius) then
					local tx, _, tz = spGetUnitPosition(turretID)
					local fx, _, fz = spGetFeaturePosition(objectID)
					return fx - tx, fz - tz
				end
			end
		elseif PRMTYPE_COORDS[paramsType] then
			local ux, uy, uz = spGetUnitPosition(turretID)
			local rx = params[1] - ux
			local ry = params[2] - uy
			local rz = params[3] - uz
			if radius * radius >= rx * rx + ry * ry + rz * rz then
				return rx, rz
			end
		end
	end
end

---Set the turret's orientation and push commands from turret to base as needed.
---@param turretID integer
---@param dx number
---@param dz number
---@param toBaseID integer?
local function applyTurretOrder(turretID, dx, dz, toBaseID)
	local headingCurrent = spGetUnitHeading(turretID)
	local headingNew = spGetHeadingFromVector(dx, dz)
	spCallCOBScript(turretID, "UpdateHeading", 0, headingNew - headingCurrent)
	-- Base unit should turn toward targets when it is otherwise idle:
	if toBaseID and spGetUnitCurrentCommand(toBaseID) == nil then
		local ux, uy, uz = Spring.GetUnitPosition(toBaseID)
		local moveRadius = turretBuildRadius[turretID] / Game.squareSize
		ux = ux + math.sgn(dx) * math.sqrt(math.abs(dx)) / moveRadius
		uz = uz + math.sgn(dz) * math.sqrt(math.abs(dz)) / moveRadius
		Spring.SetUnitMoveGoal(toBaseID, ux, uy, uz)
	end
end

---Search for orders for the turret to perform not as a "con" but as a "nano".
---This was developed for a combat engineer so is patterned for that use case.
---@param baseID integer
---@param turretID integer
---@param abilities table
---@param buildRadius number
---@return number? targetX non-nil when an order is found
---@return number targetY
---@return number targetZ
local function tryExecuteFight(baseID, turretID, teamID, abilities, buildRadius)
	local badTargets = { [baseID] = true, [turretID] = true }
	local searchRadius = buildRadius + unitDefRadiusMax
	local ux, _, uz = spGetUnitPosition(turretID)

	local _, moveState = Spring.GetUnitStates(baseID, false)
	local canSpendFunds = moveState >= MOVESTATE_ASSIST
	local canFundAllies = moveState >= MOVESTATE_ASSIST + 1

	local allyUnits = spGetUnitsInCylinder(ux, uz, searchRadius, FILTER_ALLY_UNITS)
	local enemyUnits = spGetUnitsInCylinder(ux, uz, searchRadius, FILTER_ENEMY_UNITS)

	-- Test for alliances under ceasefire.
	for i = #enemyUnits, 1, -1 do
		if isAlliedUnit(teamID, enemyUnits[i]) then
			allyUnits[#allyUnits+1] = remove(enemyUnits, i)
		end
	end

	local bruised = {}
	local unbuilt = {}
	if abilities[CMD_REPAIR] then
		for _, unitID in ipairs(allyUnits) do
			if not badTargets[unitID] and isUnitInBuildRadius(turretID, unitID) then
				if not spGetUnitIsBeingBuilt(unitID) then
					if repairableDefID[spGetUnitDefID(unitID)] then
						local health, healthMax = spGetUnitHealth(unitID)
						if health ~= nil and health < healthMax then
							if health <= healthMax * 0.95 - 20 then
								if tryGiveOrder(turretID, CMD_REPAIR, unitID) then
									return spGetUnitPosition(unitID)
								end
							else
								bruised[#bruised + 1] = unitID
							end
						end
					end
				elseif canSpendFunds then
					unbuilt[#unbuilt + 1] = unitID
				end
			end
		end
	end

	local features = spGetFeaturesInCylinder(ux, uz, searchRadius)

	local capturable = {}
	local resurrectable = {}
	if abilities[CMD_RECLAIM] then
		for _, unitID in ipairs(enemyUnits) do
			if isUnitInBuildRadius(turretID, unitID) then
				local unitDefID = spGetUnitDefID(unitID)
				if reclaimableDefID[unitDefID] and tryGiveOrder(turretID, CMD_RECLAIM, unitID) then
					return spGetUnitPosition(unitID)
				end

				if canSpendFunds and capturableDefID[unitDefID] then
					capturable[unitID] = true
				end
			end
		end

		for _, featureID in ipairs(features) do
			if isFeatureInBuildRadius(turretID, featureID, buildRadius) then
				local featureDefID = spGetFeatureDefID(featureID)
				if combatReclaimDefID[featureDefID] and tryGiveOrder(turretID, CMD_RECLAIM, unitID) then
					return spGetFeaturePosition(featureID)
				end

				if canSpendFunds and resurrectableDefID[featureDefID] then
					resurrectable[featureID] = true
				end
			end
		end
	end

	if abilities[CMD_REPAIR] then
		for _, unitID in ipairs(bruised) do
			if tryGiveOrder(turretID, CMD_REPAIR, unitID) then
				return spGetUnitPosition(unitID)
			end
		end
	end

	if canSpendFunds then
		if abilities[CMD_CAPTURE] then
			if not abilities[CMD_REPAIR] then
				-- The `capturable` table was not populated earlier. Do so now:
				for _, unitID in ipairs(enemyUnits) do
					if capturableDefID[spGetUnitDefID(unitID)] and isUnitInBuildRadius(turretID, unitID) then
						capturable[#capturable + 1] = true
					end
				end
			end

			for _, unitID in ipairs(capturable) do
				if tryGiveOrder(turretID, CMD_CAPTURE, unitID) then
					return spGetUnitPosition(unitID)
				end
			end
		end

		if abilities[CMD_RESURRECT] then
			if not abilities[CMD_RECLAIM] then
				-- The `resurrectable` table was not populated earlier. Do so now:
				for _, featureID in ipairs(features) do
					if resurrectableDefID[spGetFeatureDefID(featureID)] and isFeatureInBuildRadius(turretID, featureID, buildRadius) then
						resurrectable[#resurrectable + 1] = true
					end
				end
			end

			for _, featureID in ipairs(resurrectable) do
				if tryGiveOrder(turretID, CMD_RESURRECT, featureID) then
					local x, _, z = spGetFeaturePosition(featureID)
				end
			end
		end
	end

	if canSpendFunds and abilities.assist then
		if not abilities[CMD_REPAIR] then
			-- The `unbuilt` table was not populated earlier. Do so now:
			for _, unitID in ipairs(allyUnits) do
				if not badTargets[unitID] and spGetUnitIsBeingBuilt(unitID) then
					if isUnitInBuildRadius(turretID, unitID) then
						unbuilt[#unbuilt + 1] = unitID
					end
				end
			end
		end

		for _, unitID in ipairs(unbuilt) do
			if canFundAllies or teamID == spGetUnitTeam(unitID) then
				if tryGiveOrder(turretID, CMD_REPAIR, unitID) then
					return spGetUnitPosition(unitID)
				end
			end
		end
	end
end

---Synchronize the turret unit to the base unit's current activity,
---then attempt to continue an ongoing command already in progress,
---then attempt to find an action to perform independently,
---then forward any command to the base, if it is not busy.
---@param baseID integer
---@param turretID integer
local function updateTurretOrders(baseID, turretID, teamID)
	local abilities = turretAbilities[turretID]
	local buildRadius = turretBuildRadius[turretID]

	local command, params, paramsType, options = getCommandInfo(baseID)
	if paramsType == PRM_WAIT then
		return
	elseif command ~= nil then
		if command ~= CMD_GUARD and
			math.bit_and(options, OPT_INTERNAL) == OPT_INTERNAL and
			spGetUnitCurrentCommand(baseID, 2) == CMD_GUARD
		then
			return
		elseif paramsType ~= nil and paramsType[#params] ~= nil then
			spGiveOrderToUnit(turretID, command, params)
		end
	end

	command, params, paramsType, options = getCommandInfo(turretID)
	if paramsType == PRM_WAIT then
		return
	elseif command ~= nil then
		local dx, dz = tryOrderDirection(paramsType, params, turretID, buildRadius)
		if dx and dz then
			applyTurretOrder(turretID, dx, dz)
			return
		end
	end
	local turretCommand = command

	local x, y, z = tryExecuteFight(baseID, turretID, teamID, abilities, buildRadius)
	if x and z then
		local ux, uy, uz = spGetUnitPosition(turretID)
		applyTurretOrder(turretID, x - ux, z - uz, baseID) -- notify base
	elseif turretCommand ~= nil then
		spGiveOrderToUnit(turretID, CMD_REMOVE, turretCommand, OPT_ALT)
	end
end

---@diagnostic enable: param-type-mismatch, return-type-mismatch
---@diagnostic enable: missing-return, redundant-return-value

--------------------------------------------------------------------------------
-- Engine call-ins -------------------------------------------------------------

function gadget:Initialize()
	if not next(baseToTurretDefID) then
		gadgetHandler:RemoveGadget(self)
		return
	end

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		local transportID = Spring.GetUnitTransporter(unitID)
		if transportID then
			local transportDefID = Spring.GetUnitDefID(transportID)
			if unitDefID == baseToTurretDefID[transportDefID] then
				if GG.addPairedUnit(transportID, unitID, baseDefAttachIndex[transportDefID]) then
					baseToTurretID[transportID] = unitID
					turretBuildRadius[unitID] = UnitDefs[unitDefID].buildDistance
					turretAbilities[unitID] = turretDefAbilities[unitDefID]
				end
			end
		end
	end
end

function gadget:GameFrame(gameFrame)
	if gameFrame % updateInterval == updateOffset then
		for baseID, turretID in pairs(baseToTurretID) do
			if not getUnitIsSuspended(turretID) then
				local unitTeam = spGetUnitTeam(baseID)
				local teamRead = getCallOptions(unitTeam)
				CallAsTeam(teamRead, updateTurretOrders, baseID, turretID, unitTeam)
			end
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if baseToTurretDefID[unitDefID] then
		attachToUnit(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	baseToTurretID[unitID] = nil
	turretAbilities[unitID] = nil
	turretBuildRadius[unitID] = nil
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if cmdTag == 0 and baseToTurretID[unitID] ~= nil then
		-- Forward to the turret. Issues with paired units targeting one another
		-- (and so on) are handled separately in unit_attached_virtual_pair.lua.
		local turretID = baseToTurretID[unitID]

		cmdID, cmdParams = resolveCommand(cmdID, cmdParams)

		if cmdID >= 0 then
			if commandParamForward[cmdID][#cmdParams] then
				spGiveOrderToUnit(turretID, cmdID, cmdParams, cmdOpts)
			end
		else
			-- To avoid checking build options, they are not passed to the turret.
			-- When the build frame is already placed, though, issue a CMD_REPAIR.
			local buildFrames = CallAsTeam(getCallOptions(unitTeam),
				spGetUnitsInCylinder, cmdParams[1], cmdParams[3], Game.squareSize, FILTER_ALLY_UNITS)

			for _, assistID in ipairs(buildFrames) do
				if spGetUnitIsBeingBuilt(assistID) and -cmdID == spGetUnitDefID(assistID) then
					spGiveOrderToUnit(turretID, CMD_REPAIR, assistID)
				end
			end
		end
	end
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	return baseToTurretID[builderID] == nil
end

function gadget:AllowUnitBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	return baseToTurretID[builderID] == nil
end

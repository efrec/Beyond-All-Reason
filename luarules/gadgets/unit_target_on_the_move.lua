local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Target on the move",
		desc = "Adds a command to set a priority attack target",
		author = "Google Frog, adapted by BrainDamage, added priority to Dgun by doo",
		date = "06/05/2013",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE

local isSetTargetCommand = {
	[CMD_UNIT_SET_TARGET_NO_GROUND] = true,
	[CMD_UNIT_SET_TARGET]           = true,
	[CMD_UNIT_CANCEL_TARGET]        = true,
	[CMD_UNIT_SET_TARGET_RECTANGLE] = true,
}

local deleteMaxDistance = 30
local targetLimitAdd = 40 -- bugged, target lists aren't growing past 40, idk why
local targetLimitMax = 120

local spGetUnitRulesParam = Spring.GetUnitRulesParam

function GG.GetUnitTarget(unitID)
	local targetID = spGetUnitRulesParam(unitID, "targetID")
	targetID = tonumber(targetID) and targetID >= 0 and targetID or nil
	if not targetID then
		targetID = {
			spGetUnitRulesParam(unitID, "targetCoordX"),
			spGetUnitRulesParam(unitID, "targetCoordY"),
			spGetUnitRulesParam(unitID, "targetCoordZ"),
		}
		targetID = targetID[1] ~= -1 and targetID[3] ~= -1 and targetID or nil
	end
	return targetID
end


if gadgetHandler:IsSyncedCode() then

	-- Unseen targets will be removed after max USEEN_UPDATE_FREQUENCY frames.
	-- Should be small enough to not be evident, and big enough to save perf.
	local USEEN_UPDATE_FREQUENCY = 15

	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spSetUnitTarget = Spring.SetUnitTarget
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitLosState = Spring.GetUnitLosState
	local spGetUnitTeam = Spring.GetUnitTeam
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
	local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
	local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
	local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetAllUnits = Spring.GetAllUnits
	local spGetPlayerInfo = Spring.GetPlayerInfo

	local tremove = table.remove

	local diag = math.diag
	local pairsNext = next

	local CMD_ATTACK = CMD.ATTACK
	local CMD_DGUN = CMD.DGUN
	local CMD_FIGHT = CMD.FIGHT
	local CMD_STOP = CMD.STOP

	-- Explicit Attack and Manual Fire commands overrule Set Target's priority.
	local isAttackCommand = {
		[CMD_ATTACK]                 = true,
		[CMD.AREA_ATTACK]            = true,
		[CMD_FIGHT]                  = true,
		[GameCMD.AREA_ATTACK_GROUND] = true,
	}

	local validUnits = {}
	local unitWeapons = {}
	local unitAlwaysSeen = {}
	for unitDefID = 1, #UnitDefs do
		local unitDef = UnitDefs[unitDefID]
		local weapons = unitDef.weapons
		local weaponCount = #weapons - (unitDef.shieldWeaponDef and 1 or 0)
		if weaponCount > 0 and unitDef.canAttack and unitDef.maxWeaponRange and unitDef.maxWeaponRange > 0 then
			validUnits[unitDefID] = true
			unitWeapons[unitDefID] = {}
			for i=1, #weapons do
				unitWeapons[unitDefID][i] = true
			end
		end
		unitAlwaysSeen[unitDefID] = unitDef.isBuilding or unitDef.speed == 0
	end

	-- fastpass for units that don't have an attack command for other reasons
	if UnitDefNames.legpede then
		validUnits[UnitDefNames.legpede.id] = true
	end

	local unitTargets = {}
	local pausedTargets = {}
	local checkForManualFire = {}

	--------------------------------------------------------------------------------
	-- Commands

	local tooltipText = 'Set a priority attack target,\nto be used when within range\n(not removed by move commands)'

	local unitSetTargetNoGroundCmdDesc = {
		id = CMD_UNIT_SET_TARGET_NO_GROUND,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = 'Set Unit Target',
		action = 'settargetnoground',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = true,
		queueing = false,
	}

	local unitSetTargetCircleCmdDesc = {
		id = CMD_UNIT_SET_TARGET,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = 'Set Target', --extra spaces center the 'Set' text
		action = 'settarget',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = false,
		queueing = false,
	}

	local unitCancelTargetCmdDesc = {
		id = CMD_UNIT_CANCEL_TARGET,
		type = CMDTYPE.ICON,
		name = 'Cancel Target',
		action = 'canceltarget',
		tooltip = 'Removes top priority target, if set',
		hidden = false,
		queueing = false,
	}

	--------------------------------------------------------------------------------
	-- Target Handling

	local function AreUnitsAllied(unitID, targetID)
		--if a unit dies the unitID will still be valid for current frame unit UnitDestroyed is called
		--this means that code can reach here and spGetUnitTeam returns nil, therefore we'll nil check before
		--executing spAreTeamsAllied, returning true to being allied disables rest of the code without having
		--to pass weird nil threestate to be further checked
		local ownTeam, enemyTeam = spGetUnitTeam(unitID), spGetUnitTeam(targetID)
		return ownTeam and enemyTeam and spAreTeamsAllied(ownTeam, enemyTeam)
	end

	local function TargetCanBeReachedReal(unitID, weaponList, target)
		for weaponNum in pairsNext, weaponList do
			if type(target) == "number" then
				if spGetUnitWeaponTryTarget(unitID, weaponNum, target) then
					return true
				end
			elseif spGetUnitWeaponTestTarget(unitID, weaponNum, target[1], target[2], target[3])
				and spGetUnitWeaponTestRange(unitID, weaponNum, target[1], target[2], target[3])
				and spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, nil, nil, nil, target[1], target[2], target[3]) then
				return true
			end
		end
	end

	local function TargetCanBeReached(unitID, teamID, weaponList, target)
		return CallAsTeam(teamID, TargetCanBeReachedReal, unitID, weaponList, target)
	end

	local function checkTarget(unitID, target)
		local isUnitTarget = type(target) == "number"
		return (isUnitTarget and spValidUnitID(target) and not AreUnitsAllied(unitID, target)) or (not isUnitTarget and target)
	end

	local function allowTargetSearch(unitID, unitData)
		local _, isUserTarget = Spring.GetUnitWeaponTarget(unitID, 1) -- Assumes the primary is useful.
		if not isUserTarget then
			return true
		end

		local inCommand = spGetUnitCurrentCommand(unitID, 1)
		if inCommand and isAttackCommand[inCommand] then
			-- ! This check is insufficient because CMD_FIGHT does not set OPT_INTERNAL:
			return inCommand == CMD_ATTACK and spGetUnitCurrentCommand(unitID, 2) == CMD_FIGHT
		end

		return true
	end

	local function resetTarget(unitID, unitData)
		unitData.currentIndex = 0
		unitData.inRange = false
		spSetUnitRulesParam(unitID, "targetID",     -1)
		spSetUnitRulesParam(unitID, "targetCoordX", -1)
		spSetUnitRulesParam(unitID, "targetCoordY", -1)
		spSetUnitRulesParam(unitID, "targetCoordZ", -1)
	end

	local function setTarget(unitID, unitData, targetIndex, targetData)
		if not TargetCanBeReached(unitID, unitData.teamID, unitData.weapons, targetData.target) then
			return false
		end

		-- FIXME: Dropping autotargets does not work correctly, so this sometimes fails:
		for weaponNum in pairs(unitData.weapons) do
			spSetUnitTarget(unitID, nil, false, false, weaponNum)
		end
		spSetUnitTarget(unitID, nil)

		local target = targetData.target
		local isUserTarget = targetData.userTarget

		local targetID, targetCoordX, targetCoordY, targetCoordZ
		if type(target) == "number" then
			targetID, targetCoordX, targetCoordY, targetCoordZ = target, -1, -1, -1
			if not spSetUnitTarget(unitID, targetID, false, isUserTarget) then
				return false
			end
		else
			targetID, targetCoordX, targetCoordY, targetCoordZ = -1, target[1], target[2], target[3]
			if not spSetUnitTarget(unitID, targetCoordX, targetCoordY, targetCoordZ, false, isUserTarget) then
				return false
			end
		end

		unitData.currentIndex = targetIndex
		unitData.inRange = true
		spSetUnitRulesParam(unitID, "targetID",     targetID)
		spSetUnitRulesParam(unitID, "targetCoordX", targetCoordX)
		spSetUnitRulesParam(unitID, "targetCoordY", targetCoordY)
		spSetUnitRulesParam(unitID, "targetCoordZ", targetCoordZ)
		return true
	end

	local function setNextTarget(unitID, unitData)
		for index, targetData in pairs(unitData.targets) do
			if setTarget(unitID, unitData, index, targetData) then
				return
			end
		end
		resetTarget(unitID, unitData)
	end

	local function tryNextTarget(unitID, unitData, allowSearch)
		if allowSearch == nil then
			allowSearch = allowTargetSearch(unitID, unitData)
		end
		if allowSearch then
			setNextTarget(unitID, unitData)
			SendToUnsynced("targetIndex", unitID, unitData.currentIndex)
		end
	end

	local function removeUnseenTarget(targetData, attackerAllyTeam)
		if not targetData.alwaysSeen then
			local target = targetData.target
			if spValidUnitID(target) then
				local los = spGetUnitLosState(target, attackerAllyTeam, true)
				if not los or (los % 4 == 0) then
					return true
				end
			end
		end
		return false
	end

	local function distance(posA, posB)
		diag(posA[1] - posB[1], posA[2] - posB[2], posA[3] - posB[3])
	end

	--------------------------------------------------------------------------------
	-- Unit adding/removal

	local function sendTargetsToUnsynced(unitID)
		for index, targetData in ipairs(unitTargets[unitID].targets) do
			if not targetData.sent then
				local target = targetData.target
				if type(target) == "number" then
					SendToUnsynced("targetList", unitID, index, targetData.alwaysSeen, targetData.ignoreStop, targetData.userTarget, target)
				else
					SendToUnsynced("targetList", unitID, index, targetData.alwaysSeen, targetData.ignoreStop, targetData.userTarget, target[1], target[2], target[3])
				end
				targetData.sent = true
			end
		end
	end

	local function sendTargetsToUnsyncedBatched(unitID)
		local targetCount = #unitTargets[unitID].targets
		if targetCount == 1 then
			sendTargetsToUnsynced(unitID)
		elseif targetCount > 1 then
			local data = {}
			local count = 0
			local stride = 8
			for index, targetData in ipairs(unitTargets[unitID].targets) do
				if not targetData.sent then
					local target = targetData.target
					data[count + 1] = unitID
					data[count + 2] = index
					data[count + 3] = targetData.alwaysSeen
					data[count + 4] = targetData.ignoreStop
					data[count + 5] = targetData.userTarget
					if type(target) == "number" then
						data[count + 6] = target
						data[count + 7] = -1
						data[count + 8] = -1
					else
						data[count + 6] = target[1]
						data[count + 7] = target[2]
						data[count + 8] = target[3]
					end
					targetData.sent = true
				end
				count = count + stride
				if count > 4000 then break end
			end
			SendToUnsynced("targetListBatched", count, stride, data)
		end
	end

	local function addUnitTargets(unitID, unitDefID, targets, append, allowSearch)
		local data = unitTargets[unitID] or pausedTargets[unitID]

		local targetList = append and data and data.targets or {}
		local inTargetList = {}
		for targetIndex, targetData in pairs(targetList) do
			inTargetList[targetData.target] = targetIndex
		end

		local count = #targetList
		for _, targetData in ipairs(targetList) do
			if count == targetLimitMax then
				break
			end
			if inTargetList[targetData.target] then
				local target = targetList[inTargetList[targetData.target]]
				target.ignoreStop = target.ignoreStop or targetData.ignoreStop
				target.userTarget = target.userTarget or targetData.userTarget
				target.sent = false
			elseif checkTarget(unitID, targetData.target) then
				count = count + 1
				targetList[count] = targetData
				targetData.sent = false
			end
		end
		if count == 0 then
			return
		end

		if not data then
			data = {
				targets      = targetList,
				teamID       = spGetUnitTeam(unitID),
				allyTeam     = spGetUnitAllyTeam(unitID),
				weapons      = unitWeapons[unitDefID],
				currentIndex = 1,
				inRange      = false,
			}
		elseif not append then
			data.targets = targetList
			data.currentIndex = 1
		end

		unitTargets[unitID] = data
		pausedTargets[unitID] = nil
		checkForManualFire[unitID] = true
		tryNextTarget(unitID, data, allowSearch)
		sendTargetsToUnsynced(unitID)
	end

	local function removeUnit(unitID, keepTrack)
		if unitTargets[unitID] then
			spSetUnitTarget(unitID, nil)
			spSetUnitRulesParam(unitID, "targetID", -1)
			spSetUnitRulesParam(unitID, "targetCoordX", -1)
			spSetUnitRulesParam(unitID, "targetCoordY", -1)
			spSetUnitRulesParam(unitID, "targetCoordZ", -1)
			unitTargets[unitID] = nil
		elseif pausedTargets[unitID] then
			pausedTargets[unitID] = nil
		end
		checkForManualFire[unitID] = nil
		if not keepTrack then
			SendToUnsynced("targetList", unitID, 0)
		end
	end

	local function refreshSendList(unitID, unitData, minIndex)
		local targets = unitData.targets
		local count = #targets
		if minIndex then
			-- send as little data as possible to unsynced
			for i = 1, count do
				if i >= minIndex then
					targets[i].sent = false
				end
			end
		else
			for i = 1, count do
				targets[i].sent = false
			end
		end
		sendTargetsToUnsynced(unitID)
		SendToUnsynced("targetList", unitID, count + 1) -- ask to clear the last element when the table is smaller
	end

	local function removeTarget(unitID, index, allowSearch)
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		tremove(unitData.targets, index)
		if #unitData.targets == 0 then
			removeUnit(unitID)
		else
			tryNextTarget(unitID, unitData, allowSearch)
			refreshSendList(unitID, unitData, index)
		end
	end

	local function removeInvalidTargets(unitID, unitData, allowSearch)
		local targetList = unitData.targets
		local currentIndex = unitData.currentIndex
		local n = #targetList
		local m, minIndex = n, n
		for i = n, 1, -1 do
			if targetList[i].invalid then
				targetList[i] = targetList[m]
				targetList[m] = nil
				m = m - 1
				minIndex = i
			end
		end
		if m == 0 then
			removeUnit(unitID)
		elseif m ~= n then
			if m <= currentIndex then
				tryNextTarget(unitID, unitData, allowSearch)
			end
			refreshSendList(unitID, unitData, minIndex)
		end
	end

	local function removeStoppableTargets(unitID)
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		local targetList = unitData.targets
		local n = #targetList
		local m, minIndex = n, n
		for i = n, 1, -1 do
			if not targetList[i].ignoreStop then
				targetList[i] = targetList[m]
				targetList[m] = nil
				m = m - 1
				minIndex = i
			end
		end
		if m == 0 then
			removeUnit(unitID)
		elseif m < n then
			setNextTarget(unitID, unitData)
			refreshSendList(unitID, unitData, minIndex)
		end
	end

	function GG.getUnitTargetList(unitID)
		return unitTargets[unitID] and unitTargets[unitID].targets
	end

	function GG.getUnitTargetIndex(unitID)
		return unitTargets[unitID] and unitTargets[unitID].currentIndex
	end

	function gadget:Initialize()
		-- register command
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_NO_GROUND)
		-- register allowcommand callin
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_CANCEL_TARGET)

		for weaponDefID in pairs(WeaponDefs) do
			Script.SetWatchAllowTarget(weaponDefID, true)
		end

		-- load active units
		local allUnits = spGetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if validUnits[unitDefID] then
			spInsertUnitCmdDesc(unitID, unitSetTargetNoGroundCmdDesc)
			spInsertUnitCmdDesc(unitID, unitSetTargetCircleCmdDesc)
			spInsertUnitCmdDesc(unitID, unitCancelTargetCmdDesc)
			if unitTargets[builderID] then
				addUnitTargets(unitID, unitDefID, unitTargets[builderID].targets, false, "UnitCreated")
			end
		end
	end

	function gadget:UnitGiven(unitID, unitDefID, unitTeam)
		removeUnit(unitID)
	end

	function gadget:UnitTaken(unitID, unitDefID, unitTeam)
		removeUnit(unitID)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		removeUnit(unitID)
	end

	--------------------------------------------------------------------------------
	-- Command Tracking

	local searchCaches = {}
	local subtable = table.ensureTable

	local function processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		local nParams = #cmdParams

		if cmdID ~= CMD_UNIT_CANCEL_TARGET then
			local addTargetList

			local weapons = unitWeapons[unitDefID]
			local append = cmdOptions.shift
			local userTarget = not cmdOptions.internal
			local ignoreStop = cmdOptions.ctrl

			if nParams > 3 and not (nParams == 4 and cmdParams[4] == 0) then
				local targets
				if nParams == 6 then
					local top, bot, left, right
					if cmdParams[1] < cmdParams[4] then
						left = cmdParams[1]
						right = cmdParams[4]
					else
						left = cmdParams[4]
						right = cmdParams[1]
					end
					if cmdParams[3] < cmdParams[6] then
						top = cmdParams[3]
						bot = cmdParams[6]
					else
						bot = cmdParams[6]
						top = cmdParams[3]
					end
					local teamCache = subtable(searchCaches, spGetUnitAllyTeam(unitID))
					local allyHashe = left + top + right + bot
					targets = teamCache[allyHashe]
					if not targets then
						targets = CallAsTeam(teamID, spGetUnitsInRectangle, left, top, right, bot, -4)
						teamCache[allyHashe] = targets
					end
				elseif nParams == 4 then
					local teamCache = subtable(searchCaches, spGetUnitAllyTeam(unitID))
					local allyHashe = cmdParams[1] + cmdParams[2] + cmdParams[3] + cmdParams[4]
					targets = teamCache[allyHashe]
					if not targets then
						targets = CallAsTeam(teamID, spGetUnitsInCylinder, cmdParams[1], cmdParams[3], cmdParams[4], -4)
						teamCache[allyHashe] = targets
					end
					if not targets then
						Spring.MarkerAddPoint(Spring.GetUnitPosition(unitID))
					end
				end
				if targets and targets[1] then
					addTargetList = {}
					for i = 1, math.min(#targets, targetLimitAdd) do
						local target = targets[i]
						addTargetList[i] = {
							target     = target,
							alwaysSeen = type(target) == "table" or unitAlwaysSeen[spGetUnitDefID(target)],
							ignoreStop = ignoreStop,
							userTarget = userTarget,
						}
					end
				end
			elseif nParams >= 3 then
				if cmdParams[4] == 0 then
					if cmdID == CMD_UNIT_SET_TARGET_NO_GROUND then
						SendToUnsynced("failCommand", teamID)
						return
					end
					cmdParams[4] = nil
				end
				local elevation = spGetGroundHeight(cmdParams[1], cmdParams[3])
				if cmdParams[2] > elevation then
					cmdParams[2] = elevation
				end
				if elevation < 0 then
					elevation = 0
				end
				local validTarget = false
				for weaponNum = 1, #weapons do
					if spGetUnitWeaponTestTarget(unitID, weaponNum, cmdParams[1], cmdParams[2], cmdParams[3]) then
						validTarget = true
						break
					elseif cmdParams[2] < elevation and spGetUnitWeaponTestTarget(unitID, weaponNum, cmdParams[1], elevation, cmdParams[3]) then
						cmdParams[2] = elevation
						validTarget = true
						break
					end
				end
				if validTarget then
					addTargetList = {{
						target     = cmdParams,
						alwaysSeen = true,
						ignoreStop = ignoreStop,
						userTarget = userTarget,
					}}
				end
			elseif nParams == 1 then
				local target = cmdParams[1]
				if spValidUnitID(target) and not spAreTeamsAllied(teamID, spGetUnitTeam(target)) then
					local validTarget = false
					for weaponID = 1, #weapons do
						if spGetUnitWeaponTestTarget(unitID, weaponID, target) then
							validTarget = true
							break
						end
					end
					if validTarget then
						addTargetList = {{
							target     = target,
							alwaysSeen = unitAlwaysSeen[spGetUnitDefID(target)],
							ignoreStop = ignoreStop,
							userTarget = userTarget,
						}}
					end
				end
			end
			if addTargetList then
				addUnitTargets(unitID, unitDefID, addTargetList, append, false)
			end
		elseif unitData then
			if #cmdParams == 0 then
				removeUnit(unitID)
			elseif #cmdParams == 1 then
				if cmdOptions.alt then
					removeTarget(unitID, cmdParams[1])
				else
					local removeID = cmdParams[1]
					for index, value in ipairs(unitData.targets) do
						if value == removeID then
							removeTarget(removeID, index)
							break -- target lists are deduped
						end
					end
				end
			elseif #cmdParams == 3 then
				for index, value in ipairs(unitData.targets) do
					if type(value) == "table" and distance(value, cmdParams) < deleteMaxDistance then
						removeTarget(unitID, index)
					end
				end
			end
		end
	end

	local function pauseTargetting(unitID)
		if unitTargets[unitID] and not pausedTargets[unitID] then
			local data = unitTargets[unitID]
			removeUnit(unitID, true)
			pausedTargets[unitID] = data
		end
	end

	local function unpauseTargetting(unitID)
		addUnitTargets(unitID, Spring.GetUnitDefID(unitID), pausedTargets[unitID].targets, true)
	end

	function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
		local hasTargetData = unitTargets[unitID] or pausedTargets[unitID]
		if not hasTargetData then
			return
		end

		if cmdID == CMD_STOP then
			removeStoppableTargets(unitID)
		elseif isAttackCommand[cmdID] then
			pauseTargetting(unitID)
		end

		-- We do not know if we are coming from ExecuteInsert or FinishCommand.
		-- So we do not know whether the below command is starting or finished.
		if cmdID == CMD_DGUN or spGetUnitCurrentCommand(unitID) == CMD_DGUN then
			checkForManualFire[unitID] = true
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
		-- Accepts: CMD_UNIT_SET_TARGET_NO_GROUND, CMD_UNIT_SET_TARGET, CMD_UNIT_SET_TARGET_RECTANGLE, CMD_UNIT_CANCEL_TARGET.
		if isSetTargetCommand[cmdID] then
			if validUnits[unitDefID] then
				processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
			end
			return false
		else
			return true
		end
	end

	function gadget:UnitAutoTargetRange(unitID, autoTargetRange)
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		return unitData and unitData.inRange and 0 or autoTargetRange -- 0 disables autotargeting
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg == "settarget_line" then
			local _, _, _, teamID = spGetPlayerInfo(playerID)
			if teamID then
				SendToUnsynced("settarget_line_sound", teamID, playerID, nil, CMD_UNIT_SET_TARGET)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Target update

	function gadget:GameFrame(n)
		-- ideally timing would be synced with slow update to reduce attack jittering
		-- SlowUpdate+ causes attack command to override target command
		-- unfortunately since 103 that's not possible, attempt to override every frame
		-- it might create a slight increase of cpu usage when hundreds of units gets
		-- a set target command, howrever a quick test with 300 fidos only increased by 1%
		-- sim here

		if n % 5 == 4 then
			for unitID, unitData in pairsNext, unitTargets do
				local targets = unitData.targets
				local removed = 0

				for index = 1, #targets do
					local targetData = targets[index]
					if not checkTarget(unitID, targetData.target) then
						targetData.invalid = true
						removed = removed + 1
					end
				end

				if removed ~= 0 then
					removeInvalidTargets(unitID, unitData)
					SendToUnsynced("targetIndex", unitID, unitData.currentIndex)
				end
			end
		end

		if n % USEEN_UPDATE_FREQUENCY == 0 then
			for unitID, unitData in pairsNext, unitTargets do
				local targets = unitData.targets
				-- Iterate backwards to safely handle removals
				for index = #targets, 1, -1 do
					if removeUnseenTarget(targets[index], unitData.allyTeam) then
						removeTarget(unitID, index)
					end
				end
			end
		end

		for unitID in pairs(checkForManualFire) do
			if unitTargets[unitID] then
				if spGetUnitCurrentCommand(unitID) == CMD_DGUN then
					pauseTargetting(unitID)
				else
					checkForManualFire[unitID] = nil
				end
			elseif pausedTargets[unitID] then
				if spGetUnitCurrentCommand(unitID) ~= CMD_DGUN then
					unpauseTargetting(unitID)
				end
			else
				checkForManualFire[unitID] = nil
			end
		end

		searchCaches = {}
	end



else	-- UNSYNCED



	local glVertex = gl.Vertex
	local glPushAttrib = gl.PushAttrib
	local glLineStipple = gl.LineStipple
	local glDepthTest = gl.DepthTest
	local glLineWidth = gl.LineWidth
	local glColor = gl.Color
	local glBeginEnd = gl.BeginEnd
	local glPopAttrib = gl.PopAttrib
	local GL_LINE_STRIP = GL.LINE_STRIP
	local GL_LINES = GL.LINES

	local spGetUnitPosition = Spring.GetUnitPosition
	local spValidUnitID = Spring.ValidUnitID
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetMyTeamID = Spring.GetMyTeamID
	local spIsUnitSelected = Spring.IsUnitSelected
	local spGetSpectatingState = Spring.GetSpectatingState
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitTeam = Spring.GetUnitTeam
	local spPlaySoundFile = Spring.PlaySoundFile
	local spSetActiveCommand = Spring.SetActiveCommand
	local spAssignMouseCursor = Spring.AssignMouseCursor
	local spSetCustomCommandDrawData = Spring.SetCustomCommandDrawData
	local spAddWorldIcon = Spring.AddWorldIcon
	local pairsNext = next

	local myAllyTeam = spGetMyAllyTeamID()
	local myTeam = spGetMyTeamID()
	local mySpec, fullview = spGetSpectatingState()

	local lineWidth = 1.4
	local queueColour = { 1, 0.75, 0, 0.3 }
	local commandColour = { 1, 0.5, 0, 0.3 }

	local drawAllTargets = {}
	local drawTarget = {}
	local targetList = {}

	function GG.getUnitTargetList(unitID)
		return targetList[unitID] and targetList[unitID].targets
	end

	function GG.getUnitTargetIndex(unitID)
		return targetList[unitID] and targetList[unitID].currentIndex
	end

	local function handleFailCommand(_, teamID)
		if teamID == myTeam and not mySpec then
			spPlaySoundFile("FailedCommand", 0.75, "ui")
			spSetActiveCommand('settargetnoground')
		end
	end

	local function handleTargetListEvent(_, unitID, index, alwaysSeen, ignoreStop, userTarget, targetA, targetB, targetC)
		--tracy.ZoneBeginN(string.format("handleTargetListEvent %d %d ", unitID, index))
		if index == 0 then
			targetList[unitID] = nil
			--tracy.ZoneEnd()
			return
		end
		targetList[unitID] = targetList[unitID] or {}
		if index == 1 then
			targetList[unitID].targets = {}
		end
		if targetA == nil then
			local targets = targetList[unitID].targets
			if targets then
				for i = index, #targets do
					targets[i] = nil
				end
			end
			return
		end
		targetList[unitID].targets = targetList[unitID].targets or {}
		targetList[unitID].targets[index] = {
			alwaysSeen = alwaysSeen,
			ignoreStop = ignoreStop,
			userTarget = userTarget,
			target = (not tonumber(targetB) and targetA) or { targetA, targetB, targetC },
		}
		--tracy.ZoneEnd()
	end

	local function handleTargetListBatchedEvent(_, count, stride, data)
		for i =1, count, stride do
			local targetB = data[i+6]
			local targetC = data[i+7]
			if targetB < 0 then
				targetB = nil
			end
			if targetC < 0 then
				targetC = nil
			end
			handleTargetListEvent(_, data[i], data[i+1], data[i+2], data[i+3], data[i+4], data[i+5], targetB, targetC)
		end
	end


	local function handleTargetIndexEvent(_, unitID, index)
		if targetList[unitID] then
			targetList[unitID].targetIndex = index
		end
	end

	local function handleUnitTargetDrawEvent(_, _, params)
		drawTarget[tonumber(params[1])] = true
		return true
	end

	local function handleTargetDrawEvent(_, _, params)
		local teamID = tonumber(params[1])
		local doDraw = tonumber(params[2]) ~= 0
		drawAllTargets[teamID] = doDraw
		return true
	end

	--function handleTargetChangeEvent(_,unitID,dataA,dataB,dataC)
	--	if not dataB then
	--		--single unitID format
	--		unitTargets[unitID] = dataA
	--	elseif dataA and dataB and dataC then
	--		--3d coordinates format
	--		unitTargets[unitID] = {dataA,dataB,dataC}
	--	end
	--    return true
	--end
	local unitIconsDrawn = {}
	local function drawUnitTarget(cacheKey, x, y, z)
		glVertex(x, y, z)
		if not unitIconsDrawn[cacheKey] then
			-- avoid sending WorldIcons to engine at the same unit/location
			spAddWorldIcon(CMD_UNIT_SET_TARGET, x, y, z)
			unitIconsDrawn[cacheKey] = true
		end
	end

	local function drawTargetCommand(targetData)
		if targetData and targetData.userTarget then
			local target = targetData.target
			local isUnitTarget = type(target) == "number"

			if isUnitTarget and spValidUnitID(target) then
				local _, _, _, x2, y2, z2 = spGetUnitPosition(target, false, true)
				drawUnitTarget(-target, x2, y2, z2)
			elseif not isUnitTarget and target then
				-- 3d coordinate target
				local x2, y2, z2 = target[1], target[2], target[3]
				drawUnitTarget(x2+y2+z2, x2, y2, z2)
			end
		end
	end

	local function drawCurrentTarget(unitID, unitData)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		drawTargetCommand(unitData.targets[unitData.targetIndex])
	end

	local function drawTargetQueue(unitID, unitData)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		for _, targetData in ipairs(unitData.targets) do
			drawTargetCommand(targetData)
		end
	end

	local function drawDecorations()
		local init = false
		local skipChunkSize, skipChunkLeft = 4, 40
		local skipSize, skipLeft = 0, 0
		local count = 0
		for unitID, unitData in pairsNext, targetList do
			if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
				if skipLeft == 0 and (drawTarget[unitID] or drawAllTargets[spGetUnitTeam(unitID)] or spIsUnitSelected(unitID)) then
					if not init then
						init = true
						glPushAttrib(GL.LINE_BITS)
						glLineStipple("any") -- use spring's default line stipple pattern, moving
						glDepthTest(false)
						glLineWidth(lineWidth)
					end
					glColor(queueColour)
					glBeginEnd(GL_LINE_STRIP, drawTargetQueue, unitID, unitData, myTeam, myAllyTeam)
					if unitData.targetIndex then
						glColor(commandColour)
						glBeginEnd(GL_LINES, drawCurrentTarget, unitID, unitData, myTeam, myAllyTeam)
					end
					skipChunkLeft = skipChunkLeft - 1
					if skipChunkLeft == 0 then
						skipChunkLeft = skipChunkSize
						skipSize = skipSize == 0 and 2 or math.min(skipSize * 2, 40)
					end
					skipLeft = skipSize
					count = count + 1
				else
					skipLeft = skipLeft - 1
				end
			end
		end
		if init then
			glColor(1, 1, 1, 1)
			glLineStipple(false)
			glPopAttrib()
		end
		drawTarget = {}
		unitIconsDrawn = {}
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction("targetdrawteam", handleTargetDrawEvent, "toggles drawing targets for units, params: teamID doDraw")
		gadgetHandler:AddChatAction("targetdrawunit", handleUnitTargetDrawEvent, "toggles drawing targets for units, params: unitID")
		gadgetHandler:AddSyncAction("targetList", handleTargetListEvent)
		gadgetHandler:AddSyncAction("targetListBatched", handleTargetListBatchedEvent)
		gadgetHandler:AddSyncAction("targetIndex", handleTargetIndexEvent)
		gadgetHandler:AddSyncAction("failCommand", handleFailCommand)

		-- register cursor
		spAssignMouseCursor("settarget", "cursorsettarget", false)
		--show the command in the queue
		spSetCustomCommandDrawData(CMD_UNIT_SET_TARGET, "settarget", queueColour, true)
		spSetCustomCommandDrawData(CMD_UNIT_SET_TARGET_NO_GROUND, "settargetrectangle", queueColour, true)
		spSetCustomCommandDrawData(CMD_UNIT_SET_TARGET_RECTANGLE, "settargetnoground", queueColour, true)

	end

	function gadget:PlayerChanged(playerID)
		myAllyTeam = spGetMyAllyTeamID()
		myTeam = spGetMyTeamID()
		mySpec, fullview = spGetSpectatingState()
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("targetdrawteam")
		gadgetHandler:RemoveChatAction("targetdrawunit")
		gadgetHandler:RemoveSyncAction("targetList")
		gadgetHandler:RemoveSyncAction("targetListBatched")
		gadgetHandler:RemoveSyncAction("targetIndex")
		gadgetHandler:RemoveSyncAction("failCommand")
	end

	function gadget:DrawWorld()
		if Spring.IsGUIHidden() then
			return
		end

		if fullview then
			drawDecorations()
		else
			CallAsTeam(myTeam, drawDecorations)
		end
	end

end

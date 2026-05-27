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

-- Target precedence:
-- (0) Basics. Target exists, is valid, is seen: Yes > No.
-- (1) Aiming. Can hit > In range but blocked > Out of range.
-- (2) Command. Manual Fire, Attack, Area Attack > Set Target > Fight > Guard, Return Fire > Fire at Will.
-- (3) Priority.
--     Fight: Nearest enemy unit.
--     Fire at Will: Uses "targeting priority".
--     Set Target: Earliest index in list.

local spGetUnitRulesParam = Spring.GetUnitRulesParam

function GG.GetUnitTarget(unitID)
	local targetID = spGetUnitRulesParam(unitID, "targetID")
	if not targetID then
		return
	end

	if targetID ~= -1 then
		return targetID
	end

	local targetCoordX = spGetUnitRulesParam(unitID, "targetCoordX")
	local targetCoordY = spGetUnitRulesParam(unitID, "targetCoordY")
	local targetCoordZ = spGetUnitRulesParam(unitID, "targetCoordZ")
	if targetCoordX ~= -1 and targetCoordZ ~= -1 then
		return { targetCoordX, targetCoordY, targetCoordZ }
	end
end

if gadgetHandler:IsSyncedCode() then

	-- SYNCED CODE

	local cancelCommandDistance = 30
	local targetLimitAdd = 60
	local targetLimitMax = 120

	-- We constantly check for precedence/contention with other targeting.
	local commandUpdateFrames = 3
	-- Checks units that are destroyed or captured or alliances that change.
	local targetUpdateFrames = 10
	-- Unseen targets will be removed after max `unseenUpdateFrames` frames.
	-- Should be small enough to not be evident and big enough to save perf.
	local unseenUpdateFrames = 15

	local next = next
	local type = type
	local table_remove = table.remove
	local table_new = table.new
	local math_max = math.max
	local math_diag = math.diag

	local SendToUnsynced = SendToUnsynced
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
	local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
	local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
	local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
	local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
	local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetAllUnits = Spring.GetAllUnits
	local spGetPlayerInfo = Spring.GetPlayerInfo

	local CMD_ATTACK = CMD.ATTACK
	local CMD_FIGHT = CMD.FIGHT
	local CMD_GUARD = CMD.GUARD
	local CMD_STOP = CMD.STOP

	local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
	local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
	local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
	local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE

	local isAttackCommand = {
		[CMD_ATTACK]                 = true,
		[CMD.AREA_ATTACK]            = true,
		[CMD.MANUALFIRE]             = true,
		[GameCMD.AREA_ATTACK_GROUND] = true,
	}

	local function hasTargeting(weaponDef)
		return weaponDef.type ~= "Shield" and not weaponDef.manualFire and weaponDef.range > 10
	end

	-- Fastpass for units that don't have an attack command for other reasons.
	local allowNonAttackerUnit = { legpede = true }
	local function canSetTarget(unitDef)
		if (unitDef.canAttack or allowNonAttackerUnit[unitDef.name]) and unitDef.maxWeaponRange > 0 then
			for _, weapon in pairs(unitDef.weapons) do
				if weapon.slavedTo == 0 and hasTargeting(WeaponDefs[weapon.weaponDef]) then
					return true
				end
			end
		end
		return false
	end

	-- TODO: We don't know what weaponDefs have submissile. We can check `nuke`, for now.
	---@return 0|1|false `false` := non-targeting weapon `0` := waterWeapon `1` := everything else
	local function getWeaponType(weapon)
		local weaponDef = WeaponDefs[weapon.weaponDef]
		if hasTargeting(weaponDef) then
			return weaponDef.waterWeapon and not weaponDef.customParams.nuke and 0 or 1
		else
			return false
		end
	end

	local validUnits = {}
	local unitWeapons = {}
	local unitAlwaysSeen = {}
	for unitDefID = 1, #UnitDefs do
		local unitDef = UnitDefs[unitDefID]
		if canSetTarget(unitDef) then
			validUnits[unitDefID] = true
			unitWeapons[unitDefID] = table.map(unitDef.weapons, function(w, i) return (w.slavedTo == 0 and getWeaponType(w) or nil), i end)
		end
		-- TODO: Make this the same as leaving ghosts and the ghosted position.
		unitAlwaysSeen[unitDefID] = unitDef.isBuilding or unitDef.speed == 0
	end

	---@class SetTargetData
	---@field unitTeam integer
	---@field allyTeam integer
	---@field weapons table<integer, 0|1>
	---@field targets SetTargetItem[]
	---@field currentIndex integer
	---@field inRange boolean

	---@alias SetTargetItem SetTargetItemUnit|SetTargetItemPosition

	---@class SetTargetItemUnit
	---@field target integer
	---@field alwaysSeen boolean
	---@field ignoreStop boolean
	---@field userTarget boolean
	---@field sent boolean

	---@class SetTargetItemPosition
	---@field target xyz
	---@field alwaysSeen true
	---@field ignoreStop boolean
	---@field userTarget boolean
	---@field sent boolean

	local setTargetData = {} ---@type table<integer, SetTargetData>
	local activeTargets = {} ---@type table<integer, SetTargetData>
	local pausedTargets = {} ---@type table<integer, SetTargetData>

	local inAttackOrder = {} -- Not the same as paused since we use it to probe units.

	local queuedSendTargetListLength = {}
	local queuedSendTargetListValues = {}

	--------------------------------------------------------------------------------
	-- Commands

	-- TODO: i18n
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
	-- Sending target list info to unsynced

	local function sendTargetList(unitID, targets)
		for index, targetData in next, targets do
			if not targetData.sent then
				targetData.sent = true
				local target = targetData.target
				if type(target) == "number" then
					SendToUnsynced("targetList", unitID, index, targetData.userTarget, target)
				else
					SendToUnsynced("targetList", unitID, index, targetData.userTarget, target[1], target[2], target[3])
				end
			end
		end
	end

	local function sendTargetListBatched(unitID, unitData, minIndex)
		local targets = unitData.targets
		local targetCount = #targets

		if targetCount == 0 then
			return
		elseif targetCount <= 8 then
			sendTargetList(unitID, targets)
		end

		local data = table_new(targetCount * 5, 0)
		local total = 0
		for count = (minIndex or 1), targetCount do
			local targetData = targets[count]
			if not targetData.sent then
				targetData.sent = true
				data[count + 1] = count
				data[count + 2] = targetData.userTarget -- Other options are unused.
				local target = targetData.target
				if type(target) == "number" then
					data[count + 3] = target
					data[count + 4] = -1
					data[count + 5] = -1
				else
					data[count + 3] = target[1]
					data[count + 4] = target[2]
					data[count + 5] = target[3]
				end
			end
			total = total + 1 -- Limit this by setting the max target limit.
		end

		if data[2] then
			SendToUnsynced("targetListBatched", unitID, total, data)
		end
	end

	local function readySendList(unitID, targetList, minIndex)
		local count = #targetList
		for i = math_max(minIndex or 1, 1), count do
			targetList[i].sent = false
		end
		queuedSendTargetListLength[unitID] = count
		queuedSendTargetListValues[unitID] = true
	end

	--------------------------------------------------------------------------------
	-- Target Handling

	local function tryTargetUnit(unitID, weapons, targetID)
		for weaponNum, canTarget in next, weapons do
			if canTarget and spGetUnitWeaponTryTarget(unitID, weaponNum, targetID) then
				return true
			end
		end
		return false
	end

	local function tryTargetPos(unitID, weapons, x, y, z)
		for weaponNum, canTarget in next, weapons do
			if canTarget
				and spGetUnitWeaponTestTarget(unitID, weaponNum, x, y, z)
				and spGetUnitWeaponTestRange(unitID, weaponNum, x, y, z)
				and spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, nil, nil, nil, x, y, z) then
				return true
			end
		end
		return false
	end

	local function targetCanBeReached(unitID, teamID, weaponList, target)
		if type(target) == "number" then
			return CallAsTeam(teamID, tryTargetUnit, unitID, weaponList, target)
		else
			return CallAsTeam(teamID, tryTargetPos, unitID, weaponList, target[1], target[2], target[3])
		end
	end

	-- See notes on targeting precedence. Set Target acts as a separate queue from the order queue.
	-- TODO: Check target range. Ignore higher-precedence orders when their targets are unreachable.
	-- TODO: But that would require a separate function; we do this to see if we _should_ check that
	-- TODO: the unit is in range of any set target data, and even before we have added any targets.
	local function hasSetTargetPrecedence(unitID)
		local inCommand, _, _, param1, param2 = spGetUnitCurrentCommand(unitID, 1)
		if not inCommand or not isAttackCommand[inCommand] then
			return true
		end

		if inCommand ~= CMD_ATTACK then
			return false
		end

		local nextCommand, _, _, nextParam1 = spGetUnitCurrentCommand(unitID, 2)

		if not nextCommand then
			return true
		elseif nextCommand == CMD_FIGHT then
			-- ! FIXME: We assume the Attack command originated from within Fight but cannot be sure.
			return true
		elseif nextCommand == CMD_GUARD then
			-- We can try to detect the retaliation behavior from a guarded unit being attacked, but
			-- this is also not an easy thing to know. This may not detect Return Fire retaliations.
			if not param2 and nextParam1 and spValidUnitID(param1) and spValidUnitID(nextParam1) then
				local _, _, target = spGetUnitWeaponTarget(param1, 1)
				if target == nextParam1 then
					return false
				end
			end
		end

		return true -- Only direct Attack orders issued with user intent precede the Set Target list.
	end

	-- FIXME: Dropping autotargets does not work correctly, so this sometimes fails:
	local function dropUnitTargets(unitID, unitData)
		for weaponNum, canTarget in pairs(unitData.weapons) do
			-- TODO: Does this work correctly on slavedTo weapons
			if canTarget then
				spSetUnitTarget(unitID, nil, false, false, weaponNum)
			end
		end
		spSetUnitTarget(unitID, nil)
	end

	local function setTarget(unitID, unitData, targetIndex, targetData)
		if not targetCanBeReached(unitID, unitData.unitTeam, unitData.weapons, targetData.target) then
			return false
		end

		dropUnitTargets(unitID, unitData)

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

	local function setTargetNone(unitID, unitData)
		unitData.currentIndex = 1
		unitData.inRange = false
		spSetUnitRulesParam(unitID, "targetID")
		spSetUnitRulesParam(unitID, "targetCoordX")
		spSetUnitRulesParam(unitID, "targetCoordY")
		spSetUnitRulesParam(unitID, "targetCoordZ")
	end

	local function setTargetReset(unitID, unitData)
		if unitData.currentIndex ~= 1 then
			unitData.currentIndex = 1
			unitData.inRange = false
			local targetID, targetCoordX, targetCoordY, targetCoordZ
			local target = unitData.targets[1]
			if target then
				if type(target) == "number" then
					targetID, targetCoordX, targetCoordY, targetCoordZ = target, -1, -1, -1
				else
					targetID, targetCoordX, targetCoordY, targetCoordZ = -1, target[1], target[2], target[3]
				end
			end
			spSetUnitRulesParam(unitID, "targetID",     targetID)
			spSetUnitRulesParam(unitID, "targetCoordX", targetCoordX)
			spSetUnitRulesParam(unitID, "targetCoordY", targetCoordY)
			spSetUnitRulesParam(unitID, "targetCoordZ", targetCoordZ)
			SendToUnsynced("targetIndex", unitID, 1)
		end
	end

	local function setTargetSearch(unitID, unitData)
		for index, targetData in pairs(unitData.targets) do
			if setTarget(unitID, unitData, index, targetData) then
				return index
			end
		end
		setTargetNone(unitID, unitData)
	end

	local function tryTargetSearch(unitID, unitData)
		if false and not hasSetTargetPrecedence(unitID) then
			setTargetReset(unitID, unitData)
			inAttackOrder[unitID] = true
			return
		end

		if unitData.currentIndex ~= setTargetSearch(unitID, unitData) then
			SendToUnsynced("targetIndex", unitID, unitData.currentIndex)
		end
	end

	--------------------------------------------------------------------------------
	-- Unit adding/removal

	local function addUnitTargets(unitID, unitDefID, targets, append)
		local data = setTargetData[unitID]
		local targetList = append and data and data.targets or {}
		local targetCount = #targetList

		local reverseMap = {}
		for index = 1, targetCount do
			if type(targetList[index].target) == "number" then
				reverseMap[targetList[index].target] = index
			end
		end

		-- FIXME: Set Target commands always add units left-to-right. That is weird.
		for _, targetData in next, targets do
			if reverseMap[targetData.target] then
				if append then
					local target = targetList[reverseMap[targetData.target]]
					target.ignoreStop = target.ignoreStop or targetData.ignoreStop
					target.userTarget = target.userTarget or targetData.userTarget
					target.sent = false
				end
			elseif targetCount < targetLimitMax then
				targetCount = targetCount + 1
				targetList[targetCount] = targetData
				targetData.sent = false
			elseif not append then
				break
			end
		end

		if targetCount == 0 then
			return
		end

		if not data then
			data = {
				unitTeam     = spGetUnitTeam(unitID),
				allyTeam     = spGetUnitAllyTeam(unitID),
				weapons      = unitWeapons[unitDefID],
				targets      = targetList,
				currentIndex = 1,
				inRange      = false,
			}
			setTargetData[unitID] = data
		elseif not append then
			data.targets = targetList
			data.currentIndex = 1
			data.inRange = false
		end

		activeTargets[unitID] = data
		pausedTargets[unitID] = nil

		if not append then
			tryTargetSearch(unitID, data)
		end

		sendTargetListBatched(unitID, data)
	end

	local function removeUnit(unitID, keepTrack)
		if activeTargets[unitID] then
			if activeTargets[unitID].inRange then
				setTargetNone(unitID, setTargetData[unitID])
			end
			activeTargets[unitID] = nil
		elseif pausedTargets[unitID] then
			pausedTargets[unitID] = nil
		end
		if not keepTrack then
			setTargetData[unitID] = nil
			inAttackOrder[unitID] = nil
			queuedSendTargetListLength[unitID] = 0
			queuedSendTargetListValues[unitID] = nil
		end
	end

	local function removeTarget(unitID, unitData, targets, index)
		if table_remove(targets, index) then
			if not targets[1] then
				removeUnit(unitID)
			else
				tryTargetSearch(unitID, unitData)
				readySendList(unitID, targets, index)
			end
		end
	end

	local function removeStoppableTargets(unitID)
		local unitData = setTargetData[unitID]
		local targetList = unitData.targets
		local n = #targetList
		local minIndex
		for i = n, 1, -1 do
			if not targetList[i].ignoreStop then
				table_remove(targetList, i)
				minIndex = i
			end
		end
		if not targetList[1] then
			removeUnit(unitID)
		elseif minIndex then
			if minIndex <= unitData.currentIndex then
				tryTargetSearch(unitID, unitData)
			end
			readySendList(unitID, targetList, minIndex)
		end
	end

	function GG.getUnitTargetList(unitID)
		return activeTargets[unitID] and activeTargets[unitID].targets
	end

	function GG.getUnitTargetIndex(unitID)
		return activeTargets[unitID] and activeTargets[unitID].currentIndex
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_NO_GROUND)

		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_CANCEL_TARGET)

		for weaponDefID in pairs(WeaponDefs) do
			Script.SetWatchAllowTarget(weaponDefID, true)
		end

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
			if setTargetData[builderID] then
				addUnitTargets(unitID, unitDefID, setTargetData[builderID].targets, false)
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

	local ensureTable = table.ensureTable

	local function distance(posA, posB)
		math_diag(posA[1] - posB[1], posA[2] - posB[2], posA[3] - posB[3])
	end

	local searchCaches = {}

	local function processCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		local unitData = setTargetData[unitID]
		local nParams = #cmdParams

		if nParams == 4 and cmdParams[4] <= 1 then
			nParams, cmdParams[4] = 3, nil
		end

		if cmdID ~= CMD_UNIT_CANCEL_TARGET then
			local addTargetList ---@type SetTargetItem[]

			local append = unitData and cmdOptions.shift
			local userTarget = not cmdOptions.internal -- TODO: Remove the internal/user distinction.
			local ignoreStop = cmdOptions.ctrl

			if nParams == 1 then
				local validTarget = false
				local target = cmdParams[1]
				if not spValidUnitID(target) then
					return
				end
				for weaponNum in pairs(unitWeapons[unitDefID]) do
					if spGetUnitWeaponTestTarget(unitID, weaponNum, target) then
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
						sent       = false, -- Include `sent` to prevent resizing the table later.
					}}
				end
			elseif nParams == 3 then
				if cmdID == CMD_UNIT_SET_TARGET_NO_GROUND then
					SendToUnsynced("failCommand", unitTeam)
					return
				end

				local validTarget = false
				local posX, posZ = cmdParams[1], cmdParams[3]
				if not Spring.IsPosInMap(posX, posZ) then
					return -- TODO: Could clamp to map bounds if wanted.
				end
				local elevation = math_max(spGetGroundHeight(posX, posZ), 0) -- TODO: Allow targeting below water level.
				for weaponNum, weaponType in next, unitWeapons[unitDefID] do
					if weaponType ~= 0 or elevation <= 0 then
						if spGetUnitWeaponTestTarget(unitID, weaponNum, posX, elevation, posZ) then
							validTarget = true
							break
						end
					end
				end
				if validTarget then
					cmdParams[2] = elevation
					addTargetList = {{
						target     = cmdParams,
						alwaysSeen = true,
						ignoreStop = ignoreStop,
						userTarget = userTarget,
						sent       = false,
					}}
				end
			elseif nParams >= 4 then
				-- TODO: Targets are always returned in a left-right, top-bottom sort, which then gives a weird priority order.
				-- TODO: Probably, we should be sorting this somehow, relative to the attacking unit's initial position (here).
				local targets
				if nParams == 4 then
					local teamCache = ensureTable(searchCaches, spGetUnitAllyTeam(unitID))
					local allyHashe = cmdParams[1] + cmdParams[2] + cmdParams[3] + cmdParams[4]
					targets = teamCache[allyHashe]
					if not targets then
						targets = CallAsTeam(unitTeam, spGetUnitsInCylinder, cmdParams[1], cmdParams[3], cmdParams[4], -4)
						table.sort(targets) -- FIXME: Insanely evil way to handle our two TODOs earlier.
						teamCache[allyHashe] = targets
					end
				elseif nParams == 6 then
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
					local teamCache = ensureTable(searchCaches, spGetUnitAllyTeam(unitID))
					local allyHashe = left + top + right + bot
					targets = teamCache[allyHashe]
					if not targets then
						targets = CallAsTeam(unitTeam, spGetUnitsInRectangle, left, top, right, bot, -4)
						table.sort(targets) -- FIXME: Insanely evil way to handle our two TODOs earlier.
						teamCache[allyHashe] = targets
					end
				end
				if targets and targets[1] then
					addTargetList = {}
					for i = 1, math.min(#targets, targetLimitAdd) do
						local target = targets[i]
						addTargetList[i] = {
							target     = target,
							alwaysSeen = unitAlwaysSeen[spGetUnitDefID(target)],
							ignoreStop = ignoreStop,
							userTarget = userTarget,
							sent       = false,
						}
					end
				end
			end
			if addTargetList then
				addUnitTargets(unitID, unitDefID, addTargetList, append)
			end
		elseif unitData then
			if nParams == 0 then
				removeUnit(unitID)
			elseif nParams == 1 then
				if cmdOptions.alt then
					removeTarget(unitID, unitData, unitData.targets, cmdParams[1])
				else
					local targetID = cmdParams[1]
					if targetID < 0 then
						return
					end
					for index, target in next, unitData.targets do
						if target == targetID then
							removeTarget(unitID, unitData, unitData.targets, index)
							return
						end
					end
				end
			elseif nParams == 3 then
				local targetList = unitData.targets
				local minIndex
				for index = #targetList, 1, -1 do
					local value = targetList[index]
					if type(value) == "table" and distance(value, cmdParams) < cancelCommandDistance then
						table_remove(targetList, index)
						minIndex = index
					end
				end
				if minIndex then
					if not targetList[1] then
						removeUnit(unitID)
					else
						tryTargetSearch(unitID, unitData)
						readySendList(unitID, unitData.targets, minIndex)
					end
				end
			end
		end
	end

	local function pauseTargeting(unitID)
		if activeTargets[unitID] and not pausedTargets[unitID] then
			local data = activeTargets[unitID]
			dropUnitTargets(unitID, data) -- ! Do we know if we can drop targets? When do we pause after receiving an Attack cmd?
			removeUnit(unitID)
			pausedTargets[unitID] = data
			inAttackOrder[unitID] = true
		end
	end

	local function unpauseTargeting(unitID)
		addUnitTargets(unitID, Spring.GetUnitDefID(unitID), pausedTargets[unitID].targets, false)
	end

	--------------------------------------------------------------------------------
	-- Target update

	-- Attack commands override the Set Target command on the engine's SlowUpdate.
	-- Ideally, we could synchronize with that to eliminate target jittering, but
	-- that is not possible since engine version 103. Units also can call their own
	-- SlowUpdate method and have many triggers to do so; detection is impractical.
	-- We override on (almost) every sim frame which is only a moderate perf cost.

	local areAlliedCache
	do
		local teamList = Spring.GetTeamList()
		local n = #teamList
		areAlliedCache = table.map(Spring.GetTeamList(), function(team)
			local tbl = table.new(n - 1, 1)
			tbl[team] = true
			return tbl, team
		end)
	end

	local function updateTargetAlliance()
		local areAllied = areAlliedCache
		local teamList = Spring.GetTeamList()
		local n = #teamList
		for i = 1, n - 1 do
			local team1 = teamList[i]
			for j = i + 1, n do
				local team2 = teamList[j]
				local allied = spAreTeamsAllied(team1, team2)
				areAllied[team1][team2] = allied
				areAllied[team2][team1] = allied
			end
		end

		-- Handle target death and alliance change.
		for unitID, unitData in next, setTargetData do
			local isAllied = areAllied[unitData.unitTeam]
			local targets = unitData.targets
			local count = #targets
			local removed, minIndex = 0, count + 1

			for i = count, 1, -1 do
				local targetID = targets[i].target
				if type(targetID) == "number" and (not spValidUnitID(targetID) or isAllied[spGetUnitTeam(targetID)]) then
					table_remove(targets, i)
					minIndex = i
					removed = removed + 1
				end
			end

			if removed == count then
				removeUnit(unitID)
			elseif removed ~= 0 then
				if minIndex <= unitData.currentIndex then
					setTargetReset(unitID, unitData)
				end
				readySendList(unitID, targets, minIndex)
			end
		end
	end

	local function updateTargetTracking()
		local lostTargetCache = table.map(Spring.GetAllyTeamList(), function(allyTeam) return {}, allyTeam end)

		-- Handle target death and loss of tracking.
		for unitID, unitData in next, setTargetData do
			local allyTeam = unitData.allyTeam
			local lostTargets = lostTargetCache[allyTeam]
			local targets = unitData.targets
			local count = #targets
			local removed, minIndex = 0, count + 1

			for i = count, 1, -1 do
				local target = targets[i]
				if not target.alwaysSeen then
					local targetID = target.target
					local wasLost = lostTargets[targetID]
					if wasLost == nil then
						wasLost = not spValidUnitID(targetID) or spGetUnitLosState(targetID, allyTeam, true) % 4 == 0
						lostTargets[targetID] = wasLost
					end
					if wasLost then
						table_remove(targets, i)
						minIndex = i
						removed = removed + 1
					end
				end
			end

			if removed == count then
				removeUnit(unitID)
			elseif removed ~= 0 then
				if minIndex <= unitData.currentIndex then
					setTargetReset(unitID, unitData)
				end
				readySendList(unitID, targets, minIndex)
			end
		end
	end

	local function updateTargetCommands()
		for unitID, paused in pairs(inAttackOrder) do
			if paused then
				if hasSetTargetPrecedence(unitID) then
					unpauseTargeting(unitID)
				end
			else
				if not hasSetTargetPrecedence(unitID) then
					pauseTargeting(unitID)
				else
					inAttackOrder[unitID] = nil
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Engine callins

	function gadget:GameFrame(frame)
		if frame % targetUpdateFrames == 3 then
			updateTargetAlliance()
		elseif frame % unseenUpdateFrames == 2 then
			updateTargetTracking()
		elseif frame % commandUpdateFrames == 0 then
			updateTargetCommands()
		end

		for unitID, count in pairs(queuedSendTargetListLength) do
			SendToUnsynced("targetList", unitID, count)
		end

		for unitID, unitData in pairs(queuedSendTargetListValues) do
			sendTargetListBatched(unitID, unitData)
		end

		searchCaches = {}
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
		if validUnits[unitDefID] then
			processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		end
		return false
	end

	function gadget:UnitCommand(_, unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
		if setTargetData[unitID] then
			if cmdID == CMD_STOP then
				removeStoppableTargets(unitID)
			elseif isAttackCommand[cmdID] then
				pauseTargeting(unitID)
			end
		end
	end

	function gadget:UnitAutoTargetRange(unitID, autoTargetRange)
		local unitData = activeTargets[unitID]
		return unitData and unitData.inRange and 0 or autoTargetRange -- <= 0 disables autotargeting
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg == "settarget_line" then
			local _, _, _, teamID = spGetPlayerInfo(playerID)
			if teamID then
				SendToUnsynced("settarget_line_sound", teamID, playerID, nil, CMD_UNIT_SET_TARGET)
			end
		end
	end


else	-- UNSYNCED

	local initialDrawCount = 50 -- The first chunk size of drawn Set Target commands without skipping any units.
	local maximumSkipCount = 32 -- The maximum amount of units to skip in one draw chunk, after the first chunk.

	---@class UnitSetTargetDrawInfo
	---@field targets (number|boolean)[] A rolled array, repeating: <isUserTarget, targetXorID, targetY, targetZ>.
	---@field currentIndex integer The target index (not array position) of the current target (default = `1`).

	local next = next
	local ensureTable = table.ensureTable
	local math_min = math.min

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

	local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET

	local myAllyTeam = spGetMyAllyTeamID()
	local myTeam = spGetMyTeamID()
	local mySpec, fullview = spGetSpectatingState()

	local lineWidth = 1.4
	local queueColour = { 1, 0.75, 0, 0.3 }
	local commandColour = { 1, 0.5, 0, 0.3 }

	local drawAllTargets = {}
	local drawTarget = {}
	local targetList = {} ---@type table<integer, UnitSetTargetDrawInfo>

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

	local function handleTargetListEvent(_, unitID, index, userTarget, targetA, targetB, targetC)
		local unitTargetList = ensureTable(targetList, unitID)
		local targets = ensureTable(unitTargetList, "targets")
		local length = #targets
		if index * 4 > length then
			index = length / 4 + 1
		end
		local offset = (index - 1) * 4 + 1
		if targetA == nil then
			for i = offset, length do
				targets[i] = nil
			end
			return
		end
		targets[offset] = userTarget
		targets[offset + 1] = targetA
		targets[offset + 2] = targetB or -1
		targets[offset + 3] = targetC or -1
	end

	local function handleTargetListBatchedEvent(_, unitID, count, data)
		local unitTargetList = ensureTable(targetList, unitID)
		local targets = ensureTable(unitTargetList, "targets")
		for i = 1, 1 + (count - 1) * 5 do
			local offset = data[i]
			targets[offset]     = data[offset + 1] -- userTarget
			targets[offset + 1] = data[offset + 2] -- targetA
			targets[offset + 2] = data[offset + 3] -- targetB
			targets[offset + 3] = data[offset + 4] -- targetC
		end
	end

	local function handleTargetIndexEvent(_, unitID, index)
		if targetList[unitID] then
			targetList[unitID].currentIndex = index
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

	local unitIconsDrawn = {}
	local function drawUnitTarget(cacheKey, x, y, z)
		glVertex(x, y, z)
		if not unitIconsDrawn[cacheKey] then
			-- avoid sending WorldIcons to engine at the same unit/location
			spAddWorldIcon(CMD_UNIT_SET_TARGET, x, y, z)
			unitIconsDrawn[cacheKey] = true
		end
	end

	local function drawTargetCommand(targetA, targetB, targetC)
		if targetB == -1 and targetC == -1 then
			if spValidUnitID(targetA) then
				local _, _, _, x2, y2, z2 = spGetUnitPosition(targetA, false, true)
				drawUnitTarget(-targetA, x2, y2, z2)
			end
		else
			drawUnitTarget(targetA+targetB+targetC, targetA, targetB, targetC)
		end
	end

	local function drawCurrentTarget(unitID, unitData)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		local offset = (unitData.currentIndex - 1) * 4 + 1
		local targets = unitData.targets
		if targets[offset] then
			drawTargetCommand(targets[offset + 1], targets[offset + 2], targets[offset + 3])
		end
	end

	local function drawTargetQueue(unitID, unitData)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		local targets = unitData.targets
		for offset = 1, #targets, 4 do
			if targets[offset] then
				drawTargetCommand(targets[offset + 1], targets[offset + 2], targets[offset + 3])
			end
		end
	end

	local function drawDecorations()
		local init = false
		local skipChunkSize, skipChunkLeft = 4, initialDrawCount
		local skipSize, skipLeft = 0, 0
		for unitID, unitData in next, targetList do
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
					if unitData.currentIndex then
						glColor(commandColour)
						glBeginEnd(GL_LINES, drawCurrentTarget, unitID, unitData, myTeam, myAllyTeam)
					end
					-- We can use a gradual backoff to skip drawing decorations after very high counts.
					skipChunkLeft = skipChunkLeft - 1
					if skipChunkLeft == 0 then
						skipChunkLeft = skipChunkSize
						skipSize = math_min(maximumSkipCount, 2 * (skipSize > 0 and skipSize or 1))
					end
					skipLeft = skipSize
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
		spSetCustomCommandDrawData(GameCMD.UNIT_SET_TARGET, "settarget", queueColour, true)
		spSetCustomCommandDrawData(GameCMD.UNIT_SET_TARGET_NO_GROUND, "settargetrectangle", queueColour, true)
		spSetCustomCommandDrawData(GameCMD.UNIT_SET_TARGET_RECTANGLE, "settargetnoground", queueColour, true)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("targetdrawteam")
		gadgetHandler:RemoveChatAction("targetdrawunit")
		gadgetHandler:RemoveSyncAction("targetList")
		gadgetHandler:RemoveSyncAction("targetListBatched")
		gadgetHandler:RemoveSyncAction("targetIndex")
		gadgetHandler:RemoveSyncAction("failCommand")
	end

	function gadget:PlayerChanged(playerID)
		myAllyTeam = spGetMyAllyTeamID()
		myTeam = spGetMyTeamID()
		mySpec, fullview = spGetSpectatingState()
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

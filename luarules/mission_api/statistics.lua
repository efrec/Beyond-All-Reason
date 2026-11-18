---
--- Statistics engine for the Mission API.
---
--- Owns the shared per-trigger counting for the statistics condition types
--- (TotalUnitsLost/Built/Killed/Captured, UnitsOwned) and bridges those events
--- to managed objectives.
---
--- Trigger activation and iteration belong to the triggers gadget, so they are
--- injected via Init() rather than imported.
---

local statisticsTriggerCounts = {}
local processTriggersOfType, activateTrigger

-- The triggers that count a unit name, per condition type, rebuilt after a variable rewrites a parameter.
local triggersByUnitName = {}
local indexedParameterVersion
local NO_TRIGGERS = {}

-- What counts by name reached, in the order counted, until ActivateHeldTriggers.
local heldReactions = {} ---@type table[]
local heldTriggerIDs = {} ---@type table<table, string>

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger = dependencies.activateTrigger
	triggersByUnitName = {}
end

-- quantity > 0: reached each time the count crosses a milestone (quantity, 2*quantity, ...).
-- quantity == 0 is a special case: reached only when the count is 0.
local function hasReachedQuantity(trigger, triggerID)
	local quantity = trigger.parameters.quantity
	if quantity > 0 then
		return statisticsTriggerCounts[triggerID] >= (trigger.repeatCount + 1) * quantity
	end
	return quantity == 0 and statisticsTriggerCounts[triggerID] == 0
end

local function updateTriggerCount(trigger, triggerID, direction)
	statisticsTriggerCounts[triggerID] = (statisticsTriggerCounts[triggerID] or 0) + direction

	if (direction > 0 or trigger.parameters.quantity == 0) and hasReachedQuantity(trigger, triggerID) then
		activateTrigger(trigger)
	end
end

local function triggersCountingUnitName(conditionType, unitName)
	local parameterVersion = GG["MissionAPI"].parameterVersion
	if parameterVersion ~= indexedParameterVersion then
		triggersByUnitName = {}
		indexedParameterVersion = parameterVersion
	end

	local byUnitName = triggersByUnitName[conditionType]
	if byUnitName == nil then
		byUnitName = {}
		processTriggersOfType(conditionType, function(trigger, triggerID)
			local countedName = trigger.parameters.unitName
			if countedName then
				local counting = byUnitName[countedName]
				if counting == nil then
					counting = {}
					byUnitName[countedName] = counting
				end
				counting[#counting + 1] = { trigger = trigger, triggerID = triggerID }
			end
		end)
		triggersByUnitName[conditionType] = byUnitName
	end
	return byUnitName[unitName] or NO_TRIGGERS
end

local function updateUnitStatistics(conditionType, teamID, unitDefName, unitNames, direction)
	unitNames = unitNames or {}

	processTriggersOfType(conditionType, function(trigger, triggerID)
		if teamID ~= trigger.parameters.teamName then
			return
		end
		if trigger.parameters.unitDefName and unitDefName ~= trigger.parameters.unitDefName then
			return
		end
		if trigger.parameters.unitName and not unitNames[trigger.parameters.unitName] then
			return
		end

		updateTriggerCount(trigger, triggerID, direction)
	end)

	-- Update managed objectives:
	for _, managedObjective in ipairs(GG["MissionAPI"].ManagedObjectives[conditionType] or {}) do
		GG["MissionAPI"].Modules.Objectives.UpdateObjectiveProgress(
			managedObjective.objectiveID,
			teamID,
			unitDefName,
			unitNames,
			direction,
			managedObjective
		)
	end
end

--- Counts a unit that gained or lost one name while it stays on its team. Nothing is activated until
--- ActivateHeldTriggers.
local function updateUnitNameCount(conditionType, teamID, unitDefName, unitName, direction)
	local counting = triggersCountingUnitName(conditionType, unitName)
	for i = 1, #counting do
		local trigger = counting[i].trigger
		local parameters = trigger.parameters
		if
			parameters.teamName == teamID
			and (parameters.unitDefName == nil or parameters.unitDefName == unitDefName)
		then
			local triggerID = counting[i].triggerID
			statisticsTriggerCounts[triggerID] = (statisticsTriggerCounts[triggerID] or 0) + direction
			if
				(direction > 0 or parameters.quantity == 0)
				and heldTriggerIDs[trigger] == nil
				and hasReachedQuantity(trigger, triggerID)
			then
				heldTriggerIDs[trigger] = triggerID
				heldReactions[#heldReactions + 1] = trigger
			end
		end
	end

	local managedObjectives = GG["MissionAPI"].ManagedObjectives[conditionType]
	if managedObjectives == nil then
		return
	end
	for _, managedObjective in ipairs(managedObjectives) do
		if managedObjective.parameters.unitName == unitName then
			heldReactions[#heldReactions + 1] = {
				managedObjective = managedObjective,
				teamID = teamID,
				unitDefName = unitDefName,
				unitName = unitName,
				direction = direction,
			}
		end
	end
end

--- Activates the triggers that counts by name reached, and updates their managed objectives, in the order
--- they were counted. A trigger is activated once for each milestone its count passed, and not at all
--- when its count moved away again before this.
local function activateHeldTriggers()
	if heldReactions[1] == nil then
		return
	end
	-- An activation's actions can count by name again, so they get a list of their own.
	local reactions, triggerIDs = heldReactions, heldTriggerIDs
	heldReactions, heldTriggerIDs = {}, {}

	for i = 1, #reactions do
		local reaction = reactions[i]
		local triggerID = triggerIDs[reaction]
		if triggerID == nil then
			GG["MissionAPI"].Modules.Objectives.UpdateObjectiveProgress(
				reaction.managedObjective.objectiveID,
				reaction.teamID,
				reaction.unitDefName,
				{ [reaction.unitName] = true },
				reaction.direction,
				reaction.managedObjective
			)
		elseif reaction.parameters.quantity == 0 then
			if hasReachedQuantity(reaction, triggerID) then
				activateTrigger(reaction)
			end
		else
			-- A refused activation leaves the milestone where it was.
			while hasReachedQuantity(reaction, triggerID) and activateTrigger(reaction) do
			end
		end
	end
end

local function increment(conditionType, teamID, unitDefName, unitNames)
	updateUnitStatistics(conditionType, teamID, unitDefName, unitNames, 1)
end

local function decrement(conditionType, teamID, unitDefName, unitNames)
	updateUnitStatistics(conditionType, teamID, unitDefName, unitNames, -1)
end

return {
	Init = init,
	Increment = increment,
	Decrement = decrement,
	UpdateUnitNameCount = updateUnitNameCount,
	ActivateHeldTriggers = activateHeldTriggers,
}

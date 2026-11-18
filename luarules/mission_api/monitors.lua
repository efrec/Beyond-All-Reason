---
--- Monitors: named sets of units that keep themselves current. A unit is a member while it is
--- finished, matches the monitor's unit filter, and matches none of its exceptions. Members
--- hold the monitor's name as a unit name, which only the monitor gives or takes.
---
--- The triggers gadget calls OnUnitFinished, and OnUnitAdded at the start of MetaUnitAdded, before
--- it dispatches that call-in's triggers, so they see the membership after the change. A member
--- keeps the name through the dispatch of UnitDestroyed and of UnitTaken, so UnitKilled and
--- UnitCaptured see the membership the unit had.
--- The gadget calls OnUnitRemoved after MetaUnitRemoved's dispatch and before its Decrement, and
--- ReleaseUnitCount after MetaUnitAdded's dispatch and before its Increment. Between the two, the
--- MetaUnit call-ins count the unit, so a change made then is counted once.
---

local monitors = GG["MissionAPI"].monitors
local tracking = GG["MissionAPI"].Modules.Tracking
local unitQuery = GG["MissionAPI"].Modules.UnitQuery
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs
local trackedUnitNames = GG["MissionAPI"].trackedUnitNames

local spGetAllUnits = Spring.GetAllUnits
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitTeam = Spring.GetUnitTeam

local trackMonitorUnit = tracking.TrackMonitorUnit
local untrackMonitorUnit = tracking.UntrackMonitorUnit

local statistics ---@type table
local unitsOwnedType

local NO_UNIT_DEF_ID = -1

-- All of these are replaced, never changed in place, when a monitor is added or removed.
local monitorList = {} ---@type table[]
local monitorsByRuleUnitName = {}
local monitorsByTeamAndDef = {}
local monitorsLeftAndJoined = {}

-- The units holding a name that some monitor's rule asks about.
local ruleNamedUnits = {}

-- The units that the MetaUnit call-ins count: one leaving its team alive, mapped to that team, until its
-- MetaUnitAdded has been counted, and a dying one, once MetaUnitRemoved has uncounted it.
local uncountedUnits = {}

local function compileRule(filter, except)
	local unitDef = filter.unitDefName and UnitDefNames[filter.unitDefName]
	local rule = {
		teamID = filter.teamName,
		unitDefID = filter.unitDefName and (unitDef and unitDef.id or NO_UNIT_DEF_ID),
		unitName = filter.unitName,
		exceptsEveryUnit = false,
		exceptUnitDefIDs = {},
		exceptTeamIDs = {},
		exceptTeamDefs = {},
		exceptUnitNames = {},
		exceptNamedFilters = {},
	}
	for _, exception in ipairs(except) do
		local exceptedDef = exception.unitDefName and UnitDefNames[exception.unitDefName]
		if exception.unitDefName and not exceptedDef then
			-- Matches no unit.
		elseif exception.unitName then
			if exception.unitDefName or exception.teamName then
				rule.exceptNamedFilters[#rule.exceptNamedFilters + 1] = exception
			else
				rule.exceptUnitNames[#rule.exceptUnitNames + 1] = exception.unitName
			end
		elseif exceptedDef and exception.teamName then
			rule.exceptTeamDefs[#rule.exceptTeamDefs + 1] = { teamID = exception.teamName, unitDefID = exceptedDef.id }
		elseif exceptedDef then
			rule.exceptUnitDefIDs[exceptedDef.id] = true
		elseif exception.teamName then
			rule.exceptTeamIDs[exception.teamName] = true
		else
			rule.exceptsEveryUnit = true
		end
	end
	return rule
end

local function matchesTeamAndDef(rule, teamID, unitDefID)
	if (rule.teamID ~= nil and rule.teamID ~= teamID) or (rule.unitDefID ~= nil and rule.unitDefID ~= unitDefID) then
		return false
	end
	if rule.exceptsEveryUnit or rule.exceptUnitDefIDs[unitDefID] or rule.exceptTeamIDs[teamID] then
		return false
	end
	local exceptTeamDefs = rule.exceptTeamDefs
	for i = 1, #exceptTeamDefs do
		if exceptTeamDefs[i].teamID == teamID and exceptTeamDefs[i].unitDefID == unitDefID then
			return false
		end
	end
	return true
end

local function matchesNames(rule, unitID, unitDefID, teamID)
	local doesUnitHoldName = unitQuery.DoesUnitHoldName
	if rule.unitName ~= nil and not doesUnitHoldName(unitID, rule.unitName) then
		return false
	end
	local exceptUnitNames = rule.exceptUnitNames
	for i = 1, #exceptUnitNames do
		if doesUnitHoldName(unitID, exceptUnitNames[i]) then
			return false
		end
	end
	local exceptNamedFilters = rule.exceptNamedFilters
	for i = 1, #exceptNamedFilters do
		if unitQuery.DoesUnitMatchFilter(unitID, exceptNamedFilters[i], unitDefID, teamID) then
			return false
		end
	end
	return true
end

-- The monitors a finished unit of this team and def belongs to, when it holds no name a rule asks about.
local function monitorsOfTeamAndDef(teamID, unitDefID)
	local byDef = monitorsByTeamAndDef[teamID]
	if byDef == nil then
		byDef = {}
		monitorsByTeamAndDef[teamID] = byDef
	end
	local list = byDef[unitDefID]
	if list == nil then
		list = {}
		for i = 1, #monitorList do
			local rule = monitorList[i].rule
			if rule.unitName == nil and matchesTeamAndDef(rule, teamID, unitDefID) then
				list[#list + 1] = monitorList[i]
			end
		end
		byDef[unitDefID] = list
	end
	return list
end

local function monitorsLeftAndJoinedBy(oldTeamID, newTeamID, unitDefID)
	local byNewTeam = monitorsLeftAndJoined[oldTeamID]
	if byNewTeam == nil then
		byNewTeam = {}
		monitorsLeftAndJoined[oldTeamID] = byNewTeam
	end
	local byDef = byNewTeam[newTeamID]
	if byDef == nil then
		byDef = {}
		byNewTeam[newTeamID] = byDef
	end
	local change = byDef[unitDefID]
	if change == nil then
		local before = monitorsOfTeamAndDef(oldTeamID, unitDefID)
		local after = monitorsOfTeamAndDef(newTeamID, unitDefID)
		local isBefore, isAfter = {}, {}
		for i = 1, #before do
			isBefore[before[i]] = true
		end
		for i = 1, #after do
			isAfter[after[i]] = true
		end
		change = { left = {}, joined = {} }
		for i = 1, #before do
			if not isAfter[before[i]] then
				change.left[#change.left + 1] = before[i]
			end
		end
		for i = 1, #after do
			if not isBefore[after[i]] then
				change.joined[#change.joined + 1] = after[i]
			end
		end
		byDef[unitDefID] = change
	end
	return change
end

local function holdsRuleName(unitID)
	local names = trackedUnitNames[unitID]
	if names ~= nil then
		for name in pairs(names) do
			if monitorsByRuleUnitName[name] then
				return true
			end
		end
	end
	return false
end

local function isRuleNamed(unitID)
	if ruleNamedUnits[unitID] then
		return true
	end
	local mapi = GG["MissionAPI"]
	return unitID == mapi.unitIDBeingSpawned and monitorsByRuleUnitName[mapi.nameOfUnitBeingSpawned] ~= nil
end

-- Keeps the monitors in the order they were first added, so every pass visits them in the same order.
local function indexMonitors(changedUnitName)
	local list, byRuleUnitName = {}, {}
	local isListed = false
	for i = 1, #monitorList do
		local unitName = monitorList[i].unitName
		if monitors[unitName] ~= nil then
			list[#list + 1] = monitors[unitName]
		end
		isListed = isListed or unitName == changedUnitName
	end
	if not isListed and monitors[changedUnitName] ~= nil then
		list[#list + 1] = monitors[changedUnitName]
	end

	local namedUnits = {}
	for _, monitor in ipairs(list) do
		for ruleUnitName in pairs(monitor.ruleUnitNames) do
			local named = byRuleUnitName[ruleUnitName]
			if named == nil then
				named = {}
				byRuleUnitName[ruleUnitName] = named
				for unitID in pairs(trackedUnitIDs[ruleUnitName] or {}) do
					namedUnits[unitID] = true
				end
			end
			named[#named + 1] = monitor
		end
	end

	monitorList, monitorsByRuleUnitName = list, byRuleUnitName
	monitorsByTeamAndDef, monitorsLeftAndJoined = {}, {}
	ruleNamedUnits = namedUnits
end

local function countMembershipChange(unitName, unitDefID, teamID, direction)
	statistics.UpdateUnitNameCount(unitsOwnedType, teamID, UnitDefs[unitDefID].name, unitName, direction)
end

local function settleMembership(monitor, unitID, unitDefID, teamID, isFinished)
	local rule = monitor.rule
	local isMember = isFinished
		and matchesTeamAndDef(rule, teamID, unitDefID)
		and matchesNames(rule, unitID, unitDefID, teamID)

	local unitName = monitor.unitName
	if isMember then
		if trackMonitorUnit(unitName, unitID) and not uncountedUnits[unitID] then
			countMembershipChange(unitName, unitDefID, teamID, 1)
		end
	elseif untrackMonitorUnit(unitName, unitID) and not uncountedUnits[unitID] then
		countMembershipChange(unitName, unitDefID, teamID, -1)
	end
end

local function settleUnitInMonitors(list, unitID, unitDefID, teamID, isFinished)
	for i = 1, #list do
		settleMembership(list[i], unitID, unitDefID, teamID, isFinished)
	end
end

local function onUnitNameChanged(unitID, name)
	local named = monitorsByRuleUnitName[name]
	if named == nil then
		return
	end
	ruleNamedUnits[unitID] = holdsRuleName(unitID) or nil
	if spGetUnitIsDead(unitID) ~= false then
		return
	end

	local isFinished = not spGetUnitIsBeingBuilt(unitID)
	settleUnitInMonitors(named, unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID), isFinished)
	statistics.ActivateHeldTriggers()
end

local function rejectsMonitor(unitName, ruleUnitNames)
	for ruleUnitName in pairs(ruleUnitNames) do
		if ruleUnitName == unitName or monitors[ruleUnitName] then
			return true
		end
	end
	for _, otherMonitor in ipairs(monitorsByRuleUnitName[unitName] or {}) do
		if otherMonitor.unitName ~= unitName then
			return true
		end
	end
	return monitors[unitName] == nil and not tracking.IsUnitNameUntracked(unitName)
end

----------------------------------------------------------------
--- Exported functions:
----------------------------------------------------------------

local function init(dependencies)
	statistics = dependencies.statistics
	unitsOwnedType = GG["MissionAPI"].ConditionDefinitions.Types.UnitsOwned
	tracking.SetUnitNameChangedHandler(onUnitNameChanged)
	monitorList = {}
	indexMonitors()
end

---Adding a monitor under a name already in use replaces its rule. A monitor whose rule names a monitor,
---whose name a monitor's rule uses, or whose name units already hold from elsewhere is not added.
local function addMonitor(unitName, filter, except)
	except = except or {}
	local ruleUnitNames = {}
	if filter.unitName then
		ruleUnitNames[filter.unitName] = true
	end
	for _, exception in ipairs(except) do
		if exception.unitName then
			ruleUnitNames[exception.unitName] = true
		end
	end
	if rejectsMonitor(unitName, ruleUnitNames) then
		return
	end

	local isReplacing = monitors[unitName] ~= nil
	local monitor = {
		unitName = unitName,
		rule = compileRule(filter, except),
		ruleUnitNames = ruleUnitNames,
	}
	monitors[unitName] = monitor
	indexMonitors(unitName)

	-- A replaced rule's old members can be on any team.
	local unitIDs
	if isReplacing then
		unitIDs = spGetAllUnits()
	elseif filter.unitName then
		unitIDs = unitQuery.MatchingUnits(filter.unitName)
		if filter.unitName == GG["MissionAPI"].nameOfUnitBeingSpawned then
			unitIDs[#unitIDs + 1] = GG["MissionAPI"].unitIDBeingSpawned
		end
	elseif filter.teamName then
		unitIDs = spGetTeamUnits(filter.teamName)
	else
		unitIDs = spGetAllUnits()
	end
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		-- A unit that died this frame is still listed, and was uncounted with its names already.
		if spGetUnitIsDead(unitID) == false then
			local isFinished = not spGetUnitIsBeingBuilt(unitID)
			settleMembership(monitor, unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID), isFinished)
		end
	end
	statistics.ActivateHeldTriggers()
end

local function removeMonitor(unitName)
	if monitors[unitName] == nil then
		return
	end
	monitors[unitName] = nil
	indexMonitors(unitName)

	local unitIDs = unitQuery.MatchingUnits(unitName)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		untrackMonitorUnit(unitName, unitID)
		if not uncountedUnits[unitID] then
			countMembershipChange(unitName, spGetUnitDefID(unitID), spGetUnitTeam(unitID), -1)
		end
	end
	statistics.ActivateHeldTriggers()
end

local function onUnitFinished(unitID, unitDefID)
	-- A gadget that hears of the unit first can have destroyed it or given it away.
	if monitorList[1] == nil or spGetUnitIsDead(unitID) ~= false then
		return
	end
	local teamID = spGetUnitTeam(unitID)
	if isRuleNamed(unitID) then
		settleUnitInMonitors(monitorList, unitID, unitDefID, teamID, true)
		statistics.ActivateHeldTriggers()
		return
	end

	local joined = monitorsOfTeamAndDef(teamID, unitDefID)
	if joined[1] == nil then
		return
	end
	local isCounted = not uncountedUnits[unitID]
	for i = 1, #joined do
		local unitName = joined[i].unitName
		if trackMonitorUnit(unitName, unitID) and isCounted then
			countMembershipChange(unitName, unitDefID, teamID, 1)
		end
	end
	statistics.ActivateHeldTriggers()
end

local function onUnitReverseBuilt(unitID, unitDefID)
	if monitorList[1] == nil or spGetUnitIsDead(unitID) ~= false then
		return
	end
	local teamID = spGetUnitTeam(unitID)
	if isRuleNamed(unitID) then
		settleUnitInMonitors(monitorList, unitID, unitDefID, teamID, false)
		statistics.ActivateHeldTriggers()
		return
	end

	local left = monitorsOfTeamAndDef(teamID, unitDefID)
	if left[1] == nil then
		return
	end
	local isCounted = not uncountedUnits[unitID]
	for i = 1, #left do
		local unitName = left[i].unitName
		if untrackMonitorUnit(unitName, unitID) and isCounted then
			countMembershipChange(unitName, unitDefID, teamID, -1)
		end
	end
	statistics.ActivateHeldTriggers()
end

---Holds back counting the joins and leaves of a unit that leaves its team, since MetaUnitRemoved uncounts
---it with the names it holds then: until ReleaseUnitCount for one that lives, for good for one that dies.
local function onUnitRemoved(unitID, unitDefID, teamID)
	uncountedUnits[unitID] = spGetUnitIsDead(unitID) == false and teamID or true
end

---Settles a unit given to a new team, and holds back counting its joins and leaves until
---ReleaseUnitCount, since MetaUnitAdded counts the unit with every name it holds once its triggers have run.
local function onUnitAdded(unitID, unitDefID, teamID)
	-- Still held from MetaUnitRemoved, so the unit is changing team. One killed in UnitTaken's dispatch stays out.
	local oldTeamID = uncountedUnits[unitID]
	uncountedUnits[unitID] = true
	if not oldTeamID or oldTeamID == true or monitorList[1] == nil or spGetUnitIsDead(unitID) ~= false then
		return
	end

	local isFinished = not spGetUnitIsBeingBuilt(unitID)
	if isRuleNamed(unitID) then
		settleUnitInMonitors(monitorList, unitID, unitDefID, teamID, isFinished)
	elseif isFinished then
		-- Joins come before leaves, so the unit keeps its table of names throughout.
		local change = monitorsLeftAndJoinedBy(oldTeamID, teamID, unitDefID)
		local joined, left = change.joined, change.left
		for i = 1, #joined do
			trackMonitorUnit(joined[i].unitName, unitID)
		end
		for i = 1, #left do
			untrackMonitorUnit(left[i].unitName, unitID)
		end
	end
end

local function releaseUnitCount(unitID)
	uncountedUnits[unitID] = nil
end

local function onUnitDestroyed(unitID)
	ruleNamedUnits[unitID] = nil
	uncountedUnits[unitID] = nil
end

return {
	Init = init,
	AddMonitor = addMonitor,
	RemoveMonitor = removeMonitor,
	OnUnitFinished = onUnitFinished,
	OnUnitReverseBuilt = onUnitReverseBuilt,
	OnUnitRemoved = onUnitRemoved,
	OnUnitAdded = onUnitAdded,
	ReleaseUnitCount = releaseUnitCount,
	OnUnitDestroyed = onUnitDestroyed,
}

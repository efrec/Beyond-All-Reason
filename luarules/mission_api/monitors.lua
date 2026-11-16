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

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitTeam = Spring.GetUnitTeam

local statistics
local unitsOwnedType

local uncountedUnits = {} ---@type table<integer, true?>

local function matchesRule(monitor, unitID)
	local doesUnitMatchFilter = unitQuery.DoesUnitMatchFilter
	if not doesUnitMatchFilter(unitID, monitor.filter) then
		return false
	end

	local except = monitor.except
	for i = 1, #except do
		if doesUnitMatchFilter(unitID, except[i]) then
			return false
		end
	end
	return true
end

---@return integer direction 1 when the unit joined, -1 when it left, and 0 when its membership held
local function settleMembership(monitor, unitID, isFinished)
	local isMember = tracking.DoesUnitHaveName(unitID, monitor.unitName)
	local shouldBeMember = isFinished and matchesRule(monitor, unitID)
	if shouldBeMember == isMember then
		return 0
	end

	if shouldBeMember then
		tracking.TrackUnit(monitor.unitName, unitID)
		return 1
	end
	tracking.UntrackUnit(monitor.unitName, unitID)
	return -1
end

-- The team and unit def are read now, as an activation counted before this one may transfer the unit.
local function recordMembershipChange(changes, unitName, unitID, direction)
	if direction == 0 or uncountedUnits[unitID] then
		return
	end

	changes[#changes + 1] = {
		unitName = unitName,
		teamID = spGetUnitTeam(unitID),
		unitDefName = UnitDefs[spGetUnitDefID(unitID)].name,
		direction = direction,
	}
end

-- Counting can activate triggers whose actions change units, so it runs once membership is settled.
local function countMembershipChanges(changes)
	for i = 1, #changes do
		local change = changes[i]
		statistics.UpdateUnitNameCount(
			unitsOwnedType,
			change.teamID,
			change.unitDefName,
			change.unitName,
			change.direction
		)
	end
end

local function settleUnitInEveryMonitor(unitID, isFinished)
	local changes = {}
	for unitName, monitor in pairs(monitors) do
		recordMembershipChange(changes, unitName, unitID, settleMembership(monitor, unitID, isFinished))
	end
	countMembershipChanges(changes)
end

-- A dying unit was uncounted with its names already, and loses them all once its death call-ins end.
local function onUnitNameChanged(unitID, name)
	if spGetUnitIsDead(unitID) ~= false then
		return
	end

	local changes
	for unitName, monitor in pairs(monitors) do
		if monitor.ruleUnitNames[name] then
			changes = changes or {}
			local isFinished = not spGetUnitIsBeingBuilt(unitID)
			recordMembershipChange(changes, unitName, unitID, settleMembership(monitor, unitID, isFinished))
		end
	end
	if changes then
		countMembershipChanges(changes)
	end
end

----------------------------------------------------------------
--- Exported functions:
----------------------------------------------------------------

local function init(dependencies)
	statistics = dependencies.statistics
	unitsOwnedType = GG["MissionAPI"].ConditionDefinitions.Types.UnitsOwned
	tracking.SetUnitNameChangedHandler(onUnitNameChanged)
end

---Adding a monitor under a name already in use replaces its rule.
local function addMonitor(unitName, filter, except)
	except = except or {}
	local ruleUnitNames = {}
	if filter.unitName then
		ruleUnitNames[filter.unitName] = true
	end
	for i = 1, #except do
		if except[i].unitName then
			ruleUnitNames[except[i].unitName] = true
		end
	end

	local monitor = { unitName = unitName, filter = filter, except = except, ruleUnitNames = ruleUnitNames }
	monitors[unitName] = monitor

	local changes = {}
	local unitIDs = spGetAllUnits()
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		-- A unit that died this frame is still listed, and was uncounted with its names already.
		if spGetUnitIsDead(unitID) == false then
			local isFinished = not spGetUnitIsBeingBuilt(unitID)
			recordMembershipChange(changes, unitName, unitID, settleMembership(monitor, unitID, isFinished))
		end
	end
	countMembershipChanges(changes)
end

local function removeMonitor(unitName)
	if monitors[unitName] == nil then
		return
	end
	monitors[unitName] = nil

	local changes = {}
	local unitIDs = unitQuery.MatchingUnits(unitName)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		tracking.UntrackUnit(unitName, unitID)
		-- A dying member was uncounted with its names already.
		if spGetUnitIsDead(unitID) == false then
			recordMembershipChange(changes, unitName, unitID, -1)
		end
	end
	countMembershipChanges(changes)
end

local function onUnitFinished(unitID)
	if next(monitors) ~= nil then
		settleUnitInEveryMonitor(unitID, true)
	end
end

local function onUnitReverseBuilt(unitID)
	if next(monitors) ~= nil then
		settleUnitInEveryMonitor(unitID, false)
	end
end

---Holds back counting the joins and leaves of a unit that leaves its team alive, until ReleaseUnitCount,
---since MetaUnitRemoved uncounts it with the names it holds then.
local function onUnitRemoved(unitID)
	uncountedUnits[unitID] = spGetUnitIsDead(unitID) == false or nil
end

---Settles a unit given to a new team, and holds back counting its joins and leaves until
---ReleaseUnitCount, since MetaUnitAdded counts the unit with every name it holds once its triggers have run.
local function onUnitAdded(unitID)
	-- Still held from MetaUnitRemoved, so the unit is changing team.
	if uncountedUnits[unitID] then
		local isFinished = not spGetUnitIsBeingBuilt(unitID)
		for _, monitor in pairs(monitors) do
			settleMembership(monitor, unitID, isFinished)
		end
	end
	uncountedUnits[unitID] = true
end

local function releaseUnitCount(unitID)
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
}

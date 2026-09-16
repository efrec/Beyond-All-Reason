local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Shared Team API",
		desc = "Attributes each unit of a shared team to one player, for the widgets that automate it",
		author = "BAR Team",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -math.huge,
		enabled = true,
		hidden = true, -- other widgets need this one, so it is not the player's to toggle
	}
end

local ROSTER_POLL_FRAMES = 30

local spGetGameFrame = Spring.GetGameFrame
local spGetLocalPlayerID = Spring.GetLocalPlayerID
local spGetLocalTeamID = Spring.GetLocalTeamID
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetPlayerList = Spring.GetPlayerList
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitTeam = Spring.GetUnitTeam

local SharedTeam = assert(BAR.Utilities.SharedTeam)
local feed = SharedTeam.OpenFeed()

if not feed then
	Spring.Log("Shared Team API", LOG.ERROR, "another consumer already holds the shared team feed")
	return false
end

local localPlayerID = spGetLocalPlayerID()
local localTeamID = spGetLocalTeamID()

local localPlayerSelection = {}
local addedBuffer = {}
local removedBuffer = {}

local function refreshRoster()
	local assigned = spGetPlayerList(localTeamID) or {}
	local players = {}
	local playerCount = 0

	for i = 1, #assigned do
		local playerID = assigned[i]
		local _, isInGame, isSpec = spGetPlayerInfo(playerID, false)
		if isInGame and not isSpec then
			playerCount = playerCount + 1
			players[playerCount] = playerID
		end
	end

	table.sort(players)
	feed.OnRoster(localTeamID, players)
end

local function refreshPerspective()
	localPlayerID = spGetLocalPlayerID()
	localTeamID = spGetLocalTeamID()
	feed.SetPerspective(localPlayerID, localTeamID)
	refreshRoster()
end

local function adoptExistingUnits()
	local units = spGetTeamUnits(localTeamID) or {}
	for i = 1, #units do
		local unitID = units[i]
		feed.OnUnitCreated(unitID, localTeamID, nil)
		local owner = spGetUnitRulesParam(unitID, SharedTeam.OWNER_RULES_PARAM)
		if owner and owner >= 0 then
			feed.OnUnitOwner(unitID, localTeamID, owner)
		end
	end
end

---Selection broadcasts are throttled, so waiting would age results even longer.
local function trackLocalSelection()
	local selected = spGetSelectedUnits()
	local addedCount, removedCount = 0, 0
	local present = {}

	for i = 1, #selected do
		local unitID = selected[i]
		present[unitID] = true
		if not localPlayerSelection[unitID] then
			addedCount = addedCount + 1
			addedBuffer[addedCount] = unitID
		end
	end

	for unitID in pairs(localPlayerSelection) do
		if not present[unitID] then
			removedCount = removedCount + 1
			removedBuffer[removedCount] = unitID
		end
	end

	if addedCount == 0 and removedCount == 0 then
		return
	end

	for i = addedCount + 1, #addedBuffer do
		addedBuffer[i] = nil
	end
	for i = removedCount + 1, #removedBuffer do
		removedBuffer[i] = nil
	end

	localPlayerSelection = present
	feed.OnSelectionChanged(localPlayerID, addedBuffer, removedBuffer)
end

function widget:Initialize()
	feed.OnGameFrame(spGetGameFrame())
	refreshPerspective()
	adoptExistingUnits()
	trackLocalSelection()
end

function widget:Shutdown()
	if feed then
		feed.Close()
		feed = nil
	end
end

local onGameFrame = feed.OnGameFrame
function widget:GameFrame(frame)
	onGameFrame(frame)

	---PlayerChanged does not always arrive, so the roster is polled as well.
	if frame % ROSTER_POLL_FRAMES == 0 then
		refreshRoster()
	end
end

function widget:PlayerChanged(playerID)
	refreshPerspective()
end

function widget:SelectionChanged(selectedUnits)
	trackLocalSelection()
end

local onUnitCreated = feed.OnUnitCreated
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam == localTeamID then
		onUnitCreated(unitID, unitTeam, builderID)
	end
end

local onUnitDestroyed = feed.OnUnitDestroyed
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if unitTeam == localTeamID then
		onUnitDestroyed(unitID)
	end
end

local onUnitTransferred = feed.OnUnitTransferred
function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if oldTeam == localTeamID or newTeam == localTeamID then
		onUnitTransferred(unitID, newTeam)
	end
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if oldTeam == localTeamID or newTeam == localTeamID then
		onUnitTransferred(unitID, newTeam)
	end
end

local onUnitCommand = feed.OnUnitCommand
function widget:UnitCommand(
	unitID,
	unitDefID,
	unitTeam,
	cmdID,
	cmdParams,
	cmdOpts,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	if unitTeam == localTeamID then
		onUnitCommand(unitID, playerID, cmdID, cmdOpts, fromLua)
	end
end

local delta = table.new(1, 0) -- table is only read from

local onSelectionChanged = feed.OnSelectionChanged
function widget:SelectedUnitsAdd(playerID, unitID)
	if playerID ~= localPlayerID and spGetUnitTeam(unitID) == localTeamID then
		delta[1] = unitID
		onSelectionChanged(playerID, delta, nil)
	end
end

function widget:SelectedUnitsRemove(playerID, unitID)
	if playerID ~= localPlayerID then
		delta[1] = unitID
		onSelectionChanged(playerID, nil, delta)
	end
end

function widget:SelectedUnitsBatchUpdate(playerID, addUnits, addCount, removeUnits, removeCount)
	if playerID == localPlayerID then
		return
	end

	local added = {}
	local removed = {}
	for i = 1, addCount do
		local unitID = addUnits[i]
		if spGetUnitTeam(unitID) == localTeamID then
			added[#added + 1] = unitID
		end
	end
	for i = 1, removeCount do
		removed[i] = removeUnits[i]
	end

	onSelectionChanged(playerID, added, removed)
end

local onSelectionCleared = feed.OnSelectionCleared
function widget:SelectedUnitsClear(playerID)
	if playerID ~= localPlayerID then
		onSelectionCleared(playerID)
	end
end

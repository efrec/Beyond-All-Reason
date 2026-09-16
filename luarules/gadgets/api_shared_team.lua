local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Shared Team API",
		desc = "Attributes each unit of a shared team to one player, for gadgets and for late-loading widgets",
		author = "BAR Team",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true, -- should be self-disabling
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local ROSTER_POLL_FRAMES = 30

local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetPlayerList = Spring.GetPlayerList
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spSetUnitRulesParam = Spring.SetUnitRulesParam

local ALLIED_PARAM = { allied = true }

local SharedTeam = assert(BAR.Utilities.SharedTeam)
local feed = SharedTeam.OpenFeed()

if not feed then
	Spring.Log(gadget:GetInfo().name, LOG.ERROR, "another consumer already holds the shared team feed")
	gadgetHandler:RemoveGadget()
	return
end

local trackedTeams = {}

local function refreshRoster(teamID)
	local assigned = spGetPlayerList(teamID) or {}
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
	feed.OnRoster(teamID, players)
end

local function publishOwner(unitID, playerID)
	spSetUnitRulesParam(unitID, SharedTeam.OWNER_RULES_PARAM, playerID or -1, ALLIED_PARAM)
end

function gadget:Initialize()
	trackedTeams = spGetTeamList() or {}

	for i = 1, #trackedTeams do
		refreshRoster(trackedTeams[i])
	end

	for i = 1, #trackedTeams do
		local teamID = trackedTeams[i]
		if SharedTeam.IsShared(teamID) then
			local units = spGetTeamUnits(teamID) or {}
			for j = 1, #units do
				feed.OnUnitCreated(units[j], teamID, nil)
			end
		end
	end

	SharedTeam.Subscribe("owner", publishOwner)

	---Synced code has no local player, so remove methods that return no results.
	SharedTeam.IsLeadLocal = nil
	SharedTeam.GetUnitsToAutomate = nil
	SharedTeam.MayAutomate = nil

	GG.SharedTeam = SharedTeam
end

function gadget:Shutdown()
	SharedTeam.Unsubscribe("owner", publishOwner)
	GG.SharedTeam = nil
	if feed then
		feed.Close()
		feed = nil
	end
end

local onGameFrame = feed.OnGameFrame
function gadget:GameFrame(frame)
	onGameFrame(frame)

	---Synced code has no PlayerChanged, so the roster is polled instead.
	if frame % ROSTER_POLL_FRAMES == 0 then
		for i = 1, #trackedTeams do
			refreshRoster(trackedTeams[i])
		end
	end
end

local onUnitCreated = feed.OnUnitCreated
function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if SharedTeam.IsShared(unitTeam) then
		onUnitCreated(unitID, unitTeam, builderID)
	end
end

local onUnitDestroyed = feed.OnUnitDestroyed
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if SharedTeam.IsShared(unitTeam) then
		onUnitDestroyed(unitID)
	end
end

local onUnitTransferred = feed.OnUnitTransferred
function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if SharedTeam.IsShared(oldTeam) or SharedTeam.IsShared(newTeam) then
		onUnitTransferred(unitID, newTeam)
	end
end

local isShared = SharedTeam.IsShared
local onUnitCommand = feed.OnUnitCommand
function gadget:UnitCommand(
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
	if isShared(unitTeam) then
		onUnitCommand(unitID, playerID, cmdID, cmdOpts, fromLua)
	end
end

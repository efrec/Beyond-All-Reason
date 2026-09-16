--- sharedTeam.lua -------------------------------------------------------------
---
--- Nominally for quantum mode.
---
--- The module is a drop-in to widgets that need to know about player controls
--- outside the trivial (non-quantum) context where one player equals one team.
--- The exported functions reduce to pass-through / no-op outside quantum mode.
---
--- During quantum games, players need to know the following:
--- - who owns a unit
--- - who runs automations on a unit
--- - whether the player's command to a unit will be followed if issued
---
--- Unit ownership and automation are derived by each client independently and
--- must match; they are enforced in synchronous code with very few exceptions.
---
--- Clients run on luaui/widgets/api_shared_team.lua.
--- Games run a luarules/gadgets/api_shared_team.lua, as well.
---
--- Absent or failed code is also designed as a passthru to avoid locking games.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Requirements ----------------------------------------------------------------

if not CMD then
	return
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local RULESPARAM_OWNER = "sharedTeamOwner"

local COMMAND_LOCK_FRAMES = 30 * 30
local ROSTER_SETTLE_FRAMES = 30

---Preference widgets send these to newly built units from every client at once.
---Without checking them, the latest-arriving message would overwrite the others.
local STATE_COMMAND_NAMES = {
	"FIRE_STATE",
	"MOVE_STATE",
	"REPEAT",
	"TRAJECTORY",
	"ONOFF",
	"CLOAK",
	"IDLEMODE",
	"AUTOREPAIRLEVEL",
	"STOCKPILE",
}
local CUSTOM_STATE_COMMAND_NAMES = {
	"PRIORITY",
	"WANT_CLOAK",
	"CARRIER_SPAWN_ONOFF",
	"HOUND_WEAPON_TOGGLE",
	"SMART_TOGGLE",
	"USER_FIRESTATE",
}

--------------------------------------------------------------------------------
-- Module internals ------------------------------------------------------------

local bit_and = math.bit_and
local spGetTeamUnits = Spring.GetTeamUnits
local OPT_INTERNAL = CMD.OPT_INTERNAL

local isStateCommand = {}


local function resolveStateCommands()
	for i = 1, #STATE_COMMAND_NAMES do
		local cmdID = CMD[STATE_COMMAND_NAMES[i]]
		if cmdID then
			isStateCommand[cmdID] = true
		end
	end

	-- FIXME: GameCMD is config but is not available for code at loading time:
	local customCommands = Game.CustomCommands and Game.CustomCommands.GameCMD
	if not customCommands then
		return
	end

	for i = 1, #CUSTOM_STATE_COMMAND_NAMES do
		local cmdID = customCommands[CUSTOM_STATE_COMMAND_NAMES[i]]
		if cmdID then
			isStateCommand[cmdID] = true
		end
	end
end

local localPlayerID, localTeamID
local gameFrame = 0
local feedTaken = false
local rosterFed = false

---Per-team revisions of any managed team data bump this and invalidate any shared team caches.
local revisionOfTeam = {}

-- I promise I'll fix it:

---@type table<TeamID, { players: PlayerID[], playerCount: integer, isPlayer: table<PlayerID, boolean>, shared: boolean, version: integer, settleUntil: integer }>
local teams = {}
---@type table<PlayerID, TeamID>
local teamOfPlayer = {}
---@type table<UnitID, TeamID>
local teamOfUnit = {}
---@type table<UnitID, PlayerID?>
local ownerOfUnit = {}
---@type table<PlayerID, table<UnitID, true>>
local unitsOfPlayer = {}
---@type table<TeamID, table<UnitID, true>>
local unownedUnitsOfTeam = {}
---@type table<UnitID, { playerID: PlayerID, frame: integer }>
local lockOfUnit = {}
---@type table<UnitID, table<PlayerID, integer>>
local selectorsOfUnit = {}
---@type table<PlayerID, table<UnitID, true>>
local selectionOfPlayer = {}

local listeners = { owner = {}, roster = {} }

---@type UnitID[]
local automatedUnitsCache = {}
local automatedUnitsRevision = nil
---@type UnitID[]
local wholeTeamCache = {}
local wholeTeamRevision = nil

local function emit(event, a, b)
	local registered = listeners[event]
	for i = 1, #registered do
		registered[i](a, b)
	end
end

local function bumpTeam(teamID)
	if teamID ~= nil then
		revisionOfTeam[teamID] = (revisionOfTeam[teamID] or 0) + 1
	end
end

local function sameArray(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function copyArray(list)
	local copy = {}
	for i = 1, #list do
		copy[i] = list[i]
	end
	return copy
end

local function lookupTeam(teamID)
	return teamID ~= nil and teams[teamID] or nil
end

local function ensureTeam(teamID)
	local team = teams[teamID]
	if not team then
		team = {
			players = {},
			playerCount = 0,
			isPlayer = {},
			shared = false,
			version = 0,
			settleUntil = 0,
		}
		teams[teamID] = team
	end
	return team
end

local function isTeamShared(teamID)
	local team = teams[teamID]
	return team ~= nil and team.shared
end

local function onLocalTeam(playerID)
	local team = teams[teamOfPlayer[playerID]]
	return team ~= nil and team.isPlayer[playerID] == true
end

local function hasLocalID()
	return localPlayerID ~= nil and localTeamID ~= nil
end

---For the common case that nobody shares the team, still team-cached, with the same table result.
local function getWholeTeam()
	local teamRevision = revisionOfTeam[localTeamID]
	if teamRevision ~= nil and wholeTeamRevision == teamRevision then
		return wholeTeamCache
	end

	wholeTeamCache = localTeamID and spGetTeamUnits(localTeamID) or {}
	wholeTeamRevision = teamRevision
	return wholeTeamCache
end

local function setOwner(unitID, playerID)
	local previous = ownerOfUnit[unitID]
	if previous == playerID then
		return
	end

	if previous then
		local owned = unitsOfPlayer[previous]
		if owned then
			owned[unitID] = nil
		end
	end

	local teamID = teamOfUnit[unitID]
	local unowned = teamID and unownedUnitsOfTeam[teamID]

	ownerOfUnit[unitID] = playerID
	if playerID then
		local owned = unitsOfPlayer[playerID]
		if not owned then
			owned = {}
			unitsOfPlayer[playerID] = owned
		end
		owned[unitID] = true
		if unowned then
			unowned[unitID] = nil
		end
	elseif unowned then
		unowned[unitID] = true
	end

	bumpTeam(teamID)
	emit("owner", unitID, playerID)
end

---The units of a player that left the game join another partition on a client we can find.
---Ownership is _deliberately_ untouched here; on a reconnect, the server drops the old link
---and then accepts their new one, so a reconnect looks exactly like leaving. Play it cool.
local function lendToPartition(playerID, teamID)
	local owned = unitsOfPlayer[playerID]
	local unowned = unownedUnitsOfTeam[teamID]
	if not owned or not unowned then
		return
	end

	for unitID in pairs(owned) do
		if teamOfUnit[unitID] == teamID then
			unowned[unitID] = true
		end
	end
end

local function reclaimFromPartition(playerID, teamID)
	local owned = unitsOfPlayer[playerID]
	local unowned = unownedUnitsOfTeam[teamID]
	if not owned or not unowned then
		return
	end

	for unitID in pairs(owned) do
		if teamOfUnit[unitID] == teamID then
			unowned[unitID] = nil
		end
	end
end

---Players that have not left claim automation through ownership. The rest are partitioned.
local function getAutomatingPlayer(unitID)
	local team = teams[teamOfUnit[unitID]]
	if not team or team.playerCount == 0 or gameFrame < team.settleUntil then
		return nil
	end

	local owner = ownerOfUnit[unitID]
	if owner and team.isPlayer[owner] then
		return owner
	end

	return team.players[(unitID % team.playerCount) + 1]
end

---The oldest lock held by a live, present player wins. Clients learn of locks out of order; careful.
local function getLockHolder(unitID)
	local holder, since

	local lock = lockOfUnit[unitID]
	if lock and gameFrame - lock.frame < COMMAND_LOCK_FRAMES and onLocalTeam(lock.playerID) then
		holder, since = lock.playerID, lock.frame
	end

	local selectors = selectorsOfUnit[unitID]
	if selectors then
		for playerID, selectedSince in pairs(selectors) do
			if
				onLocalTeam(playerID)
				and (not holder or selectedSince < since or (selectedSince == since and playerID < holder))
			then
				holder, since = playerID, selectedSince
			end
		end
	end

	return holder
end

local function clearSelectors(unitID)
	local selectors = selectorsOfUnit[unitID]
	if not selectors then
		return
	end

	for playerID in pairs(selectors) do
		local selection = selectionOfPlayer[playerID]
		if selection then
			selection[unitID] = nil
		end
	end
	selectorsOfUnit[unitID] = nil
end

local function forgetSelection(playerID, unitID)
	local selectors = selectorsOfUnit[unitID]
	if selectors then
		selectors[playerID] = nil
		if next(selectors) == nil then
			selectorsOfUnit[unitID] = nil
		end
	end
end

local function isInternalOrder(options)
	if type(options) == "table" then
		return options.internal == true
	else
		return type(options) == "number" and bit_and(options, OPT_INTERNAL) ~= 0
	end
end

--------------------------------------------------------------------------------
-- Exported functions ----------------------------------------------------------

---Whether a team is being shared by multiple players in QUANTUM MODE.
---@param teamID TeamID? Defaults to the local team.
---@return boolean? shared
local function isShared(teamID)
	local team = lookupTeam(teamID or localTeamID)
	if not team then
		return nil
	end
	return team.shared
end

---The team's players, excluding players who are spectating or have dropped.
---@param teamID TeamID? Defaults to the local team.
---@return PlayerID[]? players
local function getPlayers(teamID)
	local team = lookupTeam(teamID or localTeamID)
	if not team then
		return nil
	end
	return copyArray(team.players)
end

---The team's lead player. Has the lowest ID on the team and handles team-singleton work.
---@param teamID TeamID? Defaults to the local team.
---@return PlayerID? leadID
local function getLead(teamID)
	local team = lookupTeam(teamID or localTeamID)
	return team and team.players[1]
end

---Whether the local player is the team lead and handles team-singleton work.
---@return boolean? isLead
local function isLeadLocal()
	if not rosterFed or not hasLocalID() then
		return nil
	end

	local team = teams[localTeamID]
	if not team or team.playerCount == 0 then
		return nil
	end
	return team.players[1] == localPlayerID
end

---Increasing version number on changes. Gameplay tends to increase it frequently.
---@param teamID TeamID? Defaults to the local team.
---@return integer? version `nil` if untracked
local function getRosterVersion(teamID)
	local team = lookupTeam(teamID or localTeamID)
	return team and team.version
end

-- Exported functions, ownership -----------------------------------------------

---@param unitID UnitID
---@return PlayerID? owner `nil` when no player has ordered or built the unit.
local function getOwner(unitID)
	return ownerOfUnit[unitID]
end

---Get the local player's owned units plus its partitioned share of unowned ones.
---When not in quantum mode, this returns all units on the local team.
---@return UnitID[] units
local function getUnitsToAutomate()
	if not rosterFed or not hasLocalID() then
		return {}
	end
	if not isTeamShared(localTeamID) then
		return getWholeTeam()
	end

	---The cached list would outlive the settle window, which is not part of the team revision, so
	---a settling team is answered without consulting or filling the cache.
	local team = teams[localTeamID]
	if team and gameFrame < team.settleUntil then
		return {}
	end

	local teamRevision = revisionOfTeam[localTeamID]
	if teamRevision ~= nil and automatedUnitsRevision == teamRevision then
		return automatedUnitsCache
	end

	local units = {}
	local count = 0

	local owned = unitsOfPlayer[localPlayerID]
	if owned then
		for unitID in pairs(owned) do
			if teamOfUnit[unitID] == localTeamID and getAutomatingPlayer(unitID) == localPlayerID then
				count = count + 1
				units[count] = unitID
			end
		end
	end

	local unowned = unownedUnitsOfTeam[localTeamID]
	if unowned then
		for unitID in pairs(unowned) do
			if getAutomatingPlayer(unitID) == localPlayerID then
				count = count + 1
				units[count] = unitID
			end
		end
	end

	automatedUnitsCache = units
	automatedUnitsRevision = teamRevision
	return units
end

-- Exported functions, gates ---------------------------------------------------

---Whether a player may send an order to a unit.
---Allows the order whenever the module cannot make a determination.
---@param unitID UnitID
---@param playerID PlayerID? Defaults to the local player.
---@return boolean allowed
local function mayCommand(unitID, playerID)
	if not rosterFed then
		return true
	end

	playerID = playerID or localPlayerID
	if playerID == nil then
		return true
	end

	local teamID = teamOfUnit[unitID]
	if teamID and not isTeamShared(teamID) then
		return true
	end

	local holder = getLockHolder(unitID)
	return holder == nil or holder == playerID
end

---Whether a player may send an automation order to a unit.
---Allows the order whenever the module cannot make a determination.
---@param unitID UnitID
---@return boolean allowed
local function mayAutomate(unitID)
	if not rosterFed or not hasLocalID() then
		return false
	end

	local teamID = teamOfUnit[unitID]
	if teamID == nil then
		return false
	end
	if not isTeamShared(teamID) then
		return teamID == localTeamID
	end
	return getAutomatingPlayer(unitID) == localPlayerID
end

--------------------------------------------------------------------------------
-- Exported functions, change notification -------------------------------------

---Add a callback to one of two event channels to handle low-frequency change events
---without having to reacquire the entire roster, partition, etc.
---@param event "owner"|"roster" `owner` passes (unitID, playerID), `roster` passes (teamID) of the changed team.
---@param callback fun(UnitID, PlayerID?)|fun(teamID)
local function subscribe(event, callback)
	local registered = listeners[event]
	if registered then
		registered[#registered + 1] = callback
	end
end

---@param event "owner"|"roster"
---@param callback fun(UnitID, PlayerID?)|fun(teamID)
local function unsubscribe(event, callback)
	local registered = listeners[event]
	if not registered then
		return
	end
	for i = #registered, 1, -1 do
		if registered[i] == callback then
			table.remove(registered, i)
		end
	end
end

--------------------------------------------------------------------------------
-- Feed, used by the api wupgets -----------------------------------------------

---@param playerID PlayerID
---@param teamID TeamID
local function setPerspective(playerID, teamID)
	bumpTeam(localTeamID)
	localPlayerID = playerID
	localTeamID = teamID
	bumpTeam(teamID)
end

---@param frame integer
local function onGameFrame(frame)
	gameFrame = frame
end

---@param teamID TeamID
---@param players PlayerID[] in-game and not spectating
local function onRoster(teamID, players)
	local team = ensureTeam(teamID)
	rosterFed = true

	if sameArray(team.players, players) then
		return
	end

	local departed = team.players
	local wasPlayer = team.isPlayer

	team.players = copyArray(players)
	team.playerCount = #team.players
	team.shared = team.playerCount > 1
	team.isPlayer = {}
	team.version = team.version + 1
	team.settleUntil = gameFrame + ROSTER_SETTLE_FRAMES

	for i = 1, #team.players do
		teamOfPlayer[team.players[i]] = teamID
		team.isPlayer[team.players[i]] = true
	end

	for i = 1, #departed do
		local playerID = departed[i]
		if not team.isPlayer[playerID] then
			if teamOfPlayer[playerID] == teamID then
				teamOfPlayer[playerID] = nil
			end
			lendToPartition(playerID, teamID)
		end
	end

	for i = 1, #team.players do
		local playerID = team.players[i]
		if not wasPlayer[playerID] then
			reclaimFromPartition(playerID, teamID)
		end
	end

	bumpTeam(teamID)
	emit("roster", teamID)
end

---@param unitID UnitID
---@param teamID TeamID
---@param builderID UnitID?
local function onUnitCreated(unitID, teamID, builderID)
	teamOfUnit[unitID] = teamID

	local unowned = unownedUnitsOfTeam[teamID]
	if not unowned then
		unowned = {}
		unownedUnitsOfTeam[teamID] = unowned
	end
	unowned[unitID] = true
	bumpTeam(teamID)

	local inherited = builderID and ownerOfUnit[builderID]
	if inherited then
		setOwner(unitID, inherited)
	end
end

---@param unitID UnitID
local function onUnitDestroyed(unitID)
	local teamID = teamOfUnit[unitID]
	if teamID == nil and ownerOfUnit[unitID] == nil then
		return
	end

	setOwner(unitID, nil)

	local unowned = teamID and unownedUnitsOfTeam[teamID]
	if unowned then
		unowned[unitID] = nil
	end

	clearSelectors(unitID)

	teamOfUnit[unitID] = nil
	lockOfUnit[unitID] = nil
	bumpTeam(teamID)
end

---@param unitID UnitID
---@param teamID TeamID The team the unit now belongs to.
local function onUnitTransferred(unitID, teamID)
	local previousTeam = teamOfUnit[unitID]
	if previousTeam and unownedUnitsOfTeam[previousTeam] then
		unownedUnitsOfTeam[previousTeam][unitID] = nil
	end

	setOwner(unitID, nil)
	clearSelectors(unitID)
	bumpTeam(previousTeam)
	onUnitCreated(unitID, teamID, nil)
	lockOfUnit[unitID] = nil
end

---Ownership can be set or reset according to the most recent player order.
---Automated orders carry the internal bit, and state commands are ignored.
---@param unitID UnitID
---@param playerID PlayerID
---@param cmdID integer
---@param options CommandOptions|integer
---@param fromLua boolean?
local function onUnitCommand(unitID, playerID, cmdID, options, fromLua)
	if fromLua or not playerID or playerID < 0 then
		return
	end
	if isStateCommand[cmdID] or isInternalOrder(options) then
		return
	end

	local lock = lockOfUnit[unitID]
	if lock then
		lock.playerID = playerID
		lock.frame = gameFrame
	else
		lockOfUnit[unitID] = { playerID = playerID, frame = gameFrame }
	end

	setOwner(unitID, playerID)
end

---Restores attribution that a client missed, such as after a widget reload.
---@param unitID UnitID
---@param teamID TeamID
---@param playerID PlayerID?
local function onUnitOwner(unitID, teamID, playerID)
	if teamOfUnit[unitID] == nil then
		onUnitCreated(unitID, teamID, nil)
	end
	setOwner(unitID, playerID)
end

---@param playerID PlayerID
---@param added UnitID[]?
---@param removed UnitID[]?
local function onSelectionChanged(playerID, added, removed)
	local selection = selectionOfPlayer[playerID]
	if not selection then
		selection = {}
		selectionOfPlayer[playerID] = selection
	end

	if removed then
		for i = 1, #removed do
			local unitID = removed[i]
			selection[unitID] = nil
			forgetSelection(playerID, unitID)
		end
	end

	if added then
		for i = 1, #added do
			local unitID = added[i]
			if not selection[unitID] then
				selection[unitID] = true
				local selectors = selectorsOfUnit[unitID]
				if not selectors then
					selectors = {}
					selectorsOfUnit[unitID] = selectors
				end
				selectors[playerID] = gameFrame
			end
		end
	end
end

---@param playerID PlayerID
local function onSelectionCleared(playerID)
	local selection = selectionOfPlayer[playerID]
	if selection then
		for unitID in pairs(selection) do
			forgetSelection(playerID, unitID)
		end
		selectionOfPlayer[playerID] = {}
	end
end

---Closes the feed to any other callers so it can be owned by the api driver wupdgets.
---@return table? feed `nil` when claimed already
local function closeFeed()
	feedTaken = false
end

local function openFeed()
	if feedTaken then
		return nil
	end
	feedTaken = true -- Easier reloading pattern.

	resolveStateCommands()

	return {
		Close = closeFeed,
		SetPerspective = setPerspective,
		OnGameFrame = onGameFrame,
		OnRoster = onRoster,
		OnUnitCreated = onUnitCreated,
		OnUnitDestroyed = onUnitDestroyed,
		OnUnitTransferred = onUnitTransferred,
		OnUnitCommand = onUnitCommand,
		OnUnitOwner = onUnitOwner,
		OnSelectionChanged = onSelectionChanged,
		OnSelectionCleared = onSelectionCleared,
	}
end

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

return {
	OWNER_RULES_PARAM = RULESPARAM_OWNER,

	IsShared = isShared,
	GetPlayers = getPlayers,
	GetLead = getLead,
	IsLeadLocal = isLeadLocal,
	GetRosterVersion = getRosterVersion,

	GetOwner = getOwner,
	GetUnitsToAutomate = getUnitsToAutomate,

	MayCommand = mayCommand,
	MayAutomate = mayAutomate,

	Subscribe = subscribe,
	Unsubscribe = unsubscribe,

	OpenFeed = openFeed,
}

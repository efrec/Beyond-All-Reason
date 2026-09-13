local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Ghosts API",
		desc = "Tracks positions of unit ghosts and removes them when revealed",
		author = "efrec, Chronographer",
		date = "2026-06",
		license = "GNU GPL, v2 or later",
		layer = -1000, -- Before any wupgets that would use it.
		enabled = true,
	}
end

local graceFrames = math.round(Game.targetIsLostTime * Game.gameSpeed, 0)
local updateFrames = math.round(Game.gameSpeed * 0.5, 0)
local updateOffset = math.round(updateFrames * 0.5, 0)

local bit_and = math.bit_and
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitLosState = Spring.GetUnitLosState
local spSetUnitLeavesGhost = Spring.SetUnitLeavesGhost

local LOS_INLOS = 1
local LOS_INRADAR = 2
local LOS_PREVLOS = 4

-- Shared code -----------------------------------------------------------------

-- These unitdef properties do not imply one another, but we assume they do for simplicity:
-- - leaves ghosts
-- - cannot move
-- - cannot be transported
-- - has no radar error
-- - detected by LOS or by airLOS
local leavesGhost = table.new(#UnitDefs, 0)
for unitDefID, unitDef in ipairs(UnitDefs) do
	leavesGhost[unitDefID] = unitDef.leavesGhost
end

if not table.any(leavesGhost, function(v)
	return v
end) then
	Spring.Log("UnitGhosts", LOG.INFO, "No units leave ghosts. Removing.")
	local stub = function()
		return
	end
	GG.UnitGhosts = {
		GetAllyGhostPosition = stub,
		GetTeamGhostPosition = stub,
		SetAllyGhostPosition = stub,
		GetGhostsInRectangle = stub,
		GetGhostsInCylinder = stub,
		GetGhostsInSphere = stub,
		UpdateUnitGhost = stub,
		RemoveUnitGhost = stub,
	}
	return false
end

local addGhostQueue = {}
local allyGhostPosition = {} ---@type table<AllyTeamID, table<UnitID?, UnitGhostPosition>>
local teamGhostPosition = {} ---@type table<TeamID, table<UnitID?, UnitGhostPosition>>
local allyStalePosition = {} ---@type table<AllyTeamID, table<UnitID?, UnitGhostPosition>>
local teamStalePosition = {} ---@type table<TeamID, table<UnitID?, UnitGhostPosition>>
do
	-- TODO: Do we need gaia to see unit ghosts for any reason?
	local gaiaAllyTeam = Spring.GetTeamAllyTeamID(Spring.GetGaiaTeamID())
	for _, teamID in ipairs(Spring.GetTeamList() or {}) do
		local allyTeam = select(6, Spring.GetTeamInfo(teamID, false))
		if allyTeam ~= gaiaAllyTeam then
			teamGhostPosition[teamID] = table.ensureTable(allyGhostPosition, allyTeam)
			teamStalePosition[teamID] = table.ensureTable(allyStalePosition, allyTeam)
		end
	end
end

local function canUnitLeaveGhost(unitID, allyTeam)
	local state = spGetUnitLosState(unitID, allyTeam, true)
	return not state
		or (
			state ~= 0
			and 0 == bit_and(state, LOS_INLOS) -- INLOS prevents (and resolves) ghosts.
			and 0 == bit_and(state, LOS_INRADAR) -- Radar dots already can be targeted.
			and 0 ~= bit_and(state, LOS_PREVLOS) -- Required to identify the unitDefID.
		)
end

local function canPositionLeaveGhost(x, y, z, allyTeam)
	local inLosOrRadar, inLos, _inRadar, jammed = spGetPositionLosState(x, y, z, allyTeam)
	return not inLosOrRadar or (not inLos and jammed)
end

local function isPositionInLOS(position, allyTeam)
	local _inLosOrRadar, inLos, inRadar, jammed = spGetPositionLosState(position[1], position[2], position[3], allyTeam)
	return inLos or (inRadar and not jammed)
end

--------------------------------------------------------------------------------
-- Gadget interfaces -----------------------------------------------------------

local function getGhostPositionByAllyTeam(unitID, allyTeam)
	return allyGhostPosition[allyTeam][unitID] or allyStalePosition[allyTeam][unitID]
end

local function getGhostPositionByTeam(unitID, teamID)
	return teamGhostPosition[teamID][unitID] or teamStalePosition[teamID][unitID]
end

local function collectGhostsInCylinder(positions, x, z, radiusSquared, units, count)
	for unitID, position in pairs(positions) do
		local dx = position[4] - x
		local dz = position[6] - z
		if dx * dx + dz * dz <= radiusSquared then
			count = count + 1
			units[count] = unitID
		end
	end
	return count
end

local function getUnitGhostsInCylinder(x, z, radius, teamID)
	local units = {}
	local radiusSquared = radius * radius
	local count = collectGhostsInCylinder(teamGhostPosition[teamID], x, z, radiusSquared, units, 0)
	count = collectGhostsInCylinder(teamStalePosition[teamID], x, z, radiusSquared, units, count)
	return units, count
end

local function collectGhostsInSphere(positions, x, y, z, radiusSquared, units, count)
	for unitID, position in pairs(positions) do
		local dx = position[4] - x
		local dy = position[5] - y
		local dz = position[6] - z
		if dx * dx + dy * dy + dz * dz <= radiusSquared then
			count = count + 1
			units[count] = unitID
		end
	end
	return count
end

local function getUnitGhostsInSphere(x, y, z, radius, teamID)
	local units = {}
	local radiusSquared = radius * radius
	local count = collectGhostsInSphere(teamGhostPosition[teamID], x, y, z, radiusSquared, units, 0)
	count = collectGhostsInSphere(teamStalePosition[teamID], x, y, z, radiusSquared, units, count)
	return units, count
end

local function collectGhostsInRectangle(positions, top, bot, left, right, units, count)
	for unitID, position in pairs(positions) do
		if top <= position[4] and bot >= position[4] and left <= position[6] and right >= position[6] then
			count = count + 1
			units[count] = unitID
		end
	end
	return count
end

local function getUnitGhostsInRectangle(top, bot, left, right, teamID)
	local units = {}
	local count = collectGhostsInRectangle(teamGhostPosition[teamID], top, bot, left, right, units, 0)
	count = collectGhostsInRectangle(teamStalePosition[teamID], top, bot, left, right, units, count)
	return units, count
end

-- Synced / unsynced split -----------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	local inTransport = {} ---@type { [UnitID?] : true }

	local function sendGhostAdded(allyTeam, unitID, position)
		allyStalePosition[allyTeam][unitID] = nil -- for recyclable unitIDs
		SendToUnsynced("UnitGhostAdded", allyTeam, unitID, position)
	end

	local function sendGhostRemoved(allyTeam, unitID)
		SendToUnsynced("UnitGhostRemoved", allyTeam, unitID)
	end

	local function addUnitGhost(unitID, allyTeams, gameFrame)
		local x, y, z, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(unitID, true, true)
		if not x then
			return
		end
		for allyTeam in pairs(allyTeams) do
			local positions = allyGhostPosition[allyTeam]
			if
				not positions[unitID]
				and canUnitLeaveGhost(unitID, allyTeam)
				and canPositionLeaveGhost(x, y, z, allyTeam)
			then
				local position = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame } ---@type UnitGhostPosition
				positions[unitID] = position
				sendGhostAdded(allyTeam, unitID, position)
			end
		end
	end

	local function updateUnitGhostPosition(unitID, allyTeam, gameFrame)
		if not allyTeam then
			local x, y, z, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(unitID, true, true)
			for losAllyTeam, positions in pairs(allyGhostPosition) do
				if not positions[unitID] then
					-- continue
				elseif canUnitLeaveGhost(unitID, losAllyTeam) and canPositionLeaveGhost(x, y, z, losAllyTeam) then
					local position = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame } ---@type UnitGhostPosition
					positions[unitID] = position
					sendGhostAdded(losAllyTeam, unitID, position)
				end
			end
			return
		end
		if not canUnitLeaveGhost(unitID, allyTeam) then
			return
		end
		local x, y, z, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(unitID, true, true)
		if not canPositionLeaveGhost(x, y, z, allyTeam) then
			return
		end
		local position = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame } ---@type UnitGhostPosition
		allyGhostPosition[allyTeam][unitID] = position
		sendGhostAdded(allyTeam, unitID, position)
	end

	local function setGhostPosition(unitID, allyTeam, x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame)
		if not allyTeam then
			for losAllyTeam, positions in pairs(allyGhostPosition) do
				local position = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame } ---@type UnitGhostPosition
				positions[unitID] = position
				sendGhostAdded(losAllyTeam, unitID, position)
			end
			return
		end
		local position = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame } ---@type UnitGhostPosition
		allyGhostPosition[allyTeam][unitID] = position
		sendGhostAdded(allyTeam, unitID, position)
	end

	local function suspendUnitGhosts(unitID)
		addGhostQueue[unitID] = nil
		for allyTeam, positions in pairs(allyGhostPosition) do
			local position = positions[unitID]
			if position then
				positions[unitID] = nil
				allyStalePosition[allyTeam][unitID] = position
			end
		end
	end

	local function removeUnit(unitID)
		addGhostQueue[unitID] = nil
		local hadGhost = false
		for allyTeam, positions in pairs(allyGhostPosition) do
			if positions[unitID] or allyStalePosition[allyTeam][unitID] then
				positions[unitID] = nil
				allyStalePosition[allyTeam][unitID] = nil
				hadGhost = true
			end
		end
		if hadGhost then
			sendGhostRemoved(-1, unitID) -- allyTeam=-1 broadcasts to all ally teams
		end
	end

	local function removeStalePositionsInLOS(allyTeam, positions, clearFrame)
		for unitID, position in pairs(positions) do
			if position.gameFrame <= clearFrame and isPositionInLOS(position, allyTeam) then
				positions[unitID] = nil
				sendGhostRemoved(allyTeam, unitID)
			end
		end
	end

	local function reloadGhosts()
		local store = {}
		for allyTeam, positions in pairs(allyGhostPosition) do
			local replayed = {}
			for unitID, position in pairs(allyStalePosition[allyTeam]) do
				replayed[unitID] = position
			end
			for unitID, position in pairs(positions) do
				replayed[unitID] = position
			end
			store[allyTeam] = replayed
		end
		SendToUnsynced("UnitGhostsReplay", store)
	end

	-- Engine callins --------------------------------------------------------------

	function gadget:GameFrame(frame)
		local offset = frame % updateFrames
		if offset == 0 then
			for unitID, allyTeams in pairs(addGhostQueue) do
				addGhostQueue[unitID] = nil
				addUnitGhost(unitID, allyTeams, frame)
			end
		elseif offset == updateOffset then
			local clearFrame = frame - updateFrames * 0.5
			for allyTeam, positions in pairs(allyStalePosition) do
				removeStalePositionsInLOS(allyTeam, positions, clearFrame)
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if leavesGhost[unitDefID] then
			suspendUnitGhosts(unitID)
			inTransport[unitID] = nil
		end
	end

	local function callinAllyTeamSeesGhost(self, unitID, unitTeam, allyTeam, unitDefID)
		local positions = allyGhostPosition[allyTeam]
		if positions and positions[unitID] then
			positions[unitID] = nil
			sendGhostRemoved(allyTeam, unitID)
		else
			local suspended = allyStalePosition[allyTeam]
			if inTransport[unitID] and suspended and suspended[unitID] then
				suspended[unitID] = nil
				sendGhostRemoved(allyTeam, unitID)
			end
		end
	end
	gadget.UnitEnteredLos = callinAllyTeamSeesGhost
	gadget.UnitEnteredRadar = callinAllyTeamSeesGhost

	local function callinWatchUnitGhost(self, unitID, unitTeam, allyTeam, unitDefID)
		if leavesGhost[unitDefID] and not inTransport[unitID] and Spring.GetUnitIsDead(unitID) == false then
			table.ensureTable(addGhostQueue, unitID)[allyTeam] = true
		end
	end
	gadget.UnitLeftLos = callinWatchUnitGhost
	gadget.UnitLeftRadar = callinWatchUnitGhost

	function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
		if leavesGhost[unitDefID] then
			spSetUnitLeavesGhost(unitID, false, true) -- Old ghost persists until position re-enters LOS.
			suspendUnitGhosts(unitID)
			inTransport[unitID] = true
		end
	end

	function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
		if leavesGhost[unitDefID] then
			spSetUnitLeavesGhost(unitID, true)
			inTransport[unitID] = nil
		end
	end

	-- Synced lifecycle -----------------------------------------------------------

	local teamRule = "reload_ghost_"

	function gadget:Initialize()
		GG.UnitGhosts = {
			GetAllyGhostPosition = getGhostPositionByAllyTeam,
			GetTeamGhostPosition = getGhostPositionByTeam,
			SetAllyGhostPosition = setGhostPosition,
			GetGhostsInRectangle = getUnitGhostsInRectangle,
			GetGhostsInCylinder = getUnitGhostsInCylinder,
			GetGhostsInSphere = getUnitGhostsInSphere,
			UpdateUnitGhost = updateUnitGhostPosition,
			RemoveUnitGhost = removeUnit,
		}

		if Spring.GetGameFrame() <= 0 then
			return
		end

		-- Load unit ghost positions from rules params.
		local allUnits = Spring.GetAllUnits()
		for allyTeam, unitGhosts in pairs(allyGhostPosition) do
			local teamList = Spring.GetTeamList(allyTeam)
			assert(teamList)
			for _, teamID in pairs(teamList) do
				if Spring.GetTeamRulesParam(teamID, "reload_ghosts") then
					for _, unitID in pairs(allUnits) do
						local tsv = Spring.GetTeamRulesParam(teamID, teamRule .. unitID) ---@as string?
						if tsv then
							local texts = tsv:split("|") ---@as string[]
							local x, y, z, midX, midY, midZ, aimX, aimY, aimZ =
								texts[1], texts[2], texts[3], texts[4], texts[5], texts[6], texts[7], texts[8], texts[9]
							local gameFrame = (texts[10] or ""):sub(string.len("gameFrame=") + 1)
							local tbl = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
							for k, v in pairs(tbl) do
								tbl[k] = tonumber(v)
							end
							unitGhosts[unitID] = tbl
							Spring.SetTeamRulesParam(teamID, teamRule .. unitID, nil)
						end
					end
					Spring.SetTeamRulesParam(teamID, "reload_ghosts", nil)
				end
			end
		end

		-- The unsynced half is not loaded yet, so the reload has to wait for the first frame.
		local gameFrame = gadget.GameFrame
		gadget.GameFrame = function(self, frame)
			gadget.GameFrame = gameFrame
			reloadGhosts()
			return gameFrame(self, frame)
		end
	end

	local inGameEnd = false
	function gadget:GameOver()
		inGameEnd = true
	end

	function gadget:Shutdown()
		if inGameEnd then
			return
		end

		-- Dump unit ghost positions to team rules params for reloading.
		local allyTeamToTeam = {}
		for _, teamID in pairs(Spring.GetTeamList()) do
			local allyTeam = select(6, Spring.GetTeamInfo(teamID, false))
			if not allyTeamToTeam[allyTeam] then
				allyTeamToTeam[allyTeam] = teamID
			end
		end
		for allyTeam, unitGhosts in pairs(allyGhostPosition) do
			local teamID = allyTeamToTeam[allyTeam] ---@type integer
			Spring.SetTeamRulesParam(teamID, "reload_ghosts", true)
			for unitID, position in pairs(unitGhosts) do
				Spring.SetTeamRulesParam(
					teamID,
					teamRule .. unitID,
					table.concat(position, "|") .. "|gameFrame=" .. position.gameFrame
				)
			end
		end
	end
else
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetMyPlayerID = Spring.GetMyPlayerID
	local spGetSpectatingState = Spring.GetSpectatingState

	local viewAllyTeam = nil ---@as AllyTeamID? `nil` when fullview
	local generation = 0

	local function updatePlayer()
		local _, fullView = spGetSpectatingState()
		local allyTeam = not fullView and spGetMyAllyTeamID() or nil
		if allyTeam ~= viewAllyTeam then
			viewAllyTeam = allyTeam
			generation = generation + 1
		end
	end

	local addedBatch = {} ---@type table<integer, UnitGhostPosition>
	local removedBatch = {} ---@type table<integer, true>
	local batchDirty = false

	local function clearBatch()
		addedBatch, removedBatch, batchDirty = {}, {}, false
	end

	local function onGhostAdded(_, allyTeam, unitID, position)
		allyGhostPosition[allyTeam][unitID] = position
		if allyTeam == viewAllyTeam then
			addedBatch[unitID] = position
			removedBatch[unitID] = nil
			batchDirty = true
		end
	end

	local function onGhostRemoved(_, allyTeam, unitID)
		if allyTeam >= 0 then
			allyGhostPosition[allyTeam][unitID] = nil
		else
			for _, positions in pairs(allyGhostPosition) do
				positions[unitID] = nil
			end
		end
		if viewAllyTeam and (allyTeam == viewAllyTeam or allyTeam < 0) then
			addedBatch[unitID] = nil
			removedBatch[unitID] = true
			batchDirty = true
		end
	end

	local function onGhostsReloaded(_, store)
		for _, positions in pairs(allyGhostPosition) do
			for unitID in pairs(positions) do
				positions[unitID] = nil
			end
		end
		for allyTeam, replayed in pairs(store) do
			local positions = allyGhostPosition[allyTeam]
			if positions then
				for unitID, p in pairs(replayed) do
					positions[unitID] = p
				end
			end
		end
		generation = generation + 1
	end

	-- Engine callins ----------------------------------------------------------------

	function gadget:PlayerChanged(playerID)
		if playerID == spGetMyPlayerID() then
			updatePlayer()
		end
	end

	function gadget:GameFrame(frame)
		if frame % updateFrames ~= updateOffset then
			return
		end
		if not Script.LuaUI("UnitGhostsGeneration") then
			clearBatch()
			return
		end
		if Script.LuaUI.UnitGhostsGeneration() ~= generation then
			Script.LuaUI.UnitGhostsCleared(generation, viewAllyTeam and allyGhostPosition[viewAllyTeam] or {})
			clearBatch()
		elseif batchDirty then
			generation = generation + 1
			Script.LuaUI.UnitGhostsChanged(generation, addedBatch, removedBatch)
			clearBatch()
		end
	end

	-- Unsynced lifecycle ---------------------------------------------------------

	function gadget:Initialize()
		updatePlayer()

		gadgetHandler:AddSyncAction("UnitGhostAdded", onGhostAdded)
		gadgetHandler:AddSyncAction("UnitGhostRemoved", onGhostRemoved)
		gadgetHandler:AddSyncAction("UnitGhostsReplay", onGhostsReloaded)

		GG.UnitGhosts = {
			GetAllyGhostPosition = getGhostPositionByAllyTeam,
			GetTeamGhostPosition = getGhostPositionByTeam,
			GetGhostsInRectangle = getUnitGhostsInRectangle,
			GetGhostsInCylinder = getUnitGhostsInCylinder,
			GetGhostsInSphere = getUnitGhostsInSphere,
		}
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("UnitGhostAdded")
		gadgetHandler:RemoveSyncAction("UnitGhostRemoved")
		gadgetHandler:RemoveSyncAction("UnitGhostsReplay")

		GG.UnitGhosts = nil
	end
end

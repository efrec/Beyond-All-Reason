local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Unit Ghosts API",
		desc    = "Tracks unit ghost positions and removes ghosts left by transported buildings",
		author  = "Chronographer, efrec",
		date    = "2026-06",
		license = "GNU GPL, v2 or later",
		layer   = -1000, -- Before the wupgets that would use it.
		enabled = true,
	}
end

-- Runs in both SYNCED and UNSYNCED.

local updateFrames = 0.5 * Game.gameSpeed
local updateOffset = math.round(updateFrames * 0.5)

local bit_and = math.bit_and
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitLosState = Spring.GetUnitLosState
local spSetUnitLeavesGhost = Spring.SetUnitLeavesGhost

local LOS_INLOS = 1 -- I thought there was a `LosMask` enum?
local LOS_INRADAR = 2
local LOS_PREVLOS = 4

-- These unitdef properties do not imply one another, but we assume they do for simplicity:
-- - leaves ghosts
-- - cannot move
-- - cannot be transported
-- - has no radar error
-- - detected by LOS or by airLOS
local leavesGhost = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	leavesGhost[unitDefID] = unitDef.leavesGhost
end

if not table.any(leavesGhost, function(v) return v end) then
	Spring.Log("UNITGHOSTS", LOG.INFO, "No units leave ghosts. Removing.")
	local stub = function() return end
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
	gadgetHandler:RemoveGadget()
	return
end

local isGhostedUnit = {}
local addGhostQueue = {}
local allyGhostPosition = {}
local teamGhostPosition = {} -- likely unused
for _, teamID in ipairs(Spring.GetTeamList()) do
	local allyTeam = select(6, Spring.GetTeamInfo(teamID, false))
	teamGhostPosition[teamID] = table.ensureTable(allyGhostPosition, allyTeam)
end

local function canUnitLeaveGhost(unitID, allyTeam)
	local state = spGetUnitLosState(unitID, allyTeam, true)
	return not state or (state ~= 0
		and 0 == bit_and(state, LOS_INLOS) -- INLOS prevents (and resolves) ghosts.
		and 0 == bit_and(state, LOS_INRADAR) -- Radar dots already can be targeted.
		and 0 ~= bit_and(state, LOS_PREVLOS) -- Required to identify the unitDefID.
	)
end

local function canPositionLeaveGhost(x, y, z, allyTeam)
	local inLosOrRadar, inLos, inRadar, jammed = spGetPositionLosState(x, y, z, allyTeam)
	return not inLosOrRadar or (not inLos and jammed)
end

local function isPositionInLOS(position, allyTeam)
	local inLosOrRadar, inLos, inRadar, jammed = spGetPositionLosState(position[1], position[2], position[3], allyTeam)
	return inLos or (inRadar and not jammed)
end

local function addUnitGhost(unitID, allyTeams, gameFrame)
	local hasUnitGhost = false
	local x, y, z, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(unitID, true, true)
	if not x then
		return
	end
	for allyTeam in pairs(allyTeams) do
		local positions = allyGhostPosition[allyTeam]
		if positions[unitID] then
			hasUnitGhost = true
		elseif canUnitLeaveGhost(unitID, allyTeam) and canPositionLeaveGhost(x, y, z, allyTeam) then
			positions[unitID] = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
			hasUnitGhost = true
		end
	end
	isGhostedUnit[unitID] = hasUnitGhost or nil
end

local function removeGhostPositionsInLOS(unitID, clearFrame)
	local hasUnitGhost = false
	for allyTeam, positions in pairs(allyGhostPosition) do
		local position = positions[unitID]
		if position then
			if position.gameFrame <= clearFrame and isPositionInLOS(position, allyTeam) then
				positions[unitID] = nil
			else
				hasUnitGhost = true
			end
		end
	end
	if not hasUnitGhost then
		isGhostedUnit[unitID] = nil
	end
end

local function removeUnit(unitID)
	addGhostQueue[unitID] = nil
	isGhostedUnit[unitID] = nil
	for _, positions in pairs(allyGhostPosition) do
		positions[unitID] = nil
	end
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function gadget:GameFrame(frame)
	local remainder = frame % updateFrames
	if remainder == 0 then
		for unitID, allyTeams in pairs(addGhostQueue) do
			addUnitGhost(unitID, allyTeams, frame)
		end
	elseif remainder == updateOffset then
		local clearFrame = frame - updateFrames * 0.5
		for unitID in pairs(isGhostedUnit) do
			removeGhostPositionsInLOS(unitID, clearFrame)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if leavesGhost[unitDefID] then
		removeUnit(unitID)
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if leavesGhost[unitDefID] then
		spSetUnitLeavesGhost(unitID, false, true) -- Old ghost persists until position re-enters LOS
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if leavesGhost[unitDefID] then
		spSetUnitLeavesGhost(unitID, true)
	end
end

local function callinAllyTeamSeesGhost(self, unitID, unitTeam, allyTeam, unitDefID)
	allyGhostPosition[allyTeam][unitID] = nil
end
gadget.UnitEnteredLos = callinAllyTeamSeesGhost
gadget.UnitEnteredRadar = callinAllyTeamSeesGhost

local function callinWatchUnitGhost(self, unitID, unitTeam, allyTeam, unitDefID)
	-- TODO: When do these callins trigger relative to unit destruction? No idea.
	if leavesGhost[unitDefID] and Spring.GetUnitIsDead(unitID) == false then
		table.ensureTable(addGhostQueue, unitID)[allyTeam] = true
	end
end
gadget.UnitLeftLos = callinWatchUnitGhost
gadget.UnitLeftRadar = callinWatchUnitGhost

-- Gadget interfaces -----------------------------------------------------------

local function getGhostPositionByAllyTeam(unitID, allyTeam)
	return allyGhostPosition[allyTeam][unitID]
end

local function getGhostPositionByTeam(unitID, teamID)
	return teamGhostPosition[teamID][unitID]
end

local function setGhostPosition(unitID, allyTeam, x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame)
	if not allyTeam then
		for _, positions in pairs(allyGhostPosition) do
			positions[unitID] = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
		end
		return
	end
	allyGhostPosition[allyTeam][unitID] = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
end

local function getUnitGhostsInRectangle(top, bot, left, right, teamID)
	local units, count = {}, 0
	for unitID, position in pairs(teamGhostPosition[teamID]) do
		if top <= position[4] and bot >= position[4] and left <= position[6] and right >= position[6] then
			count = count + 1
			units[count] = unitID
		end
	end
	return units, count
end

local function getUnitGhostsInCylinder(x, z, radius, teamID)
	local radiusSquared = radius * radius
	local units, count = {}, 0
	for unitID, position in pairs(teamGhostPosition[teamID]) do
		local dx = position[4] - x
		local dz = position[6] - z
		if dx * dx + dz * dz <= radiusSquared then
			count = count + 1
			units[count] = unitID
		end
	end
	return units, count
end

local function getUnitGhostsInSphere(x, y, z, radius, teamID)
	local radiusSquared = radius * radius
	local units, count = {}, 0
	for unitID, position in pairs(teamGhostPosition[teamID]) do
		local dx = position[4] - x
		local dy = position[5] - y
		local dz = position[6] - z
		if dx * dx + dy * dy + dz * dz <= radiusSquared then
			count = count + 1
			units[count] = unitID
		end
	end
	return units, count
end

local function updateUnitGhostPosition(unitID, allyTeam, gameFrame)
	if not allyTeam then
		local x, y, z, midX, midY, midZ, aimX, aimY, aimZ = spGetUnitPosition(unitID, true, true)
		for losAllyTeam, positions in pairs(allyGhostPosition) do
			if not positions[unitID] then
				--
			elseif canUnitLeaveGhost(unitID, losAllyTeam) and canPositionLeaveGhost(x, y, z, allyTeam) then
				positions[unitID] = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
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
	allyGhostPosition[allyTeam][unitID] = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
end

function gadget:Initialize()
	GG.UnitGhosts = {}
	GG.UnitGhosts.GetAllyGhostPosition = getGhostPositionByAllyTeam
	GG.UnitGhosts.GetTeamGhostPosition = getGhostPositionByTeam
	GG.UnitGhosts.SetAllyGhostPosition = setGhostPosition
	GG.UnitGhosts.GetGhostsInRectangle = getUnitGhostsInRectangle
	GG.UnitGhosts.GetGhostsInCylinder = getUnitGhostsInCylinder
	GG.UnitGhosts.GetGhostsInSphere = getUnitGhostsInSphere
	GG.UnitGhosts.UpdateUnitGhost = updateUnitGhostPosition
	GG.UnitGhosts.RemoveUnitGhost = removeUnit

	if Spring.GetGameFrame() <= 0 then
		return
	end

	-- Load unit ghost positions from rules params.
	-- TODO: synced runs before unsynced so we are clearing the rules before unsynced can use them

	local IsSyncedCode = gadgetHandler:IsSyncedCode()
	local allUnits = Spring.GetAllUnits()

	for allyTeam, unitGhosts in pairs(allyGhostPosition) do
		local teamList = Spring.GetTeamList(allyTeam)
		assert(teamList)
		for _, teamID in pairs(teamList) do
			if Spring.GetTeamRulesParam(teamID, "reload_ghosts") then
				for _, unitID in pairs(allUnits) do
					local tsv = Spring.GetTeamRulesParam(teamID, "reload_ghost_" .. unitID)
					if tsv then
						local texts = tsv:split("|")
						local x, y, z, midX, midY, midZ, aimX, aimY, aimZ = texts[1], texts[2], texts[3], texts[4], texts[5], texts[6], texts[7], texts[8], texts[9]
						local gameFrame = string.sub(texts[10], string.len("gameFrame=") + 1)
						local tbl = { x, y, z, midX, midY, midZ, aimX, aimY, aimZ, gameFrame = gameFrame }
						for k, v in pairs(tbl) do
							tbl[k] = tonumber(v)
						end
						unitGhosts[unitID] = tbl
						if IsSyncedCode then
							Spring.SetTeamRulesParam(teamID, "reload_ghost_" .. unitID, nil)
						end
					end
				end
				if IsSyncedCode then
					Spring.SetTeamRulesParam(teamID, "reload_ghosts", nil)
				end
			end
		end
	end
end

local inGameEnd = false

function gadget:GameOver()
	inGameEnd = true
end

function gadget:Shutdown()
	if inGameEnd or not gadgetHandler:IsSyncedCode() then
		return
	end

	-- Dump unit ghost positions to team rules params.

	local allyTeamToTeam = {}
	for _, teamID in pairs(Spring.GetTeamList()) do
		local allyTeam = select(6, Spring.GetTeamInfo(teamID, false))
		if not allyTeamToTeam[allyTeam] then
			allyTeamToTeam[allyTeam] = teamID
		end
	end

	for allyTeam, unitGhosts in pairs(allyGhostPosition) do
		local teamID = allyTeamToTeam[allyTeam]
		local teamRule = "reload_ghost_"
		Spring.SetTeamRulesParam(teamID, "reload_ghosts", true)
		for unitID, position in pairs(unitGhosts) do
			Spring.SetTeamRulesParam(teamID, teamRule .. unitID, table.concat(position, "|") .. "|gameFrame=" .. position.gameFrame)
		end
	end
end

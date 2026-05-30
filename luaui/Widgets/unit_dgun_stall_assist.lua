local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "DGun Stall Assist",
		desc      = "Waits cons/facs when trying to dgun and stalling",
		author    = "Niobium",
		date      = "2 April 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local watchForFrames = 3.0 * Game.gameSpeed -- How long to monitor after releasing the command
local checkForFrames = 0.1 * Game.gameSpeed -- Time between wait and un-wait update sweeps

----------------------------------------------------------------
-- Local state
----------------------------------------------------------------
local watchFrames = 0
local checkFrames = 0
local targetEnergy = 0
local waitedUnits = {}
local shouldWait = {}
local isFactory = {}
local manualFireECost = {}
local shouldBuild = {}

local gameStarted

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spGetActiveCommand = Spring.GetActiveCommand
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGiveOrderToUnitMap = Spring.GiveOrderToUnitMap
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitWorkerTask = Spring.GetUnitWorkerTask
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID

local CMD_DGUN = CMD.DGUN
local CMD_WAIT = CMD.WAIT
local CMD_RESURRECT = CMD.RESURRECT

----------------------------------------------------------------
-- Local functions
----------------------------------------------------------------
local function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

local function isFactoryInBuildTask(unitID)
	local commands = spGetFactoryCommands(unitID, 1)
	return commands and commands[1] and commands[1].id < 0 and not shouldBuild[-commands[1].id]
end

local function isFactoryInWait(unitID)
	local commands = spGetFactoryCommands(unitID, 1)
	return commands and commands[1] and commands[1].id == CMD_WAIT
end

local function isUnitInBuildTask(unitID)
	local cmdID = spGetUnitWorkerTask(unitID)
	return cmdID and ((cmdID < 0 and not shouldBuild[-cmdID]) or cmdID == CMD_RESURRECT)
end

local function isUnitInWait(unitID)
	return spGetUnitCurrentCommand(unitID) == CMD_WAIT
end

local function startDGunStallAssistWatch()
	local selection = Spring.GetSelectedUnitsCounts()
	for unitDefID in next, selection do
		if manualFireECost[unitDefID] then
			targetEnergy = manualFireECost[unitDefID]
			watchFrames = watchForFrames
			checkFrames = 0
			return
		end
	end
	targetEnergy = 0
	watchFrames = 0
	checkFrames = checkForFrames
end

local function inEnergyStall(teamID)
	local currentEnergy, energyStorage = spGetTeamResources(teamID, "energy")
	return currentEnergy < targetEnergy and energyStorage >= targetEnergy
end

local function waitUnits()
	local myTeamID = spGetMyTeamID()
	if not inEnergyStall(myTeamID) then
		return
	end
	local waitMap = {}
	local myUnits = spGetTeamUnits(myTeamID)
	assert(myUnits)
	for i = 1, #myUnits do
		local uID = myUnits[i]
		local uDefID = spGetUnitDefID(uID)
		if shouldWait[uDefID] and not waitedUnits[uID] then
			if isFactory[uDefID] then
				if isFactoryInBuildTask(uID) then -- cannot also be in wait
					waitMap[uID] = true
					waitedUnits[uID] = true
				end
			else
				if isUnitInBuildTask(uID) and not isUnitInWait(uID) then
					waitMap[uID] = true
					waitedUnits[uID] = true
				end
			end
		end
	end
	if next(waitMap) then
		spGiveOrderToUnitMap(waitMap, CMD_WAIT)
	end
end

local function unwaitUnits()
	local unwaitList, count = {}, 0
	for uID in next, waitedUnits do
		local uDefID = spGetUnitDefID(uID)
		if not uDefID then
			waitedUnits[uID] = nil
		elseif isFactory[uDefID] then
			if isFactoryInWait(uID) then
				count = count + 1
				unwaitList[count] = uID
			else
				waitedUnits[uID] = nil
			end
		else
			if isUnitInWait(uID) then
				count = count + 1
				unwaitList[count] = uID
			else
				waitedUnits[uID] = nil
			end
		end
	end
	if count > 0 then
		spGiveOrderToUnitArray(unwaitList, CMD_WAIT)
	end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end

	for uDefID, uDef in pairs(UnitDefs) do
		if uDef.canManualFire then
			for _, weapon in ipairs(uDef.weapons) do
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if weaponDef.manualFire and weaponDef.energyCost > 0 then
					manualFireECost[uDefID] = weaponDef.energyCost * 1.2 -- Add some margin
					break
				end
			end
		end
		if not manualFireECost[uDefID] and uDef.buildSpeed > 0 and (uDef.canAssist or uDef.buildOptions[1]) then
			shouldWait[uDefID] = true
			if uDef.isFactory then
				isFactory[uDefID] = true
			end
		end
		if uDef.energyCost == 0 then
			shouldBuild[uDefID] = true
		end
	end
end

function widget:GameFrame(frame)
	-- Player has to keep the command active to continue the stall,
	-- i.e. this does not check whether the DGun ever fires or not.
	local _, activeCmdID = spGetActiveCommand()
	if activeCmdID == CMD_DGUN then
		startDGunStallAssistWatch()
	end

	if watchFrames > 0 then
		watchFrames = watchFrames - 1
	end

	if checkFrames > 0 then
		checkFrames = checkFrames - 1
	else
		checkFrames = checkForFrames
		if watchFrames > 0 then
			waitUnits()
		elseif next(waitedUnits) then
			unwaitUnits()
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	waitedUnits[unitID] = nil
end

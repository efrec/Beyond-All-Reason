function gadget:GetInfo()
	return {
		name    = "Reserve Resources Command",
		desc    = "Reserves the cost of incomplete units to deny over-spending",
		author  = "efrec",
        version = "1.0",
		date    = "2024-08-03",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = false,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--[[

todo @efrec
+ moving all this proof of concept over to the unit_builder_priority gadget
+ remove any doubt that AllowUnitBuildStep should never be touched again
+ at least until it is done, not like this

]]--

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local updateTime = 1.5 -- in seconds

--------------------------------------------------------------------------------
-- Globals and imports ---------------------------------------------------------

VFS.Include('luarules/configs/customcmds.h.lua')
local CMD_RESERVE_RESOURCES = CMD_RESERVE_RESOURCES

local spGetTeamResources  = Spring.GetTeamResources
local spGetUnitHealth     = Spring.GetUnitHealth

local spGetUnitCmdDescs   = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc   = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc

local unitDefsTable = UnitDefs

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

updateTime = math.ceil(Game.gameSpeed * updateTime - 1)

local RESERVE_NONE, RESERVE_METAL, RESERVE_FULL = 0, 1, 2
local trackMetal = {
    [RESERVE_METAL] = true,
    [RESERVE_FULL] = true,
}
local trackEnergy = {
    [RESERVE_FULL] = true,
}

-- Keep track of each team's reserved units, metal, and energy.

local teamList = Spring.GetTeamList()

local reservedTeams = {}
local reservedUnits = {}
local reservedMetal = {}
local reservedEnergy = {}

-- All units receive this command when created and lose it when finished.

local cmdDescReserve = {
    id      = CMD_RESERVE_RESOURCES,
    name    = 'reserveResources',
    action  = 'reserveResources',
    type    = CMDTYPE.ICON_MODE,
    tooltip = 'Reserve Resources',
    params  = { RESERVE_NONE, 'Reserve: None', 'Reserve: Metal', 'Reserve: All' }
}

-- Each build denial needs to be memoized to speed up g:AllowBuildStep.
-- It is otherwise too mighty a resource drain evn to consider using;
-- and will have to be replaced if this proof of concept is at all liked.
-- We also can't afford to re-fetch each team's resources 1000x per frame.

local unitBuildMemo = {}
local resourcesMemo = {}
local gameFrame = 0

-- Thinking along similar lines, we also suspend the gadget after inactivity.
-- The actual feature we want is ponderously slow for the number of calls used.

local gadgetSuspended = true
local gameFrameSuspend = 0

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function restartTracking()
    for ii, teamID in pairs(teamList) do
        -- Memoization tables use a metatable with weak values.
        local teamBuildMemo = {}
        local teamResrcMemo = {}
        setmetatable(teamBuildMemo, { __mode = "v" })

        -- Each team tracks builds and resources separately.
        reservedTeams[teamID] = {} -- { unitID = { mcost, ecost, brem, level } }
        unitBuildMemo[teamID] = teamBuildMemo -- { unitID = frameEndDisallow }
        resourcesMemo[teamID] = teamResrcMemo -- { metal, energy, msent, esent }
        setmetatable(resourcesMemo, { __mode = "v" })
        reservedMetal[teamID] = 0
        reservedEnergy[teamID] = 0
    end
    reservedUnits = {}
end

local function updateResources(teamID)
    metal,  _, _, _, _, _, msent = spGetTeamResources(teamID, "metal")
    energy, _, _, _, _, _, esent = spGetTeamResources(teamID, "energy")
    local result = { metal, energy, msent, esent }
    resourcesMemo[teamID] = result
    return result
end

local setGadgetActivation -- Fix lexical scoping for cyclical reference, below.

local function allowBuildStep(unitID, unitDefID, teamID, part)
    -- Not through works but by the grace of the garbage collector alone:
    local rsrc = resourcesMemo[teamID] or updateResources(teamID)
    local metal, energy, msent, esent = rsrc[1], rsrc[2], rsrc[3], rsrc[4]

    -- Always prioritize build progress during overflow.
    if msent > 0 and (esent > 0 or reservedEnergy[teamID] < 1) then
        return true
    end

    -- Otherwise, check if the spend is within the resource reserve level.
    local unitDef = unitDefsTable[unitDefID]
    if metal - unitDef.metalCost * part < reservedMetal[teamID] or
        energy - unitDef.energyCost * part < reservedEnergy[teamID]
    then
        -- Denying a build step also blocks further steps for a time:
        unitBuildMemo[teamID][unitID] = gameFrame + updateTime
        return false
    else
        return true
    end
end

local function allowCommand(unitID, unitDefID, teamID, cmdParams)
    local index = spFindUnitCmdDesc(unitID, CMD_RESERVE_RESOURCES)
    local cmdDesc = spGetUnitCmdDescs(unitID, index, index)[1]
    local oldLevel = tonumber(cmdDesc.params[1])
    local newLevel = cmdParams[1]
    if newLevel ~= oldLevel then
        -- Update the unit's command state.
        cmdDesc.params[1] = newLevel
        spEditUnitCmdDesc(unitID, index, cmdDesc)

        -- Update the reserves tracking.
        local remaining = 1 - (select(5, spGetUnitHealth(unitID)))
        local unitDef = unitDefsTable[unitDefID]
        local mcost = unitDef.metalCost * remaining
        local ecost = unitDef.energyCost * remaining

        -- This gets redone in GameFrame, so we don't need to be dead-on.
        -- Get this close enough to continue its function and move along.
        if trackMetal[newLevel] then
            reservedUnits[unitID] = true
            reservedTeams[teamID][unitID] = { mcost, ecost, remaining, newLevel }
            if not trackMetal[oldLevel] then
                reservedMetal[teamID] = reservedMetal[teamID] + mcost
            end
            if trackEnergy[newLevel] and not trackEnergy[oldLevel] then
                reservedEnergy[teamID] = reservedEnergy[teamID] + ecost
            end
            -- Hook back into the call-ins that make the gadget work:
            if gadgetSuspended == true then
                setGadgetActivation(true) -- !
            end
        else
            reservedUnits[unitID] = nil
            reservedTeams[teamID][unitID] = nil
            reservedMetal[teamID] = math.max(0, reservedMetal[teamID] - mcost)
            if trackEnergy[oldLevel] then
                reservedEnergy[teamID] = math.max(0, reservedEnergy[teamID] - ecost)
            end
        end
        return false -- consume command
    end
    return true -- continue processing
end

-- Removable call-ins ----------------------------------------------------------

---Every factory, nano, constructor, and ressurector is going to call this, every frame.
---All possible optimization has to be considered, especially to remove this entirely.
local function active_AllowUnitBuildStep(self, buildID, buildTeam, unitID, unitDefID, part)
    -- Using reservedUnits[unitID] instead of reservedTeams[teamID][unitID] is fast
    -- at the cost of adding a sneaky bad behavior: Players can "reserve" a build
    -- so that their allies assisting them drain resources into it, rather than
    -- respecting their own reserve orders. Is this manipulative? Or correct?
    if part > 0 and reservedMetal[buildTeam] > 0 and not reservedUnits[unitID] then
        local denyUntil = unitBuildMemo[buildTeam][unitID]
        if denyUntil ~= nil and denyUntil >= gameFrame then
            return false -- disallow
        else
            return allowBuildStep(unitID, unitDefID, buildTeam, part)
        end
    else
        return true -- allow
    end
end

local function active_GameFrame(self, frame)
    gameFrame = frame

    -- Recalculate team resources and reserves.
    for _, teamID in pairs(teamList) do
        if (frame + 7 * teamID) % updateTime == 0 then
            local metal, energy = 0, 0
            for unitID, unitData in pairs(reservedTeams[teamID]) do
                local remaining = 1 - (select(5, spGetUnitHealth(unitID)))
                metal = metal + unitData[1] * remaining
                if level == RESERVE_FULL then
                    energy = energy + unitData[2] * remaining
                end
            end
            reservedMetal[teamID] = metal
            reservedEnergy[teamID] = energy
        end
        -- Probably better to deal with volatility nicely, like so:
        updateResources(teamID)
    end

    -- Attempt to suspend the gadget.
    if frame >= gameFrameSuspend then
        gameFrameSuspend = frame + 10 * updateTime
        for _, teamID in pairs(teamList) do
            if reservedMetal[teamID] > 0 then
                -- Gadget needs to remain active.
                return
            end
        end
        -- Remove active call-ins:
        setGadgetActivation(false) -- !
    end
end

---When no players have a construction reserved,
---cull the AllowUnitBuildStep and GameFrame call-ins.
setGadgetActivation = function (activate)
    if activate == true and gadgetSuspended == true then
        gadget.AllowUnitBuildStep = active_AllowUnitBuildStep
        gadget.GameFrame = active_GameFrame
        gadgetHandler:UpdateCallIn("AllowUnitBuildStep", gadget)
        gadgetHandler:UpdateCallIn("GameFrame", gadget)

        gadgetSuspended = false
        gameFrameSuspend = gameFrame + 10 * updateTime
        restartTracking()

    elseif activate == false and gadgetSuspended == false then
        gadget.AllowUnitBuildStep = nil
        gadget.GameFrame = nil
        gadgetHandler:UpdateCallIn("AllowUnitBuildStep", gadget)
        gadgetHandler:UpdateCallIn("GameFrame", gadget)

        gadgetSuspended = true
        gameFrameSuspend = 0
        restartTracking()
    end
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    gameFrame = Spring.GetGameFrame() or 0
    gameFrameSuspend = gameFrame + 10 * updateTime
    restartTracking()

    for _, unitID in ipairs(Spring.GetAllUnits()) do
        local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
        if buildProgress < 1 then
            gadget:UnitCreated(unitID)
        end
    end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_RESERVE_RESOURCES then
        return allowCommand(unitID, unitDefID, teamID, cmdParams)
    else
        return true -- continue processing
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	spInsertUnitCmdDesc(unitID, cmdDescReserve)
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
    spRemoveUnitCmdDesc(unitID, cmdDescReserve)
    reservedUnits[unitID] = nil
    reservedTeams[teamID][unitID] = nil
end

function gadget:MetaUnitRemoved(unitID, unitDefID, teamID)
    reservedUnits[unitID] = nil
    reservedTeams[teamID][unitID] = nil
end

function gadget:TeamDied(teamID)
    teamList = Spring.GetTeamList()
    unitBuildMemo[teamID] = nil
    reservedTeams[teamID] = nil
    reservedMetal[teamID] = 0
    reservedEnergy[teamID] = 0
end

function gadget:TeamChanged(teamID)
	teamList = Spring.GetTeamList()
end

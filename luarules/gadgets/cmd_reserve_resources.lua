function gadget:GetInfo()
	return {
		name    = "Reserve Resources Command",
		desc    = "Reserves the cost of incomplete units to deny over-spending",
		author  = "efrec",
        version = "pre-alpha (for suckers)",
		date    = "2024",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local updateTime = 1.0 -- in seconds

--------------------------------------------------------------------------------
-- Globals and imports ---------------------------------------------------------

VFS.Include('luarules/configs/customcmds.h.lua')

local spGetTeamResources  = Spring.GetTeamResources
local spGetUnitHealth     = Spring.GetUnitHealth

local spGetUnitCmdDescs   = Spring.GetUnitCmdDescs
local spEditUnitCmdDesc   = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc

--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

updateTime = math.ceil(Game.gameSpeed * updateTime - 1)

local RESERVE_NONE, RESERVE_METAL, RESERVE_FULL = "0", "1", "2"
local trackMetal = {
    [RESERVE_METAL] = true,
    [RESERVE_FULL] = true,
}
local trackEnergy = {
    [RESERVE_FULL] = true,
}

-- Keep track of each team's reserved units, metal, and energy.

local teamList = Spring.GetTeamList()

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
    params  = { 0, 'Reserve: None', 'Reserve: Metal', 'Reserve: All' }
}

-- Each build denial needs to be memoized to speed up g:AllowBuildStep.
-- It is otherwise too mighty a resource drain to consider using.
-- Thinking along similar lines, we also suspend the gadget after inactivity.

local unitBuildMemo = {}
local gadgetSuspended = true
local gameFrame = 0
local gameFrameSuspend = 0

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local setGadgetActivation -- Fix lexical scoping for cyclical reference, below.

local function allowBuildStep(unitID, unitDefID, teamID, part)
    if not reservedUnits[teamID][unitID] then
        local m, mstore, mpull, mgain, mlose, mshare, msent, mrcvd = spGetTeamResources(teamID, "metal")
        local e, estore, epull, egain, elose, eshare, esent, ercvd = spGetTeamResources(teamID, "energy")

        -- Always prioritize build progress during overflow.
        if msent > 0 and (esent > 0 or reservedEnergy[teamID] < 1) then
            return true
        end

        -- Otherwise, check if the spend is within the resource reserve level.
        local mreserve = reservedMetal[teamID]
        local ereserve = reservedEnergy[teamID]

        local unitDef = UnitDefs[unitDefID]
        local mcost = unitDef.metalCost * part
        local ecost = unitDef.energyCost * part

        if mstore < mreserve or m - mcost < mreserve or
            estore < ereserve or e - ecost < ereserve
        then
            unitBuildMemo[teamID][unitID] = gameFrame + updateTime
            return false
        end
    end
    return true
end

local function allowCommand(unitID, unitDefID, teamID, cmdParams)
    local index = spFindUnitCmdDesc(unitID, CMD_RESERVE_RESOURCES)
    local cmdDesc = spGetUnitCmdDescs(unitID, index, index)[1]
    local oldLevel = cmdDesc.params[1]
    local newLevel = string.format("%.0f", cmdParams[1])
    if newLevel ~= oldLevel then
        -- Update the unit's command state.
        cmdDesc.params[1] = newLevel
        spEditUnitCmdDesc(unitID, index, cmdDesc)

        -- Update the reserves tracking.
        local remaining = 1 - (select(5, spGetUnitHealth(unitID)))
        local unitDef = UnitDefs[unitDefID]
        local mcost = unitDef.metalCost * remaining
        local ecost = unitDef.energyCost * remaining

        -- This gets redone in GameFrame, so we don't need to be dead-on.
        -- Get this close enough to continue its function and move along.
        if trackMetal[newLevel] then
            reservedUnits[teamID][unitID] = { mcost, ecost, remaining, newLevel }
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
            reservedUnits[teamID][unitID] = nil
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

local function active_AllowUnitBuildStep(self, buildID, buildTeam, unitID, unitDefID, part)
    if part > 0 and reservedMetal[buildTeam] > 0 then
        local denyUntil = unitBuildMemo[buildTeam][unitID]
        if denyUntil and denyUntil >= gameFrame then
            return false -- disallow
        else
            return allowBuildStep(unitID, unitDefID, buildTeam, part)
        end
    end
    return true -- allow
end

local function active_GameFrame(self, frame)
    gameFrame = frame
    for _, teamID in pairs(teamList) do
        if (frame + 7 * teamID) % updateTime == 0 then
            local metal, energy = 0, 0
            for unitID, unitData in pairs(reservedUnits[teamID]) do
                local mcost, ecost, remaining, level = unpack(unitData)
                metal = metal + mcost
                if level == RESERVE_FULL then
                    energy = energy + ecost
                end
            end
            reservedMetal[teamID] = metal
            reservedEnergy[teamID] = energy
        end
    end
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
    elseif activate == false and gadgetSuspended == false then
        gadget.AllowUnitBuildStep = nil
        gadget.GameFrame = nil
        gadgetHandler:UpdateCallIn("AllowUnitBuildStep", gadget)
        gadgetHandler:UpdateCallIn("GameFrame", gadget)
        gadgetSuspended = true
        gameFrameSuspend = 0
    end
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    gameFrame = Spring.GetGameFrame() or 0
    gameFrameSuspend = gameFrame + 10 * updateTime

    for ii, teamID in pairs(teamList) do
        -- Memoization tables use a metatable with weak values.
        local teamBuildMemo = {}
        setmetatable(teamBuildMemo, { __mode = "v" })

        -- Each team tracks builds and resources separately.
        reservedUnits[teamID] = {} -- unitID => { mcost, ecost, remaining, level }
        unitBuildMemo[teamID] = teamBuildMemo -- unitID => frameEndDisallow
        reservedMetal[teamID] = 0
        reservedEnergy[teamID] = 0
    end

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
    reservedUnits[teamID][unitID] = nil
end

-- These could be removable call-ins, as well:

function gadget:MetaUnitRemoved(unitID, unitDefID, teamID)
    reservedUnits[teamID][unitID] = nil
end

function gadget:TeamDied(teamID)
    unitBuildMemo[teamID] = nil
    reservedUnits[teamID] = nil
    reservedMetal[teamID] = 0
    reservedEnergy[teamID] = 0
end

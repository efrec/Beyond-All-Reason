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

-- TODO @efrec
-- + make a buffer of disallowed constructions
-- + and gradually build up its allowed-ness, resetting on an allow
-- + so that a million commands can be at least a little memoized

--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local updateTime = 0.5

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

updateTime = math.floor(Game.gameSpeed * updateTime)

local RESERVE_NONE, RESERVE_METAL, RESERVE_FULL = "0", "1", "2"
local PREVENT_NONE, PREVENT_STALL, PREVENT_FULL = "0", "1", "2"

local trackMetal = {
    [RESERVE_METAL] = true,
    [RESERVE_FULL] = true,
}
local trackEnergy = {
    [RESERVE_FULL] = true,
}

-- Keep track of player preferences and reserved units, metal, and energy.

local teamList = Spring.GetTeamList()
local teamPrevent = {}
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

local gameFrame = 0
local unitBuildMemo = {}

--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local function allowBuildStep(unitID, unitDefID, teamID, part)
    if not reservedUnits[teamID][unitID] then
        local m, mstore, mpull, mgain, mlose, mshare, msent, mrcvd = spGetTeamResources(teamID, "metal")
        local e, estore, epull, egain, elose, eshare, esent, ercvd = spGetTeamResources(teamID, "energy")

        -- Always prioritize build progress during overflow.
        if msent > 0 and (esent > 0 or reservedEnergy[teamID] < 1) then
            unitBuildMemo[teamID][unitID] = nil
            return true
        end

        -- Otherwise, check if the spend is within the resource reserve level.
        -- Use the team's prevention level to determine when to deny spending.
        local prevent = teamPrevent[teamID]
        local mreserve = reservedMetal[teamID]
        local ereserve = reservedEnergy[teamID]

        local unitDef = UnitDefs[unitDefID]
        local mcost = unitDef.metalCost * part
        local ecost = unitDef.energyCost * part

        if prevent == PREVENT_FULL then
            if mstore < mreserve or m - mcost < mreserve or
                estore < ereserve or e - ecost < ereserve
            then
                unitBuildMemo[teamID][unitID] = gameFrame + updateTime
                return false
            end
        elseif prevent == PREVENT_STALL then
            local mrate = mgain - mlose + (mrcvd - msent) * 0.5
            local erate = egain - elose + (ercvd - esent) * 0.5
            -- This is somehow even more lazily concepted:
            if mstore < mreserve * 0.5 or m + mrate * updateTime * 2 < mreserve or
                estore < ereserve * 0.5 or e + erate * updateTime * 2 < ereserve
            then
                unitBuildMemo[teamID][unitID] = gameFrame + updateTime
                return false
            end
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
        Spring.Echo('[reserve] amount remaining', remaining)
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
            Spring.Echo('[reserve] after add: ', newLevel, oldLevel, reservedMetal[teamID], reservedEnergy[teamID])
        else
            reservedUnits[teamID][unitID] = nil
            reservedMetal[teamID] = math.max(0, reservedMetal[teamID] - mcost)
            if trackEnergy[oldLevel] then
                reservedEnergy[teamID] = math.max(0, reservedEnergy[teamID] - ecost)
            end
            Spring.Echo('[reserve] after remove: ', newLevel, oldLevel, reservedMetal[teamID], reservedEnergy[teamID])
        end
        return false -- consume command
    end
    return true -- continue processing
end

--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
    gameFrame = Spring.GetGameFrame() or 0

    for ii, teamID in pairs(teamList) do
        -- Memoization tables use a metatable with weak values.
        local teamBuildMemo = {}
        setmetatable(teamBuildMemo, { __mode = "v" })

        -- Each team tracks builds and resources separately.
        teamPrevent[teamID] = PREVENT_FULL
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

function gadget:GameFrame(frame)
    gameFrame = frame
    for ii, teamID in pairs(teamList) do
        local prevent = teamPrevent[teamID]
        if prevent and prevent ~= PREVENT_NONE and frame % (teamID + updateTime) == 0 then
            -- Recalculate the team's reserve quotas.
            -- We cannot do this incrementally; can't, shan't, won't.
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
end

---On reclaim, `part` values are negative. On resurrect, they are positive, those values
---being representative of the amount the target will be un-built or re-built per frame.
function gadget:AllowUnitBuildStep(buildID, buildTeam, unitID, unitDefID, part)
    if part > 0 and reservedMetal[buildTeam] > 0 then
        if unitBuildMemo[buildTeam][unitID] and
            unitBuildMemo[buildTeam][unitID] >= gameFrame
        then
            return false -- disallow
        else
            return allowBuildStep(unitID, unitDefID, buildTeam, part)
        end
    end
    return true -- allow
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

function gadget:MetaUnitRemoved(unitID, unitDefID, teamID)
    reservedUnits[teamID][unitID] = nil
end

function gadget:TeamDied(teamID)
    teamPrevent[teamID] = nil
    reservedUnits[teamID] = nil
    reservedMetal[teamID] = 0
    reservedEnergy[teamID] = 0
end

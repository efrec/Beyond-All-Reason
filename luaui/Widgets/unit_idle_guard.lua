local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Idle Constructor Guard After Build",
		desc    = "Constructors guard factories after building if they have nothing to do afterwards",
		author  = "TheFutureKnight",
		date    = "2025-1-27",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true
	}
end

local CMD_GUARD             = CMD.GUARD
local OPT_SHIFT             = CMD.OPT_SHIFT
local spGetMyTeamID         = Spring.GetMyTeamID
local spGiveOrderToUnit     = Spring.GiveOrderToUnit
local spGetUnitsInSphere    = Spring.GetUnitsInSphere
local spGetUnitDefID        = Spring.GetUnitDefID
local validGuardingBuilders = Game.UnitInfo.Cache.isConstructionUnit
local isFactory             = Game.UnitInfo.Cache.isFactory

function widget:UnitCmdDone(unitID, unitDefID, unitTeam,
														cmdID, cmdParams, _, _)
	if not validGuardingBuilders[unitDefID] then return end
	local isRepair = (cmdID == CMD.REPAIR)
	if not (isRepair or cmdID < 0) then return end
	if unitTeam ~= spGetMyTeamID() then return end
	if Spring.GetUnitCommandCount(unitID) > 0 then return end
	if not isFactory[-cmdID] and not isFactory[spGetUnitDefID(cmdParams[1])] then return end

	if isRepair then
		spGiveOrderToUnit(unitID, CMD_GUARD, cmdParams[1], OPT_SHIFT)
		return
	end

	local candidateUnits = spGetUnitsInSphere(cmdParams[1], cmdParams[2], cmdParams[3], 50)
	for _, candidateUnitID in ipairs(candidateUnits) do
		if spGetUnitDefID(candidateUnitID) == -cmdID then
			spGiveOrderToUnit(unitID, CMD_GUARD, candidateUnitID, OPT_SHIFT)
			break
		end
	end
end

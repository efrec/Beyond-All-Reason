local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function transferUnits(unitName, newTeam, captured)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	-- Copying table as UnitExists trigger with TransferUnits with the same name could cause infinite loop.
	local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])

	local newAllyTeamID = Spring.GetTeamAllyTeamID(newTeam)

	GG['MissionAPI'].transferringUnits = true
	for unitID in pairs(trackedUnitIDs) do
		-- Gift units to allies even with captured=true to comply with sharing rules.
		local given = Spring.GetUnitAllyTeam(unitID) == newAllyTeamID
		GG['MissionAPI'].capturingUnits = captured
		Spring.TransferUnit(unitID, newTeam, given)
		GG['MissionAPI'].capturingUnits = nil
	end
	GG['MissionAPI'].transferringUnits = nil
end

return {
	---Gives the units with a name to another team.
	---
	---The units keep their names. UnitCaptured and UnitReceived triggers ignore this action unless they set ignoreMissionActions = false; then captured decides which of the two fires. Nothing happens when no unit has the name.
	---@class TransferUnitsAction
	---@field unitName UnitName The name whose units change hands.
	---@field newTeam TeamID The team that receives the units.
	---@field captured? Boolean Whether the transfer counts as a capture rather than a gift.
	---@default captured false
	{
		type = 'TransferUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'newTeam', required = true, type = ParameterTypes.TeamID },
			{ name = 'captured', required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = transferUnits,
	}
}

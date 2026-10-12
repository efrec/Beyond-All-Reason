local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function unnameUnits(unitName)
	local tracking = GG['MissionAPI'].Modules.Tracking
	tracking.UntrackUnitName(unitName)
end

return {
	---Removes a name from every unit that has it.
	---
	---The units stay in the game and keep any other names they hold. Afterwards, actions and triggers that refer to the name match nothing until units are named with it again.
	---@class UnnameUnitsAction
	---@field unitName UnitName The name to remove.
	{
		type = 'UnnameUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = unnameUnits,
	}
}

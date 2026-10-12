local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setSelectable(unitName, selectable)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

	local noSelect = not selectable
	for unitID in pairs(GG['MissionAPI'].trackedUnitIDs[unitName]) do
		Spring.SetUnitNoSelect(unitID, noSelect)
	end
end

return {
	---Allows or forbids the player to select the units with a name.
	---
	---Unselectable units cannot be picked or given orders by the player, but they still obey orders from the mission. The setting applies to the units that have the name when the action runs; units named later are unaffected until the action runs again. Nothing happens when no unit has the name.
	---@class UnitSelectableAction
	---@field unitName UnitName The name whose units are affected.
	---@field selectable Boolean true lets the player select the units, and false prevents it.
	{
		type = 'UnitSelectable',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'selectable', required = true, type = ParameterTypes.Boolean },
		},
		actionFunction = setSelectable,
	}
}

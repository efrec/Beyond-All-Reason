local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local tracking = GG['MissionAPI'].Modules.Tracking

local function setTargetable(unitName, targetable)
	if tracking.IsUnitNameUntracked(unitName) then return end
	GG.SetUnitUntargetable(GG['MissionAPI'].trackedUnitIDs[unitName], not targetable)
end

return {
	---Allows or forbids enemies to target the units with a name.
	---
	---Untargetable units are not fired on automatically and cannot be given a direct attack order, though ground and area attacks can still hit them. The setting applies to the units that have the name when the action runs; units named later are unaffected until the action runs again. Nothing happens when no unit has the name.
	---@class UnitTargetableAction
	---@field unitName UnitName The name whose units are affected.
	---@field targetable Boolean true lets enemies target the units, and false protects them.
	{
		type = 'UnitTargetable',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'targetable', required = true, type = ParameterTypes.Boolean },
		},
		actionFunction = setTargetable,
	}
}

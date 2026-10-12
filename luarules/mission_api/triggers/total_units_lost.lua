local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Statistics trigger: evaluated by the centralized statistics engine in
-- api_missions_triggers.lua (shared counting + managed objectives), so it
-- declares no callins.

---Fires when the number of units a team has lost since the mission started, destroyed for any reason, reaches the quantity, and again at every further multiple of it while repeating.
---
---As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.
---@class TotalUnitsLostTrigger
---@field teamID TeamID The team that loses the units.
---@field quantity Quantity Count at which to fire; while repeating, it fires again at every further multiple of this count.
---@field unitName? UnitName Count only the lost unit with this name.
---@field unitDefName? UnitDefName Count only lost units of this unit definition.

return {
	type = 'TotalUnitsLost',
	parameters = {
		{ name = 'teamID',      required = true,  type = ParameterTypes.TeamID },
		{ name = 'quantity',    required = true,  type = ParameterTypes.Quantity },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}

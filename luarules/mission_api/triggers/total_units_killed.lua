local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Statistics trigger: evaluated by the centralized statistics engine in
-- api_missions_triggers.lua (shared counting + managed objectives), so it
-- declares no callins.

---Fires when the number of enemy units a team has destroyed since the mission started reaches the quantity, and again at every further multiple of it while repeating. Destroyed allied units do not count.
---
---As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.
---@class TotalUnitsKilledTrigger
---@field teamID TeamID The team that destroys the units.
---@field quantity Quantity Count at which to fire; while repeating, it fires again at every further multiple of this count.
---@field unitName? UnitName Count only the destroyed unit with this name.
---@field unitDefName? UnitDefName Count only destroyed units of this unit definition.

return {
	type = 'TotalUnitsKilled',
	parameters = {
		{ name = 'teamID',      required = true,  type = ParameterTypes.TeamID },
		{ name = 'quantity',    required = true,  type = ParameterTypes.Quantity },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}

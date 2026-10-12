local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Statistics trigger: evaluated by the centralized statistics engine in
-- api_missions_triggers.lua (shared counting + managed objectives), so it
-- declares no callins.

---Fires when the number of units a team has completed since the mission started reaches the quantity, and again at every further multiple of it while repeating. Units spawned by the mission and the team's starting units do not count.
---
---As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.
---@class TotalUnitsBuiltTrigger
---@field teamID TeamID The team whose completed units are counted.
---@field quantity Quantity Count at which to fire; while repeating, it fires again at every further multiple of this count.
---@field unitDefName? UnitDefName Count only units of this unit definition.

return {
	type = 'TotalUnitsBuilt',
	parameters = {
		{ name = 'teamID',      required = true,  type = ParameterTypes.TeamID },
		{ name = 'quantity',    required = true,  type = ParameterTypes.Quantity },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}

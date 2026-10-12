local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Statistics trigger: evaluated by the centralized statistics engine in
-- api_missions_triggers.lua (shared counting + managed objectives), so it
-- declares no callins.

---Fires when the number of matching units a team owns rises to the quantity, and again at every further multiple of it while repeating, or, with a quantity of 0, when the count falls to zero. Units count from the moment their construction starts, and units given to or captured by the team count as well.
---
---As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.
---@class UnitsOwnedTrigger
---@field teamID TeamID The team whose units are counted.
---@field quantity Quantity Count at which to fire; while repeating, it fires again at every further multiple of this count. A quantity of 0 fires when the team has none left.
---@field unitName? UnitName Count only the unit with this name.
---@field unitDefName? UnitDefName Count only units of this unit definition.

return {
	type = 'UnitsOwned',
	parameters = {
		{ name = 'teamID',      required = true,  type = ParameterTypes.TeamID },
		{ name = 'quantity',    required = true,  type = ParameterTypes.Quantity },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	},
}

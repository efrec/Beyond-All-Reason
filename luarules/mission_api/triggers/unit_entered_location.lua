local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires each time a matching unit enters an area, once per unit that enters.
---
---Units already inside the area when the mission starts count as entering on the first game frame.
---@class UnitEnteredLocationTrigger
---@field area Area The area to watch, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos.
---@field unitName? UnitName Only the unit with this name.
---@field unitDefName? UnitDefName Only units of this unit definition.
---@field teamID? TeamID Only units owned by this team.
---@requiresOneOf unitName unitDefName

return {
	type = 'UnitEnteredLocation',
	parameters = {
		-- Rectangle: { x1 = 0, z1 = 0, x2 = 123, z2 = 123 } with x1 < x2 and z1 < z2
		-- Circle: { x = 0, z = 0, radius = 123 }
		{ name = 'area',        required = true,  type = ParameterTypes.Area },
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		GameFrame = function(trigger, triggerID, context)
			local previousUnitsInAreas = context.PreviousUnitsInAreas
			local unitsInArea = context.GetUnitsInArea(trigger)

			local unitsEnteredArea = table.filterArray(unitsInArea, function(unitID)
				return not table.contains(previousUnitsInAreas[triggerID] or {}, unitID)
					and (not trigger.parameters.unitName or context.DoesUnitHaveName(unitID, trigger.parameters.unitName))
					and (not trigger.parameters.unitDefName or UnitDefs[Spring.GetUnitDefID(unitID)].name == trigger.parameters.unitDefName)
			end)
			previousUnitsInAreas[triggerID] = unitsInArea

			for _, unitID in ipairs(unitsEnteredArea) do
				context.ActivateTrigger(trigger)
			end
		end,
	},
}

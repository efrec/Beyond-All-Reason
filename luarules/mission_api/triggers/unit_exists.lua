local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a unit of the given definition appears, including when its construction starts, or when one is given to or captured by a team.
---@class UnitExistsTrigger
---@field unitDefName UnitDefName The unit definition to watch.
---@field teamID? TeamID Only units owned by this team.

return {
	type = 'UnitExists',
	parameters = {
		{ name = 'unitDefName', required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
	},
	callins = {
		MetaUnitAdded = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if trigger.parameters.unitDefName and trigger.parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if trigger.parameters.teamID and unitTeam ~= trigger.parameters.teamID then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}

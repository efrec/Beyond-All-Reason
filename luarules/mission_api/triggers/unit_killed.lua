local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a matching unit is destroyed for any reason.
---@class UnitKilledTrigger
---@field unitName? UnitName Only the destroyed unit with this name.
---@field unitDefName? UnitDefName Only destroyed units of this unit definition.
---@field teamID? TeamID Only destroyed units owned by this team.
---@requiresOneOf unitName unitDefName

return {
	type = 'UnitKilled',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if trigger.parameters.unitName and not context.DoesUnitHaveName(unitID, trigger.parameters.unitName) then
				return
			end
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

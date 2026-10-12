local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a matching unit leaves a team's possession, whether destroyed, given away, or captured.
---@class UnitNotExistsTrigger
---@field unitName? UnitName Only the unit with this name.
---@field unitDefName? UnitDefName Only units of this unit definition.
---@field teamID? TeamID Only units that were owned by this team.
---@requiresOneOf unitName unitDefName

return {
	type = 'UnitNotExists',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		MetaUnitRemoved = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
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

local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a unit that was under construction is completed. Units that enter the mission already complete do not count.
---@class ConstructionFinishedTrigger
---@field unitName? UnitName Only the completed unit with this name.
---@field unitDefName? UnitDefName Only completed units of this unit definition.
---@field teamID? TeamID Only completed units owned by this team.
---@requiresOneOf unitName unitDefName

return {
	type = 'ConstructionFinished',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitFinished = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not context.WasUnderConstruction[unitID] then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
				return
			end
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamID and parameters.teamID ~= unitTeam then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}

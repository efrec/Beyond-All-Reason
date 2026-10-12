local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- For buildings or units placed by constructors, see ConstructionStarted.

---Fires when a factory starts producing a unit of the given definition. Units placed by constructors are covered by ConstructionStarted instead.
---@class ProductionStartedTrigger
---@field unitDefName UnitDefName The unit definition being produced.
---@field teamID? TeamID Only production for this team.
---@field factoryName? UnitName Only production at the factory with this name.
---@field factoryDefName? UnitDefName Only production at factories of this unit definition.

return {
	type = 'ProductionStarted',
	parameters = {
		{ name = 'unitDefName',    required = true,  type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'factoryName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'factoryDefName', required = false, type = ParameterTypes.UnitDefName },
	},
	callins = {
		UnitCreated = function(trigger, triggerID, context, unitID, unitDefID, unitTeam, builderID)
			-- Spawning in-factory and completed seems possible, so this catches any odd scenarios:
			if not builderID or not Spring.GetUnitIsBeingBuilt(unitID) then
				return
			end

			local builderDef = UnitDefs[Spring.GetUnitDefID(builderID)]
			if not builderDef.isFactory then
				return
			end

			local parameters = trigger.parameters
			if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
				return
			end
			if parameters.teamID and parameters.teamID ~= unitTeam then
				return
			end
			if parameters.factoryName and not context.DoesUnitHaveName(builderID, parameters.factoryName) then
				return
			end
			if parameters.factoryDefName and parameters.factoryDefName ~= builderDef.name then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}

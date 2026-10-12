local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local DAMAGETYPE_FACTORY_CANCEL = Game.envDamageTypes.FactoryCancel
local DAMAGETYPE_FACTORY_KILLED = Game.envDamageTypes.FactoryKilled -- Kills current buildee, which might be completed. Oy vey.

local function matchesUnit(trigger, context, unitID, unitDefID, unitTeam)
	local parameters = trigger.parameters
	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.teamID and parameters.teamID ~= unitTeam then
		return false
	end
	if not context.IsBuildFrameOwner(unitID, parameters.factoryName, parameters.factoryDefName) then
		return false
	end
	return true
end

---Fires when a unit in production at a factory is removed before it is finished, whether its order is canceled, its factory is destroyed, or it is captured. Units built by constructors are covered by ConstructionCanceled instead.
---@class ProductionCanceledTrigger
---@field unitName? UnitName Only the unit in production with this name.
---@field unitDefName? UnitDefName Only units in production of this unit definition.
---@field teamID? TeamID Only units in production owned by this team.
---@field factoryName? UnitName Only units produced by the factory with this name.
---@field factoryDefName? UnitDefName Only units produced by factories of this unit definition.
---@requiresOneOf unitName unitDefName

return {
	type = 'ProductionCanceled',
	parameters = {
		{ name = 'unitName',       required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName',    required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'factoryName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'factoryDefName', required = false, type = ParameterTypes.UnitDefName },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		UnitDestroyed = function(trigger, triggerID, context, unitID, unitDefID, unitTeam,
		                         attackerID, attackerDefID, attackerTeam, weaponDefID)
			if weaponDefID ~= DAMAGETYPE_FACTORY_CANCEL and (weaponDefID ~= DAMAGETYPE_FACTORY_KILLED or not Spring.GetUnitIsBeingBuilt(unitID)) then
				return
			end

			if matchesUnit(trigger, context, unitID, unitDefID, unitTeam) then
				context.ActivateTrigger(trigger)
			end
		end,

		-- Units captured while inside a factory are not canceled. Keep this so mission authors do not have to know
		-- about the engine's split decision-making for canceling units when a factory vs its buildee is captured.
		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam)
			if not Spring.GetUnitIsBeingBuilt(unitID) or not context.InFactory(unitID) then
				return
			end

			if matchesUnit(trigger, context, unitID, unitDefID, oldTeam) then
				context.ActivateTrigger(trigger)
			end
		end,
	},
}

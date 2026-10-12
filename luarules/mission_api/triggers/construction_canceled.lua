local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Units canceled while in production at a factory belong to `ProductionCanceled`, instead.

-- This is very difficult to track if we mean anything outside "in-progress unit destroyed";
-- nevertheless, this cancels on unit capture to match the behavior of `ProductionCanceled`.

-- Builders can die yet construction does not "cancel" - other builders can finish the unit.
-- Builders can cancel the command, yet may resume it, or keep the command but be in a Wait.

---Fires when a unit being built by a constructor is removed before it is finished, whether destroyed, canceled, or transferred to another team. Units in production at a factory are covered by ProductionCanceled instead.
---
---A constructor that dies or drops its build order does not cancel the construction, since another constructor can still finish the unit.
---@class ConstructionCanceledTrigger
---@field unitName? UnitName Only the unit under construction with this name.
---@field unitDefName? UnitDefName Only units under construction of this unit definition.
---@field teamID? TeamID Only units under construction owned by this team.
---@requiresOneOf unitName unitDefName

return {
	type = 'ConstructionCanceled',
	parameters = {
		{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
		{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
		{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
		requiresOneOf = { 'unitName', 'unitDefName' },
	},
	callins = {
		-- Construction doesn't have the ambiguous decision-making between factory/buildee capture
		-- but we copy the behavior of ProductionCanceled anyway so that this remains unsurprising.
		MetaUnitRemoved = function(trigger, triggerID, context, unitID, unitDefID, unitTeam)
			if not Spring.GetUnitIsBeingBuilt(unitID) or context.InFactory(unitID) then
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

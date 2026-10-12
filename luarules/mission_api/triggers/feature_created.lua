local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a feature, such as a wreck or a map prop, appears.
---@class FeatureCreatedTrigger
---@field featureDefName? FeatureDefName Only features of this feature definition.
---@field area? Area Only features inside this area, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos.
---@requiresOneOf featureDefName area

return {
	type = 'FeatureCreated',
	parameters = {
		{ name = 'featureDefName', required = false, type = ParameterTypes.FeatureDefName },
		{ name = 'area',           required = false, type = ParameterTypes.Area },
		requiresOneOf = { 'featureDefName', 'area' },
	},
	callins = {
		FeatureCreated = function(trigger, triggerID, context, featureID, featureDefID)
			if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
				return
			end
			if trigger.parameters.area and not context.IsFeatureInArea(featureID, trigger.parameters.area) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}

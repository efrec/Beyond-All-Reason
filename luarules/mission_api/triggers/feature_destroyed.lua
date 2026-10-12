local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a feature is destroyed by anything other than being fully reclaimed. Fully reclaimed features are covered by FeatureReclaimed instead.
---@class FeatureDestroyedTrigger
---@field featureName? FeatureName Only the feature with this name.
---@field featureDefName? FeatureDefName Only features of this feature definition.
---@field allyTeamID? AllyTeamID Only features destroyed by this ally team.
---@field area? Area Only features inside this area, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos.
---@requiresOneOf featureName featureDefName allyTeamID area

return {
	type = 'FeatureDestroyed',
	parameters = {
		{ name = 'featureName',    required = false, type = ParameterTypes.FeatureName },
		{ name = 'featureDefName', required = false, type = ParameterTypes.FeatureDefName },
		{ name = 'allyTeamID',     required = false, type = ParameterTypes.AllyTeamID },
		{ name = 'area',           required = false, type = ParameterTypes.Area },
		requiresOneOf = { 'featureName', 'featureDefName', 'allyTeamID', 'area' },
	},
	callins = {
		FeatureDestroyed = function(trigger, triggerID, context, featureID, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)
			-- Skip when the feature was fully reclaimed (handled by FeatureReclaimed):
			if reclaimerTeamID and reclaimLeft <= 0 then
				return
			end

			if trigger.parameters.featureName and not context.DoesFeatureHaveName(featureID, trigger.parameters.featureName) then
				return
			end
			if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
				return
			end
			if trigger.parameters.allyTeamID and attackerAllyTeamID ~= trigger.parameters.allyTeamID then
				return
			end
			if trigger.parameters.area and not context.IsFeatureInArea(featureID, trigger.parameters.area) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}

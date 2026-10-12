local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

---Fires when a feature is fully reclaimed.
---@class FeatureReclaimedTrigger
---@field featureName? FeatureName Only the feature with this name.
---@field featureDefName? FeatureDefName Only features of this feature definition.
---@field teamID? TeamID Only features reclaimed by this team.
---@field area? Area Only features inside this area, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos.
---@requiresOneOf featureName featureDefName teamID area

return {
	type = 'FeatureReclaimed',
	parameters = {
		{ name = 'featureName',    required = false, type = ParameterTypes.FeatureName },
		{ name = 'featureDefName', required = false, type = ParameterTypes.FeatureDefName },
		{ name = 'teamID',         required = false, type = ParameterTypes.TeamID },
		{ name = 'area',           required = false, type = ParameterTypes.Area },
		requiresOneOf = { 'featureName', 'featureDefName', 'teamID', 'area' },
	},
	callins = {
		FeatureDestroyed = function(trigger, triggerID, context, featureID, featureDefID, attackerAllyTeamID, reclaimerTeamID, reclaimLeft)
			-- Feature was fully reclaimed:
			if not (reclaimerTeamID and reclaimLeft <= 0) then
				return
			end

			if trigger.parameters.featureName and not context.DoesFeatureHaveName(featureID, trigger.parameters.featureName) then
				return
			end
			if trigger.parameters.featureDefName and trigger.parameters.featureDefName ~= FeatureDefs[featureDefID].name then
				return
			end
			if trigger.parameters.teamID and reclaimerTeamID ~= trigger.parameters.teamID then
				return
			end
			if trigger.parameters.area and not context.IsFeatureInArea(featureID, trigger.parameters.area) then
				return
			end
			context.ActivateTrigger(trigger)
		end,
	},
}

local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function destroyFeatures(featureName)
	local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsFeatureNameUntracked(featureName) then return end

	local trackedFeatureIDs = table.copy((GG['MissionAPI'].trackedFeatureIDs or {})[featureName] or {})
	for featureID in pairs(trackedFeatureIDs) do
		if Spring.ValidFeatureID(featureID) then
			Spring.DestroyFeature(featureID)
		end
	end
end

return {
	---Destroys every feature currently carrying a mission feature name. Features that no longer exist are skipped.
	---@class DestroyFeaturesAction
	---@field featureName FeatureName The mission feature name of the features to destroy.
	{
		type = 'DestroyFeatures',
		parameters = {
			{ name = 'featureName', required = true, type = ParameterTypes.FeatureName },
		},
		actionFunction = destroyFeatures,
	}
}

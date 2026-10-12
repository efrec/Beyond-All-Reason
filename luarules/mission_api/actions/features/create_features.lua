local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function createFeatures(featureLoadout)
	GG['MissionAPI'].Modules.Loadout.SpawnFeatureLoadout(featureLoadout)
end

return {
	---Spawns features, such as wrecks, rocks, and trees, from a feature loadout. Each entry names a feature definition and a position in elmos; the height is taken from the ground. An entry with a featureName creates that mission feature name for other actions and triggers to refer to.
	---@class CreateFeaturesAction
	---@field featureLoadout FeatureLoadout The features to spawn, each with featureDefName, x, z, and optionally facing and featureName.
	---@declares featureLoadout
	{
		type = 'CreateFeatures',
		parameters = {
			{ name = 'featureLoadout', required = true, type = ParameterTypes.FeatureLoadout },
		},
		actionFunction = createFeatures,
	}
}

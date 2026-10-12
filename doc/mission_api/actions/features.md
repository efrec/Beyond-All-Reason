# Actions: features

Back to the [Mission API index](../index.md).

## CreateFeatures

Spawns features, such as wrecks, rocks, and trees, from a feature loadout. Each entry names a feature definition and a position in elmos; the height is taken from the ground. An entry with a featureName creates that mission feature name for other actions and triggers to refer to.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `featureLoadout` | [FeatureLoadout](../types.md#featureloadout) | Yes |  | The features to spawn, each with featureDefName, x, z, and optionally facing and featureName. |

The value of `featureLoadout` declares a new name that other actions and triggers can refer to.

## DestroyFeatures

Destroys every feature currently carrying a mission feature name. Features that no longer exist are skipped.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `featureName` | [FeatureName](../types.md#featurename) | Yes |  | The mission feature name of the features to destroy. |

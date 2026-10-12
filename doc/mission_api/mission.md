# Mission file format

Back to the [Mission API index](index.md).

## DifficultiesWrapper

A value that depends on the difficulty. Any trigger parameter, action parameter, or objective field other than trigger may be written as { difficulties = { <difficultyName> = <value>, ... } } in place of a plain value. The wrapper replaces the whole value. It cannot be used for a field inside a compound value, such as one entry of a loadout or one field of an area, so the whole parameter is given per difficulty instead. The mission uses the value for the current difficulty, else the value for the nearest easier difficulty given, else the value for the easiest difficulty given.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `difficulties` | `table<Difficulty,any>` | Yes | The value for each difficulty, keyed by difficulty name. At least one entry is required, and every name must be a known difficulty. |

## MissionAction

An action. It is run by the triggers that list its ID.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | `string` | Yes | The name of the action type. |
| `parameters` | `table` | No | The action's parameters, as described by its type. Each parameter may be given per difficulty with a DifficultiesWrapper. |

## MissionFile

A mission. A mission file is a Lua file that returns one of these tables. Every part is optional, but a mission needs at least one trigger to do anything.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `InitialStage` | [StageID](types.md#stageid) | No | The stage the mission starts in. Required when any stages are declared. |
| `Stages` | `table<StageID,MissionStage>` | No | The stages of the mission, keyed by stage ID. |
| `Objectives` | `table<ObjectiveID,MissionObjective>` | No | The objectives of the mission, keyed by objective ID. |
| `Triggers` | `table<TriggerID,MissionTrigger>` | No | The triggers of the mission, keyed by trigger ID. IDs starting with two underscores are reserved. |
| `Actions` | `table<string,MissionAction>` | No | The actions of the mission, keyed by action ID. IDs starting with two underscores are reserved. Every action must be used by at least one trigger. |
| `UnitLoadout` | [UnitLoadout](types.md#unitloadout) | No | Units placed on the map before the game starts. |
| `FeatureLoadout` | [FeatureLoadout](types.md#featureloadout) | No | Features placed on the map before the game starts. |

## MissionObjective

An objective for the player. It completes when its trigger fires enough times, or when an action completes it. Each field except trigger may be given per difficulty with a DifficultiesWrapper.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `textKey` | [String](types.md#string) | Yes | The translation key of the objective's text. |
| `trigger` | [ObjectiveTrigger](mission.md#objectivetrigger) | No | The condition that advances the objective. Without one, the objective only changes through actions. |
| `amount` | [Quantity](types.md#quantity) | No | How much the objective needs to complete. For a counting trigger, the count to reach, where zero means none left. For any other trigger, how many times it must fire. Without an amount, the objective completes the first time. |
| `nextStage` | [StageID](types.md#stageid) | No | The stage to move to once this objective is complete, and every other objective of the current stage with the same next stage is complete too. |
| `coop` | [Boolean](types.md#boolean) | No | Reserved. It has no effect. |
| `hidden` | [Boolean](types.md#boolean) | No | Whether the objective starts hidden from the player. |
| `onActivated` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective becomes active. |
| `onCanceled` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective is canceled. |
| `onProgress` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective advances without completing. |
| `onCompleted` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective completes. It runs before the move to the next stage. |
| `onFailed` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective fails. It runs before the move to the next stage. |
| `onHidden` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective is hidden. |
| `onShown` | [TriggerID](types.md#triggerid) | No | An Event trigger that fires when the objective is shown. |

## MissionStage

A stage of the mission. Entering a stage activates the objectives it lists, and leaving it cancels those that did not finish. An objective listed by both the old and the new stage carries over untouched.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `objectives` | `ObjectiveID[]` | Yes | The objectives that are active during this stage. |

## MissionTrigger

A trigger. When its condition is met and its settings allow it, it runs its actions in order.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | `string` | Yes | The name of the trigger type. |
| `parameters` | `table` | No | The trigger's parameters, as described by its type. Each parameter may be given per difficulty with a DifficultiesWrapper. |
| `settings` | [TriggerSettings](mission.md#triggersettings) | No | When the trigger is allowed to fire. |
| `actions` | `string[]` | Yes | The IDs of the actions to run, in order. At least one is required. |

## ObjectiveTrigger

The condition that advances an objective. It is a trigger with a type and parameters only, so it has no settings and no actions of its own. A counting trigger, one with a quantity parameter, counts toward the objective's amount instead, so its quantity is ignored.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | `string` | Yes | The name of the trigger type. |
| `parameters` | `table` | No | The trigger's parameters, as described by its type. |

## TriggerSettings

The settings that decide whether a trigger may fire. Every setting is optional.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `prerequisites` | `TriggerID[]` | No | Triggers that must have fired before this one may fire. |
| `repeating` | [Boolean](types.md#boolean) | No | Whether the trigger may fire more than once. |
| `maxRepeats` | [Number](types.md#number) | No | How many more times a repeating trigger may fire after its first time. Allowed only when repeating is true. Without it, a repeating trigger fires without limit. |
| `difficulties` | `Difficulty[]` | No | The difficulties on which the trigger may fire. Without it, or with an empty list, the trigger may fire on every difficulty. |
| `coop` | [Boolean](types.md#boolean) | No | Reserved. It has no effect. |
| `active` | [Boolean](types.md#boolean) | No | Whether the trigger starts enabled. A disabled trigger may be enabled by an action. |
| `stages` | `StageID[]` | No | The stages during which the trigger may fire. Without it, or with an empty list, the trigger may fire during any stage. |

## Difficulties

The difficulties are `Story`, `Easy`, `Medium`, and `Hard`, in that order. See [Difficulty](types.md#difficulty).

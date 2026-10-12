---
--- The shape of a mission file, as annotations for the mission reference and the mission editor.
--- This file holds no code and is never loaded by the game.
---

---A mission. A mission file is a Lua file that returns one of these tables. Every part is optional, but a mission needs at least one trigger to do anything.
---@class MissionFile
---@field InitialStage? StageID The stage the mission starts in. Required when any stages are declared.
---@field Stages? table<StageID, MissionStage> The stages of the mission, keyed by stage ID.
---@field Objectives? table<ObjectiveID, MissionObjective> The objectives of the mission, keyed by objective ID.
---@field Triggers? table<TriggerID, MissionTrigger> The triggers of the mission, keyed by trigger ID. IDs starting with two underscores are reserved.
---@field Actions? table<string, MissionAction> The actions of the mission, keyed by action ID. IDs starting with two underscores are reserved. Every action must be used by at least one trigger.
---@field UnitLoadout? UnitLoadout Units placed on the map before the game starts.
---@field FeatureLoadout? FeatureLoadout Features placed on the map before the game starts.

---A stage of the mission. Entering a stage activates the objectives it lists, and leaving it cancels those that did not finish. An objective listed by both the old and the new stage carries over untouched.
---@class MissionStage
---@field objectives ObjectiveID[] The objectives that are active during this stage.

---An objective for the player. It completes when its trigger fires enough times, or when an action completes it. Each field except trigger may be given per difficulty with a DifficultiesWrapper.
---@class MissionObjective
---@field textKey String The translation key of the objective's text.
---@field trigger? ObjectiveTrigger The condition that advances the objective. Without one, the objective only changes through actions.
---@field amount? Quantity How much the objective needs to complete. For a counting trigger, the count to reach, where zero means none left. For any other trigger, how many times it must fire. Without an amount, the objective completes the first time.
---@field nextStage? StageID The stage to move to once this objective is complete, and every other objective of the current stage with the same next stage is complete too.
---@field coop? Boolean Reserved. It has no effect.
---@field hidden? Boolean Whether the objective starts hidden from the player.
---@field onActivated? TriggerID An Event trigger that fires when the objective becomes active.
---@field onCanceled? TriggerID An Event trigger that fires when the objective is canceled.
---@field onProgress? TriggerID An Event trigger that fires when the objective advances without completing.
---@field onCompleted? TriggerID An Event trigger that fires when the objective completes. It runs before the move to the next stage.
---@field onFailed? TriggerID An Event trigger that fires when the objective fails. It runs before the move to the next stage.
---@field onHidden? TriggerID An Event trigger that fires when the objective is hidden.
---@field onShown? TriggerID An Event trigger that fires when the objective is shown.
---@default hidden false

---The condition that advances an objective. It is a trigger with a type and parameters only, so it has no settings and no actions of its own. A counting trigger, one with a quantity parameter, counts toward the objective's amount instead, so its quantity is ignored.
---@class ObjectiveTrigger
---@field type string The name of the trigger type.
---@field parameters? table The trigger's parameters, as described by its type.

---A trigger. When its condition is met and its settings allow it, it runs its actions in order.
---@class MissionTrigger
---@field type string The name of the trigger type.
---@field parameters? table The trigger's parameters, as described by its type. Each parameter may be given per difficulty with a DifficultiesWrapper.
---@field settings? TriggerSettings When the trigger is allowed to fire.
---@field actions string[] The IDs of the actions to run, in order. At least one is required.

---The settings that decide whether a trigger may fire. Every setting is optional.
---@class TriggerSettings
---@field prerequisites? TriggerID[] Triggers that must have fired before this one may fire.
---@field repeating? Boolean Whether the trigger may fire more than once.
---@field maxRepeats? Number How many more times a repeating trigger may fire after its first time. Allowed only when repeating is true. Without it, a repeating trigger fires without limit.
---@field difficulties? Difficulty[] The difficulties on which the trigger may fire. Without it, or with an empty list, the trigger may fire on every difficulty.
---@field coop? Boolean Reserved. It has no effect.
---@field active? Boolean Whether the trigger starts enabled. A disabled trigger may be enabled by an action.
---@field stages? StageID[] The stages during which the trigger may fire. Without it, or with an empty list, the trigger may fire during any stage.
---@default prerequisites {}
---@default repeating false
---@default coop false
---@default active true
---@default stages {}

---An action. It is run by the triggers that list its ID.
---@class MissionAction
---@field type string The name of the action type.
---@field parameters? table The action's parameters, as described by its type. Each parameter may be given per difficulty with a DifficultiesWrapper.

---A value that depends on the difficulty. Any trigger parameter, action parameter, or objective field other than trigger may be written as { difficulties = { <difficultyName> = <value>, ... } } in place of a plain value. The wrapper replaces the whole value. It cannot be used for a field inside a compound value, such as one entry of a loadout or one field of an area, so the whole parameter is given per difficulty instead. The mission uses the value for the current difficulty, else the value for the nearest easier difficulty given, else the value for the easiest difficulty given.
---@class DifficultiesWrapper
---@field difficulties table<Difficulty, any> The value for each difficulty, keyed by difficulty name. At least one entry is required, and every name must be a known difficulty.

# Actions: objectives

Back to the [Mission API index](../index.md).

## ActivateObjective

Makes an objective active so that it can progress and complete.

Nothing happens when the objective is already active or already completed, or when the objective is restricted to stages that do not include the current stage. Activating clears an earlier cancellation and fires the objective's onActivated event trigger.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to activate. |

## CancelObjective

Cancels an objective, deactivating it without completing or failing it.

Nothing happens when the objective is already completed or already canceled. Canceling fires the objective's onCanceled event trigger. A canceled objective can be activated again with ActivateObjective.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to cancel. |

## ChangeStage

Moves the mission to another stage.

Objectives listed by the current stage that are not completed are canceled, except those also listed by the new stage, which continue unchanged. Every other objective listed by the new stage is activated. Changing to the stage that is already current changes nothing.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `stageID` | [StageID](../types.md#stageid) | Yes |  | The stage to make current. |

## CompleteObjective

Completes an objective as a success, regardless of its own trigger.

Nothing happens when the objective is already completed or failed. Completing fires the objective's onCompleted event trigger and then, unless that trigger changed the stage, advances to the objective's nextStage once every objective of the current stage sharing that nextStage is complete. A completed objective cannot be activated again.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to complete. |

## FailObjective

Marks an objective as failed.

Nothing happens when the objective is already completed or failed. Failing fires the objective's onFailed event trigger and then, unless that trigger changed the stage, advances to the objective's nextStage under the same conditions as completion. A failed objective counts as finished for stage advancement and cannot be activated again.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to fail. |

## HideObjective

Marks an objective as hidden so that it is not presented to the player.

Hiding changes presentation only: a hidden objective still tracks progress and can still complete or fail. Nothing happens when it is already hidden. Hiding fires the objective's onHidden event trigger.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to hide. |

## ShowObjective

Clears an objective's hidden mark so that it is presented to the player again.

Nothing happens when the objective is not hidden. Showing fires the objective's onShown event trigger.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to show. |

## UpdateObjective

Advances an objective by one step of progress.

Only an active, unfinished objective advances. The objective completes when its progress reaches its amount, or immediately when it has no amount; otherwise its onProgress event trigger fires. Objectives whose trigger has a quantity track their own progress and are not meant to be advanced this way.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `objectiveID` | [ObjectiveID](../types.md#objectiveid) | Yes |  | The objective to advance. |

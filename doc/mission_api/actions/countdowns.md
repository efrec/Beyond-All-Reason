# Actions: countdowns

Back to the [Mission API index](../index.md).

## AddCountdown

Starts a countdown that runs down one second at a time and ends when it reaches zero. Countdown triggers and the other countdown actions refer to it by its countdownID.

Adding a countdown with the ID of a running one replaces it.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The name the countdown is known by. |
| `seconds` | [Quantity](../types.md#quantity) | Yes |  | The duration in seconds, rounded to whole seconds. |
| `displayed` | [Boolean](../types.md#boolean) | No | `true` | Whether the countdown is meant to be shown to the player. Displayed countdowns tick together on whole seconds and hold their time through their first tick; others time their duration exactly from when they are added. |

The value of `countdownID` declares a new name that other actions and triggers can refer to.

## AddTime

Adds seconds to the remaining time of a countdown. Does nothing when the countdown has ended or been canceled.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The countdown to lengthen. |
| `seconds` | [Quantity](../types.md#quantity) | Yes |  | The seconds to add; the result is rounded to whole seconds. |

## CancelCountdown

Removes a countdown without ending it, so no countdown-ended trigger fires for it.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The countdown to remove. |

## PauseCountdown

Freezes the remaining time of a countdown until UnpauseCountdown resumes it. Does nothing when the countdown has ended or been canceled.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The countdown to pause. |

## RemoveTime

Takes seconds off the remaining time of a countdown. The remaining time never goes below zero, and a countdown left at zero ends on its next tick. Does nothing when the countdown has ended or been canceled.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The countdown to shorten. |
| `seconds` | [Quantity](../types.md#quantity) | Yes |  | The seconds to remove; the result is rounded to whole seconds. |

## SetTime

Sets the remaining time of a countdown and restarts its ticking from now. Does nothing when the countdown has ended or been canceled.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The countdown to change. |
| `seconds` | [Quantity](../types.md#quantity) | Yes |  | The new remaining time in seconds, rounded to whole seconds. |

## UnpauseCountdown

Resumes a countdown paused by PauseCountdown. Does nothing when the countdown has ended or been canceled.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](../types.md#countdownid) | Yes |  | The countdown to resume. |

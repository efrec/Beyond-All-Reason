# Actions: misc

Back to the [Mission API index](../index.md).

## Custom

Runs a Lua function written in the mission script.

The function is called with no arguments, and its return value is ignored. Use it for behavior that no other action provides.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `function` | [Function](../types.md#function) | Yes |  | The function to call. |

## DisableTrigger

Turns a trigger off so that it stops firing until an EnableTrigger action turns it back on.

A disabled trigger ignores its events entirely, so an event that happens while it is disabled is missed rather than held. Disabling does not reset the trigger's repeat count.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `triggerID` | [TriggerID](../types.md#triggerid) | Yes |  | The trigger to disable. |

## EnableTrigger

Turns a trigger on so that it fires when its event next happens.

Enabling does not reset a trigger that has already fired: a non-repeating trigger that fired once stays spent, and a repeating trigger keeps its count against maxRepeats. Use this to start triggers authored with active = false.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `triggerID` | [TriggerID](../types.md#triggerid) | Yes |  | The trigger to enable. |

## SendMessage

Adds a message to the battle log for the player to read.

The text is translated on the player's side, so messageKey is a translation key rather than display text. The entry is logged as a plain message, as opposed to a briefing, objective, notification, or dialogue entry.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `messageKey` | [String](../types.md#string) | Yes |  | The translation key of the message text. |
| `messageData` | [Table](../types.md#table) | No |  | Values substituted into the translated text, keyed by placeholder name. |

## SpawnExplosion

Detonates a weapon's explosion at a position, as if that weapon had hit there.

The explosion uses the weapon's damage, area of effect, and crater settings, damages units, features, and the ground, and has no owner, so no team is credited with its kills.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `weaponDefName` | [WeaponDefName](../types.md#weapondefname) | Yes |  | The weapon whose explosion is spawned. |
| `position` | [Position](../types.md#position) | Yes |  | Where the explosion happens, in elmos. When y is omitted, the ground height at (x, z) is used. |
| `direction` | [Position](../types.md#position) | No | `{ x = 0, y = 0, z = 0 }` | The direction the explosion travels, as a vector. Always give y, because an omitted y is filled with the ground height at (x, z) as for any position. |

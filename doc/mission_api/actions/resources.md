# Actions: resources

Back to the [Mission API index](../index.md).

## AddResources

Gives a team metal and energy at once, or takes them away.

Positive amounts are added to the team's storage, and negative amounts are spent from it. Each resource is applied separately, and an omitted resource is left unchanged.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The team whose storage changes. |
| `metal` | [Number](../types.md#number) | No |  | Metal to add, or to remove when negative. |
| `energy` | [Number](../types.md#number) | No |  | Energy to add, or to remove when negative. |

At least one of `metal` and `energy` is required.

## AddResourcesPerSecond

Changes a team's ongoing income by a fixed amount of metal and energy per second for the rest of the game.

The income is delivered in two installments per second. Repeating the action adds to the rate already in effect, so a negative amount reduces or cancels an earlier rate; there is no other way to stop it. An omitted resource is left unchanged.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The team whose income changes. |
| `metal` | [Number](../types.md#number) | No |  | Metal per second to add to the team's income, or to drain from it when negative. |
| `energy` | [Number](../types.md#number) | No |  | Energy per second to add to the team's income, or to drain from it when negative. |

At least one of `metal` and `energy` is required.

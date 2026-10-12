# Actions: game

Back to the [Mission API index](../index.md).

## Defeat

Ends the game with the listed ally teams defeated; every other ally team wins.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `allyTeamIDs` | [AllyTeamIDs](../types.md#allyteamids) | Yes |  | The ally teams that lose. |

## Pause

Pauses the game in a way players cannot undo; only Unpause ends it. The usual pause overlay is not shown.

This action takes no parameters.

## Unpause

Ends a pause started by Pause. A pause made by a player is left alone.

This action takes no parameters.

## Victory

Ends the game with the listed ally teams as the winners.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `allyTeamIDs` | [AllyTeamIDs](../types.md#allyteamids) | Yes |  | The ally teams that win. |

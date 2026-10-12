# Actions: media

Back to the [Mission API index](../index.md).

## PlayMusic

Plays a music track, interrupting the track that is playing.

The path is not checked when the mission loads.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `soundfile` | [String](../types.md#string) | Yes |  | The path of the music file within the game's files. |

## PlaySound

Plays a sound once, either right away or queued behind other queued sounds so that they do not overlap.

While a queued sound plays, the game's spoken notifications are held back for its length.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `soundfile` | [SoundFile](../types.md#soundfile) | Yes |  | The path of a .wav file within the game's files; checked when the mission loads. |
| `volume` | [Number](../types.md#number) | No | `1` | The playback volume, where 1 is full volume. |
| `position` | [Position](../types.md#position) | No |  | Plays the sound from this point in the world, with x and z in elmos and y defaulting to the ground height, instead of everywhere. |
| `enqueue` | [Boolean](../types.md#boolean) | No | `false` | Whether to queue the sound after the queued sounds before it; false plays it immediately, over anything else. |

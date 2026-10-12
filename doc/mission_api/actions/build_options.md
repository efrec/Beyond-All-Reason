# Actions: build_options

Back to the [Mission API index](../index.md).

## AddBuildOption

Adds a unit type to the build options of a builder or factory type, for its current units and for every unit of that type built later, on every team.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `builtDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The unit type to add as a build option. |
| `builderDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The builder or factory type that receives the option. |
| `buildMenuPosition` | [PositiveInteger](../types.md#positiveinteger) | No | `last` | The slot the option takes among the builder's build options, counted from 1. Build menus that sort their options ignore it. |

## DisableBuildOption

Grays out a unit type in the build menus of a team so it cannot be built, either for every builder of the team or for one builder or factory type only.

The block applies to the team's current and future builders and stays until EnableBuildOption lifts it.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `builtDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The unit type that can no longer be built. |
| `builderDefName` | [UnitDefName](../types.md#unitdefname) | No | `every builder of the team` | Limits the block to this builder or factory type. |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The team whose build menus are affected. |

## EnableBuildOption

Lifts a block placed by DisableBuildOption. The builderDefName must match the one the block was placed with: a team-wide block is lifted only by a team-wide enable.

Blocks the game places for its own reasons, such as water or wind restrictions, are not affected.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `builtDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The unit type to make buildable again. |
| `builderDefName` | [UnitDefName](../types.md#unitdefname) | No | `every builder of the team` | The builder or factory type the block was placed for. |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The team whose build menus are affected. |

## RemoveBuildOption

Takes a unit type out of the build options of a builder or factory type, for its current units and for every unit of that type built later, on every team. Queued orders to build it are dropped.

The option may be one the builder has by default or one added by AddBuildOption.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `builtDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The unit type to remove as a build option. |
| `builderDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The builder or factory type that loses the option. |

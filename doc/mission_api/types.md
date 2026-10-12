# Parameter types

Back to the [Mission API index](index.md).

## AllyTeamID

The ID of an ally team in the game.

A `integer` value.

Refers to `engine.AllyTeams`.

## AllyTeamIDs

A list of at least one ally team ID.

A list of [AllyTeamID](types.md#allyteamid) values.

## Area

A region of the map, given either as a rectangle or as a circle.

One of [AreaCircle](types.md#areacircle) or [AreaRectangle](types.md#arearectangle).

Picked on the map as an area.

## AreaCircle

A circle on the map, in elmos.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `x` | [Number](types.md#number) | Yes | The east-west coordinate of the center, in elmos. |
| `z` | [Number](types.md#number) | Yes | The north-south coordinate of the center, in elmos. |
| `radius` | [Number](types.md#number) | Yes | The radius, in elmos. |

## AreaRectangle

A rectangle on the map, in elmos. The first corner must lie west and north of the second, so x1 is less than x2, and z1 is less than z2.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `x1` | [Number](types.md#number) | Yes | The west edge, in elmos. |
| `z1` | [Number](types.md#number) | Yes | The north edge, in elmos. |
| `x2` | [Number](types.md#number) | Yes | The east edge, in elmos. Must be greater than x1. |
| `z2` | [Number](types.md#number) | Yes | The south edge, in elmos. Must be greater than z1. |

## Boolean

A true or false value.

A `boolean` value.

## Command

A command that units can receive: a command ID from CMD or GameCMD, or the name of a unit definition, which stands for the order to build that unit. CMD.ANY matches every command, and CMD.BUILD matches every build order.

A `integer` or `string` value.

Edited in its own panel.

## CountdownID

The ID of a countdown. A countdown exists once an action adds it.

A `string` value.

Refers to `mission.countdowns`.

## Difficulty

The name of a difficulty, as defined in difficulties.json. Higher difficulty values are harder.

One of `Story`, `Easy`, `Medium`, or `Hard`.

## Direction

The way units face, given either as a compass angle or as a point to face toward, never both.

One of [DirectionAngle](types.md#directionangle) or [DirectionVector](types.md#directionvector).

## DirectionAngle

A heading given as a compass angle in degrees, measured clockwise from north, so 0 faces north, 90 faces east, 180 faces south, and 270 faces west.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `angle` | [Number](types.md#number) | Yes | The compass angle, in degrees. |

## DirectionVector

A heading given as a point on the map. The affected units turn to face toward that point.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `x` | [Number](types.md#number) | Yes | The east-west coordinate of the point faced, in elmos. |
| `z` | [Number](types.md#number) | Yes | The north-south coordinate of the point faced, in elmos. |
| `y` | [Number](types.md#number) | No | An optional height, in elmos. Defaults to the terrain height at (x, z). |

## Facing

The direction a placed unit or feature faces. It is written as a compass letter, a compass word, or a number. The numbers start at south and go counterclockwise.

One of `0`, `1`, `2`, `3`, `e`, `east`, `n`, `north`, `s`, `south`, `w`, or `west`.

## FeatureDefName

The internal name of a feature definition, such as "armcom_dead".

A `string` value.

Refers to `engine.FeatureDefNames`.

## FeatureLoadout

Features to place on the map, as a list of features.

A list of [FeatureLoadoutEntry](types.md#featureloadoutentry) values.

Edited in its own panel.

## FeatureLoadoutEntry

One feature to place on the map, such as a wreck or a rock.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `featureDefName` | [FeatureDefName](types.md#featuredefname) | Yes | The feature definition to place. |
| `x` | [Number](types.md#number) | Yes | The east-west coordinate of the placement, in elmos. |
| `z` | [Number](types.md#number) | Yes | The north-south coordinate of the placement, in elmos. |
| `y` | [Number](types.md#number) | No | Accepted but not used. Features are placed at the terrain height. |
| `facing` | [Facing](types.md#facing) | No | The direction the feature faces. Defaults to south. |
| `featureName` | [FeatureName](types.md#featurename) | No | A name for the feature, so that triggers and actions can refer to it. |

## FeatureName

A name given to one or more features by the mission. Features get names when they are placed by a loadout or created by an action.

A `string` value.

Refers to `mission.featureNames`.

## Fraction

A proportion between zero and one, inclusive.

A `number` value.

Between `0` and `1` inclusive.

## Function

A Lua function. It runs inside the mission with no arguments.

A `function` value.

Edited in its own panel.

## MessageType

The kind of a message shown to the player, which decides how the message is presented.

One of `Briefing`, `Message`, `Objective`, `Notification`, or `Dialogue`.

## Number

A numeric value, whole or fractional.

A `number` value.

## ObjectiveID

The ID of an objective declared in the mission.

A `string` value.

Refers to `mission.objectives`.

## Order

One order for a unit, written as an array: the command, its parameters, and its options.
The command is a command ID from CMD or GameCMD, or the name of a unit definition to build.
The parameters depend on the command. Movement and attack commands take three numbers { x, y, z }. Area commands take four numbers { x, y, z, radius }. Build orders take { x, y, z } with an optional facing as a fourth number, or nothing for a factory. Commands that act on a unit or a feature may instead take { unitName = "name" } or { featureName = "name" }, which applies the order to every unit or feature with that name. State commands take a single number.
The options are an optional list of modifier names: "right", "alt", "ctrl", "shift", or "meta".

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `[1]` | `(integer\|string)` | Yes | The command: a command ID, or the name of a unit definition to build. |
| `[2]` | `table` | No | The command's parameters: an array of numbers, or a table naming a unit or a feature. |
| `[3]` | `string[]` | No | The order's modifier options, if any. |

## Orders

A list of at least one order, issued to units in sequence.

A list of [Order](types.md#order) values.

Edited in its own panel.

## Position

A location on the map, in elmos. The height defaults to the terrain height at that point.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `x` | [Number](types.md#number) | Yes | The east-west coordinate, in elmos. |
| `z` | [Number](types.md#number) | Yes | The north-south coordinate, in elmos. |
| `y` | [Number](types.md#number) | No | The height, in elmos. Defaults to the terrain height at (x, z). |

Picked on the map as a point.

## Positions

A list of at least two map positions, in order.

A list of [Position](types.md#position) values.

Picked on the map as a series of points.

## PositiveInteger

A whole number greater than zero.

A `integer` value.

At least `1`.

## Quantity

A count or an amount that is zero or more.

A `number` value.

At least `0`.

## ResourceIncomeSources

The kinds of resource income to count, as a list of names. An empty list counts every kind.

A list of any of `extractor`, `production`, `reclaim`, and `transfer`.

## SensorTypes

The kinds of sensor that count as detecting a unit, as a list of names. An empty list counts every kind.

A list of any of `vision`, `radar`, and `seismic`.

## SoundFile

The path of a .wav sound file inside the game's or the map's files.

A `string` value.

Refers to `engine.VFS`.

## StageID

The ID of a stage declared in the mission.

A `string` value.

Refers to `mission.stages`.

## String

A text value.

A `string` value.

## Table

Any Lua table. The action or trigger that takes it describes its contents.

A `object` value.

Edited in its own panel.

## TeamID

The ID of a team in the game.

A `integer` value.

Refers to `engine.Teams`.

## TriggerID

The ID of a trigger declared in the mission.

A `string` value.

Refers to `mission.triggers`.

## UnitDefName

The internal name of a unit definition, such as "armcom".

A `string` value.

Refers to `engine.UnitDefNames`.

## UnitLoadout

Units to place on the map, as a list of unit groups.

A list of [UnitLoadoutEntry](types.md#unitloadoutentry) values.

Edited in its own panel.

## UnitLoadoutEntry

One group of units to place on the map. One unit is placed at the position, or several copies are arranged in a grid around it.

| Name | Type | Required | Description |
| --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | Yes | The unit definition to place. |
| `x` | [Number](types.md#number) | Yes | The east-west coordinate of the placement, in elmos. |
| `z` | [Number](types.md#number) | Yes | The north-south coordinate of the placement, in elmos. |
| `y` | [Number](types.md#number) | No | The height, in elmos. Defaults to the terrain height at (x, z). |
| `team` | [TeamID](types.md#teamid) | Yes | The team that owns the units. |
| `facing` | [Facing](types.md#facing) | No | The direction the units face. Defaults to south. |
| `unitName` | [UnitName](types.md#unitname) | No | A name for the units, so that triggers and actions can refer to them. |
| `construction` | [Boolean](types.md#boolean) | No | Whether the units are placed unfinished, still to be built. |
| `quantity` | [Number](types.md#number) | No | How many units to place. Defaults to one. Several units are arranged in a grid centered on the position. |
| `spacing` | [Number](types.md#number) | No | Extra distance between units in the grid, in elmos. Defaults to zero. |
| `neutral` | [Boolean](types.md#boolean) | No | Whether the units are neutral, so that no team attacks them automatically. |
| `orders` | [Orders](types.md#orders) | No | Orders given to each unit as soon as it is placed. |

## UnitName

A name given to one or more units by the mission. Units get names when they are placed by a loadout, spawned by an action, or named by an action.

A `string` value.

Refers to `mission.unitNames`.

## WeaponDefName

The internal name of a weapon definition.

A `string` value.

Refers to `engine.WeaponDefNames`.

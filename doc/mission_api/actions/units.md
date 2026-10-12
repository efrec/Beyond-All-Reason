# Actions: units

Back to the [Mission API index](../index.md).

## DespawnUnits

Removes the units with a name from the game silently, without a death explosion or a wreck.

The units count as lost for the owning team, and UnitKilled triggers watching them fire. Nothing happens when no living unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units are removed. |

## DestroyUnits

Kills the units with a name, with their death explosion and wreck.

The units count as lost for the owning team, no team is credited with the kill, and UnitKilled triggers watching them fire. Nothing happens when no living unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units are destroyed. |

## IssueOrders

Gives the units with a name a list of orders, as if the player had issued them.

Every unit with the name receives the whole list. Each order is { command, params, options }: command is a command ID, or a unit def name for a build order; params are the command's numbers, such as { x, y, z } for a move or { x, y, z, radius } for an area command; and options are any of 'shift', 'alt', 'ctrl', 'right', and 'meta'. Add 'shift' to queue an order behind the previous ones; without it, the order replaces the unit's current queue. Where a command targets a unit or feature, params may be { unitName = '...' } or { featureName = '...' } instead, and the order is repeated for every unit or feature with that name, with the copies queued behind the first. UnitOrdered and RallyOrdered triggers ignore these orders unless they set ignoreMissionActions = false. Nothing happens when no unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units receive the orders. |
| `orders` | [Orders](../types.md#orders) | Yes |  | The orders to give, in list order. |

## MoveUnits

Teleports the units with a name to a position, optionally turning them to face a direction.

Every unit with the name is placed at the same position. The direction is either { angle = degrees }, a compass angle with 0 facing north and 90 facing east, or a point { x, z } that each unit turns to face; a unit placed exactly on that point keeps its facing. Nothing happens when no living unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units are moved. |
| `position` | [Position](../types.md#position) | Yes |  | The destination in elmos. When y is omitted, the ground height at (x, z) is used. |
| `direction` | [Direction](../types.md#direction) | No |  | The facing after the move. Units keep their facing when omitted. |

## NameUnits

Gives a name to existing units chosen by team, unit def, or area, so that later actions and triggers can refer to them.

The filters combine: a teamID alone names every unit the team owns, and a unitDefName or an area narrows the selection to units matching every filter given. Only units that exist when the action runs are named; units built later are not. A unit can hold several names, and naming it does not remove names it already has.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name to give the selected units. |
| `teamID` | [Number](../types.md#number) | No |  | Only units owned by this team. |
| `unitDefName` | [String](../types.md#string) | No |  | Only units of this unit def. |
| `area` | [Area](../types.md#area) | No |  | Only units inside this area: a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |

At least one of `teamID`, `unitDefName`, and `area` is required.

The value of `unitName` declares a new name that other actions and triggers can refer to.

## ReclaimUnits

Removes the units with a name as if they were reclaimed, refunding their metal cost to a team.

Each unit's full metal cost is added to the receiving team's storage; no energy is refunded. The units leave no wreck and no explosion. UnitReclaimed triggers ignore this action unless they set ignoreMissionActions = false. Nothing happens when no living unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units are reclaimed. |
| `reclaimerTeam` | [TeamID](../types.md#teamid) | No |  | The team that receives the metal. When omitted, the team that owns the units receives it. |

## RotateUnits

Turns the units with a name to face a direction.

The direction is either { angle = degrees }, a compass angle with 0 facing north and 90 facing east, or a point { x, z } that each unit turns to face; a unit standing exactly on that point keeps its facing. Nothing happens when no living unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units turn. |
| `direction` | [Direction](../types.md#direction) | Yes |  | The facing to apply. |

## SelfDestructUnits

Self-destructs the units with a name immediately, with their self-destruct explosion and wreck.

The units count as lost for the owning team, no team is credited with the kill, and UnitKilled triggers watching them fire. Nothing happens when no living unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units self-destruct. |

## SpawnUnits

Creates units from a loadout, placing them on the map finished or under construction.

Each loadout entry gives unitDefName, x, z, and team, and may give y, facing (0 to 3, or n, e, s, w, or the full compass word; south when omitted), unitName, construction (true to spawn as an unfinished build), quantity with spacing (the units are arranged in a grid around x and z, with spacing elmos between footprints), neutral, and orders in the same form as IssueOrders. Entries with a unitName create that name, and every unit of the entry gets it. UnitOrdered and RallyOrdered triggers ignore the entry orders unless they set ignoreMissionActions = false.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitLoadout` | [UnitLoadout](../types.md#unitloadout) | Yes |  | The units to create, one entry per unit def and position. |

The value of `unitLoadout` declares a new name that other actions and triggers can refer to.

## TransferUnits

Gives the units with a name to another team.

The units keep their names. UnitCaptured and UnitReceived triggers ignore this action unless they set ignoreMissionActions = false; then captured decides which of the two fires. Nothing happens when no unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units change hands. |
| `newTeam` | [TeamID](../types.md#teamid) | Yes |  | The team that receives the units. |
| `captured` | [Boolean](../types.md#boolean) | No | `false` | Whether the transfer counts as a capture rather than a gift. |

## UnitSelectable

Allows or forbids the player to select the units with a name.

Unselectable units cannot be picked or given orders by the player, but they still obey orders from the mission. The setting applies to the units that have the name when the action runs; units named later are unaffected until the action runs again. Nothing happens when no unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units are affected. |
| `selectable` | [Boolean](../types.md#boolean) | Yes |  | true lets the player select the units, and false prevents it. |

## UnitTargetable

Allows or forbids enemies to target the units with a name.

Untargetable units are not fired on automatically and cannot be given a direct attack order, though ground and area attacks can still hit them. The setting applies to the units that have the name when the action runs; units named later are unaffected until the action runs again. Nothing happens when no unit has the name.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name whose units are affected. |
| `targetable` | [Boolean](../types.md#boolean) | Yes |  | true lets enemies target the units, and false protects them. |

## UnnameUnits

Removes a name from every unit that has it.

The units stay in the game and keep any other names they hold. Afterwards, actions and triggers that refer to the name match nothing until units are named with it again.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The name to remove. |

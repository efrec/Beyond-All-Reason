# Actions: map

Back to the [Mission API index](../index.md).

## AddMapMarker

Places a map marker at a position, visible to every player, and records it under markerName so RemoveMapMarker can erase it.

Reusing a name records the new marker and forgets the earlier one without erasing it.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `markerName` | [String](../types.md#string) | Yes |  | The name the marker is known by. |
| `position` | [Position](../types.md#position) | Yes |  | Where the marker goes, with x and z in elmos; y defaults to the ground height. |
| `markerType` | [String](../types.md#string) | No |  | Reserved for marker styles; it currently changes nothing about the marker. |
| `label` | [String](../types.md#string) | No |  | Text shown beside the marker. |

The value of `markerName` declares a new name that other actions and triggers can refer to.

## AddUnitMarker

Draws a marker above every unit matching the filters, stacked above any markers the unit already has. A unit holds at most one marker of each markerType.

Only units that exist when the action runs are marked, and a marker disappears with its unit. A teamID on its own matches no units.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | No |  | Only units carrying this mission unit name. |
| `unitDefName` | [UnitDefName](../types.md#unitdefname) | No |  | Only units of this type. |
| `teamID` | [TeamID](../types.md#teamid) | No | `every team` | Only units of this team. |
| `markerType` | [String](../types.md#string) | No | `untyped` | A label for the marker, so RemoveUnitMarker can remove it on its own. |

At least one of `unitName` and `unitDefName` is required.

## DrawLines

Draws a line through the positions in order, visible to every player, and records it under lineName. Drawing again with the same name replaces the earlier line.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `positions` | [Positions](../types.md#positions) | Yes |  | At least two positions, with x and z in elmos; y defaults to the ground height. |
| `lineName` | [String](../types.md#string) | Yes |  | The name the line is known by. |

The value of `lineName` declares a new name that other actions and triggers can refer to.

## RemoveAllLines

Erases every line drawn by DrawLines.

This action takes no parameters.

## RemoveAllMapMarkers

Erases every marker placed by AddMapMarker.

This action takes no parameters.

## RemoveLine

Erases a line drawn by DrawLines. Does nothing for a name that is not drawn.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `lineName` | [String](../types.md#string) | Yes |  | The line to erase. |

## RemoveMapMarker

Erases the marker recorded under markerName. Does nothing for a name that is not recorded.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `markerName` | [String](../types.md#string) | Yes |  | The marker to erase. |

## RemoveUnitMarker

Removes markers from every unit matching the filters.

A teamID on its own matches no units.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | No |  | Only units carrying this mission unit name. |
| `unitDefName` | [UnitDefName](../types.md#unitdefname) | No |  | Only units of this type. |
| `teamID` | [TeamID](../types.md#teamid) | No | `every team` | Only units of this team. |
| `markerType` | [String](../types.md#string) | No | `every marker of the unit` | Remove only the marker of this type. |

At least one of `unitName` and `unitDefName` is required.

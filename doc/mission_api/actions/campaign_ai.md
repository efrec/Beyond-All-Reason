# Actions: campaign_ai

Back to the [Mission API index](../index.md).

## DisableUnitDef

Stops the campaign AI of a team from building a unit type.

This only instructs the AI; the build option itself stays available, so use DisableBuildOption to gray it out as well.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The unit type the AI must not build. |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The AI team that receives the instruction. |

## DisableUnitsControl

Tells the campaign AI of a team to leave alone the units carrying a mission unit name.

Only units that exist when the action runs are affected.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The mission unit name of the units to take from the AI. |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The AI team that receives the instruction. |

## EnableUnitDef

Allows the campaign AI of a team to build a unit type.

This only instructs the AI; it does not change which build options exist.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](../types.md#unitdefname) | Yes |  | The unit type the AI may build. |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The AI team that receives the instruction. |

## EnableUnitsControl

Tells the campaign AI of a team that it may control the units carrying a mission unit name.

Only units that exist when the action runs are affected.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](../types.md#unitname) | Yes |  | The mission unit name of the units to hand to the AI. |
| `teamID` | [TeamID](../types.md#teamid) | Yes |  | The AI team that receives the instruction. |

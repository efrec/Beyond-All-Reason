# Triggers

Back to the [Mission API index](index.md).

## ConstructionCanceled

Fires when a unit being built by a constructor is removed before it is finished, whether destroyed, canceled, or transferred to another team. Units in production at a factory are covered by ProductionCanceled instead.

A constructor that dies or drops its build order does not cancel the construction, since another constructor can still finish the unit.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit under construction with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units under construction of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units under construction owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## ConstructionFinished

Fires when a unit that was under construction is completed. Units that enter the mission already complete do not count.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the completed unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only completed units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only completed units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## ConstructionProgress

Fires when the build progress of a matching unit under construction reaches a fraction of completion. Each unit can fire the trigger only once, and units that are already complete when first checked do not count.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `progress` | [Fraction](types.md#fraction) | Yes |  | The build progress to reach, from 0 to 1. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit under construction with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units under construction of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units under construction owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## ConstructionStarted

Fires when a unit of the given definition starts being built, either as a new build frame or when the first builder matching the filters assists an existing one. Each unit under construction fires the trigger at most once, and units spawned by the mission while under construction count as started.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | Yes |  | The unit definition being built. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units under construction owned by this team. |
| `builderName` | [UnitName](types.md#unitname) | No |  | Only construction by the builder with this name. |
| `builderDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only construction by builders of this unit definition. |

## CountdownFinished

Fires when the named countdown reaches zero.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](types.md#countdownid) | Yes |  | The countdown to watch. |

## CountdownReached

Fires when the named countdown ticks down to the given number of seconds remaining.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `countdownID` | [CountdownID](types.md#countdownid) | Yes |  | The countdown to watch. |
| `timeRemaining` | [PositiveInteger](types.md#positiveinteger) | Yes |  | The whole seconds remaining at which to fire, at least 1; use CountdownFinished for zero. |

## Event

Fires only when an objective names it in one of its events (onActivated, onProgress, onCompleted, or onCanceled). It has no parameters and never fires on its own.

This trigger takes no parameters.

## FeatureCreated

Fires when a feature, such as a wreck or a map prop, appears.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `featureDefName` | [FeatureDefName](types.md#featuredefname) | No |  | Only features of this feature definition. |
| `area` | [Area](types.md#area) | No |  | Only features inside this area, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |

At least one of `featureDefName` and `area` is required.

## FeatureDestroyed

Fires when a feature is destroyed by anything other than being fully reclaimed. Fully reclaimed features are covered by FeatureReclaimed instead.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `featureName` | [FeatureName](types.md#featurename) | No |  | Only the feature with this name. |
| `featureDefName` | [FeatureDefName](types.md#featuredefname) | No |  | Only features of this feature definition. |
| `allyTeamID` | [AllyTeamID](types.md#allyteamid) | No |  | Only features destroyed by this ally team. |
| `area` | [Area](types.md#area) | No |  | Only features inside this area, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |

At least one of `featureName`, `featureDefName`, `allyTeamID`, and `area` is required.

## FeatureReclaimed

Fires when a feature is fully reclaimed.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `featureName` | [FeatureName](types.md#featurename) | No |  | Only the feature with this name. |
| `featureDefName` | [FeatureDefName](types.md#featuredefname) | No |  | Only features of this feature definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only features reclaimed by this team. |
| `area` | [Area](types.md#area) | No |  | Only features inside this area, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |

At least one of `featureName`, `featureDefName`, `teamID`, and `area` is required.

## MissionStarted

Fires once when the mission starts, after the starting units are placed and the first stage is active, and before any interactive gameplay.

Some effects of the mission setup may not have taken place yet when it fires.

This trigger takes no parameters.

## ProductionCanceled

Fires when a unit in production at a factory is removed before it is finished, whether its order is canceled, its factory is destroyed, or it is captured. Units built by constructors are covered by ConstructionCanceled instead.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit in production with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units in production of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units in production owned by this team. |
| `factoryName` | [UnitName](types.md#unitname) | No |  | Only units produced by the factory with this name. |
| `factoryDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units produced by factories of this unit definition. |

At least one of `unitName` and `unitDefName` is required.

## ProductionOrdered

Fires when a factory receives an order to produce a unit of the given definition.

**Not available.** Production orders cannot be observed reliably yet.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `buildDefName` | [UnitDefName](types.md#unitdefname) | Yes |  | The unit definition ordered for production. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the factory with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only factories of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only factories owned by this team. |
| `ignoreMissionActions` | [Boolean](types.md#boolean) | No | `true` | Whether orders issued by mission actions are ignored. |

## ProductionStarted

Fires when a factory starts producing a unit of the given definition. Units placed by constructors are covered by ConstructionStarted instead.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | Yes |  | The unit definition being produced. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only production for this team. |
| `factoryName` | [UnitName](types.md#unitname) | No |  | Only production at the factory with this name. |
| `factoryDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only production at factories of this unit definition. |

## RallyOrdered

Fires when a factory receives a rally order, that is, an order it does not carry out itself but passes on to the units it produces. Orders to produce units and orders the factory carries out itself do not count.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `command` | [Command](types.md#command) | Yes |  | The order to match: a command ID, or CMD.ANY for any order. Build orders never match. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the factory with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only factories of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only factories owned by this team. |
| `ignoreMissionActions` | [Boolean](types.md#boolean) | No | `true` | Whether orders issued by mission actions are ignored. |

At least one of `unitName` and `unitDefName` is required.

## ResourceIncome

Fires when a team's income of metal, energy, or both is at or above the given amounts per second. Income is checked once per second, and both thresholds must be met when both are given. While repeating, it fires again every second the thresholds hold.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team whose income is measured. |
| `metal` | [Number](types.md#number) | No |  | The metal income per second to reach. |
| `energy` | [Number](types.md#number) | No |  | The energy income per second to reach. |
| `sources` | [ResourceIncomeSources](types.md#resourceincomesources) | No |  | Count only income from these sources: 'extractor' (metal only), 'reclaim', 'production' (all remaining income), and 'transfer' (resources shared by allies). When omitted, the team's total income counts. |

At least one of `metal` and `energy` is required.

## ResourcePull

Fires when a team's demand for metal, energy, or both is at or above the given amounts per second. Demand is checked once per second, and both thresholds must be met when both are given. While repeating, it fires again every second the thresholds hold.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team whose demand is measured. |
| `metal` | [Number](types.md#number) | No |  | The metal demand per second to reach. |
| `energy` | [Number](types.md#number) | No |  | The energy demand per second to reach. |

At least one of `metal` and `energy` is required.

## ResourceStored

Fires when a team has at least the given amounts of metal, energy, or both in storage. Storage is checked every game frame, and both thresholds must be met when both are given. While repeating, it fires again every game frame the thresholds hold.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team whose storage is measured. |
| `metal` | [Number](types.md#number) | No |  | The stored metal to reach. |
| `energy` | [Number](types.md#number) | No |  | The stored energy to reach. |

At least one of `metal` and `energy` is required.

## TeamDestroyed

Fires when the given team is eliminated.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [Number](types.md#number) | Yes |  | The team to watch. |

## TimeElapsed

Fires once a number of seconds after the mission starts, and again on an interval while repeating.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `seconds` | [Number](types.md#number) | Yes |  | Seconds after the mission starts, rounded to the nearest game frame. |
| `interval` | [Number](types.md#number) | No |  | Seconds between repeats while the trigger is repeating; without it, a repeating trigger fires only once. |

## TotalUnitsBuilt

Fires when the number of units a team has completed since the mission started reaches the quantity, and again at every further multiple of it while repeating. Units spawned by the mission and the team's starting units do not count.

As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team whose completed units are counted. |
| `quantity` | [Quantity](types.md#quantity) | Yes |  | Count at which to fire; while repeating, it fires again at every further multiple of this count. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Count only units of this unit definition. |

## TotalUnitsCaptured

Fires when the number of units a team has captured since the mission started reaches the quantity, and again at every further multiple of it while repeating.

As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team that captures the units. |
| `quantity` | [Quantity](types.md#quantity) | Yes |  | Count at which to fire; while repeating, it fires again at every further multiple of this count. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Count only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Count only units of this unit definition. |

## TotalUnitsKilled

Fires when the number of enemy units a team has destroyed since the mission started reaches the quantity, and again at every further multiple of it while repeating. Destroyed allied units do not count.

As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team that destroys the units. |
| `quantity` | [Quantity](types.md#quantity) | Yes |  | Count at which to fire; while repeating, it fires again at every further multiple of this count. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Count only the destroyed unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Count only destroyed units of this unit definition. |

## TotalUnitsLost

Fires when the number of units a team has lost since the mission started, destroyed for any reason, reaches the quantity, and again at every further multiple of it while repeating.

As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team that loses the units. |
| `quantity` | [Quantity](types.md#quantity) | Yes |  | Count at which to fire; while repeating, it fires again at every further multiple of this count. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Count only the lost unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Count only lost units of this unit definition. |

## TransportLoaded

Fires when a transport picks up a passenger. Units docking with other kinds of units count only when transportDefName names that unit definition.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `transportName` | [UnitName](types.md#unitname) | No |  | Only the transport with this name. |
| `transportDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only transports of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only transports owned by this team. |
| `passengerName` | [UnitName](types.md#unitname) | No |  | Only the passenger with this name. |
| `passengerDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only passengers of this unit definition. |

At least one of `transportName` and `transportDefName` is required.

## TransportUnloaded

Fires when a transport drops off a passenger. Units undocking from other kinds of units count only when transportDefName names that unit definition, and a destroyed transport drops off its passengers as well.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `transportName` | [UnitName](types.md#unitname) | No |  | Only the transport with this name. |
| `transportDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only transports of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only transports owned by this team. |
| `passengerName` | [UnitName](types.md#unitname) | No |  | Only the passenger with this name. |
| `passengerDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only passengers of this unit definition. |

At least one of `transportName` and `transportDefName` is required.

## UnitAttacked

Fires each time a matching unit is damaged by an enemy. Damage with no identifiable enemy attacker, such as from allies, from the explosions of dying units, or from the environment, does not count.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the damaged unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only damaged units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only damaged units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitCaptured

Fires when a matching unit is captured by another team. Units given away are covered by UnitReceived instead.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the captured unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only captured units of this unit definition. |
| `oldTeamID` | [TeamID](types.md#teamid) | No |  | Only units captured from this team. |
| `newTeamID` | [TeamID](types.md#teamid) | No |  | Only units captured by this team. |
| `ignoreMissionActions` | [Boolean](types.md#boolean) | No | `true` | Whether transfers made by mission actions are ignored. |

At least one of `unitName` and `unitDefName` is required.

## UnitDetected

Fires when a matching unit comes into the watched sensors of another ally team: seen, on radar, or heard by seismic detectors. A unit already inside the watched sensors is not detected again until it has dropped out of all of them.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the detected unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only detected units of this unit definition. |
| `owningTeamID` | [TeamID](types.md#teamid) | No |  | Only detected units owned by this team. |
| `sensorAllyTeam` | [AllyTeamID](types.md#allyteamid) | No |  | Only detection by this ally team's sensors. When omitted, the sensors of every ally team other than the unit's own count, and Gaia's sensors are excluded. |
| `sensorTypes` | [SensorTypes](types.md#sensortypes) | No | `{ 'vision', 'radar', 'seismic' }` | The sensors that count: 'vision', 'radar', 'seismic', or any combination. When omitted, every sensor counts. |

At least one of `unitName` and `unitDefName` is required.

## UnitDwellLocation

Fires when a matching unit has stayed inside an area for a duration. Each unit fires the trigger once per stay, and leaving the area and returning starts a new count.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `area` | [Area](types.md#area) | Yes |  | The area to watch, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |
| `duration` | [Number](types.md#number) | Yes |  | How long the unit must stay in the area, in game frames (30 per second). |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitEnteredLocation

Fires each time a matching unit enters an area, once per unit that enters.

Units already inside the area when the mission starts count as entering on the first game frame.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `area` | [Area](types.md#area) | Yes |  | The area to watch, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitExists

Fires when a unit of the given definition appears, including when its construction starts, or when one is given to or captured by a team.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | Yes |  | The unit definition to watch. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |

## UnitIdled

Fires when a matching unit runs out of work: its order queue empties, or only brief automatic tasks remain in it.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitKilled

Fires when a matching unit is destroyed for any reason.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the destroyed unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only destroyed units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only destroyed units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitLeftLocation

Fires each time a matching unit leaves an area, once per unit that leaves.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `area` | [Area](types.md#area) | Yes |  | The area to watch, a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitLoaded

Fires when a matching unit is loaded into a transport. Only loading into transports counts.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `passengerName` | [UnitName](types.md#unitname) | No |  | Only the passenger with this name. |
| `passengerDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only passengers of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only passengers owned by this team. |
| `transportName` | [UnitName](types.md#unitname) | No |  | Only loading into the transport with this name. |
| `transportDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only loading into transports of this unit definition. |

At least one of `passengerName` and `passengerDefName` is required.

## UnitNotExists

Fires when a matching unit leaves a team's possession, whether destroyed, given away, or captured.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units that were owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitOrdered

Fires when a matching unit receives an order it is likely to carry out. Orders a factory queues or passes on to the units it produces do not count; see ProductionOrdered and RallyOrdered.

Some commands are handled before they reach the unit and never fire this trigger; validation warns about them. A unit can still refuse an order after the trigger has fired.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `command` | [Command](types.md#command) | Yes |  | The order to match: a command ID, a unit definition name for a build order, CMD.ANY for any order, or CMD.BUILD for any build order. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |
| `ignoreMissionActions` | [Boolean](types.md#boolean) | No | `true` | Whether orders issued by mission actions are ignored. |

At least one of `unitName` and `unitDefName` is required.

## UnitReceived

Fires when a matching unit is given to another team. Captures are covered by UnitCaptured instead.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the given unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only given units of this unit definition. |
| `oldTeamID` | [TeamID](types.md#teamid) | No |  | Only units given by this team. |
| `newTeamID` | [TeamID](types.md#teamid) | No |  | Only units given to this team. |
| `ignoreMissionActions` | [Boolean](types.md#boolean) | No | `true` | Whether transfers made by mission actions are ignored. |

At least one of `unitName` and `unitDefName` is required.

## UnitReclaimed

Fires when a matching unit is fully reclaimed.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the reclaimed unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only reclaimed units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only reclaimed units owned by this team. |
| `ignoreMissionActions` | [Boolean](types.md#boolean) | No | `true` | Whether reclaims performed by mission actions are ignored. |

At least one of `unitName` and `unitDefName` is required.

## UnitResurrected

Fires when a unit is resurrected from a wreck.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only resurrected units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only resurrected units owned by this team. |
| `featureName` | [FeatureName](types.md#featurename) | No |  | Only resurrection of the wreck with this name. |

At least one of `featureName` and `unitDefName` is required.

## UnitUndetected

Fires when a matching unit drops out of the watched sensors of other ally teams: no longer seen, on radar, or heard by seismic detectors. A unit held by several of the watched sensors is lost only when it leaves all of them, and a destroyed unit does not count as lost.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the lost unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only lost units of this unit definition. |
| `owningTeamID` | [TeamID](types.md#teamid) | No |  | Only lost units owned by this team. |
| `sensorAllyTeam` | [AllyTeamID](types.md#allyteamid) | No |  | Only loss from this ally team's sensors. When omitted, the sensors of every ally team other than the unit's own count, and Gaia's sensors are excluded. |
| `sensorTypes` | [SensorTypes](types.md#sensortypes) | No | `{ 'vision', 'radar', 'seismic' }` | The sensors that count: 'vision', 'radar', 'seismic', or any combination. When omitted, every sensor counts. |

At least one of `unitName` and `unitDefName` is required.

## UnitUnidled

Fires when a matching unit gets work again: its order queue receives an order that is more than a brief automatic task.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only units of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only units owned by this team. |

At least one of `unitName` and `unitDefName` is required.

## UnitUnloaded

Fires when a matching unit is unloaded from a transport. Only unloading from transports counts, and a destroyed transport unloads its passengers as well.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `unitName` | [UnitName](types.md#unitname) | No |  | Only the passenger with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only passengers of this unit definition. |
| `teamID` | [TeamID](types.md#teamid) | No |  | Only passengers owned by this team. |
| `transportName` | [UnitName](types.md#unitname) | No |  | Only unloading from the transport with this name. |
| `transportDefName` | [UnitDefName](types.md#unitdefname) | No |  | Only unloading from transports of this unit definition. |

At least one of `unitName` and `unitDefName` is required.

## UnitsOwned

Fires when the number of matching units a team owns rises to the quantity, and again at every further multiple of it while repeating, or, with a quantity of 0, when the count falls to zero. Units count from the moment their construction starts, and units given to or captured by the team count as well.

As an objective's trigger, the running count is the objective's progress, the objective's amount is the target, and quantity is ignored.

| Name | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `teamID` | [TeamID](types.md#teamid) | Yes |  | The team whose units are counted. |
| `quantity` | [Quantity](types.md#quantity) | Yes |  | Count at which to fire; while repeating, it fires again at every further multiple of this count. A quantity of 0 fires when the team has none left. |
| `unitName` | [UnitName](types.md#unitname) | No |  | Count only the unit with this name. |
| `unitDefName` | [UnitDefName](types.md#unitdefname) | No |  | Count only units of this unit definition. |

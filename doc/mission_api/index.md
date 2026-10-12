# Mission API

Generated from the annotations in `luarules/mission_api` by `tools/mission_api/build_docs.sh`.

- [Parameter types](types.md)
- [Mission file format](mission.md)
- [Triggers](triggers.md)

## Actions

### [build_options](actions/build_options.md)

- [AddBuildOption](actions/build_options.md#addbuildoption)
- [DisableBuildOption](actions/build_options.md#disablebuildoption)
- [EnableBuildOption](actions/build_options.md#enablebuildoption)
- [RemoveBuildOption](actions/build_options.md#removebuildoption)

### [campaign_ai](actions/campaign_ai.md)

- [DisableUnitDef](actions/campaign_ai.md#disableunitdef)
- [DisableUnitsControl](actions/campaign_ai.md#disableunitscontrol)
- [EnableUnitDef](actions/campaign_ai.md#enableunitdef)
- [EnableUnitsControl](actions/campaign_ai.md#enableunitscontrol)

### [countdowns](actions/countdowns.md)

- [AddCountdown](actions/countdowns.md#addcountdown)
- [AddTime](actions/countdowns.md#addtime)
- [CancelCountdown](actions/countdowns.md#cancelcountdown)
- [PauseCountdown](actions/countdowns.md#pausecountdown)
- [RemoveTime](actions/countdowns.md#removetime)
- [SetTime](actions/countdowns.md#settime)
- [UnpauseCountdown](actions/countdowns.md#unpausecountdown)

### [features](actions/features.md)

- [CreateFeatures](actions/features.md#createfeatures)
- [DestroyFeatures](actions/features.md#destroyfeatures)

### [game](actions/game.md)

- [Defeat](actions/game.md#defeat)
- [Pause](actions/game.md#pause)
- [Unpause](actions/game.md#unpause)
- [Victory](actions/game.md#victory)

### [map](actions/map.md)

- [AddMapMarker](actions/map.md#addmapmarker)
- [AddUnitMarker](actions/map.md#addunitmarker)
- [DrawLines](actions/map.md#drawlines)
- [RemoveAllLines](actions/map.md#removealllines)
- [RemoveAllMapMarkers](actions/map.md#removeallmapmarkers)
- [RemoveLine](actions/map.md#removeline)
- [RemoveMapMarker](actions/map.md#removemapmarker)
- [RemoveUnitMarker](actions/map.md#removeunitmarker)

### [media](actions/media.md)

- [PlayMusic](actions/media.md#playmusic)
- [PlaySound](actions/media.md#playsound)

### [misc](actions/misc.md)

- [Custom](actions/misc.md#custom)
- [DisableTrigger](actions/misc.md#disabletrigger)
- [EnableTrigger](actions/misc.md#enabletrigger)
- [SendMessage](actions/misc.md#sendmessage)
- [SpawnExplosion](actions/misc.md#spawnexplosion)

### [objectives](actions/objectives.md)

- [ActivateObjective](actions/objectives.md#activateobjective)
- [CancelObjective](actions/objectives.md#cancelobjective)
- [ChangeStage](actions/objectives.md#changestage)
- [CompleteObjective](actions/objectives.md#completeobjective)
- [FailObjective](actions/objectives.md#failobjective)
- [HideObjective](actions/objectives.md#hideobjective)
- [ShowObjective](actions/objectives.md#showobjective)
- [UpdateObjective](actions/objectives.md#updateobjective)

### [resources](actions/resources.md)

- [AddResources](actions/resources.md#addresources)
- [AddResourcesPerSecond](actions/resources.md#addresourcespersecond)

### [units](actions/units.md)

- [DespawnUnits](actions/units.md#despawnunits)
- [DestroyUnits](actions/units.md#destroyunits)
- [IssueOrders](actions/units.md#issueorders)
- [MoveUnits](actions/units.md#moveunits)
- [NameUnits](actions/units.md#nameunits)
- [ReclaimUnits](actions/units.md#reclaimunits)
- [RotateUnits](actions/units.md#rotateunits)
- [SelfDestructUnits](actions/units.md#selfdestructunits)
- [SpawnUnits](actions/units.md#spawnunits)
- [TransferUnits](actions/units.md#transferunits)
- [UnitSelectable](actions/units.md#unitselectable)
- [UnitTargetable](actions/units.md#unittargetable)
- [UnnameUnits](actions/units.md#unnameunits)

## Triggers

- [ConstructionCanceled](triggers.md#constructioncanceled)
- [ConstructionFinished](triggers.md#constructionfinished)
- [ConstructionProgress](triggers.md#constructionprogress)
- [ConstructionStarted](triggers.md#constructionstarted)
- [CountdownFinished](triggers.md#countdownfinished)
- [CountdownReached](triggers.md#countdownreached)
- [Event](triggers.md#event)
- [FeatureCreated](triggers.md#featurecreated)
- [FeatureDestroyed](triggers.md#featuredestroyed)
- [FeatureReclaimed](triggers.md#featurereclaimed)
- [MissionStarted](triggers.md#missionstarted)
- [ProductionCanceled](triggers.md#productioncanceled)
- [ProductionOrdered](triggers.md#productionordered)
- [ProductionStarted](triggers.md#productionstarted)
- [RallyOrdered](triggers.md#rallyordered)
- [ResourceIncome](triggers.md#resourceincome)
- [ResourcePull](triggers.md#resourcepull)
- [ResourceStored](triggers.md#resourcestored)
- [TeamDestroyed](triggers.md#teamdestroyed)
- [TimeElapsed](triggers.md#timeelapsed)
- [TotalUnitsBuilt](triggers.md#totalunitsbuilt)
- [TotalUnitsCaptured](triggers.md#totalunitscaptured)
- [TotalUnitsKilled](triggers.md#totalunitskilled)
- [TotalUnitsLost](triggers.md#totalunitslost)
- [TransportLoaded](triggers.md#transportloaded)
- [TransportUnloaded](triggers.md#transportunloaded)
- [UnitAttacked](triggers.md#unitattacked)
- [UnitCaptured](triggers.md#unitcaptured)
- [UnitDetected](triggers.md#unitdetected)
- [UnitDwellLocation](triggers.md#unitdwelllocation)
- [UnitEnteredLocation](triggers.md#unitenteredlocation)
- [UnitExists](triggers.md#unitexists)
- [UnitIdled](triggers.md#unitidled)
- [UnitKilled](triggers.md#unitkilled)
- [UnitLeftLocation](triggers.md#unitleftlocation)
- [UnitLoaded](triggers.md#unitloaded)
- [UnitNotExists](triggers.md#unitnotexists)
- [UnitOrdered](triggers.md#unitordered)
- [UnitReceived](triggers.md#unitreceived)
- [UnitReclaimed](triggers.md#unitreclaimed)
- [UnitResurrected](triggers.md#unitresurrected)
- [UnitUndetected](triggers.md#unitundetected)
- [UnitUnidled](triggers.md#unitunidled)
- [UnitUnloaded](triggers.md#unitunloaded)
- [UnitsOwned](triggers.md#unitsowned)

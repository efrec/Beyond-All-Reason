---
--- Created by Hobo Joe.
--- DateTime: 4/26/2023 8:48 PM
---


local unitEnergyCost      = Game.UnitInfo.Cache.energyCost ---@type table<number, number>
local unitMetalCost       = Game.UnitInfo.Cache.metalCost ---@type table<number, number>
local unitBuildOptions    = Game.UnitInfo.Cache.buildOptions ---@type table<number, table>
local factoryBuildOptions = Game.UnitInfo.Cache.factoryBuildOptions ---@type table<number, table>
local unitIconType        = Game.UnitInfo.Cache.iconType ---@type table<number, number>
local unitGroup           = Game.UnitInfo.Cache.unitgroup ---@type table<number, string>
local isMex               = Game.UnitInfo.Cache.needsMetalSpot ---@type table<number, true>
local isGeothermal        = Game.UnitInfo.Cache.needsGeothermal ---@type table<number, true>
local isWind              = Game.UnitInfo.Cache.needsMapWind ---@type table<number, true>
local isWaterUnit         = Game.UnitInfo.Cache.needsMapWater ---@type table<number, true>
local isRestrictedUnit    = Game.UnitInfo.Cache.isRestrictedUnit ---@type table<number, true>

local isRestrictedGUI     = table.copy(isRestrictedUnit) ---@type table<number, true>

---@param disable boolean
local function restrictWindUnits(disable)
	for unitDefID in pairs(isWind) do
		isRestrictedGUI[unitDefID] = isRestrictedUnit[unitDefID] or disable
	end
end

---@param disable boolean
local function restrictGeothermalUnits(disable)
	for unitDefID in pairs(isGeothermal) do
		isRestrictedGUI[unitDefID] = isRestrictedUnit[unitDefID] or disable
	end
end

---@param disable boolean
local function restrictWaterUnits(disable)
	for unitDefID in pairs(isWaterUnit) do
		isRestrictedGUI[unitDefID] = isRestrictedUnit[unitDefID] or disable
	end
end

---Sets geothermal unit restriction based on the presence of geothermal
---features.
local function checkGeothermalFeatures()
	local hideGeoUnits = true
	local geoThermalFeatures = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoThermalFeatures[defID] = true
		end
	end
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			hideGeoUnits = false
			break
		end
	end
	restrictGeothermalUnits(hideGeoUnits)
end


------------------------------------
-- UNIT ORDER ----------------------
------------------------------------

---At the end of this 'UNIT ORDER' section, unitOrder is an array with unitIDs
---sorted by their value specified in unitOrderManualOverrideTable. If no
---value is specified, the unit will be placed at the end of the array.
---@type number[]
local unitOrder = {}

local unitOrderManualOverrideTable = VFS.Include("luaui/configs/buildmenu_sorting.lua")

-- Populate unitOrder with unit IDs.
for id in pairs(UnitDefs) do
	unitOrder[id] = id
end

-- maxOrder is the largest order value found in unitOrderManualOverrideTable.
-- Units with no value in unitOrderManualOverrideTable will implicitly take the
-- maxOrder value when sorting unitOrder below.
local maxOrder = 0
for _, order in pairs(unitOrderManualOverrideTable) do
	if order > maxOrder then
		maxOrder = order
	end
end
maxOrder = maxOrder + 1

-- Sorts unitIDs by their order value (if one exists) specified in
-- unitOrderManualOverrideTable. All units who do not have an order value
-- specified in unitOrderManualOverrideTable are considered to have an order
-- value of maxOrder.
-- For units who have the same order value we compare the unit's IDs.
-- This sort is always stable, as no two units should have the same ID.
table.sort(unitOrder, function(aID, bID)
	local aOrder = unitOrderManualOverrideTable[aID] or maxOrder
	local bOrder = unitOrderManualOverrideTable[bID] or maxOrder

	if (aOrder == bOrder) then
		return aID < bID
	end
	return aOrder < bOrder
end)


local units = {
	unitEnergyCost = unitEnergyCost,
	unitMetalCost = unitMetalCost,
	unitGroup = unitGroup,
	unitRestricted = isRestrictedGUI,
	unitIconType = unitIconType,
	---Set of unit IDs that are factories.
	isFactory = factoryBuildOptions,
	---Set of unit IDs that have build options.
	isBuilder = unitBuildOptions,
	---Set of unit IDs that require metal.
	isMex = isMex,
	---Set of unit IDs that require wind.
	isWind = isWind,
	---Set of unit IDs that require water.
	isWaterUnit = isWaterUnit,
	---Set of unit IDs that require geothermal.
	isGeothermal = isGeothermal,
	minWaterUnitDepth = -11,
	---An array with unitIDs sorted by their value specified in
	---`unitOrderManualOverrideTable`. If no value is specified, the unit will be
	---placed at the end of the array.
	unitOrder = unitOrder,

	checkGeothermalFeatures = checkGeothermalFeatures,
	restrictGeothermalUnits = restrictGeothermalUnits,
	restrictWindUnits = restrictWindUnits,
	restrictWaterUnits = restrictWaterUnits,
}

return units

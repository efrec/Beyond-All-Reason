-- luaui/Include/blueprint_substitution/definitions.lua
-- Contains unit category definitions for blueprint substitution
-- Used by logic.lua

local DefinitionsModule = {}

local SIDES_ENUM = VFS.Include("gamedata/sides_enum.lua")
if not SIDES_ENUM then
    error("[BlueprintDefinitions] CRITICAL: Failed to load sides_enum.lua!")
    -- Return an empty or minimal table if sides are critical and missing
    return DefinitionsModule 
end
DefinitionsModule.SIDES = SIDES_ENUM

DefinitionsModule.UNIT_CATEGORIES = {} -- Enum Name -> Category Name
DefinitionsModule.categoryUnits = {}   -- Category Name -> { Side -> Unit Name }
DefinitionsModule.unitCategories = {}  -- Unit Name -> Category Name

-- ===================================================================
-- Define Unit Categories
-- ===================================================================

local function DefCat(enumKey, unitTable) -- Made local to definitions.lua
    if DefinitionsModule.UNIT_CATEGORIES[enumKey] then
        local errorMsg = string.format("[BlueprintDefinitions ERROR] Duplicate category key definition attempted: '%s'. The previous definition will be overwritten.", enumKey)
        Spring.Log("BlueprintDefs", LOG.ERROR, errorMsg)
    end

    DefinitionsModule.UNIT_CATEGORIES[enumKey] = enumKey 
    DefinitionsModule.categoryUnits[enumKey] = unitTable 

    for _, unitName in pairs(unitTable) do -- side variable isn't used here
        if unitName then
            DefinitionsModule.unitCategories[unitName:lower()] = enumKey
        end
    end
end

function DefinitionsModule.defineUnitCategories()
    Spring.Log("BlueprintDefs", LOG.INFO, "Defining static unit categories START...")
    local SIDES = DefinitionsModule.SIDES -- Use SIDES from the module
	local ARMADA = SIDES.ARMADA
	local CORTEX = SIDES.CORTEX
	local LEGION = SIDES.LEGION

    -- Clear existing tables (important if this function could be called multiple times on the same module instance, though typically not)
    for k in pairs(DefinitionsModule.UNIT_CATEGORIES) do DefinitionsModule.UNIT_CATEGORIES[k] = nil end
    for k in pairs(DefinitionsModule.categoryUnits) do DefinitionsModule.categoryUnits[k] = nil end
    for k in pairs(DefinitionsModule.unitCategories) do DefinitionsModule.unitCategories[k] = nil end

    -- Resource buildings
    DefCat("METAL_EXTRACTOR", {[ARMADA]="armmex", [CORTEX]="cormex", [LEGION]="legmex"})
    DefCat("EXPLOITER", {[ARMADA]="armamex", [CORTEX]="corexp", [LEGION]="legmext15"})
    DefCat("ADVANCED_EXTRACTOR", {[ARMADA]="armmoho", [CORTEX]="cormoho", [LEGION]="legmoho"})
    DefCat("ADVANCED_EXPLOITER", {[ARMADA]="armmoho", [CORTEX]="cormexp", [LEGION]="cormexp"})
    DefCat("UW_EXTRACTOR", {[ARMADA]="armuwmex", [CORTEX]="coruwmex", [LEGION]="leguwmex"})
    DefCat("ADVANCED_UW_EXTRACTOR", {[ARMADA]="armuwmme", [CORTEX]="coruwmme", [LEGION]="leguwmme"})
    DefCat("METAL_STORAGE", {[ARMADA]="armmstor", [CORTEX]="cormstor", [LEGION]="legmstor"})
    DefCat("ADVANCED_METAL_STORAGE", {[ARMADA]="armuwadvms", [CORTEX]="coramstor", [LEGION]="legamstor"})
    DefCat("UW_METAL_STORAGE", {[ARMADA]="armuwms", [CORTEX]="coruwms", [LEGION]="legamstor"})
    DefCat("UW_ADVANCED_METAL_STORAGE", {[ARMADA]="armuwadvms", [CORTEX]="coruwadvms", [LEGION]="coruwadvms"})

    -- Energy buildings
    DefCat("SOLAR", {[ARMADA]="armsolar", [CORTEX]="corsolar", [LEGION]="legsolar"})
    DefCat("ENERGY_CONVERTER", {[ARMADA]="armmakr", [CORTEX]="cormakr", [LEGION]="legeconv"})
    DefCat("ADVANCED_ENERGY_CONVERTER", {[ARMADA]="armmmkr", [CORTEX]="", [LEGION]="legadveconv"})
    DefCat("ADVANCED_SOLAR", {[ARMADA]="armadvsol", [CORTEX]="coradvsol", [LEGION]="legadvsol"})
    DefCat("WIND", {[ARMADA]="armwin", [CORTEX]="corwin", [LEGION]="legwin"})
    DefCat("TIDAL", {[ARMADA]="armtide", [CORTEX]="cortide", [LEGION]="legtide"})
    DefCat("FUSION", {[ARMADA]="armfus", [CORTEX]="corfus", [LEGION]="legfus"})
    DefCat("ADVANCED_FUSION", {[ARMADA]="armafus", [CORTEX]="corafus", [LEGION]="legafus"})
    DefCat("UW_FUSION", {[ARMADA]="armuwfus", [CORTEX]="coruwfus", [LEGION]="leguwfus"})
    DefCat("GEOTHERMAL", {[ARMADA]="armageo", [CORTEX]="corbhmth", [LEGION]="leggeo"})
    DefCat("ADVANCED_GEO", {[ARMADA]="armgmm", [CORTEX]="corgmm", [LEGION]="leggmm"})
    DefCat("UW_ADV_GEO", {[ARMADA]="armuwageo", [CORTEX]="coruwageo", [LEGION]="leguwageo"})
    DefCat("ENERGY_STORAGE", {[ARMADA]="armestor", [CORTEX]="corestor", [LEGION]="legestor"})
    DefCat("ADVANCED_ENERGY_STORAGE", {[ARMADA]="armuwadves", [CORTEX]="coradvestore", [LEGION]="legadvestore"})
    DefCat("UW_ENERGY_STORAGE", {[ARMADA]="armuwes", [CORTEX]="coruwes", [LEGION]="leguwes"})
    DefCat("UW_ADVANCED_ENERGY_STORAGE", {[ARMADA]="armuwadves", [CORTEX]="coruwadves", [LEGION]="coruwadves"})

    -- Factory buildings
    DefCat("BOT_LAB", {[ARMADA]="armlab", [CORTEX]="corlab", [LEGION]="leglab"})
    DefCat("VEHICLE_PLANT", {[ARMADA]="armvp", [CORTEX]="corvp", [LEGION]="legvp"})
    DefCat("AIRCRAFT_PLANT", {[ARMADA]="armap", [CORTEX]="corap", [LEGION]="legap"})
    DefCat("ADVANCED_AIRCRAFT_PLANT", {[ARMADA]="armaap", [CORTEX]="coraap", [LEGION]="legaap"})
    DefCat("SHIPYARD", {[ARMADA]="armsy", [CORTEX]="corsy", [LEGION]="corsy"})
    DefCat("ADVANCED_SHIPYARD", {[ARMADA]="armasy", [CORTEX]="corasy", [LEGION]="legasy"})
    DefCat("HOVER_PLATFORM", {[ARMADA]="armhp", [CORTEX]="corhp", [LEGION]="leghp"})
    DefCat("AIR_REPAIR_PAD", {[ARMADA]="armasp", [CORTEX]="corasp", [LEGION]="legasp"})
    DefCat("FLOATING_AIR_REPAIR_PAD", {[ARMADA]="armfasp", [CORTEX]="corfasp", [LEGION]="legfasp"})
    DefCat("EXPIREMENTAL_GANTRY", {[ARMADA]="armshltx", [CORTEX]="corgant", [LEGION]="leggant"})
    DefCat("SEAPLANE_PLATFORM", {[ARMADA]="armplat", [CORTEX]="corplat", [LEGION]="corplat"})

    -- Static defense buildings
    DefCat("LIGHT_LASER", {[ARMADA]="armllt", [CORTEX]="corllt", [LEGION]="leglht"})
    DefCat("HEAVY_LIGHT_LASER", {[ARMADA]="armbeamer", [CORTEX]="corhllt", [LEGION]="legmg"})
    DefCat("HEAVY_LASER", {[ARMADA]="armhlt", [CORTEX]="corhlt", [LEGION]="leghive"})
    DefCat("MISSILE_DEFENSE", {[ARMADA]="armrl", [CORTEX]="corrl", [LEGION]="legrl"})
    DefCat("SAM_SITE", {[ARMADA]="armcir", [CORTEX]="cormadsam", [LEGION]="legrhapsis"})
    DefCat("POPUP_AREA_DEFENSE", {[ARMADA]="armpb", [CORTEX]="corvipe", [LEGION]="legbombard"})
    DefCat("POPUP_AIR_DEFENSE", {[ARMADA]="armferret", [CORTEX]="corerad", [LEGION]="leglupara"})
    DefCat("FLAK", {[ARMADA]="armflak", [CORTEX]="corflak", [LEGION]="legflak"})
    DefCat("FLOATING_FLAK", {[ARMADA]="armfflak", [CORTEX]="corfflak", [LEGION]="legfflak"})
    DefCat("FLOATING_HEAVY_LASER", {[ARMADA]="armfhlt", [CORTEX]="corfhlt", [LEGION]="legfhlt"})
    DefCat("FLOATING_MISSILE", {[ARMADA]="armfrt", [CORTEX]="corfrt", [LEGION]="corfrt"})
    DefCat("LONG_RANGE_ANTI_AIR", {[ARMADA]="armmercury", [CORTEX]="corscreamer", [LEGION]="leglraa"})
    DefCat("TORPEDO", {[ARMADA]="armdl", [CORTEX]="cordl", [LEGION]="cordl"})
    DefCat("ADV_TORPEDO", {[ARMADA]="armatl", [CORTEX]="coratl", [LEGION]="legatl"})
    DefCat("OFFSHORE_TORPEDO", {[ARMADA]="armptl", [CORTEX]="corptl", [LEGION]="legptl"})
    DefCat("ARTILLERY", {[ARMADA]="armguard", [CORTEX]="corpun", [LEGION]="legcluster"})
    DefCat("LONG_RANGE_PLASMA_CANNON", {[ARMADA]="armbrtha", [CORTEX]="corint", [LEGION]="leglrpc"})
    DefCat("RAPID_FIRE_LONG_RANGE_PLASMA_CANNON", {[ARMADA]="armvulc", [CORTEX]="corbuzz", [LEGION]="legstarfall"})
    DefCat("ANNIHILATOR", {[ARMADA]="armanni", [CORTEX]="cordoom", [LEGION]="legbastion"})
    DefCat("ADVANCED_PLASMA_ARTILLERY", {[ARMADA]="armamb", [CORTEX]="cortoast", [LEGION]="legacluster"})
    DefCat("DRAGONS_CLAW", {[ARMADA]="armclaw", [CORTEX]="cormaw", [LEGION]="legdrag"})
    DefCat("DRAGONS_TEETH", {[ARMADA]="armdrag", [CORTEX]="cordrag", [LEGION]="legdrag"})
    DefCat("ADVANCED_DRAGONS_TEETH", {[ARMADA]="armfort", [CORTEX]="corfort", [LEGION]="legforti"})
    DefCat("SHIELD", {[ARMADA]="armgate", [CORTEX]="", [LEGION]="legdeflector"})
    DefCat("MEDIUM_RANGE_MISSILE", {[ARMADA]="armemp", [CORTEX]="cortron", [LEGION]="legperdition"})

    -- Intel and special buildings
    DefCat("RADAR", {[ARMADA]="armrad", [CORTEX]="corrad", [LEGION]="legrad"})
    DefCat("ADVANCED_RADAR", {[ARMADA]="armarad", [CORTEX]="corarad", [LEGION]="legarad"})
    DefCat("ADV_RADAR", {[ARMADA]="armarad", [CORTEX]="corarad", [LEGION]="legarad"})
    DefCat("JAMMER", {[ARMADA]="armjamt", [CORTEX]="corjamt", [LEGION]="legjam"})
    DefCat("ADVANCED_JAMMER", {[ARMADA]="armveil", [CORTEX]="corshroud", [LEGION]="legajam"})
    DefCat("SONAR", {[ARMADA]="armsonar", [CORTEX]="corsonar", [LEGION]="legsonar"})
    DefCat("ADV_SONAR", {[ARMADA]="armason", [CORTEX]="corason", [LEGION]="legason"})
    DefCat("CAMERA", {[ARMADA]="armeyes", [CORTEX]="coreyes", [LEGION]="legeyes"})
    DefCat("NUKE", {[ARMADA]="armsilo", [CORTEX]="corsilo", [LEGION]="legsilo"})
    DefCat("ANTINUKE", {[ARMADA]="armamd", [CORTEX]="corfmd", [LEGION]="legabm"})
    DefCat("JUNO", {[ARMADA]="armjuno", [CORTEX]="corjuno", [LEGION]="legjuno"})
    DefCat("NANO_TOWER", {[ARMADA]="armnanotc", [CORTEX]="cornanotc", [LEGION]="legnanotc"})
    DefCat("ADV_NANO_TOWER", {[ARMADA]="armnanotct2", [CORTEX]="cornanotct2", [LEGION]="legnanotct2"})
    DefCat("STEALTH_DETECTION", {[ARMADA]="armrsd", [CORTEX]="corrsd", [LEGION]="legsd"})
    DefCat("PINPOINTER", {[ARMADA]="armtarg", [CORTEX]="cortarg", [LEGION]="legtarg"})

    -- Categories derived from pregame_build.lua that were not directly matching or missing
    DefCat("FLOATING_TORPEDO_LAUNCHER_PG", {[ARMADA]="armtl", [CORTEX]="cortl", [LEGION]="cortl"})
    DefCat("FLOATING_RADAR_PG", {[ARMADA]="armfrad", [CORTEX]="corfrad", [LEGION]="corfrad"})
    DefCat("FLOATING_CONVERTER_PG", {[ARMADA]="armfmkr", [CORTEX]="corfmkr", [LEGION]="legfmkr"})
    DefCat("FLOATING_DRAGONSTEETH_PG", {[ARMADA]="armfdrag", [CORTEX]="corfdrag", [LEGION]="corfdrag"})
    DefCat("FLOATING_HOVER_PLATFORM_PG", {[ARMADA]="armfhp", [CORTEX]="corfhp", [LEGION]="legfhp"})

    -- NOT BUILDINGS
    DefCat("COMMANDER", {[ARMADA]="armcom", [CORTEX]="corcom", [LEGION]="legcom"})

    local unitCount = 0
    for _, units in pairs(DefinitionsModule.categoryUnits) do
        for _, unit in pairs(units) do
            if unit then unitCount = unitCount + 1 end
        end
    end
    local categoryCount = 0
    for _ in pairs(DefinitionsModule.UNIT_CATEGORIES) do categoryCount = categoryCount + 1 end
    Spring.Log("BlueprintDefs", LOG.INFO, string.format("Defined %d categories covering %d units. END", categoryCount, unitCount))
end

DefinitionsModule.defineUnitCategories() -- Call it once to populate the module table

return DefinitionsModule
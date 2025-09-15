-- This file processes all the unit-attached lights configs
-- Including cob-animated lights, like thruster attached ones, and fusion glows
-- Searchlights also
-- Muzzle glow also
-- Nanolasers also
-- (c) Beherith (mysterme@gmail.com)

-- Example Light:
-- ["lightName"] = {
--    lightType = "point", -- or cone or beam
--    -- if pieceName == nil then the light is treated as WORLD-SPACE
--    -- if pieceName == valid piecename, then the light is attached to that piece
--    -- if pieceName == invalid piecename, then the light is attached to base of unit
--    pieceName = nil,
--    -- If you want to make the light be offset from the top of the unit, specify how many elmos above it should be!
--    aboveUnit = nil,
--    -- Lights that should spawn even if they are outside of view need this set:
--    alwaysVisible = nil,
--    lightConfig = {
--       posx = 0, posy = 0, posz = 0, radius = 100,
--       r = 1, g = 1, b = 1, a = 1,
--       -- point lights only, colortime in seconds for unit-attached:
--          color2r = 1, color2g = 1, color2b = 1, colortime = 15,
--       -- cone lights only, specify direction and half-angle in radians:
--          dirx = 0, diry = 0, dirz = 1, theta = 0.5,
--       -- beam lights only, specifies the endpoint of the beam:
--          pos2x = 100, pos2y = 100, pos2z = 100,
--       modelfactor = 1, specular = 1, scattering = 1, lensflare = 1,
--       lifetime = 0, sustain = 1,    selfshadowing = 0
--    },
-- }

-- These become unit event lights:
local weaponLights = {}

-- Pull from DEFS before trying to copy duplicates.
-- Hardcoded values above supercede values in DEFS.

local function getLightsData(name, lights)
	local configs, data
	if lights.unitLights then
		configs = unitLights
		data = lights.unitLights
	elseif lights.weaponLights then
		configs = weaponLights
		data = lights.weaponLights
	else
		return
	end
	configs[name] = table.merge(data, configs[name] or {})
end

for name, lights in pairs(DEFS.lightDefs) do
	getLightsData(name, lights)
	DEFS.lightDefs[name] = nil
end
DEFS.lightDefs = nil -- consume input configs

-- Duplicate lights across units.

for unitName, copyFrom in pairs {
	armtorps   = "armmls",
	armshltxuw = "armshltx",
	corgantuw  = "corgant",
	armdecom   = "armcom",
	cordecom   = "corcom",
	armcomcon  = "armcom",
	corcomcon  = "corcom",
	armdf      = "armfus",
	armuwfus   = "armfus",
	armckfus   = "armfus",
	legdecom   = "legcom",
} do
	-- Handle options and tweaks that may remove some units:
	if UnitDefNames[unitName] and unitLights[copyFrom] then
		unitLights[unitName] = table.copy(unitLights[copyFrom])
	end
end

--AND THE REST
---unitEventLightsNames -> unitEventLights
local unitEventLights = {}
for key, subtables in pairs(unitEventLightsNames) do
		unitEventLights[key] = {}
		for subKey, lights in pairs(subtables) do
			if UnitDefNames[subKey] then
				unitEventLights[key][UnitDefNames[subKey].id] = lights
			else
				unitEventLights[key][subKey] = lights --preserve defaults etc
			end
		end
end
unitEventLightsNames = nil


-- convert unitname -> unitDefID
local unitDefLights = {}
for unitName, lights in pairs(unitLights) do
	if UnitDefNames[unitName] then
		unitDefLights[UnitDefNames[unitName].id] = lights
	end
end
unitLights = nil

if not (Spring.GetConfigInt("headlights", 1) == 1) then
	for unitDefID, lights in pairs(unitDefLights) do
		for name, params in pairs(lights) do
			if string.find(name, "headlight") or string.find(name, "searchlight") then
				unitDefLights[unitDefID][name] = nil
			end
		end
	end
end

if not (Spring.GetConfigInt("buildlights", 1) == 1) then
	for unitDefID, lights in pairs(unitDefLights) do
		for name, params in pairs(lights) do
			if string.find(name, "buildlight") then
				unitDefLights[unitDefID][name] = nil
			end
		end
	end
end

-- deep copy helper
local function deepcopy(orig)
    local orig_type = type(orig)
    if orig_type ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepcopy(v)
    end
    return copy
end

-- add scavenger equivalents with adjusted head/search-light colors
local scavUnitDefLights = {}
for unitDefID, lights in pairs(unitDefLights) do
    local baseName = UnitDefs[unitDefID].name
    local scavUD = UnitDefNames[baseName .. "_scav"]
    if scavUD then
        local newLights = {}
        for lightName, lightDef in pairs(lights) do
            local ld = deepcopy(lightDef)
            -- only tweak headlight or searchlight variants
            local lname = lightName:lower()
            if lname:find("headlight") or lname:find("searchlight") then
                ld.lightConfig.r = 0.50
                ld.lightConfig.g = 0.20
                ld.lightConfig.b = 1.1
				ld.lightConfig.a = 1.0
				ld.lightConfig.color2r = 0.58
                ld.lightConfig.color2g = 0.42
                ld.lightConfig.color2b = 1.15
            end
			if lname:find("eye") or lname:find("eyes") or lname:find("thrust") or lname:find("engine") or lname:find("lightning") then
                ld.lightConfig.r = 0.48
                ld.lightConfig.g = 0.20
                ld.lightConfig.b = 1.1
				--ld.lightConfig.a = 2.5
				ld.lightConfig.color2r = 0.55
                ld.lightConfig.color2g = 0.38
                ld.lightConfig.color2b = 1.2
            end
			if lname:find("flash") then
                ld.lightConfig.r = 0.48
                ld.lightConfig.g = 0.20
                ld.lightConfig.b = 1.1
            end
            newLights[lightName] = ld
        end
        scavUnitDefLights[scavUD.id] = newLights
    end
end

unitDefLights = table.merge(unitDefLights, scavUnitDefLights)
scavUnitDefLights = nil



-------------------- Feature Lights

local featureDefLights = {
}

local WreckBaseLight = {
	lightType = "point",
	lightConfig = { posx = 1, posy = -2 , posz = 1, radius = 9, -- underground relative to unit, radius will be overwritten
		dirx = 0.003, diry = 0.0035, dirz = 0.003, theta = 0.9,
		r = 1.2, g = 0.60, b = 0, a = 0.12, 		-- start at orange
		color2r = 0.6, color2g = 0.08, color2b = -0.5, colortime = 28, -- in 450 frames, transition to dull red
		modelfactor = 3.0, specular = -0.25, scattering = 4.6, lensflare = 0, -- no scatterin
		lifetime = 300, sustain = 1.1, selfshadowing = 0},  -- remove at 300 frames, sustain is exp alpha fade
}

for featureDefID, featureDef in pairs(FeatureDefs) do
	local name = featureDef.name
	if string.sub(name, string.len(name)-4) == "_dead" then
		local wreckRng = math.random() * 2 - 1
		local featureSize = math.sqrt((featureDef.xsize or 1) * (featureDef.zsize or 1)) / 2.1
		--Spring.Echo(name, featureDef.xsize , featureDef.zsize)
		local featureDefLight = table.copy(WreckBaseLight)
		featureDefLight.lightConfig.radius = featureSize * 19
		featureDefLight.lightConfig.colortime = featureDefLight.lightConfig.colortime * featureSize * 1.5
		--featureDefLight.lightConfig.lifetime = featureDefLight.lightConfig.lifetime * featureSize * 0.5
		--featureDefLight.lightConfig.sustain = featureDefLight.lightConfig.sustain / (featureSize * 1.4)
		featureDefLight.lightConfig.posx = featureDefLight.lightConfig.posx * (wreckRng * featureSize * 7)
		featureDefLight.lightConfig.posz = featureDefLight.lightConfig.posz * (wreckRng * featureSize * 7)
		if (featureSize > 3) then --for super large structures/units - lower light posy
			featureDefLight.lightConfig.posy = featureDefLight.lightConfig.posy * (featureSize * 4)
		end
		featureDefLight.lightConfig.dirx = featureDefLight.lightConfig.dirx * (wreckRng * (featureSize / 4) * 2)
		featureDefLight.lightConfig.dirz = featureDefLight.lightConfig.dirz * (wreckRng * (featureSize / 4) * 2)
		featureDefLights[featureDefID] = {FeatureCreated = featureDefLight}
	end
end




local crystalLightBase =  {
			lightType = "point",
			lightConfig = { posx = 0, posy = 12, posz = 0, radius = 72,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0.1,
							r = -1, g = 1, b = 1, a = 0.66,
							modelfactor = 1.1, specular = 0.9, scattering = 0.8, lensflare = 0,
							lifetime = 0, sustain = 0, selfshadowing = 0},
		}

local crystalColors = { -- note that the underscores are needed here
	[""] = {0.78,0.46,0.94,0.11}, -- same as violet
	_violet = {0.8,0.5,0.95,0.33},
	_blue = {0,0,1,0.33},
	_green = {0,1,0,0.15},
	_lime = {0.4,1,0.2,0.15},
	_obsidian = {0.3,0.2,0.2,0.33},
	_quartz = {0.3,0.3,0.5,0.33},
	_orange = {1,0.5,0,0.11},
	_red = {1,0.2,0.2,0.067},
	_teal = {0,1,1,0.15},
	_team = {1,1,1,0.15},
	}

for colorname, colorvalues in pairs(crystalColors) do
	for size = 1,3 do
		local crystaldefname = "pilha_crystal" .. colorname .. tostring(size)
		if FeatureDefNames[crystaldefname] then
			local crystalLight = table.copy(crystalLightBase)
			crystalLight.lightConfig.r = colorvalues[1]
			crystalLight.lightConfig.g = colorvalues[2]
			crystalLight.lightConfig.b = colorvalues[3]
			crystalLight.lightConfig.a = colorvalues[4]

			crystalLight.lightConfig.color2r   = colorvalues[1] * 0.6
			crystalLight.lightConfig.color2g   = colorvalues[2] * 0.6
			crystalLight.lightConfig.color2b   = colorvalues[3] * 0.6
			crystalLight.lightConfig.colortime = 0.002 + 0.01 / size


			crystalLight.lightConfig.radius = (size + 0.2) * (crystalLight.lightConfig.radius * 0.6)
			crystalLight.lightConfig.posy = (size + 1.5) * crystalLight.lightConfig.posy
			featureDefLights[FeatureDefNames[crystaldefname].id] = {crystalLight = crystalLight}
		end
	end
end

local fraction = 5
local day = tonumber(os.date("%d"))
if day <= 25 then
	fraction = fraction + (25 - day)
else
	fraction = fraction + ((day - 25) * 5)
end
local xmaslightbase = {
			fraction = fraction,
			lightType = "point",
			lightConfig = { posx = 0, posy = 0, posz = 0, radius = 5,
							color2r = 0, color2g = 0, color2b = 0, colortime = 0.1,
							r = 1, g = 1, b = 1, a = 0.12,
							modelfactor = 1.1, specular = 0.9, scattering = 4.5, lensflare = 20,
							lifetime = 0, sustain = 0, selfshadowing = 0},
}

-- Supreme Isthmus Winter 1.8.2
-- Ascendancy 2.2
-- Avalanche 3.4
-- blindside remake
-- Frozen Ford v2
-- Glacier pass 1.2
-- Nuclear Winter BAR 1.4
-- The cold place BAR v 1.1
-- White Fire Remake 1.3
-- Ice Scream v2.5.1
-- add colorful xmas lights to a percentage of certain snowy trees
if os.date("%m") == "12" and os.date("%d") >= "12" then --and  os.date("%d") <= "26"
	local snowy_tree_keys = {allpinesb_ad0 = 60, __tree_fir_tall_3 = 60, __tree_fir_ = 60}
	local xmasColors = {
		[1] = {234,13,13}, -- red
		[2] = {251,11,36}, -- orange
		[3] = {251,242,26}, -- yellow
		[4] = {36, 208, 36}, -- green
		[5] = {10,83, 222}, -- blue
	}

	for featureDefID , featureDef in pairs(FeatureDefs) do
		local featureName = featureDef.name
		-- Check if its a snowy tree:
		-- estimate its height/ radius via model extrema
		-- spawn lights in a cone shape around it
		for key, count in pairs(snowy_tree_keys) do
			if string.find(featureName, key, nil, true) then
				--Spring.Echo("Found snowy tree: " .. featureName, key)

				featureDefLights[featureDefID] = {}
				local maxy = featureDef.model.maxy
				local maxx = featureDef.model.maxx
				local maxz = featureDef.model.maxz

				for i= 1, count do
					local xmaslight = table.copy(xmaslightbase)

					local y = maxy * (math.random() * 0.8 +   0.1)
					local rely = 1.0 - y / maxy

					local x = rely * maxx * (math.random() - 0.5) * 1.5
					local z = rely * maxz * (math.random() - 0.5) * 1.5
					--Spring.Echo(maxx, maxy, maxz, x,y,z)
					xmaslight.lightConfig.posy = y
					xmaslight.lightConfig.posx = x
					xmaslight.lightConfig.posz = z

					local color = math.ceil(math.random() * 4)

					xmaslight.lightConfig.r = xmasColors[color][1] / 255
					xmaslight.lightConfig.g = xmasColors[color][2] / 255
					xmaslight.lightConfig.b = xmasColors[color][3] / 255

					xmaslight.lightConfig.color2r = xmasColors[color+1][1] /255
					xmaslight.lightConfig.color2g = xmasColors[color+1][2] /255
					xmaslight.lightConfig.color2b = xmasColors[color+1][3] /255


					--[[

					xmaslight.lightConfig.r = math.random() > 0.5 and 1 or 0
					xmaslight.lightConfig.g = math.random()> 0.5 and 1 or 0
					xmaslight.lightConfig.b = math.random()> 0.5 and 1 or 0

					xmaslight.lightConfig.color2r = math.random() > 0.5 and 1 or 0
					xmaslight.lightConfig.color2g = math.random()> 0.5 and 1 or 0
					xmaslight.lightConfig.color2b = math.random()> 0.5 and 1 or 0
					]]--

					xmaslight.lightConfig.colortime = 0.005 + math.random()* 0.005

					featureDefLights[featureDefID]["xmaslight" .. tostring(i)] = xmaslight

				end
				break
			end
		end
	end
end

local allLights = {
	unitEventLights  = unitEventLights,
	unitDefLights    = unitDefLights,
	featureDefLights = featureDefLights
}

----------------- Debugging code to do the reverse dump -----------------

--[[
local lightParamKeyOrder = {	posx = 1, posy = 2, posz = 3, radius = 4,
	r = 9, g = 10, b = 11, a = 12,
	color2r = 5, color2g = 6, color2b = 7, colortime = 8, -- point lights only, colortime in seconds for unit-attached
	dirx = 5, diry = 6, dirz = 7, theta = 8,  -- cone lights only, specify direction and half-angle in radians
	pos2x = 5, pos2y = 6, pos2z = 7, -- beam lights only, specifies the endpoint of the beam
	modelfactor = 13, specular = 14, scattering = 15, lensflare = 16,
	lifetime = 18, sustain = 19, selfshadowing = 20
}

for typename, typetable in pairs(allLights) do
	Spring.Echo(typename)
	for lightunitclass, classinfo in pairs(typetable) do
		if type(lightunitclass) == type(1) then
			Spring.Echo(UnitDefs[lightunitclass].name)
		else
			Spring.Echo(lightunitclass)
		end
		for lightname, lightinfo in pairs(classinfo) do
			Spring.Echo(lightname)
			local lightParamTable = lightinfo.lightParamTable
			Spring.Echo(string.format("			lightConfig = { posx = %f, posy = %f, posz = %f, radius = %f,", lightinfo.lightParamTable[1], lightParamTable[2],lightParamTable[3],lightParamTable[4] ))
			if lightinfo.lightType == "point" then
				Spring.Echo(string.format("				color2r = %f, color2g = %f, color2b = %f, colortime = %f,", lightinfo.lightParamTable[5], lightParamTable[6],lightParamTable[7],lightParamTable[8] ))

			elseif lightinfo.lightType == "beam" then
				Spring.Echo(string.format("				pos2x = %f, pos2y = %f, pos2z = %f,", lightinfo.lightParamTable[5], lightParamTable[6],lightParamTable[7]))
			elseif lightinfo.lightType == "cone" then
				Spring.Echo(string.format("				dirx = %f, diry = %f, dirz = %f, theta = %f,", lightinfo.lightParamTable[5], lightParamTable[6],lightParamTable[7],lightParamTable[8] ))

			end
			Spring.Echo(string.format("				r = %f, g = %f, b = %f, a = %f,", lightinfo.lightParamTable[9], lightParamTable[10],lightParamTable[11],lightParamTable[12] ))
			Spring.Echo(string.format("				modelfactor = %f, specular = %f, scattering = %f, lensflare = %f,", lightinfo.lightParamTable[13], lightParamTable[14],lightParamTable[15],lightParamTable[16] ))
			Spring.Echo(string.format("				lifetime = %f, sustain = %f, selfshadowing = %f},", lightinfo.lightParamTable[18], lightParamTable[19],lightParamTable[20]))

		end
	end
end
]]--

-- Icexuick Check-list


return allLights

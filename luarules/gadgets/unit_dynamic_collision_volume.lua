local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Dynamic collision volumes",
		desc    = "Manages collision volumes by setting, updating, and correcting them.",
		author  = "Deadnight Warrior, efrec",
		date    = "Nov 26, 2011",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local pairs = pairs

local spGetFeatureColVolData = Spring.GetFeatureCollisionVolumeData
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeatureHeight = Spring.GetFeatureHeight
local spGetFeatureRadius = Spring.GetFeatureRadius
local spGetUnitArmored = Spring.GetUnitArmored
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitDirection = Spring.GetUnitDirection
local spGetUnitPieceMatrix = Spring.GetUnitPieceMatrix

local spSetFeatureColVolData = Spring.SetFeatureCollisionVolumeData
local spSetFeatureRadiusAndHeight = Spring.SetFeatureRadiusAndHeight
local spSetPieceColVolData = Spring.SetUnitPieceCollisionVolumeData
local spSetUnitColVolData = Spring.SetUnitCollisionVolumeData
local spSetUnitMidAndAimPos = Spring.SetUnitMidAndAimPos
local spSetUnitRadiusAndHeight = Spring.SetUnitRadiusAndHeight

-- Initialization --------------------------------------------------------------

local unitDefColVolData = {}
local unitDefColVolIndex ---@type table<string|integer, 1|2|3|4>
local colvolFeatureModel ---@type table

local featureModelType = {}
for featureDefID, featureDef in ipairs(FeatureDefs) do
	featureModelType[featureDefID] = featureDef.modeltype
end

local popupUnits = {} -- Pop-up style unit volumes
local colvolCtrl = {} -- Managed collision volumes
local wasCreated = {} -- Late-loading unitDef data

-- Local functions -------------------------------------------------------------

local function loadColVolConfigs()
	local CollisionVolumes = VFS.Include("LuaRules/Configs/CollisionVolumes.lua")

	local unitDefColVolConfig = CollisionVolumes.ColVolConfigs ---@type CollisionVolumeConfigs
	unitDefColVolIndex = CollisionVolumes.UnitDefColVolIndex ---@type table<string|integer, 1|2|3|4>

	for unitDefID in ipairs(UnitDefs) do
		local configType = unitDefColVolIndex[unitDefID]
		local config = configType and unitDefColVolConfig[configType][unitDefID]

		unitDefColVolData[unitDefID] = config or false

		if not config or getmetatable(config) == nil then
			wasCreated[unitDefID] = true -- has full colvol info available
		end
	end

	colvolFeatureModel = CollisionVolumes.ModelToVolumeScale.FEATURE ---@type table
end

local function getMidAimPosition(unitID, colvol, config)
	local height = (colvol.height or spGetUnitHeight(unitID)) * 0.5
	local map = { 0, height, 0, 0, height, 0, true }

	if config.on then
		if not config.on.offsets then
			config.on.offsets = map
		end
		if not config.off.offsets then
			config.off.offsets = map
		end
	else
		colvol.offsets = map
	end

	return map
end

local function updateDynamicUnitVolume(unitID, popup)
	local state = spGetUnitArmored(unitID) and "off" or "on"
	if popup.state ~= state and spGetUnitIsDead(unitID) == false then
		popup.state = state
		local colvol = popup.config[state]
		if popup.configType == 2 then
			spSetUnitColVolData(unitID, colvol[1], colvol[2], colvol[3], colvol[4], colvol[5], colvol[6], colvol[7], colvol[8], colvol[9])
		else
			for piece = 1, colvol.count do
				local p = colvol[piece]
				spSetPieceColVolData(unitID, piece, p[9], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
			end
		end
		local unitHeight
		if colvol.radius or colvol.height then
			unitHeight = colvol.height or spGetUnitHeight(unitID) or 0
			spSetUnitRadiusAndHeight(unitID, colvol.radius, unitHeight)
		else
			unitHeight = spGetUnitHeight(unitID) or 0
		end
		local offset = colvol.offset
		if offset then
			spSetUnitMidAndAimPos(unitID, offset[1], unitHeight * 0.5, offset[3], offset[4], offset[5], offset[6], true)
		else
			spSetUnitMidAndAimPos(unitID, 0, unitHeight * 0.5, 0, 0, unitHeight * 0.5, 0, true)
		end
	end
end

local function setMapFeatureVolume(featureID, data)
	spSetFeatureColVolData(featureID, data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9])
	spSetFeatureRadiusAndHeight(featureID, math.min(data[1], data[3]) * 0.5, data[2])
end

local function getSetMapFeatureS3o(featureID)
	local sx, sy, sz, ox, oy, oz, vtype, htype = spGetFeatureColVolData(featureID)
	if vtype >= 3 and sx == sy and sy == sz then
		local model = colvolFeatureModel["S3O"]
		local scale, toOffset = model.HEIGHT_SCALE, model.HEIGHT_TO_OFFSET
		local vType, pAxis = model.VOLUME_TYPE, model.VOLUME_AXIS -- Only used for map features? Trees, I guess?
		spSetFeatureColVolData(featureID, sx, sy * scale, sz, ox, oy + sy * toOffset, oz, vType, htype, pAxis)
	end
end

local function getSetFeature3do(featureID)
	local model = colvolFeatureModel["3DO"]
	local rs, hs
	if spGetFeatureRadius(featureID) > model.SMALL_RADIUS then
		rs, hs = model.RADIUS_SCALE, model.HEIGHT_SCALE
	else
		rs, hs = model.SMALL_RADIUS_SCALE, model.SMALL_HEIGHT_SCALE
	end
	local toOffset = model.HEIGHT_TO_OFFSET

	local sx, sy, sz, ox, oy, oz, vtype, htype, axis = spGetFeatureColVolData(featureID)
	if vtype >= 3 and sx == sy and sy == sz then
		spSetFeatureColVolData(featureID, sx * rs, sy * hs, sz * rs, ox, oy + sy * toOffset * rs, oz, vtype, htype, axis)
	end
	spSetFeatureRadiusAndHeight(featureID, spGetFeatureRadius(featureID) * rs, spGetFeatureHeight(featureID) * hs)
end

local function getSetFeatureS3o(featureID)
	local sx, sy, sz, ox, oy, oz, vtype, htype, axis = spGetFeatureColVolData(featureID)
	if vtype >= 3 and sx == sy and sy == sz then
		local model = colvolFeatureModel["S3O"]
		local scale, toOffset = model.HEIGHT_SCALE, model.HEIGHT_TO_OFFSET -- Ignore vType, pAxis, unlike map features.
		spSetFeatureColVolData(featureID, sx, sy * scale, sz, ox, oy + sy * toOffset, oz, vtype, htype, axis)
	end
end

local function loadMapFeatures(allFeatures)
	local mapConfig = "LuaRules/Configs/DynCVmapCFG/" .. tostring(Game.mapName) .. ".lua"

	if VFS.FileExists(mapConfig) then
		local mapFeatures = VFS.Include(mapConfig)
		for i = 1, #allFeatures do
			local featureID = allFeatures[i]
			local featDefID = spGetFeatureDefID(featureID)
			local modelPath = FeatureDefs[featDefID].modelpath:lower()
			if modelPath:len() > 4 then
				local mapFeature = mapFeatures[modelPath:sub(1, -5)]
				if mapFeature then
					setMapFeatureVolume(featureID, mapFeature)
				elseif featureModelType[featDefID] == "s3o" then
					getSetMapFeatureS3o(featureID)
				end
			end
		end
	else
		for i = 1, #allFeatures do
			local featureID = allFeatures[i]
			local modelType = featureModelType[spGetFeatureDefID(featureID)]
			if modelType == "3do" then
				getSetFeature3do(featureID)
			elseif modelType == "s3o" then
				getSetFeatureS3o(featureID)
			end
		end
	end
end

-- API controllers -------------------------------------------------------------

---Fetches collision volume data "safely" without prematurely tripping the lazy-
---loading behavior of some colvol data that is missing at initialization time.
---@param unitDefID integer
---@return UnitColVolConfig colvol
---@return 1|2|3|4 colvolTypeIndex Unit:1|2, Piece:3|4, Static:1|3, Dynamic:2|4
---@return boolean hasCompleteData Some def colvol data is fetched at UnitCreated
GG.GetUnitDefCollisionVolumeData = function(unitDefID)
	local configType = unitDefColVolIndex[unitDefID]
	if wasCreated[unitDefID] then
		local config = unitDefColVolData[unitDefID]
		return config, configType, true
	else
		return {}, configType, false
	end
end

---Enable or disable manual control over collision volumes.
GG.CollisionVolumeCtrl = function(unitID, state)
	colvolCtrl[unitID] = state or nil
end

---Update a popup-style unit's collision volume, depending on its current state,
---or restore a non-dynamic collision volume to its original, static dimensions.
GG.RestoreDefaultColVol = function(unitID)
	if popupUnits[unitID] then
		updateDynamicUnitVolume(unitID, popupUnits[unitID])
	else
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end

-- Utilities -------------------------------------------------------------------

local function dotProduct(ax, ay, az, bx, by, bz)
	return ax * bx + ay * by + az * bz
end

GG.WorldToUnitBasis = function(x, y, z, unitID)
	local frontX, frontY, frontZ, rightX, rightY, rightZ, upX, upY, upZ = spGetUnitDirection(unitID)
	return
		dotProduct(x, y, z, rightX, rightY, rightZ),
		dotProduct(x, y, z, upX, upY, upZ),
		dotProduct(x, y, z, frontX, frontY, frontZ)
end

GG.UnitToWorldBasis = function(x, y, z, unitID)
	local frontX, frontY, frontZ, rightX, rightY, rightZ, upX, upY, upZ = spGetUnitDirection(unitID)
	return
		dotProduct(x, y, z, rightX, upX, frontX),
		dotProduct(x, y, z, rightY, upY, frontY),
		dotProduct(x, y, z, rightZ, upZ, frontZ)
end

GG.WorldToPieceBasis = function(x, y, z, unitID, pieceID)
	local
	m11, m12, m13, m14, -- 4x4 matrix with some values elided
	m21, m22, m23, m24,
	m31, m32, m33, m34 = spGetUnitPieceMatrix(unitID, pieceID)
	return
		dotProduct(x, y, z, m11, m12, m13),
		dotProduct(x, y, z, m21, m22, m23),
		dotProduct(x, y, z, m31, m32, m33)
end

GG.PieceToWorldBasis = function(x, y, z, unitID, pieceID)
	local
	m11, m12, m13, m14, -- 4x4 matrix with some values elided
	m21, m22, m23, m24,
	m31, m32, m33, m34 = spGetUnitPieceMatrix(unitID, pieceID)
	return
		dotProduct(x, y, z, m11, m21, m31),
		dotProduct(x, y, z, m12, m22, m32),
		dotProduct(x, y, z, m13, m23, m33)
end

-- Engine callins --------------------------------------------------------------

function gadget:Initialize()
	loadColVolConfigs()

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end

	local allFeatures = Spring.GetAllFeatures()
	loadMapFeatures(allFeatures)
end

function gadget:FeatureCreated(featureID, allyTeam)
	if featureModelType[spGetFeatureDefID(featureID)] == "3do" then
		getSetFeature3do(featureID)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local config, configType = unitDefColVolData[unitDefID], unitDefColVolIndex[unitDefID]

	local vol = config.on
	if vol then
		popupUnits[unitID] = { config = config, configType = configType, state = "on" }
	else
		vol = config
	end

	if configType <= 2 then
		spSetUnitColVolData(unitID, vol[1], vol[2], vol[3], vol[4], vol[5], vol[6], vol[7], vol[8], vol[9])
	else
		for piece = 1, vol.count do
			local p = vol[piece]
			spSetPieceColVolData(unitID, piece, p[9], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8])
		end
	end

	if vol.radius or vol.height then
		spSetUnitRadiusAndHeight(unitID, vol.radius, vol.height)
	end

	local mao = vol.offsets or getMidAimPosition(unitID, vol, config)
	spSetUnitMidAndAimPos(unitID, mao[1], mao[2], mao[3], mao[4], mao[5], mao[6], mao[7])

	wasCreated[unitDefID] = true
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	popupUnits[unitID] = nil
	colvolCtrl[unitID] = nil
end

function gadget:GameFrame(n)
	if n % 15 == 0 then
		for unitID, data in pairs(popupUnits) do
			if not colvolCtrl[unitID] then
				updateDynamicUnitVolume(unitID, data)
			end
		end
	end
end

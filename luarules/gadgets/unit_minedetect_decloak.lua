if (not gadgetHandler:IsSyncedCode()) then return end

function gadget:GetInfo()
	return {
		name    = "Mine Detect and Decloak",
		desc    = "Toggleable mine detection that decloaks mines",
		author  = "efrec",
		date    = "2024-07-21",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end


--------------------------------------------------------------------------------
-- Configuration ---------------------------------------------------------------

local detectionRate = 0.5
local detectionTime = 10

local cegSpawnName = "radarpulse_minesweep_slow"
local cegSpawnTime = 4

---- Customparams setup --------------------------------------------------------
-- 
-- onoffable = true,                             -- << Required.
-- customparams = {
--     onoffname             = "minedetection",  -- << Required.
--     minedetection_radius  = <number> | default radius
-- }
-- 
-- Where the default radius is a function of:
-- (1) sightDistance
-- (2) radarDistance
-- (3) anti-mine weapon range
-- (4) anti-mine weapon area of effect
-- (5) the inverse detection rate, so slow polling rates don't cause issues.


--------------------------------------------------------------------------------
-- Deglobalization -------------------------------------------------------------

local spGetUnitAllyTeam   = Spring.GetUnitAllyTeam
local spGetUnitPosition   = Spring.GetUnitPosition

PokeDecloakUnit = GG.PokeDecloakUnit
local CMD_ONOFF = CMD.ONOFF
local CMD_OFF   = CMD.OFF
local CMD_ON    = CMD.ON
local OFF, ON   = 0, 1


--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

detectionRate = math.round(detectionRate * Game.gameSpeed)
detectionTime = math.round(detectionTime * Game.gameSpeed)
cegSpawnTime  = math.round(cegSpawnTime * (Game.gameSpeed / detectionRate))

-- Find all defs that are immobile mines.

local mineUnitDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if tonumber(unitDef.customParams.detonaterange) then
		mineUnitDefs[unitDefID] = true
	end
end

-- Find all defs that detect or damage mines (specifically).

local mineDetectorDefs = {}
local mineSweeperWDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.onoffname == "minedetection" then
		local radius = tonumber(unitDef.customParams.minedetection_radius) or 0
		if radius == 0 then
			for index, weapon in ipairs(unitDef.weapons) do
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if string.find(weaponDef.name, "mine") then
					mineDetectorDefs[unitDefID] = (
							1 * (weaponDef.range + weaponDef.damageAreaOfEffect / 2) +
							2 * math.max(unitDef.sightDistance, unitDef.radarDistance)
						) / 3
						-- Add some range for slower poll rates:
						+ 200 * (detectionRate / Game.gameSpeed)
					break
				end
			end
		end
		if radius > 0 then
			mineDetectorDefs[unitDefID] = radius
		end
	end
end

-- Keep track of mines and minesweepers.

local mines = {}
local mineDetectors = {}


--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

local addTrackedUnit
local removeTrackedUnit
local getSearchRegions
do
	-- Populate some info tables for tracking stationary objects.
	local regions = {}
	local searches = {}
	local unitToIndex = {}

	-- Our grid cells have to be larger than the largest detection radius
	-- and can be any size larger than that (to prevent making 1M regions).
	local gridSize = 128 -- NB: The maximum grid cell count is this, squared.
	local hashSize = -math.huge
	for unitDefID, detectionRadius in pairs(mineDetectorDefs) do
		if detectionRadius > hashSize then
			hashSize = detectionRadius
		end
	end
	hashSize = hashSize + 8*2 -- add some mine width or whatever
	hashSize = math.max(hashSize, math.min(Game.mapSizeX, Game.mapSizeZ) / gridSize)

	-- Ignoring out-of-bounds positions:
	local mapSizeX = 1 + math.ceil(Game.mapSizeX / hashSize)
	local mapSizeZ = 1 + math.ceil(Game.mapSizeZ / hashSize)

	local mapSizeA = math.min(gridSize, math.max(1, mapSizeX, mapSizeZ))
	local mapSizeB = math.max(1, math.round(math.min(gridSize, mapSizeX, mapSizeZ) / mapSizeA))
	if mapSizeX < mapSizeZ then
		mapSizeX = math.min(mapSizeA, mapSizeB)
		mapSizeZ = math.max(mapSizeA, mapSizeB)
	else
		mapSizeX = math.max(mapSizeA, mapSizeB)
		mapSizeZ = math.min(mapSizeA, mapSizeB)
	end

	-- Row-ordered index over a grid
	local function regionIndex(x, z)
		return 1 + math.round(x / hashSize) +
		           math.round(z / hashSize) * mapSizeX
	end

	for ii = 1, regionIndex(Game.mapSizeX, Game.mapSizeZ) do
		local adjacencies = {}

		local ix = math.floor(ii / mapSizeX)
		local iz = math.round((ii - ix) / mapSizeZ)

		local xfirst = ix == 1
		local zfirst = iz == 1
		local xfinal = ix == mapSizeX
		local zfinal = iz == mapSizeZ

		-- if only there were a better way
		-- corners
		if xfirst and zfirst then
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii + mapSizeX)
			table.insert(adjacencies, ii + mapSizeX + 1)
		elseif xfinal and zfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii - mapSizeX)
			table.insert(adjacencies, ii - mapSizeX - 1)
		elseif xfirst and zfinal then
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii - mapSizeX)
			table.insert(adjacencies, ii - mapSizeX + 1)
		elseif zfirst and xfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + mapSizeX)
			table.insert(adjacencies, ii + mapSizeX - 1)
		-- sides
		elseif xfirst then
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii + mapSizeX)
			table.insert(adjacencies, ii - mapSizeX)
			table.insert(adjacencies, ii + mapSizeX + 1)
			table.insert(adjacencies, ii - mapSizeX + 1)
		elseif xfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + mapSizeX)
			table.insert(adjacencies, ii - mapSizeX)
			table.insert(adjacencies, ii + mapSizeX - 1)
			table.insert(adjacencies, ii - mapSizeX - 1)
		elseif zfirst then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii + mapSizeX)
			table.insert(adjacencies, ii + mapSizeX + 1)
			table.insert(adjacencies, ii + mapSizeX - 1)
		elseif zfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii - mapSizeX)
			table.insert(adjacencies, ii - mapSizeX + 1)
			table.insert(adjacencies, ii - mapSizeX - 1)
		-- middle
		else
			adjacencies = {
			    ii - 1 + mapSizeX ,   ii + mapSizeX ,   ii + 1 + mapSizeX ,
			    ii - 1            ,  --[[ midpoint]]    ii + 1            ,
			    ii - 1 - mapSizeX ,   ii - mapSizeX ,   ii + 1 - mapSizeX ,
			}
		end

		searches[ii] = adjacencies
		table.insert(searches[ii], ii)
	end

	addTrackedUnit = function(unitID)
		local allyID  = spGetUnitAllyTeam(unitID)
		local x, y, z = spGetUnitPosition(unitID)
		if not x then return end -- born to the abyss, rip

		local index = regionIndex(x, z)
		unitToIndex[unitID] = index

		if not regions[index] then
			regions[index] = {}
		end
		table.insert(regions[index], unitID)

		mines[unitID] = { allyID, x, y, z }
	end

	removeTrackedUnit = function(unitID)
		local index = unitToIndex[unitID]
		unitToIndex[unitID] = nil

		local region = regions[index]
		table.removeFirst(region, unitID)
		if #region == 0 then
			regions[index] = nil
		end

		mines[unitID] = nil
	end

	getSearchRegions = function(x, z)
		local searchRegions = {}
		for _, index in ipairs(searches[regionIndex(x, z)]) do
			if regions[index] then
				searchRegions[#searchRegions+1] = regions[index]
			end
		end
		return searchRegions
	end
end

local function detectEnemyMines(unitID, params)
	if not (Spring.GetUnitIsStunned(unitID)) then
		local ux, uy, uz = Spring.GetUnitPosition(unitID) -- from base
		if not ux then return end -- maybe dead

		local allyID  = params[1]
		local detect2 = params[2] * params[2]
		local regions = getSearchRegions(ux, uz)

		for _, region in ipairs(regions) do
			for _, mineID in ipairs(region) do
				local mineData = mines[mineID]
				if allyID ~= mineData[1] then
					local distanceSq = (mineData[2] - ux) * (mineData[2] - ux) +
					                   (mineData[3] - uy) * (mineData[3] - uy) +
					                   (mineData[4] - uz) * (mineData[4] - uz)
					if detect2 >= distanceSq then
						PokeDecloakUnit(mineID, detectionTime)
					end
				end
			end
		end
	end
end

local function setMineDetection(unitID, unitDefID, state)	
	if state == ON then
		mineDetectors[unitID] = { spGetUnitAllyTeam(unitID), mineDetectorDefs[unitDefID] }
	else
		mineDetectors[unitID] = nil
	end
	return false -- continue processing other on/off's
end


--------------------------------------------------------------------------------
-- Gadget call-ins -------------------------------------------------------------

function gadget:Initialize()
	-- Remove only if there is total certainty that we may do so.
	if not next(mineUnitDefs) or not next(mineDetectorDefs) then
		Spring.Log(gadget:GetInfo().name, LOG.INFO,
			"No mine detectors or sweepers found. Removing gadget.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	-- Init/restore unit tracking.
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(
			unitID,
			Spring.GetUnitDefID(unitID),
			Spring.GetUnitTeam(unitID)
		)
	end
end

function gadget:GameFrame(gameFrame)
	for unitID, params in pairs(mineDetectors) do
		if (unitID + gameFrame) % detectionRate == 0 then
			detectEnemyMines(unitID, params)
			if (unitID + gameFrame) % cegSpawnTime == 0 then
				Spring.SpawnCEG(cegSpawnName, ux, uy, uz, 0, 0, 0, 0, 0)
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if mineUnitDefs[unitDefID] then
		addTrackedUnit(unitID)
	elseif mineDetectorDefs[unitDefID] then
		setMineDetection(unitID, unitDefID, ON)
	end
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	if mineUnitDefs[unitDefID] then
		mines[unitID][1] = spGetUnitAllyTeam(unitID)
	elseif mineDetectorDefs[unitDefID] then
		mineDetectors[unitID][1] = spGetUnitAllyTeam(unitID)
	end
end

function gadget:UnitDestroyed(unitID)
	if mines[unitID] then
		removeTrackedUnit(unitID)
	else
		mineDetectors[unitID] = nil
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if (cmdID == CMD_ONOFF or cmdID == CMD_ON or cmdID == CMD_OFF)
		and mineDetectorDefs[unitDefID]
	then
		return not setMineDetection(
			unitID, unitDefID,
			(cmdID == CMD_ON  and ON)  or
			(cmdID == CMD_OFF and OFF) or
			(not mineDetectors[unitDefID] and ON) or OFF
		)
	else
		return true -- continue processing
	end
end
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

local detectionRate = 37 / 30
local detectionTime = 10

---- Customparams setup --------------------------------------------------------
-- 
-- onoffable = true,                                     -- << Required.
-- customparams = {
--     onoffname             = "minedetection",          -- << Required.
--     minedetection_radius  = <number> | default radius
-- }


--------------------------------------------------------------------------------
-- Deglobalization -------------------------------------------------------------

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitPosition = Spring.GetUnitPosition

local PokeDecloakUnit = GG.PokeDecloakUnit

local CMD_ONOFF = CMD.ONOFF
local CMD_OFF   = CMD.OFF
local CMD_ON    = CMD.ON
local OFF, ON   = 0, 1


--------------------------------------------------------------------------------
-- Initialization --------------------------------------------------------------

detectionRate = math.round(detectionRate * Game.gameSpeed)
detectionTime = math.round(detectionTime * Game.gameSpeed)

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
			-- Try to define a reasonable radius based on the unit:
			for index, weapon in ipairs(unitDef.weapons) do
				local weaponDef = WeaponDefs[weapon.weaponDef]
				if string.find(weaponDef.name, "mine") then
					radius = (
							1 * (weaponDef.range + weaponDef.damageAreaOfEffect / 2) +
							2 * math.max(unitDef.sightDistance, unitDef.radarDistance)
						) / 3
						-- Add some range for slower poll rates:
						+ unitDef.speed * (detectionRate / Game.gameSpeed)
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

-- Grid spatial indexing with variable-radius range search.

local gridRegions = {}
local unitToIndex = {}

-- The size of each grid cell must meet or exceed the largest search radius.
-- For efficiency, they should not be significantly larger than that amount.
local cellSize = 0
for unitDefID, detectionRadius in pairs(mineDetectorDefs) do
	if cellSize < detectionRadius then
		cellSize = detectionRadius
	end
end

-- For memory space, though, we want larger cells, to produce fewer regions.
-- This allows tracked positions to fall outside the map (by at most cellSize):
local gridSizeMax = 128 * 128
cellSize = math.ceil(math.sqrt(math.max(
	cellSize * cellSize,
	((Game.mapSizeX + cellSize) / gridSizeMax) *
	((Game.mapSizeZ + cellSize) / gridSizeMax)
)))
local rows = math.ceil((Game.mapSizeX + cellSize) / cellSize)
local cols = math.ceil((Game.mapSizeZ + cellSize) / cellSize)


--------------------------------------------------------------------------------
-- Local functions -------------------------------------------------------------

---Index your grid
local floor = math.floor
local function getRegionIndex(x, z)
	return floor(1.5 + x / cellSize) +
	       floor(1.5 + z / cellSize) * rows
end

---Debug your grid
function pingRegionIndex(indices)
	if type(indices) == "number" then
		local index = indices % (rows * cols)
		local ix = index % rows
		local iz = (index - ix) / rows
		local mx = (ix - 0.5) * cellSize
		local mz = (iz - 0.5) * cellSize
		local my = Spring.GetGroundHeight(mx, mz)
		Spring.MarkerAddPoint(mx, my, mz, "region "..index.." ("..ix..",".. iz..")")
	elseif type(indices) == "table" then
		for _, index in ipairs(indices) do
			pingRegionIndex(index)
		end
	end
end

---Add a unit and its tracking data to its grid cell
local addTrackedUnit = function(unitID)
	local allyID  = spGetUnitAllyTeam(unitID)
	local x, _, z = spGetUnitPosition(unitID)
	if not x then return end -- born to the abyss, rip

	local index = getRegionIndex(x, z)
	unitToIndex[unitID] = index
	if not gridRegions[index] then
		gridRegions[index] = {}
	end
	table.insert(gridRegions[index], unitID)

	mines[unitID] = { allyID, x, z }
end

---Find and remove a unit from its grid cell
local removeTrackedUnit = function(unitID)
	local index = unitToIndex[unitID]
	unitToIndex[unitID] = nil
	if index then
		local region = gridRegions[index]
		table.removeFirst(region, unitID)
		if #region == 0 then
			gridRegions[index] = nil
		end
	end
	mines[unitID] = nil
end

local getSearchRegions
do
	local gridQueries = {}
	for ii = 0, getRegionIndex(Game.mapSizeX + cellSize, Game.mapSizeZ + cellSize) do
		local adjacencies = {}

		local iz = math.floor(ii / rows)
		local ix = ii - iz * rows

		local xfirst = ix == 1
		local zfirst = iz == 1
		local xfinal = ix == rows
		local zfinal = iz == cols

		-- if only there were a better way
		-- corners
		if xfirst and zfirst then
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii + rows)
			table.insert(adjacencies, ii + rows + 1)
		elseif xfinal and zfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii - rows)
			table.insert(adjacencies, ii - rows - 1)
		elseif xfirst and zfinal then
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii - rows)
			table.insert(adjacencies, ii - rows + 1)
		elseif zfirst and xfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + rows)
			table.insert(adjacencies, ii + rows - 1)
		-- sides
		elseif xfirst then
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii + rows)
			table.insert(adjacencies, ii - rows)
			table.insert(adjacencies, ii + rows + 1)
			table.insert(adjacencies, ii - rows + 1)
		elseif xfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + rows)
			table.insert(adjacencies, ii - rows)
			table.insert(adjacencies, ii + rows - 1)
			table.insert(adjacencies, ii - rows - 1)
		elseif zfirst then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii + rows)
			table.insert(adjacencies, ii + rows + 1)
			table.insert(adjacencies, ii + rows - 1)
		elseif zfinal then
			table.insert(adjacencies, ii - 1)
			table.insert(adjacencies, ii + 1)
			table.insert(adjacencies, ii - rows)
			table.insert(adjacencies, ii - rows + 1)
			table.insert(adjacencies, ii - rows - 1)
		-- middle
		else
			adjacencies = {
				ii - 1 + rows ,   ii + rows ,   ii + 1 + rows ,
				ii - 1        , --[[midpoint]]  ii + 1        ,
				ii - 1 - rows ,   ii - rows ,   ii + 1 - rows ,
			}
		end

		gridQueries[ii] = adjacencies
		table.insert(gridQueries[ii], ii)
	end

	---Get the regions to search surrounding an x-z coordinate
	getSearchRegions = function(x, z)
		local searchRegions = {}
		local regions = gridRegions
		local indices = gridQueries[getRegionIndex(x, z)]
		for ii = 1, #indices do
			searchRegions[#searchRegions+1] = regions[indices[ii]]
		end
		return searchRegions
	end
end

---Handle the onoffable toggle state for minesweepers.
local function setMineDetection(unitID, unitDefID, state)	
	if state == ON then
		mineDetectors[unitID] = { spGetUnitAllyTeam(unitID), mineDetectorDefs[unitDefID] }
	elseif state == OFF then
		mineDetectors[unitID] = nil
	end
	return true -- continue processing other on/off's
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
	local regions = gridRegions
	for unitID, params in pairs(mineDetectors) do
		if (unitID + gameFrame) % detectionRate == 0 then
			if not (Spring.GetUnitIsStunned(unitID)) then
				local allyID = params[1]
				local spotSq = params[2] * params[2]
				local ux, uy, uz = Spring.GetUnitPosition(unitID) -- from base

				local indices = getSearchRegions(ux, uz)
				for ii = 1, #indices do
					local region = regions[indices[ii]]
					for jj = 1, #region do
						local mineID   = region[jj]
						local mineData = mines[mineID]
						if allyID ~= mineData[1] then
							local mx, mz = mineData[2], mineData[3]
							local distSq = (mx-ux)*(mx-ux) + (mz-uz)*(mz-uz)
							if spotSq >= distSq then
								local duration = detectionTime * (1 - distSq / (2 * spotSq))
								PokeDecloakUnit(mineID, duration)
							end
						end
					end
				end
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
		and mineDetectorDefs[unitDefID] then
		return setMineDetection(
			unitID, unitDefID,
			(cmdID == CMD_ON  and ON)  or
			(cmdID == CMD_OFF and OFF) or
			(not mineDetectors[unitDefID] and ON) or OFF
		)
	else
		return true -- continue processing
	end
end
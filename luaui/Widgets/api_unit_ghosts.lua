local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Ghosts API",
		desc = "Receives events from the unsynced gadget api_unit_ghosts and keeps them in sync",
		author = "efrec, Chronographer",
		date = "2026-06",
		license = "GNU GPL, v2 or later",
		layer = -1000, -- Before any wupgets that would use it.
		enabled = true,
		hidden = true, -- cannot be disabled by users
	}
end

local ghostPosition = {} ---@type { UnitID? : UnitGhostPosition }
local generation = -1 -- `-1` forces a full reset and push

-- Interface functions ---------------------------------------------------------

local function getUnitGhostsInCylinder(x, z, radius)
	local radiusSquared = radius * radius
	local units, count = {}, 0
	for unitID, position in pairs(ghostPosition) do
		local dx = position[4] - x
		local dz = position[6] - z
		if dx * dx + dz * dz <= radiusSquared then
			count = count + 1
			units[count] = unitID
		end
	end
	return units, count
end

local function getUnitGhostsInSphere(x, y, z, radius)
	local radiusSquared = radius * radius
	local units, count = {}, 0
	for unitID, position in pairs(ghostPosition) do
		local dx = position[4] - x
		local dy = position[5] - y
		local dz = position[6] - z
		if dx * dx + dy * dy + dz * dz <= radiusSquared then
			count = count + 1
			units[count] = unitID
		end
	end
	return units, count
end

local function getUnitGhostsInRectangle(xMin, zMin, xMax, zMax)
	local units, count = {}, 0
	for unitID, position in pairs(ghostPosition) do
		if xMin <= position[4] and xMax >= position[4] and zMin <= position[6] and zMax >= position[6] then
			count = count + 1
			units[count] = unitID
		end
	end
	return units, count
end

-- Script calls via the unsynced gadget ----------------------------------------

local function unitGhostsChanged(counter, added, removed)
	for unitID in pairs(removed) do
		ghostPosition[unitID] = nil
	end
	for unitID, position in pairs(added) do
		ghostPosition[unitID] = position
	end
	generation = counter
end

local function unitGhostsCleared(counter, store)
	ghostPosition = store
	generation = counter
end

local function unitGhostsGeneration()
	return generation
end

function widget:Initialize()
	widgetHandler:RegisterGlobal("UnitGhostsChanged", unitGhostsChanged)
	widgetHandler:RegisterGlobal("UnitGhostsCleared", unitGhostsCleared)
	widgetHandler:RegisterGlobal("UnitGhostsGeneration", unitGhostsGeneration)

	WG.UnitGhosts = {
		GetGhostPosition = function(unitID)
			return ghostPosition[unitID]
		end,
		GetGhostsInCylinder = getUnitGhostsInCylinder,
		GetGhostsInSphere = getUnitGhostsInSphere,
		GetGhostsInRectangle = getUnitGhostsInRectangle,
	}
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("UnitGhostsChanged")
	widgetHandler:DeregisterGlobal("UnitGhostsCleared")
	widgetHandler:DeregisterGlobal("UnitGhostsGeneration")
	WG.UnitGhosts = nil
end

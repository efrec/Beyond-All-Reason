local gadget = gadget ---@type Gadget

local enabled = false
local success, mapinfo = pcall(VFS.Include, "mapinfo.lua")

if not success or mapinfo == nil then
	Spring.Echo("Map VoidWater failed to load the mapinfo.lua")
else
	enabled = mapinfo.voidwater
end

function gadget:GetInfo()
	return {
		name = "Map VoidWater",
		desc = "Destroys units in the void",
		author = "Floris, Beherith",
		date = "October 2021",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = enabled,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetFeaturePosition = Spring.GetFeaturePosition
local mapx = Game.mapSizeX
local mapz = Game.mapSizeZ

local isVoidGroundTarget = Game.UnitInfo.Cache.isGroundMoveCtrlUnit

function gadget:FeatureCreated(featureID)
	if select(2, spGetFeaturePosition(featureID)) <= 1 then
		Spring.DestroyFeature(featureID, false)
	end
end

-- periodically destroy units that end up in the void
function gadget:GameFrame(gf)
	if gf % 49 == 1 then
		local units = Spring.GetAllUnits()
		for k = 1, #units do
			local unitID = units[k]
			if isVoidGroundTarget[spGetUnitDefID(unitID)] then
				local x,y,z = spGetUnitPosition(unitID)
				if x ~= nil and (y < 0) and ( x > 0 and x < mapx ) and (z > 0 and z < mapz) then
					Spring.DestroyUnit(unitID)
				end
			end
		end
	end
end

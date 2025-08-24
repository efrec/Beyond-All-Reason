local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = 'Footprint clearance',
        desc      = 'Clears ground under newly build units any features that are under its footprint',
        author    = '',
        version   = '',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isBuilding = Game.UnitInfo.Cache.isStructureUnit
local footprint = Game.UnitInfo.Cache.footprint
local gibFeatureDefs = {}
for featureDefID, fDef in pairs(FeatureDefs) do
	if not fDef.geoThermal and fDef.name ~= 'geovent' and fDef.name ~= 'xelnotgawatchtower' and fDef.name ~= 'crystalring' then
		gibFeatureDefs[featureDefID] = true
	end
end

function gadget:UnitCreated(uID, uDefID, uTeam, bID)
	--Instagibb any features that are unlucky enough to be in the build radius of new construction projects
	if isBuilding[uDefID] then
		local xr, zr
		local sizes = footprint[uDefID]
		if Spring.GetUnitBuildFacing(uID) % 2 == 0 then
			xr, zr = sizes[1], sizes[2]
		else
			xr, zr = sizes[2], sizes[1]
		end
		xr = xr * 5 -- maybe should be: Game.squareSize * Game.footprintScale * 0.5
		zr = zr * 5 -- which is larger (8 vs 5)

		local ux, _, uz = Spring.GetUnitPosition(uID)
		local features = Spring.GetFeaturesInRectangle(ux-xr, uz-zr, ux+xr, uz+zr)
		for i = 1, #features do
			if gibFeatureDefs[Spring.GetFeatureDefID(features[i])] then
				local fx, fy, fz = Spring.GetFeaturePosition(features[i])
				Spring.DestroyFeature(features[i])
				Spring.SpawnCEG('sparklegreen', fx, fy, fz)
				Spring.PlaySoundFile('reclaimate', 1, fx, fy, fz, 'sfx')
			end
		end
	end
end

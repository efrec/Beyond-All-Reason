
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Tombstones",
		desc		= "Adds a tombstone next to commander wreck",
		author		= "Floris",
		date		= "December 2021",
		license     = "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local isCommander = Game.UnitInfo.Cache.isCommanderUnit
local tombstone = {}
for defID, def in ipairs(UnitDefs) do
	if isCommander[defID] then
		local stone = FeatureDefNames[def.name:sub(1, 3) .. "stone"]
		if stone then
			tombstone[defID] = stone and stone.id
		else
			Spring.Log("UnitDefs", LOG.WARNING, "Commander missing its tombstone: " .. def.name)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if tombstone[unitDefID] then
		local px,py,pz = Spring.GetUnitPosition(unitID)
		pz = pz - 40
		if not Spring.GetUnitRulesParam(unitID, "unit_evolved") then
			local tombstoneID = Spring.CreateFeature(tombstone[unitDefID], px, Spring.GetGroundHeight(px,pz), pz, 0, teamID)
			if tombstoneID then
				local rx,ry,rz = Spring.GetFeatureRotation(tombstoneID)
				rx = rx + 0.18 + (math.random(0, 6) / 50)
				rz = rz - 0.12 + (math.random(0, 12) / 50)
				ry = ry - 0.12 + (math.random(0, 12) / 50)
				Spring.SetFeatureRotation(tombstoneID, rx,ry,rz)
			end
		end
	end
end

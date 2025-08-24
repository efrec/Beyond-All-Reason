local modoptions = Spring.GetModOptions()
if modoptions.playableraptors ~= true and modoptions.forceallunits ~= true then
	return false
end

function gadget:GetInfo()
	return {
		name = "Playable Raptor Manager",
		desc = "Manages gameplay mechanics/behaviors unique to Playable Raptors",
		author = "robert the pie",
		date = "9th of March, 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local foundling = Game.UnitInfo.Cache.prap_foundling

if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if not builderID then
		return
	end

	local builderDefID = Spring.GetUnitDefID(builderID)
	if foundling[builderDefID] then
		Spring.SetUnitHealth(unitID, {health=2,build=1})
		Spring.DestroyUnit(builderID, false, true)
	end
end

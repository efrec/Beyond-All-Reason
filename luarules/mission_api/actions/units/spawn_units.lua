local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function spawnUnits(unitLoadout)
	GG['MissionAPI'].Modules.Loadout.SpawnUnitLoadout(unitLoadout)
end

return {
	---Creates units from a loadout, placing them on the map finished or under construction.
	---
	---Each loadout entry gives unitDefName, x, z, and team, and may give y, facing (0 to 3, or n, e, s, w, or the full compass word; south when omitted), unitName, construction (true to spawn as an unfinished build), quantity with spacing (the units are arranged in a grid around x and z, with spacing elmos between footprints), neutral, and orders in the same form as IssueOrders. Entries with a unitName create that name, and every unit of the entry gets it. UnitOrdered and RallyOrdered triggers ignore the entry orders unless they set ignoreMissionActions = false.
	---@class SpawnUnitsAction
	---@field unitLoadout UnitLoadout The units to create, one entry per unit def and position.
	---@declares unitLoadout
	{
		type = 'SpawnUnits',
		parameters = {
			{ name = 'unitLoadout', required = true, type = ParameterTypes.UnitLoadout },
		},
		actionFunction = spawnUnits,
	}
}

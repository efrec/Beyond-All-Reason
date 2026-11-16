local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function unmonitorUnits(unitName)
	GG['MissionAPI'].Modules.Monitors.RemoveMonitor(unitName)
end

return {
	{
		type = 'UnmonitorUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
		},
		actionFunction = unmonitorUnits,
	}
}

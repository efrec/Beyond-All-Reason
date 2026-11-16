local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function monitorUnits(unitName, filter, except)
	GG['MissionAPI'].Modules.Monitors.AddMonitor(unitName, filter, except)
end

return {
	{
		type = 'MonitorUnits',
		parameters = {
			{ name = 'unitName',  required = true,  type = ParameterTypes.UnitName },
			{ name = 'filter', required = true,  type = ParameterTypes.UnitFilter },
			{ name = 'except',    required = false, type = ParameterTypes.UnitFilters },
		},
		actionFunction = monitorUnits,
	}
}

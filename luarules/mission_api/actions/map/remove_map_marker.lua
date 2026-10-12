local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeMapMarker(markerName)
	local position = GG['MissionAPI'].markerNames[markerName]
	GG['MissionAPI'].markerNames[markerName] = nil
	if not position then return end

	Spring.MarkerErasePosition(position.x, position.y, position.z, nil, false, nil, true)
end

return {
	---Erases the marker recorded under markerName. Does nothing for a name that is not recorded.
	---@class RemoveMapMarkerAction
	---@field markerName String The marker to erase.
	{
		type = 'RemoveMapMarker',
		parameters = {
			{ name = 'markerName', required = true, type = ParameterTypes.String },
		},
		actionFunction = removeMapMarker,
	}
}

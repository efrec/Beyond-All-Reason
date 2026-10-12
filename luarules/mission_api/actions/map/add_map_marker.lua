local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Drawing is stubbed on the engine's map marks, which pin themselves to the terrain and cannot be
-- styled, so markerType is taken and kept until we draw the marker types ourselves.

local function addMapMarker(markerName, position, markerType, label)
	GG['MissionAPI'].markerNames[markerName] = position
	Spring.MarkerAddPoint(position.x, position.y, position.z, label, false)
end

return {
	---Places a map marker at a position, visible to every player, and records it under markerName so RemoveMapMarker can erase it.
	---
	---Reusing a name records the new marker and forgets the earlier one without erasing it.
	---@class AddMapMarkerAction
	---@field markerName String The name the marker is known by.
	---@field position Position Where the marker goes, with x and z in elmos; y defaults to the ground height.
	---@field markerType? String Reserved for marker styles; it currently changes nothing about the marker.
	---@field label? String Text shown beside the marker.
	---@declares markerName
	{
		type = 'AddMapMarker',
		parameters = {
			{ name = 'markerName', required = true,  type = ParameterTypes.String },
			{ name = 'position',   required = true,  type = ParameterTypes.Position },
			{ name = 'markerType', required = false, type = ParameterTypes.String },
			{ name = 'label',      required = false, type = ParameterTypes.String },
		},
		actionFunction = addMapMarker,
	}
}

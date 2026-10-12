local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types
local matchingUnits = GG['MissionAPI'].Modules.UnitQuery.MatchingUnits

local markerParameters = {
	{ name = 'unitName',    required = false, type = ParameterTypes.UnitName },
	{ name = 'unitDefName', required = false, type = ParameterTypes.UnitDefName },
	{ name = 'teamID',      required = false, type = ParameterTypes.TeamID },
	{ name = 'markerType',  required = false, type = ParameterTypes.String },
	requiresOneOf = { 'unitName', 'unitDefName' },
}

local function addUnitMarker(unitName, unitDefName, teamID, markerType)
	local unitMarkers = GG['MissionAPI'].Modules.UnitMarkers
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		unitMarkers.AddUnitMarker(unitID, markerType)
	end
end

local function removeUnitMarker(unitName, unitDefName, teamID, markerType)
	local unitMarkers = GG['MissionAPI'].Modules.UnitMarkers
	for _, unitID in ipairs(matchingUnits(unitName, unitDefName, teamID)) do
		unitMarkers.RemoveUnitMarker(unitID, markerType)
	end
end

return {
	---Draws a marker above every unit matching the filters, stacked above any markers the unit already has. A unit holds at most one marker of each markerType.
	---
	---Only units that exist when the action runs are marked, and a marker disappears with its unit. A teamID on its own matches no units.
	---@class AddUnitMarkerAction
	---@field unitName? UnitName Only units carrying this mission unit name.
	---@field unitDefName? UnitDefName Only units of this type.
	---@field teamID? TeamID Only units of this team.
	---@field markerType? String A label for the marker, so RemoveUnitMarker can remove it on its own.
	---@default teamID every team
	---@default markerType untyped
	---@requiresOneOf unitName unitDefName
	{
		type = 'AddUnitMarker',
		parameters = markerParameters,
		actionFunction = addUnitMarker,
	},
	---Removes markers from every unit matching the filters.
	---
	---A teamID on its own matches no units.
	---@class RemoveUnitMarkerAction
	---@field unitName? UnitName Only units carrying this mission unit name.
	---@field unitDefName? UnitDefName Only units of this type.
	---@field teamID? TeamID Only units of this team.
	---@field markerType? String Remove only the marker of this type.
	---@default teamID every team
	---@default markerType every marker of the unit
	---@requiresOneOf unitName unitDefName
	{
		type = 'RemoveUnitMarker',
		parameters = markerParameters,
		actionFunction = removeUnitMarker,
	}
}

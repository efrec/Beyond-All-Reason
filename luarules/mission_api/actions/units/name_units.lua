local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function nameUnits(unitName, teamID, unitDefName, area)
	local tracking = GG['MissionAPI'].Modules.Tracking
	local hasFilterOtherThanTeamID = unitDefName or area

	local allUnitsOfTeam = {}
	if not hasFilterOtherThanTeamID then
		allUnitsOfTeam = Spring.GetTeamUnits(teamID)
	end

	local unitsFromDef = {}
	if unitDefName and UnitDefNames[unitDefName] then
		local unitDefID = UnitDefNames[unitDefName].id
		if teamID then
			unitsFromDef = Spring.GetTeamUnitsByDefs(teamID, unitDefID)
		else
			for _, allyTeamID in pairs(Spring.GetAllyTeamList()) do
				for _, teamIDForAllyTeam in pairs(Spring.GetTeamList(allyTeamID)) do
					table.append(unitsFromDef, Spring.GetTeamUnitsByDefs(teamIDForAllyTeam, unitDefID))
				end
			end
		end
	end

	local unitsInArea = {}
	if area and area.x1 and area.z1 and area.x2 and area.z2 then
		unitsInArea = Spring.GetUnitsInRectangle(area.x1, area.z1, area.x2, area.z2, teamID)
	elseif area and area.x and area.z and area.radius then
		unitsInArea = Spring.GetUnitsInCylinder(area.x, area.z, area.radius, teamID)
	end

	local unitsToName = {}
	if hasFilterOtherThanTeamID then
		unitsToName = table.valueIntersection(
			unpack(table.filterArray({ unitsFromDef, unitsInArea }, function(tbl) return not table.isEmpty(tbl) end))
		)
	else
		unitsToName = allUnitsOfTeam
	end

	local trackUnit = tracking.TrackUnit
	for _, unitID in pairs(unitsToName) do
		trackUnit(unitName, unitID)
	end
end

return {
	---Gives a name to existing units chosen by team, unit def, or area, so that later actions and triggers can refer to them.
	---
	---The filters combine: a teamID alone names every unit the team owns, and a unitDefName or an area narrows the selection to units matching every filter given. Only units that exist when the action runs are named; units built later are not. A unit can hold several names, and naming it does not remove names it already has.
	---@class NameUnitsAction
	---@field unitName UnitName The name to give the selected units.
	---@field teamID? Number Only units owned by this team.
	---@field unitDefName? String Only units of this unit def.
	---@field area? Area Only units inside this area: a rectangle { x1, z1, x2, z2 } or a circle { x, z, radius }, in elmos.
	---@requiresOneOf teamID unitDefName area
	---@declares unitName
	{
		type = 'NameUnits',
		parameters = {
			{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
			{ name = 'teamID', required = false, type = ParameterTypes.Number },
			{ name = 'unitDefName', required = false, type = ParameterTypes.String },
			{ name = 'area', required = false, type = ParameterTypes.Area },
			requiresOneOf = { 'teamID', 'unitDefName', 'area' },
		},
		actionFunction = nameUnits,
	}
}

local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- For simple line-of-sight spotting of units, prefer the `UnitSpotted` trigger.
-- It has no options and fires every time it receives the appropriate LOS events.

-- This tries to eat as much complexity from the event system as possible to give
-- multi-sensor discovery events that follow some sensible single-counting rules.

-- A unit is discovered once per allyTeam that spots it by whichever sensor is first.
-- Repeating triggers correctly fire once per each distinct matching unit discovered.

-- Discovered units can be forgotten and rediscovered only when the unit has died or when
-- it changes to a different allyTeam (even if ceasefired to the previous allyTeam).

-- `sensorTypes` optionally restricts which sensors to count, or all are included.

-- Synced gadgets receive the seismic pings for all units, even when fully visible.
-- In unsynced, seismic discovery would imply not-INLOS (though, not not-INRADAR).

local function matchesUnit(trigger, context, unitID, unitTeam, unitDefID, spottingAllyTeamID)
	local parameters = trigger.parameters

	-- We need this to forget units that are crashing, exploding, or running a death script.
	if Spring.GetUnitIsDead(unitID) then
		return false
	end
	-- Never discover units on the same allyTeam. This can happen after team transfer.
	if Spring.GetUnitAllyTeam(unitID) == spottingAllyTeamID then
		return false
	end

	if parameters.unitName and not context.DoesUnitHaveName(unitID, parameters.unitName) then
		return false
	end
	if parameters.unitDefName and parameters.unitDefName ~= UnitDefs[unitDefID].name then
		return false
	end
	if parameters.owningTeamID and parameters.owningTeamID ~= unitTeam then
		return false
	end
	if parameters.spottingAllyTeamID and parameters.spottingAllyTeamID ~= spottingAllyTeamID then
		return false
	end
	return true
end

local function sensorEnabled(trigger, sensorType)
	return not trigger.parameters.sensorTypes or trigger.parameters.sensorTypes[sensorType]
end

-- Record the unit as discovered by the allyTeam and return whether it is a new contact.
local function discoverUnit(context, triggerID, spottingAllyTeamID, unitID)
	local discoveredByAllyTeam = context.DiscoveredUnits[triggerID]
	if not discoveredByAllyTeam then
		discoveredByAllyTeam = {}
		context.DiscoveredUnits[triggerID] = discoveredByAllyTeam
	end

	local discoveredUnits = discoveredByAllyTeam[spottingAllyTeamID]
	if not discoveredUnits then
		discoveredUnits = {}
		discoveredByAllyTeam[spottingAllyTeamID] = discoveredUnits
	end

	if discoveredUnits[unitID] then
		return false
	end

	discoveredUnits[unitID] = true
	return true
end

-- Forget the unitID so it can be discovered again by all allyTeams.
local function forgetUnit(context, triggerID, unitID)
	local discoveredByAllyTeam = context.DiscoveredUnits[triggerID]
	if not discoveredByAllyTeam then
		return
	end
	for _, discoveredUnits in pairs(discoveredByAllyTeam) do
		discoveredUnits[unitID] = nil
	end
end

return {
	type = "UnitDiscovered",
	parameters = {
		{ name = "unitName",           required = false, type = ParameterTypes.UnitName },
		{ name = "unitDefName",        required = false, type = ParameterTypes.UnitDefName },
		{ name = "owningTeamID",       required = false, type = ParameterTypes.TeamID },
		{ name = "spottingAllyTeamID", required = false, type = ParameterTypes.AllyTeamID },
		{ name = "sensorTypes",        required = false, type = ParameterTypes.SensorTypes },
		requiresOneOf = { "unitName", "unitDefName" },
	},
	callins = {
		UnitEnteredLos = function(trigger, triggerID, context, unitID, unitTeam, spottingAllyTeamID, unitDefID)
			if not sensorEnabled(trigger, "sight") then
				return
			end
			if not matchesUnit(trigger, context, unitID, unitTeam, unitDefID, spottingAllyTeamID) then
				return
			end
			if discoverUnit(context, triggerID, spottingAllyTeamID, unitID) then
				context.ActivateTrigger(trigger)
			end
		end,

		UnitEnteredRadar = function(trigger, triggerID, context, unitID, unitTeam, spottingAllyTeamID, unitDefID)
			if not sensorEnabled(trigger, "radar") then
				return
			end
			if not matchesUnit(trigger, context, unitID, unitTeam, unitDefID, spottingAllyTeamID) then
				return
			end
			if discoverUnit(context, triggerID, spottingAllyTeamID, unitID) then
				context.ActivateTrigger(trigger)
			end
		end,

		UnitSeismicPing = function(trigger, triggerID, context, x, y, z, strength, spottingAllyTeamID, unitID, unitDefID)
			if not sensorEnabled(trigger, "seismic") then
				return
			end
			if not matchesUnit(trigger, context, unitID, Spring.GetUnitTeam(unitID), unitDefID, spottingAllyTeamID) then
				return
			end
			if discoverUnit(context, triggerID, spottingAllyTeamID, unitID) then
				context.ActivateTrigger(trigger)
			end
		end,

		UnitDestroyed = function(trigger, triggerID, context, unitID)
			forgetUnit(context, triggerID, unitID)
		end,

		UnitTaken = function(trigger, triggerID, context, unitID, unitDefID, oldTeam, newTeam)
			if Spring.GetTeamAllyTeamID(oldTeam) ~= Spring.GetTeamAllyTeamID(newTeam) then
				forgetUnit(context, triggerID, unitID)
			end
		end,
	},
}

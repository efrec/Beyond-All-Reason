local ParameterTypes = GG["MissionAPI"].Modules.ParameterTypes.Types

-- For simple line-of-sight detection of units, prefer the `UnitSpotted` trigger.
-- It has no options and fires every time it receives the appropriate LOS events.

-- This tries to eat as much complexity from the event system as possible to give
-- multi-sensor detection events that follow some sensible single-counting rules.

-- A unit is detected once per allyTeam that spots it by whichever sensor is first.
-- Repeating triggers correctly fire once per each distinct matching unit detected.

-- Detected units can be forgotten and redetected only when the unit has died or when
-- it changes to a different allyTeam (even if ceasefired to the previous allyTeam).

-- `sensorTypes` optionally restricts which sensors to count, or all are included.

-- Synced gadgets receive the seismic pings for all units, even when fully visible.
-- In unsynced, seismic detection would imply not-INLOS (though, not not-INRADAR).

local function matchesUnit(trigger, context, unitID, unitTeam, unitDefID, spottingAllyTeamID)
	local parameters = trigger.parameters

	-- We need this to forget units that are crashing, exploding, or running a death script.
	if Spring.GetUnitIsDead(unitID) then
		return false
	end
	-- Never detect units on the same allyTeam. This can happen after team transfer.
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

-- Record the unit as detected by the allyTeam and return whether it is a new contact.
local function detectUnit(context, triggerID, spottingAllyTeamID, unitID)
	local detectedByAllyTeam = context.DetectedUnits[triggerID]
	if not detectedByAllyTeam then
		detectedByAllyTeam = {}
		context.DetectedUnits[triggerID] = detectedByAllyTeam
	end

	local detectedUnits = detectedByAllyTeam[spottingAllyTeamID]
	if not detectedUnits then
		detectedUnits = {}
		detectedByAllyTeam[spottingAllyTeamID] = detectedUnits
	end

	if detectedUnits[unitID] then
		return false
	end

	detectedUnits[unitID] = true
	return true
end

-- Forget the unitID so it can be detected again by all allyTeams.
local function forgetUnit(context, triggerID, unitID)
	local detectedByAllyTeam = context.DetectedUnits[triggerID]
	if not detectedByAllyTeam then
		return
	end
	for _, detectedUnits in pairs(detectedByAllyTeam) do
		detectedUnits[unitID] = nil
	end
end

return {
	type = "UnitDetected",
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
			if detectUnit(context, triggerID, spottingAllyTeamID, unitID) then
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
			if detectUnit(context, triggerID, spottingAllyTeamID, unitID) then
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
			if detectUnit(context, triggerID, spottingAllyTeamID, unitID) then
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

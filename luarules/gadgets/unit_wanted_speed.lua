local gadget = gadget ---@type Gadget

local enabled = Spring.GetModOptions().emprework

function gadget:GetInfo()
	return {
		name      = "Wanted Speed",
		desc      = "Adds a command which sets maxWantedSpeed.",
		author    = "GoogleFrog",
		date      = "11 November 2018",
		license   = "GNU GPL, v2 or later",
		layer     = -1000000, -- Before every state toggle gadget.
		enabled   = enabled,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local CMD_WANTED_SPEED = GameCMD.WANTED_SPEED

local moveTypeByDefID = Game.UnitInfo.Cache.moveType
local units = {}

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function SetUnitWantedSpeed(unitID, unitDefID, wantedSpeed, forceUpdate)
	if not unitDefID then
		return
	end
	if not units[unitID] then
		if not (forceUpdate or wantedSpeed) then
			return
		end
		local moveType = moveTypeByDefID[unitDefID]
		units[unitID] = {
			unhandled = (moveType ~= 1) and (moveType ~= 2), -- Planes are unhandled.
			moveType = moveType,
		}
	end

	if units[unitID].unhandled then
		return
	end

	if Spring.MoveCtrl.GetTag(unitID) then
		units[unitID].lastWantedSpeed = wantedSpeed
		return
	end

	if (not forceUpdate) and (units[unitID].lastWantedSpeed == wantedSpeed) then
		return
	end
	units[unitID].lastWantedSpeed = wantedSpeed

	--Spring.Utilities.UnitEcho(unitID, wantedSpeed or "f")
	if units[unitID].moveType == 1 then
		Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "maxWantedSpeed", (wantedSpeed or 2000))
	elseif units[unitID].moveType == 2 then
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxWantedSpeed", (wantedSpeed or 2000))
	end
end

function GG.ForceUpdateWantedMaxSpeed(unitID, unitDefID, clearWanted)
	SetUnitWantedSpeed(unitID, unitDefID, (not clearWanted) and units and units[unitID] and units[unitID].lastWantedSpeed, true)
end

local function MaintainWantedSpeed(unitID)
	if not (units[unitID] and units[unitID].lastWantedSpeed) then
		return
	end

	if Spring.MoveCtrl.GetTag(unitID) then
		return
	end

	if units[unitID].moveType == 1 then
		Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "maxWantedSpeed", units[unitID].lastWantedSpeed)
	elseif units[unitID].moveType == 2 then
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxWantedSpeed", units[unitID].lastWantedSpeed)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ANY)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Command Handling

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD_WANTED_SPEED then
		MaintainWantedSpeed(unitID)
		return true
	end

	local wantedSpeed = cmdParams[1]
	if not (wantedSpeed and teamID) then
		return false
	end
	wantedSpeed = (wantedSpeed > 0) and wantedSpeed
	SetUnitWantedSpeed(unitID, unitDefID, wantedSpeed)

	-- Overkill?
	--for i = 2, #cmdParams do
	--	if teamID == Spring.GetUnitTeam(cmdParams[i]) then
	--		SetUnitWantedSpeed(cmdParams[i], Spring.GetUnitDefID(cmdParams[i]), wantedSpeed)
	--	end
	--end

	return false
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Cleanup

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	units[unitID] = nil
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

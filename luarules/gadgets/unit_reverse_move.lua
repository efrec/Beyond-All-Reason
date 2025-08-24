local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "ReverseMovementHandler",
		desc = "Sets reverse speeds/angles/distances",
		author = "[Fx]Doo",
		date = "27 of July 2017",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local unitSpeed = Game.UnitInfo.Cache.speed
local unitRspeed = Game.UnitInfo.Cache.rSpeed

if not next(unitRspeed) then
	return
end

local spGetUnitCommands = Spring.GetUnitCommands
local reverseUnit = {}
local refreshList = {}

function gadget:UnitCreated(unitID, unitDefID)
	if unitRspeed[unitDefID] then
		reverseUnit[unitID] = unitDefID
		refreshList[unitID] = unitDefID
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", unitSpeed[unitDefID])
		Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", 0)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	reverseUnit[unitID] = nil
	refreshList[unitID] = nil
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if reverseUnit[unitID] then
		refreshList[unitID] = unitDefID
	end
end

function gadget:UnitIdle(unitID, unitDefID)
	if reverseUnit[unitID] then
		refreshList[unitID] = unitDefID
	end
end

-- /luarules profile shows this eats a bit regardless of reverse units being present
function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if reverseUnit[unitID] then
		refreshList[unitID] = unitDefID
	end
end

function gadget:GameFrame(f)
	for unitID, unitDefID in pairs(refreshList) do
		local cmd = spGetUnitCommands(unitID, 1)
		if cmd and cmd[1] and cmd[1]["options"] and cmd[1]["options"].ctrl then
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", unitRspeed[unitDefID])
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", unitRspeed[unitDefID])
		else
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxSpeed", unitSpeed[unitDefID])
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseSpeed", 0)
		end
		refreshList[unitID] = nil
	end
end

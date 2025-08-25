--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file:		CMD.unit_mover.lua
--	brief:	 Allows combat engineers to use repeat when building mobile units (use 2 or more build spots)
--	author:	Owen Martindell
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name		= "Unit Mover",
		desc		= "Allows combat engineers to use repeat when building mobile units (use 2 or more build spots)",
		author		= "TheFatController",
		date		= "Mar 20, 2007",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= false
	}
end

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitDirection = Spring.GetUnitDirection
local GetMyTeamID = Spring.GetMyTeamID
local GetUnitDefID = Spring.GetUnitDefID

local CMD_MOVE = CMD.MOVE

--------------------------------------------------------------------------------

local myTeamID = GetMyTeamID()
local engineers = {}
local engineerDefs = Game.UnitInfo.Cache.isConstructionUnit
local unitRadius = Game.UnitInfo.Cache.radius
local gameStarted

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
	local units = Spring.GetTeamUnits(myTeamID);
	for i=1,#units do
		local unitID = units[i]
		widget:UnitCreated(unitID,GetUnitDefID(unitID),myTeamID)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam,builderID)
	if unitTeam ~= myTeamID then
		return
	end
	if engineerDefs[unitDefID] then
		engineers[unitID] = {}
	end
	if builderID and engineers[builderID] then
		local x, y, z = GetUnitPosition(unitID)
		local dx,dy,dz = GetUnitDirection(unitID)
		local moveDist = 40 + unitRadius[unitID]
		GiveOrderToUnit(unitID, CMD_MOVE, {x+dx*moveDist, y, z+dz*moveDist}, 0)
	end
end

function widget:UnitDestroyed(unitID)
	engineers[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID, newTeam, oldTeamID)
	widget:UnitDestroyed(unitID)
	widget:UnitCreated(unitID, unitDefID, newTeam)
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeam)
	widget:UnitDestroyed(unitID)
	widget:UnitCreated(unitID, unitDefID, newTeam)
end




--------------------------------------------------------------------------------

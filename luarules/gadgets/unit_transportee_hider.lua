local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Transportee Hider",
		desc = "Hides units when inside a closed transport, issues stop command to units trying to enter a full transport",
		author = "FLOZi",
		date = "09/02/10",
		license = "PD",
		layer = 0,
		enabled = false
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local SetUnitNoDraw = Spring.SetUnitNoDraw
local SetUnitStealth = Spring.SetUnitStealth
local SetUnitSonarStealth = Spring.SetUnitSonarStealth
local GetUnitDefID = Spring.GetUnitDefID
local GiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_LOAD_ONTO = CMD.LOAD_ONTO
local CMD_STOP = CMD.STOP

local massLeft = {}
local toBeLoaded = {}

local isTransport = Game.UnitInfo.Cache.isTransport
local isAirUnit = Game.UnitInfo.Cache.isAirUnit
local isAirbase = Game.UnitInfo.Cache.isairbase
local unitMass = Game.UnitInfo.Cache.mass
local unitTransportMass = Game.UnitInfo.Cache.transportMass

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.LOAD_ONTO
	local transportID = cmdParams[1]
	toBeLoaded[unitID] = transportID
	return true
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	if isTransport[unitDefID] then
		massLeft[unitID] = unitTransportMass[unitDefID]
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	massLeft[unitID] = nil
	toBeLoaded[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_ONTO)
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

local function TransportIsFull(transportID)
	for unitID, targetTransporterID in pairs(toBeLoaded) do
		if targetTransporterID == transportID then
			GiveOrderToUnit(unitID, CMD_STOP, {}, 0)
			toBeLoaded[unitID] = nil
		end
	end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	--Spring.Echo("UnitLoaded", unitID, unitDefID, transportID)
	if not unitDefID or not transportID or not massLeft[transportID] then
		return
	end
	massLeft[transportID] = massLeft[transportID] - unitMass[unitDefID]
	-- todo: Why on earth does "transportee hider" handle transported unit mass?
	if massLeft[transportID] <= 0 then
		TransportIsFull(transportID)
	end
	local transportDefID = GetUnitDefID(transportID)
	if not isAirUnit[transportDefID] and not isAirbase[transportDefID] then
		SetUnitNoDraw(unitID, true)
		SetUnitStealth(unitID, true)
		SetUnitSonarStealth(unitID, true)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	--Spring.Echo("UnitUnloaded", unitID, unitDefID, transportID)
	if not unitDefID or not transportID or not massLeft[transportID] then
		return
	end
	massLeft[transportID] = massLeft[transportID] + unitMass[unitDefID]
	local transportDefID = GetUnitDefID(transportID)
	if not isAirUnit[transportDefID] and not isAirbase[transportDefID] then
		SetUnitNoDraw(unitID, false)
		SetUnitStealth(unitID, false)
		SetUnitSonarStealth(unitID, false)
	end
end

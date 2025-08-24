local gadget = gadget ---@type Gadget

local doesThisDoAnythingAtAll = false -- why

function gadget:GetInfo()
	return {
		name = "Air Transports Speed",
		desc = "Slows down transport depending on loaded mass",
		author = "raaar, Hornet",--added com mod 13/06/24
		date = "2015",
		license = "PD",
		layer = 0,
		enabled = doesThisDoAnythingAtAll,
	}
end

if not gadgetHandler:IsSyncedCode() then return end

local TRANSPORTED_MASS_SPEED_PENALTY = 0.2 -- higher makes unit slower
local FRAMES_PER_SECOND = Game.gameSpeed

local airTransports = {}
local airTransportMaxSpeeds = {}

local isAirUnit = Game.UnitInfo.Cache.isAirUnit
local unitMass = Game.UnitInfo.Cache.mass
local unitTransportMass = Game.UnitInfo.Cache.transportMass
local unitSpeed = Game.UnitInfo.Cache.speed
local isCommander = Game.UnitInfo.Cache.isCommanderUnit
local transportSpeedMult = Game.UnitInfo.Cache.transportspeedmult

local massUsageFraction = 0
local allowedSpeed = 0

local spGetUnitVelocity = Spring.GetUnitVelocity
local spSetUnitVelocity = Spring.SetUnitVelocity
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting

-- update allowed speed for transport
local function updateAllowedSpeed(transportId)
	local uDefID = spGetUnitDefID(transportId)
	local units = spGetUnitIsTransporting(transportId)
	local tunitdefid
	local hasCommander = false
	local massTotal = 0
	local speedmult = 0.0
	if doesThisDoAnythingAtAll then
		if units then
			for _,tUnitId in pairs(units) do
				tunitdefid = spGetUnitDefID(tUnitId)
				hasCommander = hasCommander or isCommander[tunitdefid]
				speedmult = transportSpeedMult[tunitdefid] or speedmult
				massTotal = massTotal + unitMass[tunitdefid]
			end
			massUsageFraction = (massTotal / unitTransportMass[uDefID])

			if hasCommander then
				allowedSpeed = unitSpeed[uDefID] * (1 - massUsageFraction * (TRANSPORTED_MASS_SPEED_PENALTY+speedmult)) / FRAMES_PER_SECOND
			else
				allowedSpeed = unitSpeed[uDefID] * (1 - massUsageFraction * TRANSPORTED_MASS_SPEED_PENALTY) / FRAMES_PER_SECOND
			end
			airTransportMaxSpeeds[transportId] = allowedSpeed
		end
	end
end

-- add transports to table when they load a unit
function gadget:UnitLoaded(unitId, unitDefId, unitTeam, transportId, transportTeam)
	if isAirUnit[spGetUnitDefID(transportId)] and not airTransports[transportId] then
		airTransports[transportId] = true
		updateAllowedSpeed(transportId)
	end
end

-- cleanup transports and unloaded unit tables when destroyed
function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
	airTransports[unitId] = nil
	airTransportMaxSpeeds[unitId] = nil
end

-- every frame, adjust speed of air transports according to transported mass, if any
function gadget:GameFrame(n)
	-- for each air transport with units loaded, reduce speed if currently greater than allowed
	local factor = 1
	local vx,vy,vz,vw = 0
	local alSpeed = 0
	for unitId,_ in pairs(airTransports) do
		vx,vy,vz,vw = spGetUnitVelocity(unitId)
		alSpeed = airTransportMaxSpeeds[unitId]
		if alSpeed and vw and vw > alSpeed then
			factor = alSpeed / vw
			spSetUnitVelocity(unitId,vx * factor,vy * factor,vz * factor)
		end
	end
end


function gadget:UnitUnloaded(unitId, unitDefId, teamId, transportId)
	if isAirUnit[spGetUnitDefID(transportId)] then
		local units = airTransports[transportId] and spGetUnitIsTransporting(transportId) or {}
		if airTransports[transportId] and not units[1] then
			-- transport is empty, cleanup tables
			airTransports[transportId] = nil
			airTransportMaxSpeeds[transportId] = nil
		else
			updateAllowedSpeed(transportId)
		end
	end
end

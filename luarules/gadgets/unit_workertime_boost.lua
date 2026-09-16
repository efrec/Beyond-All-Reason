local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Workertime Multiplier Boost",
		desc = "Allows units with added UnitDefs to build and repair gadget-defined types of units faster.",
		author = "SethDGamre",
		date = "April 2024",
		license = "Public domain",
		layer = 0,
		enabled = true,
	}
end

-- synced only
if not gadgetHandler:IsSyncedCode() then
	return false
end

-- workertimeboost = number -- in the unitdefs of the builder. This is the multiplier by which workertime is boosted.
-- wtboostunittype = "MOBILE TURRET" defined in unitdef of builder which defines what units trigger workertime boost for that builder.

local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitDefID = Spring.GetUnitDefID

local ATTRIBUTE_SOURCE = "workertime_boost"

local boostableUnits = {}
local builderWatchDefs = {}
local builderWatch = {}

for id, def in pairs(UnitDefs) do
	if def.isBuilder and def.customParams.workertimeboost and def.customParams.wtboostunittype then
		builderWatchDefs[id] = {
			factor = tonumber(def.customParams.workertimeboost),
			trigger = def.customParams.wtboostunittype,
		}
	end
	boostableUnits[id] = {}
	if def.speed and def.speed ~= 0 then
		table.insert(boostableUnits[id], "MOBILE")
	end
	if def.speed == 0 and def.weapons[1] then
		table.insert(boostableUnits[id], "TURRET")
	end
	if def.speed == 0 and not def.weapons[1] and def.buildSpeed < 1 then
		table.insert(boostableUnits[id], "PASSIVE")
	end
	if def.buildSpeed and def.buildSpeed > 0 then
		table.insert(boostableUnits[id], "BUILDER")
	end
end

if table.count(builderWatchDefs) <= 0 then -- this enables or disables the gadget
	return false
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderWatchDefs[unitDefID] then
		builderWatch[unitID] = builderWatchDefs[unitDefID]
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	builderWatch[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % 16 == 0 then
		local setUnitModifier = GG.UnitAttributes.SetUnitModifier
		for id, data in pairs(builderWatch) do
			local project = spGetUnitIsBuilding(id) or nil
			local enableBoost = false
			if project then
				local projectStrings = boostableUnits[spGetUnitDefID(project)] or { " " }
				for _, string in pairs(projectStrings) do
					if string.find(data.trigger, string) then
						enableBoost = true
						break
					end
				end
			end
			setUnitModifier(id, "buildSpeed", enableBoost and data.factor or nil, ATTRIBUTE_SOURCE)
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end

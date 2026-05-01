local gadget = gadget ---@type Gadget

if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:GetInfo()
	return {
		name    = "COB Unit Stats",
		desc    = "makes custom unitdef statistics known to unit scripts",
		author  = "efrec",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

local spCallCOBScript = Spring.CallCOBScript
local spGetCOBScriptID = Spring.GetCOBScriptID

local hasSetSweepfire = {}
local hasBeenCreated = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.unitscript_sweepfire then
		hasSetSweepfire[unitDefID] = {
			1000 * tonumber(unitDef.customParams.burst),
			1000 * tonumber(unitDef.customParams.reload),
		}
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if not hasSetSweepfire[unitDefID] then
		return
	elseif not hasBeenCreated[unitDefID] then
		hasBeenCreated[unitDefID] = true
		if not spGetCOBScriptID(unitID, "SetSweepfire") then
			hasSetSweepfire[unitDefID] = nil
			return
		end
	end

	spCallCOBScript(unitID, "SetSweepfire", 0, unpack(hasSetSweepfire[unitDefID]))
end

function gadget:Initialize()
	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

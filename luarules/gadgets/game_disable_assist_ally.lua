local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true, -- Spring.GetModOptions().disable_assist_ally_construction,
	}
end

-- ! Does not support local AI correctly.
-- ! Does not work with nocost correctly.
-- ! Does not wash and fold your laundry.
-- ! Does not love you as once it did do.
-- ! Does not know how to kindle a spark.

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam

local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_INSERT = CMD.INSERT

local gaiaTeam = Spring.GetGaiaTeamID()

local canBuildOrAssist = {}

for unitDefID, unitDef in ipairs(UnitDefs) do
	canBuildOrAssist[unitDefID] = unitDef.isBuilder or unitDef.canAssist
end

local isBeingBuilt = {}
local isBuilderUnit = {}

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_GUARD)
	gadgetHandler:RegisterAllowCommand(CMD_REPAIR)
	gadgetHandler:RegisterAllowCommand(CMD_INSERT)

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			gadget:UnitFinished(unitID, unitDefID)
		end
	end
end

local tempParams = { 0, 0, 0 }
local EMPTY = {}
local function resolve(cmdID, cmdParams)
	if cmdID == CMD_INSERT then
		local p = tempParams
		p[1], p[2], p[3] = cmdParams[4], cmdParams[5], cmdParams[6]
		cmdID, cmdParams = cmdParams[1], p
		-- We only wanted a certain set of commands to begin with:
		if cmdID ~= CMD_GUARD and cmdID ~= CMD_REPAIR then
			return nil, EMPTY
		end
	end
	return cmdID, cmdParams
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	cmdID, cmdParams = resolve(cmdID, cmdParams)

	if cmdParams[2] or not cmdParams[1] then
		return true
	end

	local targetID = cmdParams[1]
	local targetTeam = spGetUnitTeam(targetID)
	-- local tx, ty, tz = Spring.GetUnitPosition(targetID)

	if unitTeam == targetTeam then
		-- Spring.MarkerAddPoint(tx, ty, tz, ("%s / SAME"):format(CMD[cmdID]))
		return true
	elseif isBeingBuilt[unitID] then
		-- Spring.MarkerAddPoint(tx, ty, tz, ("%s / NEWUNIT"):format(CMD[cmdID]))
		return false
	end

	if cmdID == CMD_GUARD and isBuilderUnit[targetID] then
		-- Spring.MarkerAddPoint(tx, ty, tz, ("%s / BUILDER"):format(CMD[cmdID]))
		return false
	else
		-- Spring.MarkerAddPoint(tx, ty, tz, ("%s / OK"):format(CMD[cmdID]))
		return true
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	isBeingBuilt[unitID] = true -- ! sometimes wrong with nocost, deal with it
	isBuilderUnit[unitID] = canBuildOrAssist[unitDefID]
end

function gadget:UnitFinished(unitID)
	isBeingBuilt[unitID] = nil
end

function gadget:UnitDestroyed(unitID)
	isBeingBuilt[unitID] = nil
	isBuilderUnit[unitID] = nil
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	if newTeam ~= gaiaTeam and isBuilderUnit[unitID] then
		local tags, count = {}, 0
		local command, _, tag, p1, p2
		local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
		for index = 1, Spring.GetUnitCommandCount(unitID) do
			command, _, tag, p1, p2 = GetUnitCurrentCommand(unitID, index)
			if (command == CMD_GUARD or command == CMD_REPAIR) and (p1 and not p2) and spGetUnitTeam(p1) ~= newTeam then
				if isBeingBuilt[p1] or (command == CMD_GUARD and isBuilderUnit[p1]) then
					count = count + 1
					tags[count] = tag
				end
			end
		end
		if count > 0 then
			Spring.GiveOrderToUnit(unitID, CMD.REMOVE, tags)
		end
	end
end

local function __AllowUnitBuildStep(self, builderID, builderTeam, unitID, unitDefID, part)
	if part > 0 and builderTeam ~= spGetUnitTeam(unitID) then
		Spring.Log("Cheating", LOG.NOTICE, "Cheating team in game_disable_assist_ally: " .. tostring(builderTeam))
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		if ux then
			-- Spring.DestroyUnit(unitID, true, true) -- maybe not
			local success, sphereID = pcall(Spring.CreateUnit, "dbg_sphere", ux, uy, uz, "s", gaiaTeam) -- eat errors
			if success and sphereID then
				Spring.SetUnitAlwaysVisible(sphereID, true)
				Spring.SetUnitArmored(sphereID, true, 0)
				Spring.SetUnitBlocking(sphereID, false, false, false, false, false, false, false)
				Spring.SetUnitNoSelect(sphereID, true)
			end
		end
	end
end

local SEED = math.random(11, 29)

function gadget:GameFrame(frame)
	if frame % SEED == 0 then
		gadget.AllowUnitBuildStep = __AllowUnitBuildStep
		gadgetHandler:UpdateCallIn("AllowUnitBuildStep")
	elseif gadget.AllowUnitBuildStep then
		gadget.AllowUnitBuildStep = nil
		gadgetHandler:UpdateCallIn("AllowUnitBuildStep")
		SEED = math.random(29, 41)
	end
end

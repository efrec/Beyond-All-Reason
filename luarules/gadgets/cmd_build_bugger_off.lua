local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Builder buggeroff",
		desc	= "Enables busy builders and moving units to buggeroff",
		author  = "Flameink",
		date	= "March 14, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true   --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local CMD_BUGGER_OFF = Game.CustomCommands.GameCMD.BUGGER_OFF

---@type CommandDescription
local CMD_BUGGER_OFF_DESC = {
	id       = CMD_BUGGER_OFF,
	name     = "Avoid Build Site",
	type     = CMDTYPE.ICON_AREA, -- 1..3: map position, 4: sourceID
	hidden   = true,
	queueing = true,
}

local shouldNotBuggeroff = {}
local cachedUnitDefs = {}
local cachedBuilderTeams = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isImmobile then
		shouldNotBuggeroff[unitDefID] = true
	end

	cachedUnitDefs[unitDefID] = { radius = unitDef.radius, isBuilder = unitDef.isBuilder}
end

local function willBeNearTarget(unitID, tx, ty, tz, seconds, maxDistance)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	if not ux then return false end

	local vx, vy, vz = Spring.GetUnitVelocity(unitID)
	if not vx then return false end

	local futureX = ux + vx * seconds * Game.gameSpeed
	local futureY = uy + vy * seconds * Game.gameSpeed
	local futureZ = uz + vz * seconds * Game.gameSpeed

	local dx = futureX - tx
	local dy = futureY - ty
	local dz = futureZ - tz
	return math.diag(dx, dy, dz) <= maxDistance
end

local function isInTargetArea(interferingUnitID, x, y, z, radius)
	local ux, uy, uz = Spring.GetUnitPosition(interferingUnitID)
	if not ux then return false end
	return math.diag(ux - x, uz - z) <= radius
end

local function IsUnitRepeatOn(unitID)
	local cmdDescs = Spring.GetUnitCmdDescs(unitID)
	if not cmdDescs then return false end
	for _, desc in ipairs(cmdDescs) do
		if desc.id == CMD.REPEAT then
			return desc.params and desc.params[1] == "1"
		end
	end
	return false
end

local slowUpdateBuilders 	= {}
local watchedBuilders 		= {}
local builderRadiusOffsets 	= {}
local commandDependencies   = {}
local needsUpdate 			= false

local FAST_UPDATE_RADIUS	= 400
-- builders take about this much to enter build stance; determined empirically
local BUILDER_DELAY_SECONDS = 3.3
local BUILDER_BUILD_RADIUS  = 200
local SEARCH_RADIUS_OFFSET  = 200
local FAST_UPDATE_FREQUENCY = 30
local SLOW_UPDATE_FREQUENCY = 60
local MAX_BUGGEROFF_RADIUS  = 400
local BUGGEROFF_RADIUS_INCREMENT = 4 * Game.squareSize

local goalRadius = Game.squareSize -- strict for now
local goalIdleRadius = {}

local function watchBuilder(builderID)
	slowUpdateBuilders[builderID]   = nil
	watchedBuilders[builderID]		= true
	builderRadiusOffsets[builderID] = 0
end

local function removeBuilder(builderID)
	slowUpdateBuilders[builderID]   = nil
	watchedBuilders[builderID]	  	= nil
	builderRadiusOffsets[builderID] = nil
end

local function slowWatchBuilder(builderID)
	watchedBuilders[builderID]	  	= nil
	slowUpdateBuilders[builderID]   = true
	builderRadiusOffsets[builderID] = nil
	-- Give builder initial slow update right away in case the builder is already close
	needsUpdate = true
end

local function shouldIssueBuggeroff(builderTeam, interferingUnitID, x, y, z, radius)
	if Spring.AreTeamsAllied(Spring.GetUnitTeam(interferingUnitID), builderTeam) == false then
		return false
	end

	if shouldNotBuggeroff[Spring.GetUnitDefID(interferingUnitID)] then
		return false
	end

	if willBeNearTarget(interferingUnitID, x, y, z, BUILDER_DELAY_SECONDS, radius) then
		return true
	end

	if isInTargetArea(interferingUnitID, x, y, z, radius) then
		return true
	end

	return false
end

function gadget:GameFrame(frame)
	if frame % FAST_UPDATE_FREQUENCY ~= 0 then
		return
	end

	local visitedTeams = {}
	local visitedUnits = {}

	for builderID in pairs(watchedBuilders) do
		local cmdID, options, tag, targetX, targetY, targetZ =  Spring.GetUnitCurrentCommand(builderID)
		local isBuilding  	= false
		local x, y, z		= Spring.GetUnitPosition(builderID)
		local targetID		= Spring.GetUnitIsBuilding(builderID)
		local builderTeam   = Spring.GetUnitTeam(builderID);
		if targetID then isBuilding = true end

		if cmdID == nil or cmdID > -1 or math.distance2d(targetX, targetZ, x, z) > FAST_UPDATE_RADIUS  then
			slowWatchBuilder(builderID)

		elseif math.distance2d(targetX, targetZ, x, z) < BUILDER_BUILD_RADIUS + cachedUnitDefs[-cmdID].radius and isBuilding == false and Spring.GetUnitIsBeingBuilt(builderID) == false then
			local builtUnitDefID	= -cmdID
			local buggerOffRadius	= cachedUnitDefs[builtUnitDefID].radius + builderRadiusOffsets[builderID]
			local searchRadius		= cachedUnitDefs[builtUnitDefID].radius + SEARCH_RADIUS_OFFSET
			local interferingUnits	= Spring.GetUnitsInCylinder(targetX, targetZ, searchRadius)

			-- Make sure at least one builder per player is never told to move
			if (visitedTeams[builderTeam] == nil) then
				visitedUnits[builderID] = true
			end
			visitedTeams[builderTeam] = true
			-- Escalate the radius every update. We want to send units away the minimum distance, but
			-- if there are many units in the way, they may cause a traffic jam and need to clear more room.
			builderRadiusOffsets[builderID] = builderRadiusOffsets[builderID] + BUGGEROFF_RADIUS_INCREMENT

			for _, interferingUnitID in ipairs(interferingUnits) do
				if builderID ~= interferingUnitID and visitedUnits[interferingUnitID] == nil and Spring.GetUnitIsBeingBuilt(interferingUnitID) == false  then
					-- Only buggeroff from one build site at a time
					visitedUnits[interferingUnitID] = true
					local unitX, _, unitZ = Spring.GetUnitPosition(interferingUnitID)
					if shouldIssueBuggeroff(cachedBuilderTeams[builderID], interferingUnitID, targetX, targetY, targetZ, buggerOffRadius) then
						local sendX, sendZ = math.closestPointOnCircle(targetX, targetZ, buggerOffRadius, unitX, unitZ)

						if Spring.TestMoveOrder(Spring.GetUnitDefID(interferingUnitID), sendX, targetY, sendZ) then
							goalIdleRadius[interferingUnitID] = 0
							Spring.GiveOrderToUnit(interferingUnitID, CMD.INSERT, {0, CMD_BUGGER_OFF, 0, sendX, targetY, sendZ, builderID}, CMD.OPT_ALT)
							Spring.SetUnitMoveGoal(interferingUnitID, sendX, targetY, sendZ, goalRadius) -- even if command is mysteriously disallowed
						end
					end
				end
			end

			if builderRadiusOffsets[builderID] > MAX_BUGGEROFF_RADIUS or IsUnitRepeatOn(builderID) then
				removeBuilder(builderID)
			end

		elseif isBuilding then
			-- We want to keep updating in case the builder has got another job nearby
			builderRadiusOffsets[builderID] = 0
		end
	end

	if frame % SLOW_UPDATE_FREQUENCY ~= 0 and not needsUpdate then
		return
	end

	needsUpdate = false
	for builderID, _ in pairs(slowUpdateBuilders) do
		local builderCommands   = Spring.GetUnitCommands(builderID, -1)
		local hasBuildCommand, buildCommandFirst = false, false
		local targetX, targetZ  = 0, 0

		if builderCommands ~= nil then
			for idx, command in ipairs(builderCommands) do
				if command.id < 0 then
					hasBuildCommand = true
					if idx == 1 and command.params[1] and command.params[3] then
						buildCommandFirst = true
						targetX, targetZ  = command.params[1], command.params[3]
					end
				end
			end
		end

		local isBuilding  = false
		if Spring.GetUnitIsBuilding(builderID) then isBuilding = true end

		local x, _, z = Spring.GetUnitPosition(builderID)
		if hasBuildCommand == false then
			removeBuilder(builderID)
		elseif buildCommandFirst and isBuilding == false and math.distance2d(targetX, targetZ, x, z) <= FAST_UPDATE_RADIUS then
			watchBuilder(builderID)
		end
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if cachedUnitDefs[unitDefID].isBuilder then
		cachedBuilderTeams[unitID] = unitTeam
	end
end

---@type CreateCommand
local removeBuggerOffs = { CMD.REMOVE, CMD_BUGGER_OFF, CMD.OPT_ALT }

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and commandDependencies[builderID] then
		if Spring.GiveOrderArrayToUnitMap(commandDependencies[builderID], removeBuggerOffs) then
			commandDependencies[builderID] = nil
		else
			Spring.Echo("Something went wrong")
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if not shouldNotBuggeroff[unitDefID] then
		Spring.InsertUnitCmdDesc(unitID, CMD_BUGGER_OFF_DESC)
	end
end

function gadget:Initialize()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local unitList = Spring.GetTeamUnits(teamID)
		for _, unitID in ipairs(unitList) do
			gadget:MetaUnitAdded(unitID, Spring.GetUnitDefID(unitID), teamID)
		end
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	cachedBuilderTeams[unitID] = nil
	if cachedUnitDefs[unitDefID].isBuilder then
		removeBuilder(unitID)
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cachedUnitDefs[unitDefID].isBuilder then
		slowWatchBuilder(unitID)
	end
	if cmdID == CMD_BUGGER_OFF then
		Spring.SetUnitMoveGoal(unitID, cmdParams[1], cmdParams[2], cmdParams[3], goalRadius)
	end
end

function gadget:CommandFallback(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_BUGGER_OFF then
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local tx, ty, tz = cmdParams[1], cmdParams[2], cmdParams[3]
		Spring.SetUnitMoveGoal(unitID, tx, ty, tz, goalRadius)
		local unitGoalRadius = goalRadius + goalIdleRadius[unitID]

		if not Spring.GetUnitWorkerTask(cmdParams[4]) and math.distance2d(ux, uz, tx, tz) >= goalRadius then
			-- Add impatience:
			goalIdleRadius[unitID] = goalIdleRadius[unitID] + 1
			return true, false -- used / remove
		else
			return true, true
		end
	end

	return false
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag)
	if cmdID == CMD_BUGGER_OFF then
		Spring.MarkerAddPoint(Spring.GetUnitPosition(unitID))
	end
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Build Assist Ownership",
		desc    = "Who builds does not assist. Who assists does not acquire.",
		author  = "efrec",
		date    = "2025",
		license = "GNU GPL, v2 or later",
		layer   = 999999, -- must be the last call to AllowUnitBuildStep
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local buildTargets = {}

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local beingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)

	if beingBuilt and buildProgress < 1 then
		local buildCost, metalCost, energyCost = Spring.GetUnitCosts(unitID)
		buildTargets[unitID] = {
			originTeam = unitTeam,
			metalCost = metalCost,
			energyCost = energyCost,
			buildCost = buildCost,
			[unitTeam] = buildProgress,
		}
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local info = buildTargets[unitID]

	if info ~= nil then
		local teamBest = unitTeam
		local progressBest = info[unitTeam] or 0

		-- okay i made the iter a little dumb
		for teamID, progress in pairs(info) do
			if type(teamID) == "number" and progress > progressBest then
				progressBest = progress
				teamBest = teamID
			end
		end

		if teamBest ~= unitTeam then
			-- nerd
			Spring.TransferUnit(unitID, teamBest, true)
		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if buildTargets[unitID] then
		-- nerddd
		gadget:UnitCreated(unitID, unitDefID, newTeam)
	end
end

function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
	local info = buildTargets[unitID]

	if info ~= nil then
		-- add progress on build assist and repair
		-- remove it on reclaim
		info[builderTeam] = (info[builderTeam] or 0) + part
	end
end

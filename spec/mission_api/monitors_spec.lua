local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

local UNITS_OWNED = 7
local PAWN = 1
local COMMANDER = 2

-- monitors.lua and unit_query.lua keep the engine calls they make at load, so the stubs read this table.
---@type table<integer, { unitDefID: integer, teamID: integer, beingBuilt: boolean?, dead: boolean? }>
local units = {}
env.Spring.GetAllUnits = function()
	local unitIDs = {}
	for unitID in pairs(units) do
		unitIDs[#unitIDs + 1] = unitID
	end
	table.sort(unitIDs)
	return unitIDs
end
env.Spring.GetUnitDefID = function(unitID)
	return units[unitID].unitDefID
end
env.Spring.GetUnitTeam = function(unitID)
	return units[unitID].teamID
end
env.Spring.GetUnitIsBeingBuilt = function(unitID)
	return units[unitID].beingBuilt == true
end
env.Spring.GetUnitIsDead = function(unitID)
	return units[unitID].dead == true
end
env.UnitDefs = { [PAWN] = { name = "armpw" }, [COMMANDER] = { name = "armcom" } }
env.UnitDefNames = { armpw = { id = PAWN }, armcom = { id = COMMANDER } }

describe("mission_api.monitors", function()
	local missionApi, tracking, monitors
	local counts -- every UpdateUnitNameCount call, in order

	local statisticsSpy = {
		UpdateUnitNameCount = function(conditionType, teamID, unitDefName, unitName, direction)
			counts[#counts + 1] = {
				conditionType = conditionType,
				teamID = teamID,
				unitDefName = unitDefName,
				unitName = unitName,
				direction = direction,
			}
		end,
	}

	local function count(teamID, unitDefName, direction)
		return {
			conditionType = UNITS_OWNED,
			teamID = teamID,
			unitDefName = unitDefName,
			unitName = "army",
			direction = direction,
		}
	end

	local function members()
		local unitIDs = missionApi.Modules.UnitQuery.MatchingUnits("army")
		table.sort(unitIDs)
		return unitIDs
	end

	-- The player's units, except the commander and the pawn, as processed: team names are IDs.
	local function addArmy()
		monitors.AddMonitor("army", { teamName = 0 }, { { unitName = "commander" }, { unitName = "pawn7" } })
	end

	before_each(function()
		for unitID in pairs(units) do
			units[unitID] = nil
		end
		units[100] = { unitDefID = COMMANDER, teamID = 0 }
		units[101] = { unitDefID = PAWN, teamID = 0 }
		units[102] = { unitDefID = PAWN, teamID = 0 }
		units[103] = { unitDefID = PAWN, teamID = 1 }

		missionApi = MissionApiBuilder.new()
			:WithTrackedUnit("commander", 100)
			:WithTrackedUnit("pawn7", 101)
			:WithConditionDefinitions({ Types = { UnitsOwned = UNITS_OWNED } })
			:Install(env)
		tracking = missionApi.Modules.Tracking
		-- Included per test, since each install loads a fresh tracking module for it to listen to.
		monitors = MissionSpecEnv.include(env, "luarules/mission_api/monitors.lua")
		monitors.Init({ statistics = statisticsSpy })
		counts = {}
	end)

	describe("AddMonitor", function()
		it("makes every finished unit matching the rule a member, counted", function()
			addArmy()

			assert.are.same({ 102 }, members())
			assert.are.same({ count(0, "armpw", 1) }, counts)
		end)

		it("leaves out build frames and dead units", function()
			units[104] = { unitDefID = PAWN, teamID = 0, beingBuilt = true }
			units[105] = { unitDefID = PAWN, teamID = 0, dead = true }

			addArmy()

			assert.are.same({ 102 }, members())
		end)

		it("settles every member before counting any", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			local membersAtFirstCount
			monitors.Init({
				statistics = {
					UpdateUnitNameCount = function()
						membersAtFirstCount = membersAtFirstCount or members()
					end,
				},
			})

			addArmy()

			assert.are.same({ 102, 104 }, membersAtFirstCount)
		end)

		it("replaces the rule of a monitor with the same name", function()
			addArmy()
			counts = {}

			monitors.AddMonitor("army", { unitName = "commander" })

			assert.are.same({ 100 }, members())
			assert.are.same({ count(0, "armcom", 1), count(0, "armpw", -1) }, counts)
		end)
	end)

	describe("a name only the monitor gives", function()
		it("refuses a monitor whose rule names a monitor", function()
			addArmy()

			monitors.AddMonitor("veterans", { unitName = "army" })

			assert.is_nil(missionApi.monitors.veterans)
		end)

		it("refuses a monitor whose name a monitor's rule uses", function()
			monitors.AddMonitor("army", { teamName = 0 }, { { unitName = "reserve" } })

			monitors.AddMonitor("reserve", { teamName = 1 })

			assert.is_nil(missionApi.monitors.reserve)
		end)

		it("refuses a monitor whose name units already hold", function()
			monitors.AddMonitor("commander", { teamName = 0 })

			assert.is_nil(missionApi.monitors.commander)
		end)
	end)

	describe("RemoveMonitor", function()
		it("takes the name from every member, counted", function()
			addArmy()
			counts = {}

			monitors.RemoveMonitor("army")

			assert.are.same({}, members())
			assert.are.same({ count(0, "armpw", -1) }, counts)
		end)

		it("stops the monitor, so finished units no longer join", function()
			addArmy()
			monitors.RemoveMonitor("army")
			units[104] = { unitDefID = PAWN, teamID = 0 }

			monitors.OnUnitFinished(104)

			assert.are.same({}, members())
		end)

		it("lets the name be added again", function()
			addArmy()
			monitors.RemoveMonitor("army")

			addArmy()

			assert.are.same({ 102 }, members())
		end)

		it("does nothing for a name no monitor gives", function()
			monitors.RemoveMonitor("army")

			assert.are.same({}, counts)
		end)
	end)

	describe("OnUnitFinished", function()
		it("joins a unit that finished building, counted", function()
			addArmy()
			counts = {}
			units[104] = { unitDefID = PAWN, teamID = 0 }

			monitors.OnUnitFinished(104)

			assert.are.same({ 102, 104 }, members())
			assert.are.same({ count(0, "armpw", 1) }, counts)
		end)

		it("leaves out a unit matching an exception", function()
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			tracking.TrackUnit("pawn7", 104)

			monitors.OnUnitFinished(104)

			assert.are.same({ 102 }, members())
		end)

		it("leaves out a unit being spawned with an excepted loadout name", function()
			addArmy()
			units[104] = { unitDefID = COMMANDER, teamID = 0 }
			missionApi.nameOfUnitBeingSpawned = "commander"
			missionApi.unitIDBeingSpawned = 104

			monitors.OnUnitFinished(104)

			missionApi.nameOfUnitBeingSpawned = nil
			missionApi.unitIDBeingSpawned = nil
			assert.are.same({ 102 }, members())
		end)
	end)

	describe("OnUnitReverseBuilt", function()
		it("takes out a member that is a build frame again, counted", function()
			addArmy()
			counts = {}
			units[102].beingBuilt = true

			monitors.OnUnitReverseBuilt(102)

			assert.are.same({}, members())
			assert.are.same({ count(0, "armpw", -1) }, counts)
		end)
	end)

	describe("a unit changing team", function()
		-- The order of the MetaUnit call-ins in a transfer, with the engine's team change between them.
		local function transfer(unitID, teamID)
			monitors.OnUnitRemoved(unitID)
			units[unitID].teamID = teamID
			monitors.OnUnitAdded(unitID)
		end

		it("joins a unit given to the monitored team, uncounted", function()
			addArmy()
			counts = {}

			transfer(103, 0)

			assert.are.same({ 102, 103 }, members())
			assert.are.same({}, counts)
		end)

		it("takes out a member given to another team, uncounted", function()
			addArmy()
			counts = {}

			transfer(102, 1)

			assert.are.same({}, members())
			assert.are.same({}, counts)
		end)

		it("keeps the name until MetaUnitAdded, so UnitTaken's triggers see the old membership", function()
			addArmy()

			monitors.OnUnitRemoved(102)
			units[102].teamID = 1

			assert.are.same({ 102 }, members())
		end)

		it("leaves a build frame out", function()
			addArmy()
			units[103].beingBuilt = true

			transfer(103, 0)

			assert.are.same({ 102 }, members())
		end)

		it("leaves out a unit killed during UnitTaken's dispatch", function()
			addArmy()
			monitors.OnUnitRemoved(103)
			units[103].dead = true
			units[103].teamID = 0

			monitors.OnUnitAdded(103)

			assert.are.same({ 102 }, members())
		end)

		it(
			"does not count a leave by naming during UnitTaken's dispatch, as MetaUnitRemoved uncounted the unit",
			function()
				addArmy()
				counts = {}
				monitors.OnUnitRemoved(102)

				tracking.TrackUnit("commander", 102)

				assert.are.same({}, members())
				assert.are.same({}, counts)
			end
		)

		it("does not count a monitor removed during UnitTaken's dispatch", function()
			addArmy()
			counts = {}
			monitors.OnUnitRemoved(102)

			monitors.RemoveMonitor("army")

			assert.are.same({}, counts)
		end)

		it("holds nothing back for a unit removed by its death", function()
			addArmy()
			counts = {}
			units[102].dead = true
			monitors.OnUnitRemoved(102)
			-- Alive again only so that a hold, if any, would show in the count.
			units[102].dead = nil

			tracking.TrackUnit("commander", 102)

			assert.are.same({ count(0, "armpw", -1) }, counts)
		end)

		it("leaves a unit created on its team to be settled when it finishes", function()
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0 }

			monitors.OnUnitAdded(104)

			assert.are.same({ 102 }, members())
		end)
	end)

	describe("a unit being added", function()
		it("joins uncounted during MetaUnitAdded's dispatch, which counts it with its names after", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			monitors.OnUnitAdded(104)

			addArmy()

			assert.are.same({ 102, 104 }, members())
			assert.are.same({ count(0, "armpw", 1) }, counts)
		end)

		it("is counted again once released", function()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			monitors.OnUnitAdded(104)
			addArmy()
			monitors.ReleaseUnitCount(104)
			counts = {}

			tracking.TrackUnit("pawn7", 104)

			assert.are.same({ count(0, "armpw", -1) }, counts)
		end)
	end)

	describe("a member's death", function()
		it("keeps the name through UnitDestroyed's dispatch, so UnitKilled on the monitor fires", function()
			local unitKilled = MissionSpecEnv.include(env, "luarules/mission_api/conditions/unit_killed.lua")
			local activated = {}
			local context = {
				DoesUnitHaveName = tracking.DoesUnitHaveName,
				ActivateTrigger = function(trigger)
					activated[#activated + 1] = trigger
					return true
				end,
			}
			local trigger = { parameters = { unitName = "army" } }
			addArmy()
			units[102].dead = true

			unitKilled.callins.UnitDestroyed(trigger, "t", context, 102, PAWN, 0)

			assert.are.same({ trigger }, activated)
		end)

		it("is not counted by the monitor, as its names are uncounted on removal", function()
			addArmy()
			counts = {}
			units[102].dead = true

			tracking.UntrackUnitID(102)

			assert.are.same({}, members())
			assert.are.same({}, counts)
		end)
	end)

	describe("a name given or taken by anything else", function()
		it("takes out a member given an excepted name, counted", function()
			addArmy()
			counts = {}

			tracking.TrackUnit("commander", 102)

			assert.are.same({}, members())
			assert.are.same({ count(0, "armpw", -1) }, counts)
		end)

		it("joins a unit whose excepted name is taken, counted", function()
			addArmy()
			counts = {}

			tracking.UntrackUnitName("pawn7")

			assert.are.same({ 101, 102 }, members())
			assert.are.same({ count(0, "armpw", 1) }, counts)
		end)

		it("ignores a name the rule does not use", function()
			addArmy()
			counts = {}

			tracking.TrackUnit("scout", 102)
			tracking.TrackUnit("scout", 103)

			assert.are.same({ 102 }, members())
			assert.are.same({}, counts)
		end)

		it("ignores a dying unit", function()
			addArmy()
			counts = {}
			units[102].dead = true

			tracking.TrackUnit("commander", 102)

			assert.are.same({}, counts)
		end)
	end)

	describe("counting", function()
		local statistics, unitsOwnedTriggers, activated

		before_each(function()
			unitsOwnedTriggers = {}
			activated = {}
			statistics = MissionSpecEnv.include(env, "luarules/mission_api/statistics.lua")
			statistics.Init({
				processTriggersOfType = function(conditionType, func)
					for triggerID, trigger in pairs(unitsOwnedTriggers) do
						if trigger.type == conditionType then
							func(trigger, triggerID)
						end
					end
				end,
				activateTrigger = function(trigger)
					activated[#activated + 1] = trigger
					trigger.repeatCount = trigger.repeatCount + 1
					return true
				end,
			})
			monitors.Init({ statistics = statistics })
		end)

		local function unitsOwned(parameters)
			return { type = UNITS_OWNED, parameters = parameters, repeatCount = 0 }
		end

		it("keeps a UnitsOwned count on the monitor's name true", function()
			unitsOwnedTriggers.armyGone = unitsOwned({ teamName = 0, unitName = "army", quantity = 0 })
			addArmy()
			units[104] = { unitDefID = PAWN, teamID = 0 }
			monitors.OnUnitFinished(104)

			tracking.TrackUnit("commander", 102)
			assert.are.same({}, activated)

			units[104].beingBuilt = true
			monitors.OnUnitReverseBuilt(104)
			assert.are.same({ unitsOwnedTriggers.armyGone }, activated)
		end)

		it("leaves a UnitsOwned count by type alone", function()
			unitsOwnedTriggers.pawns = unitsOwned({ teamName = 0, unitDefName = "armpw", quantity = 1 })

			addArmy()

			assert.are.same({}, activated)
		end)
	end)
end)

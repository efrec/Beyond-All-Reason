local statistics = VFS.Include("luarules/mission_api/statistics.lua")

describe("mission_api.statistics", function()
	local CONDITION_TYPE = 1

	---@type table<string, table>
	local triggers -- triggerID -> trigger
	---@type table[]
	local activated -- ordered list of activated triggers
	---@type table
	local objectiveUpdates -- ordered list of managed-objective update calls

	-- Fakes injected in place of the gadget's trigger core:
	local function processTriggersOfType(conditionType, func)
		for triggerID, trigger in pairs(triggers) do
			if trigger.type == conditionType then
				func(trigger, triggerID)
			end
		end
	end

	local function activateTrigger(trigger)
		activated[#activated + 1] = trigger
		-- Mimic a valid repeating activation so milestone thresholds advance. Return value is ignored.
		trigger.triggered = true
		trigger.repeatCount = trigger.repeatCount + 1
		return true
	end

	local function makeTrigger(conditionType, parameters)
		return { type = conditionType, parameters = parameters, triggered = false, repeatCount = 0 }
	end

	before_each(function()
		triggers = {}
		activated = {}
		objectiveUpdates = {}
		GG["MissionAPI"] = {
			ManagedObjectives = {},
			Modules = {
				Objectives = {
					-- Spy: record every argument it receives so tests can assert on them.
					UpdateObjectiveProgress = function(
						objectiveID,
						teamID,
						unitDefName,
						unitNames,
						direction,
						managedObjective
					)
						objectiveUpdates[#objectiveUpdates + 1] = {
							objectiveID = objectiveID,
							teamID = teamID,
							unitDefName = unitDefName,
							unitNames = unitNames,
							direction = direction,
							managedObjective = managedObjective,
						}
					end,
				},
			},
		}
		statistics.Init({ processTriggersOfType = processTriggersOfType, activateTrigger = activateTrigger })
	end)

	-- Note: statisticsTriggerCounts is module-private and persists for the whole
	-- run, so each test uses a unique triggerID to stay isolated.

	it("fires when the count reaches quantity", function()
		triggers.reach = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 2 })

		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(0, #activated)

		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(1, #activated)
	end)

	it("re-fires at each quantity milestone (2*q, 3*q, ...)", function()
		triggers.milestones = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 2 })

		for _ = 1, 6 do
			statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		end

		-- milestones crossed at counts 2, 4, 6
		assert.are.equal(3, #activated)
	end)

	it("does not fire before the next milestone", function()
		triggers.partial = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 3 })

		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(0, #activated)
	end)

	it("counts decrements against the milestone", function()
		triggers.net = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 2 })

		statistics.Increment(CONDITION_TYPE, 0, "armwar", {}) -- count 1
		statistics.Decrement(CONDITION_TYPE, 0, "armwar", {}) -- count 0
		statistics.Increment(CONDITION_TYPE, 0, "armwar", {}) -- count 1
		assert.are.equal(0, #activated) -- still below quantity 2

		statistics.Increment(CONDITION_TYPE, 0, "armwar", {}) -- count 2
		assert.are.equal(1, #activated) -- milestone reached
	end)

	it("with quantity 0, fires only when the count reaches 0", function()
		triggers.zero = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 0 })

		-- Leaving 0 (count 0 -> 1) does not fire.
		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(0, #activated)

		-- Returning to 0 (count 1 -> 0) fires.
		statistics.Decrement(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(1, #activated)

		-- It fires again each time the count returns to 0, but never on the way up.
		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(1, #activated)
		statistics.Decrement(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(2, #activated)
	end)

	it("filters by teamName", function()
		triggers.filterTeam = makeTrigger(CONDITION_TYPE, { teamName = 5, quantity = 1 })

		-- Wrong team: no match.
		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(0, #activated)

		-- Right team: fires.
		statistics.Increment(CONDITION_TYPE, 5, "armwar", {})
		assert.are.equal(1, #activated)
	end)

	it("filters by unitDefName", function()
		triggers.filterDef = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 1, unitDefName = "armcom" })

		-- Wrong unit def: no match.
		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})
		assert.are.equal(0, #activated)

		-- Matching unit def: fires.
		statistics.Increment(CONDITION_TYPE, 0, "armcom", {})
		assert.are.equal(1, #activated)
	end)

	it("filters by unitName", function()
		triggers.filterNamed = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 1, unitName = "boss" })

		-- Required unit name absent: no match.
		statistics.Increment(CONDITION_TYPE, 0, "armcom", {})
		assert.are.equal(0, #activated)

		-- Required unit name present: fires.
		statistics.Increment(CONDITION_TYPE, 0, "armcom", { boss = true })
		assert.are.equal(1, #activated)
	end)

	it("forwards events to managed objectives even with no matching triggers", function()
		GG["MissionAPI"].ManagedObjectives[CONDITION_TYPE] = { { objectiveID = "obj" } }

		statistics.Increment(CONDITION_TYPE, 0, "armwar", {})

		assert.are.equal(1, #objectiveUpdates)
		local objectiveUpdate = objectiveUpdates[1] --[[@as table<string, any>]]
		assert.are.equal("obj", objectiveUpdate.objectiveID)
		assert.are.equal(0, objectiveUpdate.teamID)
		assert.are.equal("armwar", objectiveUpdate.unitDefName)
		assert.are.equal(1, objectiveUpdate.direction)
	end)

	describe("UpdateUnitNameCount", function()
		it("counts a unit under the name for a trigger filtering on it", function()
			triggers.nameCounted = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 2, unitName = "army" })

			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", 1)
			assert.are.equal(0, #activated)

			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", 1)
			assert.are.equal(1, #activated)
		end)

		it("fires a quantity 0 trigger when the last named unit is uncounted", function()
			triggers.nameEmptied = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 0, unitName = "army" })

			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", 1)
			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", -1)
			assert.are.same({ triggers.nameEmptied }, activated)
		end)

		it("leaves triggers without that name alone", function()
			triggers.typeOnly = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 1 })
			triggers.otherName = makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 1, unitName = "boss" })

			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", 1)
			assert.are.equal(0, #activated)
		end)

		it("filters by teamName and unitDefName", function()
			triggers.nameOtherTeam = makeTrigger(CONDITION_TYPE, { teamName = 5, quantity = 1, unitName = "army" })
			triggers.nameOtherDef =
				makeTrigger(CONDITION_TYPE, { teamName = 0, quantity = 1, unitName = "army", unitDefName = "armcom" })

			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", 1)
			assert.are.equal(0, #activated)
		end)

		it("updates only the managed objectives filtering on that name", function()
			local named = { objectiveID = "named", parameters = { unitName = "army" } }
			local typeOnly = { objectiveID = "typeOnly", parameters = {} }
			GG["MissionAPI"].ManagedObjectives[CONDITION_TYPE] = { named, typeOnly }

			statistics.UpdateUnitNameCount(CONDITION_TYPE, 0, "armwar", "army", -1)

			assert.are.same({
				{
					objectiveID = "named",
					teamID = 0,
					unitDefName = "armwar",
					unitNames = { army = true },
					direction = -1,
					managedObjective = named,
				},
			}, objectiveUpdates)
		end)
	end)
end)

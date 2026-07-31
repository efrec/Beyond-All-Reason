require('spec_helper')

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Spring.GetUnit* / UnitDefs inside its handlers.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

_G.Game = _G.Game or {}
_G.Game.gameSpeed = 30

local unitDetected = VFS.Include('luarules/mission_api/triggers/unit_detected.lua')
local onEnteredLos = unitDetected.callins.UnitEnteredLos
local onEnteredRadar = unitDetected.callins.UnitEnteredRadar
local onSeismicPing = unitDetected.callins.UnitSeismicPing
local onDestroyed = unitDetected.callins.UnitDestroyed
local onTaken = unitDetected.callins.UnitTaken

describe('mission_api.triggers.unit_detected', function()
	-- Unit 100 is on team 3, allyteam 1. It is detected by an enemy on allyteam 0.
	-- Teams 0 and 1 are on allyteam 0; teams 2 and 3 are on allyteam 1.
	local teamAllyTeams = { [0] = 0, [1] = 0, [2] = 1, [3] = 1 }

	before_each(function()
		Spring.GetUnitTeam = function(_unitID) return 3 end
		Spring.GetUnitAllyTeam = function(_unitID) return 1 end
		Spring.GetUnitIsDead = function(_unitID) return false end
		Spring.GetTeamAllyTeamID = function(teamID) return teamAllyTeams[teamID] end
	end)

	local function newContext()
		local fired = 0
		local context = {
			DetectedUnits = {},
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
		}
		return context, function() return fired end
	end

	local function trigger(parameters, settings)
		return { parameters = parameters or {}, settings = settings or {} }
	end

	local triggerID = 't'

	it('declares its type and parameters', function()
		assert.are.equal('UnitDetected', unitDetected.type)
		local names = {}
		for _, parameter in ipairs(unitDetected.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.owningTeamID)
		assert.is_true(names.spottingAllyTeamID)
		assert.is_true(names.sensorTypes)
		assert.are.same({ 'unitName', 'unitDefName' }, unitDetected.parameters.requiresOneOf)
	end)

	it('filters by unitDefName, owningTeamID, and spottingAllyTeamID', function()
		local context, fired = newContext()
		onEnteredLos(trigger({ unitDefName = 'corfast' }), triggerID, context, 100, 3, 0, 1)
		onEnteredLos(trigger({ owningTeamID = 9 }), triggerID, context, 100, 3, 0, 1)
		onEnteredLos(trigger({ spottingAllyTeamID = 5 }), triggerID, context, 100, 3, 0, 1) -- recheck
		assert.are.equal(0, fired())
	end)

	it('skips firing on allied units', function()
		Spring.GetUnitAllyTeam = function(_unitID) return 0 end -- 0 is the spec's detecting allyTeam
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		onSeismicPing(t, triggerID, context, 0, 0, 0, 1, 0, 100, 1)
		assert.are.equal(0, fired())
	end)

	it('fires on a matching enemy unit entering LOS', function()
		local context, fired = newContext()
		onEnteredLos(trigger({ unitDefName = 'armpw' }), triggerID, context, 100, 3, 0, 1) -- unitDefID 1 = armpw
		assert.are.equal(1, fired())
	end)

	it('fires on radar entry for a radar-only contact', function()
		local context, fired = newContext()
		onEnteredRadar(trigger({ unitDefName = 'armpw' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())
	end)

	it('fires on a seismic ping alone', function()
		local context, fired = newContext()
		onSeismicPing(trigger({ unitDefName = 'armpw' }), triggerID, context, 0, 0, 0, 1, 0, 100, 1)
		assert.are.equal(1, fired())
	end)

	it('skips firing on excluded sensorTypes when others are specified', function()
		local context, fired = newContext()
		onEnteredLos(trigger({ unitDefName = 'armpw', sensorTypes = { radar = true } }), triggerID, context, 100, 3, 0, 1)
		onEnteredRadar(trigger({ unitDefName = 'armpw', sensorTypes = { sight = true } }), triggerID, context, 100, 3, 0, 1)
		onSeismicPing(trigger({ unitDefName = 'armpw', sensorTypes = { sight = true } }), triggerID, context, 0, 0, 0, 1, 0, 100, 1)
		assert.are.equal(0, fired())
	end)

	-- Single-counting across multiple sensors:

	it('counts a unit once when LOS and radar report it together', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())
	end)

	it('counts a unit once when a radar contact later walks into LOS', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())
	end)

	it('counts a unit once across a continuous stream of seismic pings', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 10 do
			onSeismicPing(t, triggerID, context, 0, 0, 0, 1, 0, 100, 1)
		end
		assert.are.equal(1, fired())
	end)

	it('counts a visible unit once while it keeps pinging seismic sensors', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		for _ = 1, 10 do
			onSeismicPing(t, triggerID, context, 0, 0, 0, 1, 0, 100, 1)
		end
		assert.are.equal(1, fired())
	end)

	it('counts each unit separately', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		onEnteredLos(t, triggerID, context, 101, 3, 0, 1)
		onEnteredLos(t, triggerID, context, 102, 3, 0, 1)
		assert.are.equal(3, fired())
	end)

	-- Not sure about this. If the author does not specify allyTeam, though, how else to do it:
	it('counts a unit once for each allyteam that spots it', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1) -- spotted by allyteam 0
		onEnteredLos(t, triggerID, context, 100, 3, 2, 1) -- and by allyteam 2
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1) -- allyteam 0 again: already detected
		assert.are.equal(2, fired())
	end)

	it('counts separately for separate triggers', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, 'first', context, 100, 3, 0, 1)
		onEnteredLos(t, 'second', context, 100, 3, 0, 1)
		assert.are.equal(2, fired())
	end)

	-- Forgetting detected units:

	-- Units remain simulated while dying. They move, change LOS state, etc. until rendered destroyed.
	-- Unsynced does receive the final RenderDestroyed event but we do not in our synced gadget space.
	local function renderDestroyed(unitID)
		Spring.GetUnitIsDead = function(deadUnitID) return deadUnitID == unitID end -- keeps one dead ID
	end

	it('does not detect a dying unit that it had never detected', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		renderDestroyed(100)
		onDestroyed(t, triggerID, context, 100)
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it('does not detect a dying unit that it had already detected', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())

		renderDestroyed(100)
		onDestroyed(t, triggerID, context, 100)

		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		onSeismicPing(t, triggerID, context, 0, 0, 0, 1, 0, 100, 1)
		assert.are.equal(1, fired())
	end)

	it('detects a once-detected unitID that has been recycled', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())

		renderDestroyed(100)
		onDestroyed(t, triggerID, context, 100)
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())

		-- The corpse is gone and unitID 100 now belongs to some other, living unit.
		Spring.GetUnitIsDead = function(_unitID) return false end
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(2, fired())
	end)

	it('detects a once-detected unitID that has changed allyteam', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())

		onTaken(t, triggerID, context, 100, 1, 3, 1) -- team 3 (allyteam 1) -> team 1 (allyteam 0)
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(2, fired())
	end)

	it('does not re-detect a unit that changed team within its allyteam', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())

		onTaken(t, triggerID, context, 100, 1, 3, 2) -- team 3 -> team 2, both allyteam 1
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())
	end)

	it('forgets a unit for every allyteam at once', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		onEnteredLos(t, triggerID, context, 100, 3, 2, 1)
		assert.are.equal(2, fired())

		onTaken(t, triggerID, context, 100, 1, 3, 1) -- allyteam 1 -> allyteam 0
		onEnteredLos(t, triggerID, context, 100, 3, 0, 1)
		onEnteredLos(t, triggerID, context, 100, 3, 2, 1)
		assert.are.equal(4, fired())
	end)

	it('tolerates forgetting a unit the trigger never detected', function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onDestroyed(t, triggerID, context, 100)
		onTaken(t, triggerID, context, 100, 1, 3, 1)
		assert.are.equal(0, fired())
	end)
end)

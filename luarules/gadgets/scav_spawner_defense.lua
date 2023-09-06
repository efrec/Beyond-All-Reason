function gadget:GetInfo()
	return {
		name = "Scav Defense Spawner",
		desc = "Spawns burrows and scavs",
		author = "TheFatController/quantum, Damgam",
		date = "27 February, 2012",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if Spring.Utilities.Gametype.IsScavengers() and not Spring.Utilities.Gametype.IsRaptors() then
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Activated!")
else
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "Scav Defense Spawner Deactivated!")
	return false
end

local config = VFS.Include('LuaRules/Configs/scav_spawn_defs.lua')

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	-- SYNCED CODE
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Speed-ups
	--

	local ValidUnitID = Spring.ValidUnitID
	local GetUnitNeutral = Spring.GetUnitNeutral
	local GetTeamList = Spring.GetTeamList
	local GetTeamLuaAI = Spring.GetTeamLuaAI
	local GetGaiaTeamID = Spring.GetGaiaTeamID
	local SetGameRulesParam = Spring.SetGameRulesParam
	local GetGameRulesParam = Spring.GetGameRulesParam
	local GetTeamUnitCount = Spring.GetTeamUnitCount
	local GetGameFrame = Spring.GetGameFrame
	local GetGameSeconds = Spring.GetGameSeconds
	local DestroyUnit = Spring.DestroyUnit
	local GetTeamUnits = Spring.GetTeamUnits
	local GetUnitPosition = Spring.GetUnitPosition
	local GiveOrderToUnit = Spring.GiveOrderToUnit
	local TestBuildOrder = Spring.TestBuildOrder
	local GetGroundBlocked = Spring.GetGroundBlocked
	local CreateUnit = Spring.CreateUnit
	local SetUnitBlocking = Spring.SetUnitBlocking
	local GetGroundHeight = Spring.GetGroundHeight
	local GetUnitHealth = Spring.GetUnitHealth
	local SetUnitExperience = Spring.SetUnitExperience
	local GetUnitIsDead = Spring.GetUnitIsDead

	local mRandom = math.random
	local math = math
	local Game = Game
	local table = table
	local ipairs = ipairs
	local pairs = pairs

	local MAPSIZEX = Game.mapSizeX
	local MAPSIZEZ = Game.mapSizeZ

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	Spring.SetGameRulesParam("BossFightStarted", 0)
	local bossLifePercent = 100
	local maxTries = 30
	local scavUnitCap = math.floor(Game.maxUnits*0.95)
	local minBurrows = 1
	local timeOfLastSpawn = -999999
	local timeOfLastWave = 0
	local t = 0 -- game time in secondstarget
	local bossAnger = 0
	local techAnger = 0
	local bossMaxHP = 0
	local playerAggression = 0
	local playerAggressionLevel = 0
	local playerAggressionEcoValue = 0
	local bossAngerAggressionLevel = 0
	local difficultyCounter = config.difficulty
	local waveParameters = {
		baseCooldown = 5,
		waveSizeMultiplier = 1,
		waveTimeMultiplier = 1,
		waveAirPercentage = 20,
		waveSpecialPercentage = 33,
		airWave = {
			cooldown = mRandom(5,15),
		},
		specialWave = {
			cooldown = mRandom(5,15),
		},
		basicWave = {
			cooldown = mRandom(5,15),
		},
		smallWave = {
			cooldown = mRandom(5,15),
		},
		largerWave = {
			cooldown = mRandom(10,30),
		},
		hugeWave = {
			cooldown = mRandom(15,50),
		},
		epicWave = {
			cooldown = mRandom(20,75),
		}
	}
	local squadSpawnOptions = config.squadSpawnOptionsTable
	--local miniBossCooldown = 0
	local firstSpawn = true
	local gameOver = nil
	local humanTeams = {}
	local spawnQueue = {}
	local deathQueue = {}
	local bossResistance = {}
	local bossID
	local scavTeamID, scavAllyTeamID
	local lsx1, lsz1, lsx2, lsz2
	local burrows = {}
	local squadsTable = {}
	local unitSquadTable = {}
	local squadPotentialTarget = {}
	local squadPotentialHighValueTarget = {}
	local unitTargetPool = {}
	local unitCowardCooldown = {}
	local unitTeleportCooldown = {}
	local squadCreationQueue = {
		units = {},
		role = false,
		life = 10,
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}
	squadCreationQueueDefaults = {
		units = {},
		role = false,
		life = 10,
		regroupenabled = true,
		regrouping = false,
		needsregroup = false,
		needsrefresh = true,
	}

	--------------------------------------------------------------------------------
	-- Teams
	--------------------------------------------------------------------------------

	local teams = GetTeamList()
	for _, teamID in ipairs(teams) do
		local teamLuaAI = GetTeamLuaAI(teamID)
		if (teamLuaAI and string.find(teamLuaAI, "ScavengersAI")) then
			scavTeamID = teamID
			scavAllyTeamID = select(6, Spring.GetTeamInfo(scavTeamID))
			--computerTeams[teamID] = true
		else
			humanTeams[teamID] = true
		end
	end

	local gaiaTeamID = GetGaiaTeamID()
	if not scavTeamID then
		scavTeamID = gaiaTeamID
		scavAllyTeamID = select(6, Spring.GetTeamInfo(scavTeamID))
	else
		--computerTeams[gaiaTeamID] = nil
	end

	humanTeams[gaiaTeamID] = nil

	function PutScavAlliesInScavTeam(n)
		local players = Spring.GetPlayerList()
		for i = 1,#players do
			local player = players[i]
			local name, active, spectator, teamID, allyTeamID = Spring.GetPlayerInfo(player)
			if allyTeamID == scavAllyTeamID and (not spectator) then
				Spring.AssignPlayerToTeam(player, scavTeamID)
				local units = GetTeamUnits(teamID)
				scavteamhasplayers = true
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
				end
				Spring.KillTeam(teamID)
			end
		end

		local scavAllies = Spring.GetTeamList(scavAllyTeamID)
		for i = 1,#scavAllies do
			local _,_,_,AI = Spring.GetTeamInfo(scavAllies[i])
			local LuaAI = Spring.GetTeamLuaAI(scavAllies[i])
			if (AI or LuaAI) and scavAllies[i] ~= scavTeamID then
				local units = GetTeamUnits(scavAllies[i])
				for u = 1,#units do
					Spring.DestroyUnit(units[u], false, true)
					Spring.KillTeam(scavAllies[i])
				end
			end
		end
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Utility
	--

	function SetToList(set)
		local list = {}
		local count = 0
		for k in pairs(set) do
			count = count + 1
			list[count] = k
		end
		return list
	end

	function SetCount(set)
		local count = 0
		for k in pairs(set) do
			count = count + 1
		end
		return count
	end

	function getRandomMapPos()
		local x = mRandom(16, MAPSIZEX - 16)
		local z = mRandom(16, MAPSIZEZ - 16)
		local y = GetGroundHeight(x, z)
		return { x = x, y = y, z = z }
	end

	function getRandomEnemyPos()
		local loops = 0
		local targetCount = SetCount(squadPotentialTarget)
		local highValueTargetCount = SetCount(squadPotentialHighValueTarget)
		local pos = {}
		local pickedTarget = nil
		repeat
			loops = loops + 1
			if highValueTargetCount > 0 and mRandom() <= 0.75 then
				for target in pairs(squadPotentialHighValueTarget) do
					if mRandom(1,highValueTargetCount) == 1 then
						if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
							local x,y,z = Spring.GetUnitPosition(target)
							pos = {x = x+mRandom(-32,32), y = y, z = z+mRandom(-32,32)}
							pickedTarget = target
							break
						end
					end
				end
			else
				for target in pairs(squadPotentialTarget) do
					if mRandom(1,targetCount) == 1 then
						if ValidUnitID(target) and not GetUnitIsDead(target) and not GetUnitNeutral(target) then
							local x,y,z = Spring.GetUnitPosition(target)
							pos = {x = x+mRandom(-32,32), y = y, z = z+mRandom(-32,32)}
							pickedTarget = target
							break
						end
					end
				end
			end

		until pos.x or loops >= 10

		if not pos.x then
			pos = getRandomMapPos()
		end

		return pos, pickedTarget
	end

	function setScavXP(unitID)
		local maxXP = config.maxXP
		local bossAnger = bossAnger or 0
		local xp = mRandom(0, math.ceil((bossAnger*0.01) * maxXP * 1000))*0.001
		SetUnitExperience(unitID, xp)
		return xp
	end


	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Difficulty
    --

	local maxBurrows = ((config.maxBurrows*(1-config.scavPerPlayerMultiplier))+(config.maxBurrows*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
	local bossTime = (config.bossTime + config.gracePeriod)
	if config.difficulty == config.difficulties.survival then
		bossTime = math.ceil(bossTime*0.5)
	end
	local maxWaveSize = ((config.maxScavs*(1-config.scavPerPlayerMultiplier))+(config.maxScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
	local minWaveSize = ((config.minScavs*(1-config.scavPerPlayerMultiplier))+(config.minScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
	local currentMaxWaveSize = minWaveSize
	local endlessLoopCounter = 1
	function updateDifficultyForSurvival()
		t = GetGameSeconds()
		config.gracePeriod = t-1
		bossAnger = 0  -- reenable scav spawning
		techAnger = 0
		playerAggression = 0
		bossAngerAggressionLevel = 0
		pastFirstBoss = true
		SetGameRulesParam("scavBossAnger", bossAnger)
		SetGameRulesParam("scavTechAnger", techAnger)
		local nextDifficulty
		difficultyCounter = difficultyCounter + 1
		endlessLoopCounter = endlessLoopCounter + 1
		if config.difficultyParameters[difficultyCounter] then
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.bossResistanceMult = nextDifficulty.bossResistanceMult
			config.damageMod = nextDifficulty.damageMod
		else
			difficultyCounter = difficultyCounter - 1
			nextDifficulty = config.difficultyParameters[difficultyCounter]
			config.scavSpawnMultiplier = config.scavSpawnMultiplier+1
			config.bossResistanceMult = config.bossResistanceMult+0.5
			config.damageMod = config.damageMod+0.25
		end
		config.bossName = nextDifficulty.bossName
		config.burrowSpawnRate = nextDifficulty.burrowSpawnRate
		config.turretSpawnRate = nextDifficulty.turretSpawnRate
		config.bossSpawnMult = nextDifficulty.bossSpawnMult
		config.spawnChance = nextDifficulty.spawnChance
		config.maxScavs = nextDifficulty.maxScavs
		config.minScavs = nextDifficulty.minScavs
		config.maxBurrows = nextDifficulty.maxBurrows
		config.maxXP = nextDifficulty.maxXP
		config.angerBonus = nextDifficulty.angerBonus
		config.bossTime = math.ceil(nextDifficulty.bossTime/endlessLoopCounter)

		bossTime = (config.bossTime + config.gracePeriod)
		maxBurrows = ((config.maxBurrows*(1-config.scavPerPlayerMultiplier))+(config.maxBurrows*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
		maxWaveSize = ((config.maxScavs*(1-config.scavPerPlayerMultiplier))+(config.maxScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
		minWaveSize = ((config.minScavs*(1-config.scavPerPlayerMultiplier))+(config.minScavs*config.scavPerPlayerMultiplier)*SetCount(humanTeams))*config.scavSpawnMultiplier
		config.scavSpawnRate = nextDifficulty.scavSpawnRate
		currentMaxWaveSize = minWaveSize
		SetGameRulesParam("ScavBossAngerGain_Base", 100/config.bossTime)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Game Rules
	--

	SetGameRulesParam("scavBossTime", bossTime)
	SetGameRulesParam("scavBossHealth", bossLifePercent)
	SetGameRulesParam("scavBossAnger", bossAnger)
	SetGameRulesParam("scavTechAnger", techAnger)
	SetGameRulesParam("scavGracePeriod", config.gracePeriod)
	SetGameRulesParam("scavDifficulty", config.difficulty)
	SetGameRulesParam("ScavBossAngerGain_Base", 100/config.bossTime)
	SetGameRulesParam("ScavBossAngerGain_Aggression", 0)
	SetGameRulesParam("ScavBossAngerGain_Eco", 0)


	function scavEvent(type, num, tech)
		SendToUnsynced("ScavEvent", type, num, tech)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--
	-- Spawn Dynamics
	--

	local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
	local ScavStartboxXMin, ScavStartboxZMin, ScavStartboxXMax, ScavStartboxZMax = Spring.GetAllyTeamStartBox(scavAllyTeamID)

	--[[

		-> table containing all squads
		squadsTable = {
			[1] = {
				squadRole = "assault"/"raid"
				squadUnits = {unitID, unitID, unitID}
				squadLife = numberOfWaves
			}
		}

		-> refference table to quickly check which unit is in which squad, and if it has a squad at all.
		unitSquadTable = {
			[unitID] = [squadID]
		}


	]]
	function squadManagerKillerLoop() -- Kills squads that have been alive for too long (most likely stuck somewhere on the map)
		--squadsTable
		for i = 1,#squadsTable do

			squadsTable[i].squadLife = squadsTable[i].squadLife - 1
			if squadsTable[i].squadLife < 3 and squadsTable[i].squadRegroupEnabled then
				squadsTable[i].squadRegroupEnabled = false
			end
			-- Spring.Echo("SquadLifeReport - SquadID: #".. i .. ", LifetimeRemaining: ".. squadsTable[i].squadLife)

			if squadsTable[i].squadLife <= 0 then
				-- Spring.Echo("Life is 0, time to do some killing")
				if SetCount(squadsTable[i].squadUnits) > 0 then
					if squadsTable[i].squadBurrow and (not bossID) then
						Spring.DestroyUnit(squadsTable[i].squadBurrow, true, false)
					end
					-- Spring.Echo("There are some units to kill, so let's kill them")
					-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
					local destroyQueue = {}
					for j, unitID in pairs(squadsTable[i].squadUnits) do
						if unitID then
							destroyQueue[#destroyQueue+1] = unitID
							-- Spring.Echo("Killing old unit. ID: ".. unitID .. ", Name:" .. UnitDefs[Spring.GetUnitDefID(unitID)].name)
						end
					end
					for j = 1,#destroyQueue do
						-- Spring.Echo("Destroying Unit. ID: ".. unitID .. ", Name:" .. UnitDefs[Spring.GetUnitDefID(unitID)].name)
						Spring.DestroyUnit(destroyQueue[j], true, false)
					end
					destroyQueue = nil
					-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
				end
			end
		end
	end


	--or Spring.GetGameSeconds() <= config.gracePeriod
	function squadCommanderGiveOrders(squadID, targetx, targety, targetz)
		local units = squadsTable[squadID].squadUnits
		local role = squadsTable[squadID].squadRole
		if SetCount(units) > 0 and squadsTable[squadID].target and squadsTable[squadID].target.x then
			if squadsTable[squadID].squadRegroupEnabled then
				local xmin = 999999
				local xmax = 0
				local zmin = 999999
				local zmax = 0
				local xsum = 0
				local zsum = 0
				local count = 0
				for i, unitID in pairs(units) do
					if ValidUnitID(unitID) and not GetUnitIsDead(unitID) and not GetUnitNeutral(unitID) then
						local x,y,z = Spring.GetUnitPosition(unitID)
						if x < xmin then xmin = x end
						if z < zmin then zmin = z end
						if x > xmax then xmax = x end
						if z > zmax then zmax = z end
						xsum = xsum + x
						zsum = zsum + z
						count = count + 1
					end
				end
				-- Calculate average unit position
				if count > 0 then
					local xaverage = xsum/count
					local zaverage = zsum/count
					if xmin < xaverage-512 or xmax > xaverage+512 or zmin < zaverage-512 or zmax > zaverage+512 then
						targetx = xaverage
						targetz = zaverage
						targety = Spring.GetGroundHeight(targetx, targetz)
						role = "raid"
						squadsTable[squadID].squadNeedsRegroup = true
					else
						squadsTable[squadID].squadNeedsRegroup = false
					end
				end
			else
				squadsTable[squadID].squadNeedsRegroup = false
			end


			if (squadsTable[squadID].squadNeedsRefresh) or (squadsTable[squadID].squadNeedsRegroup == true and squadsTable[squadID].squadRegrouping == false) or (squadsTable[squadID].squadNeedsRegroup == false and squadsTable[squadID].squadRegrouping == true) then
				for i, unitID in pairs(units) do
					if ValidUnitID(unitID) and not GetUnitIsDead(unitID) and not GetUnitNeutral(unitID) then
						-- Spring.Echo("GiveOrderToUnit #" .. i)
						if not unitCowardCooldown[unitID] then
							if role == "assault" or role == "artillery" then
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "raid" then
								Spring.GiveOrderToUnit(unitID, CMD.MOVE, {targetx+mRandom(-256, 256), targety, targetz+mRandom(-256, 256)} , {})
							elseif role == "aircraft" or role == "kamikaze" then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256)} , {})
							elseif role == "healer" then
								local pos = getRandomEnemyPos()
								Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
								if mRandom() <= 0.33 then
									Spring.GiveOrderToUnit(unitID, CMD.CAPTURE, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 10000} , {"shift"})
								end
								if mRandom() <= 0.33 then
									Spring.GiveOrderToUnit(unitID, CMD.RESURRECT, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 10000} , {"shift"})
								end
								if mRandom() <= 0.33 then
									Spring.GiveOrderToUnit(unitID, CMD.RECLAIM, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 10000} , {"shift"})
								end
								if mRandom() <= 0.33 then
									Spring.GiveOrderToUnit(unitID, CMD.REPAIR, {pos.x+mRandom(-256, 256), pos.y, pos.z+mRandom(-256, 256), 10000} , {"shift"})
								end
								Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {pos.x, pos.y, pos.z} , {"shift"})
							end
						end
					end
				end
				squadsTable[squadID].squadNeedsRefresh = false
				if squadsTable[squadID].squadNeedsRegroup == true then
					squadsTable[squadID].squadRegrouping = true
				elseif squadsTable[squadID].squadNeedsRegroup == false then
					squadsTable[squadID].squadRegrouping = false
				end
			end
		end
	end

	function refreshSquad(squadID) -- Get new target for a squad
		local pos, pickedTarget = getRandomEnemyPos()
		--Spring.Echo(pos.x, pos.y, pos.z, pickedTarget)
		unitTargetPool[squadID] = pickedTarget
		squadsTable[squadID].target = pos
		-- Spring.MarkerAddPoint (squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z, "Squad #" .. squadID .. " target")
		local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
		squadsTable[squadID].squadNeedsRefresh = true
		--squadCommanderGiveOrders(squadID, targetx, targety, targetz)
	end

	function createSquad(newSquad)
		-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
		-- Check if there's any free squadID to recycle
		local squadID = 0
		if #squadsTable == 0 then
			squadID = 1
			-- Spring.Echo("First squad, #".. squadID)
		else
			for i = 1,#squadsTable do
				-- Spring.Echo("Attempt to recycle squad #" .. i .. ". Containing " .. SetCount(squadsTable[i].squadUnits) .. " units.")
				if SetCount(squadsTable[i].squadUnits) == 0 then -- Yes, we found one empty squad to recycle
					squadID = i
					-- Spring.Echo("Recycled squad, #".. squadID)
					break
				elseif i == #squadsTable then -- No, there's no empty squad, we need to create new one
					squadID = i+1
					-- Spring.Echo("Created new squad, #".. squadID)
				end
			end
		end

		if squadID ~= 0 then -- If it's 0 then we f***** up somewhere
			local role = "assault"
			if not newSquad.role then
				if mRandom(0,100) <= 60 then
					role = "raid"
				end
			else
				role = newSquad.role
			end
			if not newSquad.life then
				newSquad.life = 10
			end


			squadsTable[squadID] = {
				squadUnits = newSquad.units,
				squadLife = newSquad.life,
				squadRole = role,
				squadRegroupEnabled = newSquad.regroupenabled,
				squadRegrouping = newSquad.regrouping,
				squadNeedsRegroup = newSquad.needsregroup,
				squadNeedsRefresh = newSquad.needsrefresh,
				squadBurrow = newSquad.burrow,
			}

			-- Spring.Echo("Created Scav Squad, containing " .. #squadsTable[squadID].squadUnits .. " units!")
			-- Spring.Echo("Role: " .. squadsTable[squadID].squadRole)
			-- Spring.Echo("Lifetime: " .. squadsTable[squadID].squadLife)
			for i = 1,SetCount(squadsTable[squadID].squadUnits) do
				local unitID = squadsTable[squadID].squadUnits[i]
				unitSquadTable[unitID] = squadID
				-- Spring.Echo("#".. i ..", ID: ".. unitID .. ", Name:" .. UnitDefs[Spring.GetUnitDefID(unitID)].name)
			end
			refreshSquad(squadID)
		else
			-- Spring.Echo("Failed to create new squad, something went wrong")
		end
		squadCreationQueue = table.copy(squadCreationQueueDefaults)
		return squadID
		-- Spring.Echo("----------------------------------------------------------------------------------------------------------------------------")
	end

	function manageAllSquads() -- Get new target for all squads that need it
		for i = 1,#squadsTable do
			if mRandom(1,100) == 1 then
				local hasTarget = false
				for squad, target in pairs(unitTargetPool) do
					if i == squad then
						hasTarget = true
						break
					end
				end
				if not hasTarget then
					refreshSquad(i)
				end
			end
		end
	end


	function getScavSpawnLoc(burrowID, size)
		local x, y, z
		local bx, by, bz = GetUnitPosition(burrowID)
		if not bx or not bz then
			return false
		end

		local tries = 0
		local s = config.spawnSquare

		repeat
			x = mRandom(bx - s, bx + s)
			z = mRandom(bz - s, bz + s)
			s = s + config.spawnSquareIncrement
			tries = tries + 1
			if x >= MAPSIZEX then
				x = (MAPSIZEX - mRandom(1, 40))
			elseif (x <= 0) then
				x = mRandom(1, 40)
			end
			if z >= MAPSIZEZ then
				z = (MAPSIZEZ - mRandom(1, 40))
			elseif (z <= 0) then
				z = mRandom(1, 40)
			end
		until (TestBuildOrder(size, x, by, z, 1) == 2 and not GetGroundBlocked(x, z)) or (tries > maxTries)

		y = GetGroundHeight(x, z)
		return x, y, z

	end

	function SpawnRandomOffWaveSquad(burrowID, scavType, count)
		if gameOver then
			return
		end
		local squadCounter = 0
		if scavType then
			if not count then count = 1 end
			squad = { count .. " " .. scavType }
			for i, sString in pairs(squad) do
				local nEnd, _ = string.find(sString, " ")
				local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
				local scavName = string.sub(sString, (nEnd + 1))
				for j = 1, unitNumber, 1 do
					if mRandom() <= config.spawnChance or j == 1 then
						squadCounter = squadCounter + 1
						table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
					end
				end
			end
		else
			squadCounter = 0
			local squad
			local specialRandom = mRandom(1,100)
			local burrowX, burrowY, burrowZ = Spring.GetUnitPosition(burrowID)
			local surface = positionCheckLibrary.LandOrSeaCheck(burrowX, burrowY, burrowZ, config.burrowSize)
			for _ = 1,1000 do
				local potentialSquad
				if specialRandom <= waveParameters.waveSpecialPercentage then
					if surface == "land" then
						potentialSquad = squadSpawnOptions.specialLand[mRandom(1, #squadSpawnOptions.specialLand)]
					elseif surface == "sea" then
						potentialSquad = squadSpawnOptions.specialSea[mRandom(1, #squadSpawnOptions.specialSea)]
					end
					if potentialSquad then
						if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
						or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
							squad = potentialSquad
							break
						end
					end
				else
					if surface == "land" then
						potentialSquad = squadSpawnOptions.basicLand[mRandom(1, #squadSpawnOptions.basicLand)]
					elseif surface == "sea" then
						potentialSquad = squadSpawnOptions.basicSea[mRandom(1, #squadSpawnOptions.basicSea)]
					end
					if potentialSquad then
						if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
						or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
							squad = potentialSquad
							break
						end
					end
				end
			end
			if squad then
				for i, sString in pairs(squad.units) do
					local nEnd, _ = string.find(sString, " ")
					local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
					local scavName = string.sub(sString, (nEnd + 1))
					for j = 1, unitNumber, 1 do
						if mRandom() <= config.spawnChance or j == 1 then
							squadCounter = squadCounter + 1
							table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
						end
					end
				end
			end
		end
		return squadCounter
	end

	function SetupBurrow(unitID, x, y, z)
		burrows[unitID] = 0
		SetUnitBlocking(unitID, false, false)
		setScavXP(unitID)
	end

	function SpawnBurrow(number)
		for i = 1, (number or 1) do
			local canSpawnBurrow = false
			local spread = config.burrowSize*1.5
			local spawnPosX, spawnPosY, spawnPosZ

			if config.useScum and config.burrowSpawnType ~= "alwaysbox" and GetGameSeconds() > config.gracePeriod then -- Attempt #1, find position in creep/scum (skipped if creep is disabled or alwaysbox is enabled)
				for _ = 1,100 do
					spawnPosX = mRandom(spread, MAPSIZEX - spread)
					spawnPosZ = mRandom(spread, MAPSIZEZ - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnBurrow then
						canSpawnBurrow = GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
					end
					if canSpawnBurrow then
						break
					end
				end
			end

			if (not canSpawnBurrow) and config.burrowSpawnType ~= "avoid" then -- Attempt #2 Force spawn in Startbox, ignore any kind of player vision
				for _ = 1,100 do
					spawnPosX = mRandom(ScavStartboxXMin + spread, ScavStartboxXMax - spread)
					spawnPosZ = mRandom(ScavStartboxZMin + spread, ScavStartboxZMax - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnBurrow and noScavStartbox then -- this is for case where they have no startbox. We don't want them spawning on top of your stuff.
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
					end
					if canSpawnBurrow then
						break
					end
				end
			end

			if (not canSpawnBurrow) then -- Attempt #3 Find some good position in Spawnbox (not Startbox)
				for _ = 1,100 do
					spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
					spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
					spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
					canSpawnBurrow = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
					end
					if canSpawnBurrow then
						canSpawnBurrow = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
					end
					if canSpawnBurrow then
						canSpawnBurrow = not (positionCheckLibrary.VisibilityCheck(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, false, false)) -- we need to reverse result of this, because we want this to be true when pos is in LoS of Scav team, and the visibility check does the opposite.
					end
					if canSpawnBurrow then
						break
					end
				end
			end

			if canSpawnBurrow and GetGameSeconds() < config.gracePeriod then -- Don't spawn new burrows in existing creep during grace period - Force them to spread as much as they can..... AT LEAST THAT'S HOW IT'S SUPPOSED TO WORK, lol.
				canSpawnBurrow = not GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
			end

			if canSpawnBurrow then
				local burrowID = CreateUnit(config.burrowName, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), scavTeamID)
				if burrowID then
					SetupBurrow(burrowID, spawnPosX, spawnPosY, spawnPosZ)
				end
			else
				timeOfLastSpawn = GetGameSeconds()
				playerAggression = playerAggression + (config.angerBonus*(bossAnger*0.01))
			end
		end
	end

	function updateBossLife()
		if not bossID then
			SetGameRulesParam("scavBossHealth", 0)
			return
		end
		local curH, maxH = GetUnitHealth(bossID)
		local lifeCheck = math.ceil(((curH / maxH) * 100) - 0.5)
		if bossLifePercent ~= lifeCheck then
			-- health changed since last update, update it
			bossLifePercent = lifeCheck
			SetGameRulesParam("scavBossHealth", bossLifePercent)
		end
	end

	function SpawnBoss()
		local bestScore = 0
		local bestBurrowID
		local sx, sy, sz
		for burrowID, _ in pairs(burrows) do
			-- Try to spawn the boss at the 'best' burrow
			local x, y, z = GetUnitPosition(burrowID)
			if x and y and z then
				local score = 0
				score = mRandom(1,1000)
				if score > bestScore then
					bestScore = score
					bestBurrowID = burrowID
					sx = x
					sy = y
					sz = z
				end
			end
		end

		if sx and sy and sz then
			if bestBurrowID then
				Spring.DestroyUnit(bestBurrowID, true, false)
			end
			return CreateUnit(config.bossName, sx, sy, sz, mRandom(0,3), scavTeamID), burrowID
		end

		local x, z, y
		local tries = 0
		local canSpawnBoss = false
		repeat
			x = mRandom(ScavStartboxXMin, ScavStartboxXMax)
			z = mRandom(ScavStartboxZMin, ScavStartboxZMax)
			y = GetGroundHeight(x, z)
			tries = tries + 1
			canSpawnBoss = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, true)

			if canSpawnBoss then
				if tries < maxTries*3 then
					canSpawnBoss = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.burrowSize, scavAllyTeamID, true, true, true)
				else
					canSpawnBoss = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, config.burrowSize, scavAllyTeamID, true, true, false)
				end
			end

			if canSpawnBoss then
				canSpawnBoss = positionCheckLibrary.OccupancyCheck(x, y, z, config.burrowSize*0.25)
			end

			if canSpawnBoss then
				canSpawnBoss = positionCheckLibrary.MapEdgeCheck(x, y, z, 256)
			end

		until (canSpawnBoss == true or tries >= maxTries * 6)

		if canSpawnBoss then
			return CreateUnit(config.bossName, x, y, z, mRandom(0,3), scavTeamID)
		else
			for i = 1,100 do
				x = mRandom(ScavStartboxXMin, ScavStartboxXMax)
				z = mRandom(ScavStartboxZMin, ScavStartboxZMax)
				y = GetGroundHeight(x, z)

				canSpawnBoss = positionCheckLibrary.StartboxCheck(x, y, z, scavAllyTeamID)
				if canSpawnBoss then
					canSpawnBoss = positionCheckLibrary.FlatAreaCheck(x, y, z, 128, 30, true)
				end
				if canSpawnBoss then
					canSpawnBoss = positionCheckLibrary.MapEdgeCheck(x, y, z, 128)
				end
				if canSpawnBoss then
					canSpawnBoss = positionCheckLibrary.OccupancyCheck(x, y, z, 128)
				end
				if canSpawnBoss then
					return CreateUnit(config.bossName, x, y, z, mRandom(0,3), scavTeamID)
				end
			end
		end
		return nil
	end

	function Wave()

		if gameOver then
			return
		end

		squadManagerKillerLoop()

		waveParameters.baseCooldown = waveParameters.baseCooldown - 1
		waveParameters.airWave.cooldown = waveParameters.airWave.cooldown - 1
		waveParameters.basicWave.cooldown = waveParameters.basicWave.cooldown - 1
		waveParameters.specialWave.cooldown = waveParameters.specialWave.cooldown - 1
		waveParameters.smallWave.cooldown = waveParameters.smallWave.cooldown - 1
		waveParameters.largerWave.cooldown = waveParameters.largerWave.cooldown - 1
		waveParameters.hugeWave.cooldown = waveParameters.hugeWave.cooldown - 1
		waveParameters.epicWave.cooldown = waveParameters.epicWave.cooldown - 1

		waveParameters.waveSpecialPercentage = mRandom(5,50)
		waveParameters.waveAirPercentage = mRandom(0,10)

		waveParameters.waveSizeMultiplier = 1
		waveParameters.waveTimeMultiplier = 1

		if waveParameters.baseCooldown <= 0 then
			-- special waves
			if techAnger > config.airStartAnger and waveParameters.airWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.airWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 0
				waveParameters.waveAirPercentage = 50

			elseif waveParameters.specialWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.specialWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 50
				waveParameters.waveAirPercentage = 0

			elseif waveParameters.basicWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.basicWave.cooldown = mRandom(0,10)

				waveParameters.waveSpecialPercentage = 0
				waveParameters.waveAirPercentage = 0

			elseif waveParameters.smallWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.smallWave.cooldown = mRandom(0,10)

				waveParameters.waveSizeMultiplier = 0.5
				waveParameters.waveTimeMultiplier = 0.5

			elseif waveParameters.largerWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.largerWave.cooldown = mRandom(0,25)

				waveParameters.waveSizeMultiplier = 1.5
				waveParameters.waveTimeMultiplier = 1.25

				waveParameters.waveAirPercentage = mRandom(5,40)
				waveParameters.waveSpecialPercentage = mRandom(5,40)

			elseif waveParameters.hugeWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.hugeWave.cooldown = mRandom(0,50)

				waveParameters.waveSizeMultiplier = 3
				waveParameters.waveTimeMultiplier = 1.5

				waveParameters.waveAirPercentage = mRandom(5,25)
				waveParameters.waveSpecialPercentage = mRandom(5,25)

			elseif waveParameters.epicWave.cooldown <= 0 and mRandom() <= config.spawnChance then

				waveParameters.baseCooldown = mRandom(0,2)
				waveParameters.epicWave.cooldown = mRandom(0,100)

				waveParameters.waveSizeMultiplier = 5
				waveParameters.waveTimeMultiplier = 2.5

				waveParameters.waveAirPercentage = mRandom(5,10)
				waveParameters.waveSpecialPercentage = mRandom(5,10)

			end
		end

		local cCount = 0
		local loopCounter = 0
		local squadCounter = 0

		repeat
			loopCounter = loopCounter + 1
			for burrowID in pairs(burrows) do
				if mRandom() <= config.spawnChance then
					squadCounter = 0
					local airRandom = mRandom(1,100)
					local squad
					local burrowX, burrowY, burrowZ = Spring.GetUnitPosition(burrowID)
					local surface = positionCheckLibrary.LandOrSeaCheck(burrowX, burrowY, burrowZ, config.burrowSize)
					if techAnger > config.airStartAnger and airRandom <= waveParameters.waveAirPercentage then
						for _ = 1,1000 do
							local potentialSquad
							if surface == "land" then
								potentialSquad = squadSpawnOptions.airLand[mRandom(1, #squadSpawnOptions.airLand)]
							elseif surface == "sea" then
								potentialSquad = squadSpawnOptions.airSea[mRandom(1, #squadSpawnOptions.airSea)]
							end
							if potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger then
								squad = potentialSquad
								break
							end
						end
					else
						local specialRandom = mRandom(1,100)
						for _ = 1,1000 do
							local potentialSquad
							if specialRandom <= waveParameters.waveSpecialPercentage then
								if surface == "land" then
									potentialSquad = squadSpawnOptions.specialLand[mRandom(1, #squadSpawnOptions.specialLand)]
								elseif surface == "sea" then
									potentialSquad = squadSpawnOptions.specialSea[mRandom(1, #squadSpawnOptions.specialSea)]
								end
								if potentialSquad then
									if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
									or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
										squad = potentialSquad
										break
									end
								end
							else
								if surface == "land" then
									potentialSquad = squadSpawnOptions.basicLand[mRandom(1, #squadSpawnOptions.basicLand)]
								elseif surface == "sea" then
									potentialSquad = squadSpawnOptions.basicSea[mRandom(1, #squadSpawnOptions.basicSea)]
								end
								if potentialSquad then
									if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger)
									or (specialRandom <= 1 and math.max(10, potentialSquad.minAnger-30) <= techAnger and math.max(40, potentialSquad.maxAnger-30) >= techAnger) then -- Super Squad
										squad = potentialSquad
										break
									end
								end
							end
						end
					end
					if squad then
						for i, sString in pairs(squad.units) do
							local nEnd, _ = string.find(sString, " ")
							local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
							local scavName = string.sub(sString, (nEnd + 1))
							for j = 1, unitNumber, 1 do
								if mRandom() <= config.spawnChance or j == 1 then
									squadCounter = squadCounter + 1
									table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
									cCount = cCount + 1
								end
							end
						end
					end
					if loopCounter <= 1 and mRandom() <= config.spawnChance then
						squad = nil
						squadCounter = 0
						for _ = 1,1000 do
							local potentialSquad
							if surface == "land" then
								potentialSquad = squadSpawnOptions.healerLand[mRandom(1, #squadSpawnOptions.healerLand)]
							elseif surface == "sea" then
								potentialSquad = squadSpawnOptions.healerSea[mRandom(1, #squadSpawnOptions.healerSea)]
							end
							if potentialSquad then
								if (potentialSquad.minAnger <= techAnger and potentialSquad.maxAnger >= techAnger) then -- Super Squad
									squad = potentialSquad
									break
								end
							end
						end
						if squad then
							for i, sString in pairs(squad.units) do
								local nEnd, _ = string.find(sString, " ")
								local unitNumber = mRandom(1, string.sub(sString, 1, (nEnd - 1)))
								local scavName = string.sub(sString, (nEnd + 1))
								for j = 1, unitNumber, 1 do
									if mRandom() <= config.spawnChance or j == 1 then
										squadCounter = squadCounter + 1
										table.insert(spawnQueue, { burrow = burrowID, unitName = scavName, team = scavTeamID, squadID = squadCounter })
										cCount = cCount + 1
									end
								end
							end
						end
					end
				end
			end
		until (cCount > currentMaxWaveSize*waveParameters.waveSizeMultiplier or loopCounter >= 200*config.scavSpawnMultiplier)

		if config.useWaveMsg then
			scavEvent("wave", cCount)
		end

		return cCount
	end

	function spawnCreepStructure(unitDefName, unitSettings, spread)
		local canSpawnStructure = false
		spread = spread or 128
		local spawnPosX, spawnPosY, spawnPosZ

		if config.useScum then -- If creep/scum is enabled, only allow to spawn turrets on the creep
			for _ = 1,100 do
				spawnPosX = mRandom(spread, MAPSIZEX - spread)
				spawnPosZ = mRandom(spread, MAPSIZEZ - spread)
				spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
				canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				end
				if canSpawnStructure then
					canSpawnStructure = GG.IsPosInRaptorScum(spawnPosX, spawnPosY, spawnPosZ)
				end
				if canSpawnStructure then
					break
				end
			end
		else -- Otherwise use Scav LoS as creep with Players sensors being the safety zone
			for _ = 1,100 do
				spawnPosX = mRandom(lsx1 + spread, lsx2 - spread)
				spawnPosZ = mRandom(lsz1 + spread, lsz2 - spread)
				spawnPosY = Spring.GetGroundHeight(spawnPosX, spawnPosZ)
				canSpawnStructure = positionCheckLibrary.FlatAreaCheck(spawnPosX, spawnPosY, spawnPosZ, spread, 30, true)
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.OccupancyCheck(spawnPosX, spawnPosY, spawnPosZ, spread)
				end
				if canSpawnStructure then
					canSpawnStructure = positionCheckLibrary.VisibilityCheckEnemy(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, true, true)
				end
				if canSpawnStructure then
					canSpawnStructure = not (positionCheckLibrary.VisibilityCheck(spawnPosX, spawnPosY, spawnPosZ, spread, scavAllyTeamID, true, false, false)) -- we need to reverse result of this, because we want this to be true when pos is in LoS of Scav team, and the visibility check does the opposite.
				end
				if canSpawnStructure then
					break
				end
			end
		end
		if (unitSettings.surfaceType == "land" and spawnPosY <= 0) or (unitSettings.surfaceType == "sea" and spawnPosY > 0) then
			canSpawnStructure = false
		end

		if canSpawnStructure then
			local structureUnitID = Spring.CreateUnit(unitDefName, spawnPosX, spawnPosY, spawnPosZ, mRandom(0,3), scavTeamID)
			if structureUnitID then
				SetUnitBlocking(structureUnitID, false, false)
				return structureUnitID, spawnPosX, spawnPosY, spawnPosZ
			end
		end
	end

	function spawnCreepStructuresWave()
		for uName, uSettings in pairs(config.scavTurrets) do
			--Spring.Echo(uName)
			--Spring.Debug.TableEcho(uSettings)
			if not uSettings.maxBossAnger then uSettings.maxBossAnger = uSettings.minBossAnger + 100 end
			if uSettings.minBossAnger <= techAnger and uSettings.maxBossAnger >= techAnger then
				local numOfTurrets = math.ceil((uSettings.spawnedPerWave*(1-config.scavPerPlayerMultiplier))+(uSettings.spawnedPerWave*config.scavPerPlayerMultiplier)*SetCount(humanTeams))
				local maxExisting = math.ceil((uSettings.maxExisting*(1-config.scavPerPlayerMultiplier))+(uSettings.maxExisting*config.scavPerPlayerMultiplier)*SetCount(humanTeams))
				local maxAllowedToSpawn
				if techAnger <= 100 then  -- i don't know how this works but it does. scales maximum amount of turrets allowed to spawn with techAnger.
					maxAllowedToSpawn = math.ceil(maxExisting*((techAnger-uSettings.minBossAnger)/(math.min(100-uSettings.minBossAnger, uSettings.maxBossAnger-uSettings.minBossAnger))))
				else
					maxAllowedToSpawn = math.ceil(maxExisting*(techAnger*0.01))
				end
				--Spring.Echo(uName,"MaxExisting",maxExisting,"MaxAllowed",maxAllowedToSpawn)
				for i = 1, numOfTurrets do
					if mRandom() < config.spawnChance*math.min((GetGameSeconds()/config.gracePeriod),1) and (Spring.GetTeamUnitDefCount(scavTeamID, UnitDefNames[uName].id) <= maxAllowedToSpawn) then
						local attempts = 0
						local footprintX = UnitDefNames[uName].xsize -- why the fuck is this footprint *2??????
						local footprintZ = UnitDefNames[uName].zsize -- why the fuck is this footprint *2??????
						local footprintAvg = 128
						if footprintX and footprintZ then
							footprintAvg = ((footprintX+footprintZ))*4
						end
						repeat
							attempts = attempts + 1
							local turretUnitID, spawnPosX, spawnPosY, spawnPosZ = spawnCreepStructure(uName, uSettings, footprintAvg+32)
							if turretUnitID then
								setScavXP(turretUnitID)
								Spring.GiveOrderToUnit(turretUnitID, CMD.PATROL, {spawnPosX + mRandom(-128,128), spawnPosY, spawnPosZ + mRandom(-128,128)}, {"meta"})
							end
						until turretUnitID or attempts > 100
					end
				end
			end
		end
	end

	function SpawnMinions(unitID, unitDefID)
		local unitName = UnitDefs[unitDefID].name
		if config.scavMinions[unitName] then
			local minion = config.scavMinions[unitName][mRandom(1,#config.scavMinions[unitName])]
			SpawnRandomOffWaveSquad(unitID, minion, 4)
		end
	end

	--------------------------------------------------------------------------------
	-- Call-ins
	--------------------------------------------------------------------------------
	local createUnitQueue = {}
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if unitTeam == scavTeamID then
			local x,y,z = Spring.GetUnitPosition(unitID)
			if (not UnitDefs[unitDefID].isscavenger) and UnitDefs[unitDefID] and UnitDefs[unitDefID].name and UnitDefNames[UnitDefs[unitDefID].name .. "_scav"] then
				Spring.DestroyUnit(unitID, true, true)
				createUnitQueue[#createUnitQueue+1] = {UnitDefs[unitDefID].name .. "_scav", x, y, z, 0, scavTeamID}
			end
			Spring.GiveOrderToUnit(unitID,CMD.FIRE_STATE,{config.defaultScavFirestate},0)
			Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
			if UnitDefs[unitDefID].canCloak then
				Spring.GiveOrderToUnit(unitID,37382,{1},0)
			end
			return
		end
		if squadPotentialTarget[unitID] or squadPotentialHighValueTarget[unitID] then
			squadPotentialTarget[unitID] = nil
			squadPotentialHighValueTarget[unitID] = nil
		end
		if not UnitDefs[unitDefID].canMove then
			squadPotentialTarget[unitID] = true
			if config.highValueTargets[unitDefID] then
				squadPotentialHighValueTarget[unitID] = true
			end
		end
		if config.ecoBuildingsPenalty[unitDefID] then
			playerAggressionEcoValue = playerAggressionEcoValue + (config.ecoBuildingsPenalty[unitDefID]/(config.bossTime/3600)) -- scale to 60minutes = 3600seconds boss time
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)

		if attackerTeam == scavTeamID then
			damage = damage * config.damageMod
		end

		if unitID == bossID then -- Boss Resistance
			if attackerDefID then
				if weaponID == -1 and damage > 1 then
					damage = 1
				end
				if not bossResistance[attackerDefID] then
					bossResistance[attackerDefID] = {}
					bossResistance[attackerDefID].damage = (damage * 4 * config.bossResistanceMult)
					bossResistance[attackerDefID].notify = 0
				end
				local resistPercent = math.min((bossResistance[attackerDefID].damage) / bossMaxHP, 0.95)
				if resistPercent > 0.5 then
					if bossResistance[attackerDefID].notify == 0 then
						scavEvent("bossResistance", attackerDefID)
						bossResistance[attackerDefID].notify = 1
						spawnCreepStructuresWave()
					end
					damage = damage - (damage * resistPercent)

				end
				bossResistance[attackerDefID].damage = bossResistance[attackerDefID].damage + (damage * 4 * config.bossResistanceMult)
			else
				damage = 1
			end
			return damage
		end
		return damage, 1
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
		if not scavteamhasplayers then
			if config.scavBehaviours.SKIRMISH[attackerDefID] and (unitTeam ~= scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.SKIRMISH[attackerDefID].chance) and unitTeam ~= attackerTeam then
				local ux, uy, uz = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				if x and ux then
					local angle = math.atan2(ux - x, uz - z)
					local distance = mRandom(math.ceil(config.scavBehaviours.SKIRMISH[attackerDefID].distance*0.75), math.floor(config.scavBehaviours.SKIRMISH[attackerDefID].distance*1.25))
					if config.scavBehaviours.SKIRMISH[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						Spring.SetUnitPosition(attackerID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
						Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", x - (math.sin(angle) * distance), y ,z - (math.cos(angle) * distance), 0,0,0)
						unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.scavBehaviours.SKIRMISH[attackerDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
					end
					unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
				end
			elseif config.scavBehaviours.COWARD[unitDefID] and (unitTeam == scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.COWARD[unitDefID].chance) and unitTeam ~= attackerTeam then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH and curH < (maxH * 0.8) then
					local ax, ay, az = GetUnitPosition(attackerID)
					local x, y, z = GetUnitPosition(unitID)
					if x and ax then
						local angle = math.atan2(ax - x, az - z)
						local distance = mRandom(math.ceil(config.scavBehaviours.COWARD[unitDefID].distance*0.75), math.floor(config.scavBehaviours.COWARD[unitDefID].distance*1.25))
						if config.scavBehaviours.COWARD[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64, 30, false) and positionCheckLibrary.MapEdgeCheck(x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance), 64) then
							Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
							Spring.SetUnitPosition(unitID, x - (math.sin(angle) * distance), z - (math.cos(angle) * distance))
							Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
							Spring.SpawnCEG("scav-spawnexplo", x - (math.sin(angle) * distance), y ,z - (math.cos(angle) * distance), 0,0,0)
							unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.scavBehaviours.COWARD[unitDefID].teleportcooldown*30
						else
							Spring.GiveOrderToUnit(unitID, CMD.MOVE, { x - (math.sin(angle) * distance), y, z - (math.cos(angle) * distance)}, {})
						end
						unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
					end
				end
			elseif config.scavBehaviours.BERSERK[unitDefID] and (unitTeam == scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.BERSERK[unitDefID].chance) and unitTeam ~= attackerTeam then
				local ax, ay, az = GetUnitPosition(attackerID)
				local x, y, z = GetUnitPosition(unitID)
				local separation = Spring.GetUnitSeparation(unitID, attackerID)
				if ax and separation < (config.scavBehaviours.BERSERK[unitDefID].distance or 10000) then
					if config.scavBehaviours.BERSERK[unitDefID].teleport and (unitTeleportCooldown[unitID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						ax = ax + mRandom(-256,256)
						az = az + mRandom(-256,256)
						Spring.SetUnitPosition(unitID, ax, ay, az)
						Spring.GiveOrderToUnit(unitID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", ax, ay, az, 0,0,0)
						unitTeleportCooldown[unitID] = Spring.GetGameFrame() + config.scavBehaviours.BERSERK[unitDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(unitID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
					end
					unitCowardCooldown[unitID] = Spring.GetGameFrame() + 900
				end
			elseif config.scavBehaviours.BERSERK[attackerDefID] and (unitTeam ~= scavTeamID) and attackerID and (mRandom() < config.scavBehaviours.BERSERK[attackerDefID].chance) and unitTeam ~= attackerTeam then
				local ax, ay, az = GetUnitPosition(unitID)
				local x, y, z = GetUnitPosition(attackerID)
				local separation = Spring.GetUnitSeparation(unitID, attackerID)
				if ax and separation < (config.scavBehaviours.BERSERK[attackerDefID].distance or 10000) then
					if config.scavBehaviours.BERSERK[attackerDefID].teleport and (unitTeleportCooldown[attackerID] or 1) < Spring.GetGameFrame() and positionCheckLibrary.FlatAreaCheck(ax, ay, az, 128, 30, false) and positionCheckLibrary.MapEdgeCheck(ax, ay, az, 128) then
						Spring.SpawnCEG("scav-spawnexplo", x, y, z, 0,0,0)
						ax = ax + mRandom(-256,256)
						az = az + mRandom(-256,256)
						Spring.SetUnitPosition(attackerID, ax, ay, az)
						Spring.GiveOrderToUnit(attackerID, CMD.STOP, 0, 0)
						Spring.SpawnCEG("scav-spawnexplo", ax, ay, az, 0,0,0)
						unitTeleportCooldown[attackerID] = Spring.GetGameFrame() + config.scavBehaviours.BERSERK[attackerDefID].teleportcooldown*30
					else
						Spring.GiveOrderToUnit(attackerID, CMD.MOVE, { ax+mRandom(-64,64), ay, az+mRandom(-64,64)}, {})
					end
					unitCowardCooldown[attackerID] = Spring.GetGameFrame() + 900
				end
			end
			if bossID and unitID == bossID then
				local curH, maxH = GetUnitHealth(unitID)
				if curH and maxH then
					curH = math.max(curH, maxH*0.05)
					local spawnChance = math.max(0, math.ceil(curH/maxH*10000))
					if mRandom(0,spawnChance) == 1 then
						SpawnMinions(bossID, Spring.GetUnitDefID(bossID))
						SpawnMinions(bossID, Spring.GetUnitDefID(bossID))
					end
				end
			end
			if unitTeam == scavTeamID or attackerTeam == scavTeamID then
				if (unitID and unitSquadTable[unitID] and squadsTable[unitSquadTable[unitID]] and squadsTable[unitSquadTable[unitID]].squadLife and squadsTable[unitSquadTable[unitID]].squadLife < 10) then
					squadsTable[unitSquadTable[unitID]].squadLife = 10
				end
				if (attackerID and unitSquadTable[attackerID] and squadsTable[unitSquadTable[attackerID]] and squadsTable[unitSquadTable[attackerID]].squadLife and squadsTable[unitSquadTable[attackerID]].squadLife < 10) then
					squadsTable[unitSquadTable[attackerID]].squadLife = 10
				end
			end
		end
	end

	function gadget:GameStart()
		if config.burrowSpawnType == "initialbox" or config.burrowSpawnType == "alwaysbox" or config.burrowSpawnType == "initialbox_post" then
			local _, _, _, _, _, luaAllyID = Spring.GetTeamInfo(scavTeamID, false)
			if luaAllyID then
				lsx1, lsz1, lsx2, lsz2 = Spring.GetAllyTeamStartBox(luaAllyID)
				if not lsx1 or not lsz1 or not lsx2 or not lsz2 then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Scav start box available, Burrow Placement set to 'Avoid Players'")
					noScavStartbox = true
				elseif lsx1 == 0 and lsz1 == 0 and lsx2 == Game.mapSizeX and lsz2 == Game.mapSizeX then
					config.burrowSpawnType = "avoid"
					Spring.Log(gadget:GetInfo().name, LOG.INFO, "No Scav start box available, Burrow Placement set to 'Avoid Players'")
					noScavStartbox = true
				end
			end
		end
		if not lsx1 then lsx1 = 0 end
		if not lsz1 then lsz1 = 0 end
		if not lsx2 then lsx2 = Game.mapSizeX end
		if not lsz2 then lsz2 = Game.mapSizeZ end
	end

	function SpawnScavs()
		local i, defs = next(spawnQueue)
		if not i or not defs then
			if #squadCreationQueue.units > 0 then
				if mRandom(1,5) == 1 then
					squadCreationQueue.regroupenabled = false
				end
				local squadID = createSquad(squadCreationQueue)
				squadCreationQueue.units = {}
				refreshSquad(squadID)
				-- Spring.Echo("[RAPTOR] Number of active Squads: ".. #squadsTable)
				-- Spring.Echo("[RAPTOR] Wave spawn complete.")
				-- Spring.Echo(" ")
			end
			return
		end

		local unitID
		if UnitDefNames[defs.unitName] then
			local x, y, z = getScavSpawnLoc(defs.burrow, UnitDefNames[defs.unitName].id)
			if not x or not y or not z then
				spawnQueue[i] = nil
				return
			end
			unitID = CreateUnit(defs.unitName, x, y, z, mRandom(0,3), defs.team)
		else
			Spring.Echo("Error: Cannot spawn unit " .. defs.unitName .. ", invalid name.")
			spawnQueue[i] = nil
			return
		end
		
		if unitID then
			if (not defs.squadID) or (defs.squadID and defs.squadID == 1) then
				if #squadCreationQueue.units > 0 then
					if mRandom(1,5) == 1 then
						squadCreationQueue.regroupenabled = false
					end
					createSquad(squadCreationQueue)
				end
			end
			if defs.burrow and (not squadCreationQueue.burrow) then
				squadCreationQueue.burrow = defs.burrow
			end
			squadCreationQueue.units[#squadCreationQueue.units+1] = unitID
			if config.scavBehaviours.HEALER[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "healer"
				squadCreationQueue.regroupenabled = false
				if squadCreationQueue.life < 20 then
					squadCreationQueue.life = 20
				end
			end
			if config.scavBehaviours.ARTILLERY[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "artillery"
				squadCreationQueue.regroupenabled = false
			end
			if config.scavBehaviours.KAMIKAZE[UnitDefNames[defs.unitName].id] then
				squadCreationQueue.role = "kamikaze"
				squadCreationQueue.regroupenabled = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end
			if UnitDefNames[defs.unitName].canFly then
				squadCreationQueue.role = "aircraft"
				squadCreationQueue.regroupenabled = false
				if squadCreationQueue.life < 100 then
					squadCreationQueue.life = 100
				end
			end

			GiveOrderToUnit(unitID, CMD.IDLEMODE, { 0 }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })
			GiveOrderToUnit(unitID, CMD.MOVE, { x + mRandom(-128, 128), y, z + mRandom(-128, 128) }, { "shift" })

			setScavXP(unitID)
		end
		spawnQueue[i] = nil
	end

	function updateSpawnBoss()
		if not bossID and not gameOver then
			-- spawn boss if not exists
			bossID = SpawnBoss()
			if bossID then
				bossSquad = table.copy(squadCreationQueueDefaults)
				bossSquad.life = 999999
				bossSquad.role = "raid"
				bossSquad.units = {bossID}
				createSquad(bossSquad)
				spawnQueue = {}
				scavEvent("boss") -- notify unsynced about boss spawn
				_, bossMaxHP = GetUnitHealth(bossID)
				SetUnitExperience(bossID, 0)
				timeOfLastWave = t
				burrows[bossID] = 0
				SetUnitBlocking(bossID, false, false)
				for burrowID, _ in pairs(burrows) do
					if mRandom() < config.spawnChance then
						SpawnRandomOffWaveSquad(burrowID)
					else
						SpawnRandomOffWaveSquad(burrowID)
					end
				end
				Spring.SetGameRulesParam("BossFightStarted", 1)
				Spring.SetUnitAlwaysVisible(bossID, true)
			end
		end
	end

	function updateScavSpawnBox()
		if config.burrowSpawnType == "initialbox_post" then
			lsx1 = math.max(ScavStartboxXMin - ((MAPSIZEX*0.01) * techAnger), 0)
			lsz1 = math.max(ScavStartboxZMin - ((MAPSIZEZ*0.01) * techAnger), 0)
			lsx2 = math.min(ScavStartboxXMax + ((MAPSIZEX*0.01) * techAnger), MAPSIZEX)
			lsz2 = math.min(ScavStartboxZMax + ((MAPSIZEZ*0.01) * techAnger), MAPSIZEZ)
		end
	end

	local announcedFirstWave = false
	function gadget:GameFrame(n)

		if #createUnitQueue > 0 then
			for i = 1,#createUnitQueue do
				local unitID = Spring.CreateUnit(createUnitQueue[i][1],createUnitQueue[i][2],createUnitQueue[i][3],createUnitQueue[i][4],createUnitQueue[i][5],createUnitQueue[i][6])
				if unitID then
					Spring.SetUnitHealth(unitID, 10)
				end
			end
			createUnitQueue = {}
		end



		if announcedFirstWave == false and GetGameSeconds() > config.gracePeriod then
			scavEvent("firstWave")
			announcedFirstWave = true
		end
		-- remove initial commander (no longer required)
		if n == 1 then
			PutScavAlliesInScavTeam(n)
			local units = GetTeamUnits(scavTeamID)
			for _, unitID in ipairs(units) do
				Spring.DestroyUnit(unitID, false, true)
			end
		end

		if gameOver then
			return
		end

		local scavTeamUnitCount = GetTeamUnitCount(scavTeamID) or 0
		if scavTeamUnitCount < scavUnitCap then
			SpawnScavs()
		end

		for unitID, defs in pairs(deathQueue) do
			if ValidUnitID(unitID) and not GetUnitIsDead(unitID) then
				DestroyUnit(unitID, defs.selfd or false, defs.reclaimed or false)
			end
		end

		if n%30 == 16 then
			t = GetGameSeconds()
			playerAggression = playerAggression*0.995
			playerAggressionLevel = math.floor(playerAggression)
			SetGameRulesParam("scavPlayerAggressionLevel", playerAggressionLevel)
			if not bossID then
				currentMaxWaveSize = (minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))
			else
				currentMaxWaveSize = math.ceil((minWaveSize + math.ceil((techAnger*0.01)*(maxWaveSize - minWaveSize)))*(config.bossFightWaveSizeScale*0.01))
			end
			if pastFirstBoss then
				techAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / ((bossTime/Spring.GetModOptions().scav_bosstimemult) - config.gracePeriod) * 100), 999), 0)
			else
				techAnger = math.max(math.ceil(math.min((t - (config.gracePeriod/Spring.GetModOptions().scav_graceperiodmult)) / ((bossTime/Spring.GetModOptions().scav_bosstimemult) - (config.gracePeriod/Spring.GetModOptions().scav_graceperiodmult)) * 100), 999), 0)
			end
			if t < config.gracePeriod then
				bossAnger = 0
				minBurrows = SetCount(humanTeams)*(t/config.gracePeriod)
			else
				if not bossID then
					bossAnger = math.max(math.ceil(math.min((t - config.gracePeriod) / (bossTime - config.gracePeriod) * 100) + bossAngerAggressionLevel, 100), 0)
					minBurrows = SetCount(humanTeams)
				else
					bossAnger = 100
					minBurrows = SetCount(humanTeams)
				end
				bossAngerAggressionLevel = bossAngerAggressionLevel + ((playerAggression*0.01)/(config.bossTime/3600)) + playerAggressionEcoValue
				SetGameRulesParam("ScavBossAngerGain_Aggression", (playerAggression*0.01)/(config.bossTime/3600))
				SetGameRulesParam("ScavBossAngerGain_Eco", playerAggressionEcoValue)
			end
			SetGameRulesParam("scavBossAnger", bossAnger)
			SetGameRulesParam("scavTechAnger", techAnger)

			if bossAnger >= 100 then
				-- check if the boss should be alive
				updateSpawnBoss()
				updateBossLife()
			end

			local burrowCount = SetCount(burrows)
			if burrowCount < minBurrows then
				SpawnBurrow()
				timeOfLastSpawn = t
				if firstSpawn then
					timeOfLastWave = (config.gracePeriod + 10) - config.scavSpawnRate
					firstSpawn = false
				end
			end

			if (t > config.burrowSpawnRate and burrowCount < minBurrows and (t > timeOfLastSpawn + 10 or burrowCount == 0)) or (config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount < maxBurrows) then
				if (config.burrowSpawnType == "initialbox") and (t > config.gracePeriod) then
					config.burrowSpawnType = "initialbox_post"
				end
				if firstSpawn then
					SpawnBurrow()
					timeOfLastWave = (config.gracePeriod + 10) - config.scavSpawnRate
					timeOfLastSpawn = t
					firstSpawn = false
				else
					SpawnBurrow()
					timeOfLastSpawn = t
				end
				scavEvent("burrowSpawn")
				SetGameRulesParam("scav_hiveCount", SetCount(burrows))
			elseif config.burrowSpawnRate < t - timeOfLastSpawn and burrowCount >= maxBurrows then
				timeOfLastSpawn = t
			end

			if t > config.gracePeriod+5 then
				if burrowCount > 0
				and SetCount(spawnQueue) == 0
				and ((config.scavSpawnRate*waveParameters.waveTimeMultiplier) < (t - timeOfLastWave)) then
					Wave()
					timeOfLastWave = t
				end
			end

			updateScavSpawnBox()
		end
		if n%((math.ceil(config.turretSpawnRate))*30) == 0 and n > 900 and scavTeamUnitCount < scavUnitCap then
			spawnCreepStructuresWave()
		end
		local squadID = ((n % (#squadsTable*2))+1)/2 --*2 and /2 for lowering the rate of commands
		if not scavteamhasplayers then
			if squadID and squadsTable[squadID] and squadsTable[squadID].squadRegroupEnabled then
				local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
				if targetx then
					squadCommanderGiveOrders(squadID, targetx, targety, targetz)
				else
					refreshSquad(squadID)
				end
			end
		end
		if n%7 == 3 and not scavteamhasplayers then
			local scavs = GetTeamUnits(scavTeamID)
			for i = 1,#scavs do
				if mRandom(1,math.ceil((33*math.max(1, Spring.GetTeamUnitDefCount(scavTeamID, Spring.GetUnitDefID(scavs[i])))))) == 1 and mRandom() < config.spawnChance then
					SpawnMinions(scavs[i], Spring.GetUnitDefID(scavs[i]))
				end
				if mRandom(1,60) == 1 then
					if unitCowardCooldown[scavs[i]] and (Spring.GetGameFrame() > unitCowardCooldown[scavs[i]]) then
						unitCowardCooldown[scavs[i]] = nil
						Spring.GiveOrderToUnit(scavs[i], CMD.STOP, 0, 0)
					end
					if Spring.GetCommandQueue(scavs[i], 0) <= 0 then
						if unitCowardCooldown[scavs[i]] then
							unitCowardCooldown[scavs[i]] = nil
						end
						local squadID = unitSquadTable[scavs[i]]
						if squadID then
							local targetx, targety, targetz = squadsTable[squadID].target.x, squadsTable[squadID].target.y, squadsTable[squadID].target.z
							if targetx then
								squadsTable[squadID].squadNeedsRefresh = true
								squadCommanderGiveOrders(squadID, targetx, targety, targetz)
							else
								refreshSquad(squadID)
							end
						else
							local pos = getRandomEnemyPos()
							Spring.GiveOrderToUnit(scavs[i], CMD.FIGHT, {pos.x, pos.y, pos.z}, {})
						end
					end
				end
			end
		end
		manageAllSquads()
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)

		if unitTeam == scavTeamID then
			if unitDefID == config.burrowDef then
				if mRandom() <= config.spawnChance then
					spawnCreepStructuresWave()
				end
			end
		end

		if unitSquadTable[unitID] then
			for index, id in ipairs(squadsTable[unitSquadTable[unitID]].squadUnits) do
				if id == unitID then
					table.remove(squadsTable[unitSquadTable[unitID]].squadUnits, index)
				end
			end
			unitSquadTable[unitID] = nil
		end

		squadPotentialTarget[unitID] = nil
		squadPotentialHighValueTarget[unitID] = nil
		for squad in ipairs(unitTargetPool) do
			if unitTargetPool[squad] == unitID then
				refreshSquad(squad)
			end
		end

		if unitTeam == scavTeamID then
			local kills = GetGameRulesParam("scav" .. "Kills") or 0
			SetGameRulesParam("scav" .. "Kills", kills + 1)
		end

		if unitID == bossID then
			-- boss destroyed
			bossID = nil
			bossResistance = {}
			Spring.SetGameRulesParam("BossFightStarted", 0)

			if Spring.GetModOptions().scav_endless then
				updateDifficultyForSurvival()
			else
				gameOver = GetGameFrame() + 200
				spawnQueue = {}
				gameIsOver = true

				if not killedScavsAllyTeam then
					killedScavsAllyTeam = true

					-- kill scav team
					Spring.KillTeam(scavTeamID)

					-- check if scavengers are in the same allyteam and alive
					local scavengersFoundAlive = false
					for _, teamID in ipairs(Spring.GetTeamList(scavAllyTeamID)) do
						local luaAI = Spring.GetTeamLuaAI(teamID)
						if luaAI and (luaAI:find("Scavengers") or luaAI:find("ScavReduxAI")) and not select(3, Spring.GetTeamInfo(teamID, false)) then
							scavengersFoundAlive = true
						end
					end

					-- kill whole allyteam
					if not scavengersFoundAlive then
						for _, teamID in ipairs(Spring.GetTeamList(scavAllyTeamID)) do
							if not select(3, Spring.GetTeamInfo(teamID, false)) then
								Spring.KillTeam(teamID)
							end
						end
					end
				end
			end
		end

		if unitDefID == config.burrowDef and not gameOver then
			local kills = GetGameRulesParam(config.burrowName .. "Kills") or 0
			SetGameRulesParam(config.burrowName .. "Kills", kills + 1)

			burrows[unitID] = nil
			if attackerID and Spring.GetUnitTeam(attackerID) ~= scavTeamID then
				playerAggression = playerAggression + (config.angerBonus/config.scavSpawnMultiplier)
				config.maxXP = config.maxXP*1.01
			end

			for i, defs in pairs(spawnQueue) do
				if defs.burrow == unitID then
					spawnQueue[i] = nil
				end
			end

			for i = 1,#squadsTable do
				if squadsTable[i].squadBurrow == unitID then
					squadsTable[i].squadBurrow = nil
					break
				end
			end

			SetGameRulesParam("scav_hiveCount", SetCount(burrows))
		-- elseif unitTeam == scavTeamID and UnitDefs[unitDefID].isBuilding and (attackerID and Spring.GetUnitTeam(attackerID) ~= scavTeamID) then
		-- 	playerAggression = playerAggression + ((config.angerBonus/config.scavSpawnMultiplier)*0.01)
		end
		if unitTeleportCooldown[unitID] then
			unitTeleportCooldown[unitID] = nil
		end
		if unitTeam ~= scavTeamID and config.ecoBuildingsPenalty[unitDefID] then
			playerAggressionEcoValue = playerAggressionEcoValue - (config.ecoBuildingsPenalty[unitDefID]/(config.bossTime/3600)) -- scale to 60minutes = 3600seconds boss time
		end
	end

	function gadget:TeamDied(teamID)
		humanTeams[teamID] = nil
		--computerTeams[teamID] = nil
	end

	function gadget:FeatureCreated(featureID, featureAllyTeamID)

	end

	function gadget:FeatureDestroyed(featureID, featureAllyTeamID)

	end

	function gadget:GameOver()
		-- don't end game in survival mode
		if config.difficulty ~= config.difficulties.survival then
			gameOver = GetGameFrame()
		end
	end

	-- function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- 	if teamID == scavTeamID and cmdID == CMD.SELFD then
	-- 		return false
	-- 	else
	-- 		return true
	-- 	end
	-- end

else	-- UNSYNCED

	local hasScavEvent = false
	local mRandom = math.random

	function HasScavEvent(ce)
		hasScavEvent = (ce ~= "0")
	end

	function WrapToLuaUI(_, type, num, tech)
		if hasScavEvent then
			local scavEventArgs = {}
			if type ~= nil then
				scavEventArgs["type"] = type
			end
			if num ~= nil then
				scavEventArgs["number"] = num
			end
			if tech ~= nil then
				scavEventArgs["tech"] = tech
			end
			Script.LuaUI.ScavEvent(scavEventArgs)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction('ScavEvent', WrapToLuaUI)
		gadgetHandler:AddChatAction("HasScavEvent", HasScavEvent, "toggles hasScavEvent setting")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("HasScavEvent")
	end

end

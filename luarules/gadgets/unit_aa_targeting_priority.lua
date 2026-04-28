local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'AA Targeting Priority',
		desc = '',
		author = 'Doo', --additions wilkubyk
		version = 'v1.0',
		date = 'May 2018',
		license = 'GNU GPL, v2 or later',
		layer = -1, --must run before game_initial_spawn, because game_initial_spawn must control the return of GameSteup
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then
	local spGetUnitDefID = Spring.GetUnitDefID
	local stringFind = string.find
	local math_abs = math.abs
	local gameSpeed = Game.gameSpeed

	local PRIORITY_BOMBERS = 1
	local PRIORITY_VTOLS = 10
	local PRIORITY_FIGHTERS = 20
	local PRIORITY_SCOUTS = 1000

	local avoidanceTime = 30 ---@type integer Ignore targets for up to this many seconds (from zero).
	local avoidMinimum = PRIORITY_FIGHTERS

	local isAntiAirWeapon = {}
	local avoidsAirTargets = {}

	-- Pre-compute direct unitDefID → priority multiplier for all air units
	local airPriorityMultiplier = {}
	for unitDefID, unitDef in ipairs(UnitDefs) do
		local weapons = unitDef.weapons

		if unitDef.isAirUnit then
			local mult = PRIORITY_SCOUTS
			if unitDef.isTransport or unitDef.isBuilder then
				mult = PRIORITY_VTOLS
			else
				for i = 1, #weapons do
					local weaponDef = WeaponDefs[weapons[i].weaponDef]
					if weaponDef.type == 'AircraftBomb' or weaponDef.type == 'TorpedoLauncher' or stringFind(weaponDef.name, 'arm_pidr', 1, true) then
						mult = PRIORITY_BOMBERS
					elseif weapons[i].onlyTargets.vtol then
						mult = PRIORITY_FIGHTERS
					else
						mult = PRIORITY_VTOLS
					end
				end
			end
			airPriorityMultiplier[unitDefID] = mult
		end

		for i = 1, #weapons do
			if weapons[i].onlyTargets.vtol then
				local weaponDefID = weapons[i].weaponDef
				local weaponDef = WeaponDefs[weaponDefID]

				isAntiAirWeapon[weaponDefID] = true
				Script.SetWatchAllowTarget(weaponDefID, true) -- for AllowWeaponTarget access

				if weapons[i].badTargets.lightairscout then
					-- Assume that target avoidance and stock replenishment are correlated ~moderately.
					-- And include targets at varying priority levels given more extreme restock times.
					if math.max(weaponDef.reload + weaponDef.stockpileTime) >= avoidanceTime / 2 then
						avoidsAirTargets[weaponDefID] = PRIORITY_FIGHTERS
					else
						avoidsAirTargets[weaponDefID] = PRIORITY_SCOUTS
					end
				end
			end
		end
	end

	local interval, generation = 0, 0
	local unitInterval = {}

	local function getUnitInterval(unitID)
		return Spring.ValidUnitID(unitID) and ((unitID + 999983) * 7 + generation) % avoidanceTime
	end

	local function avoid(unitID)
		return math_abs(unitInterval[unitID] - interval) > 1
	end

	function gadget:UnitCreated(unitID)
		unitInterval[unitID] = getUnitInterval(unitID)
	end
	function gadget:GameFrame(frame)
		interval = (frame % gameSpeed) % avoidanceTime
		if interval == 0 then
			generation = (generation + 1 + frame % gameSpeed) % avoidanceTime
			for unitID in pairs(unitInterval) do
				unitInterval[unitID] = getUnitInterval(unitID)
			end
		end
	end
	function gadget:Initialize()
		interval = (Spring.GetGameFrame() % gameSpeed) % avoidanceTime
		generation = ((Spring.GetGameFrame() + 1) % gameSpeed) % avoidanceTime -- ! idk is that right?
		for _, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID)
		end
	end

	function gadget:AllowWeaponTarget(unitID, targetID, weaponNum, weaponDefID, priority)
		if isAntiAirWeapon[weaponDefID] then
			local multiplier = airPriorityMultiplier[spGetUnitDefID(targetID)]
			if not multiplier then
				return true, priority
			end

			if multiplier >= avoidMinimum and avoidsAirTargets[weaponDefID] and avoid(unitID) then
				return false
			end

			if priority then
				return true, priority * multiplier
			end
		end
		return true, priority
	end

end

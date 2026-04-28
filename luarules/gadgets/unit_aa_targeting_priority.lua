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

	local PRIORITY_BOMBERS = 1
	local PRIORITY_VTOLS = 10
	local PRIORITY_FIGHTERS = 20
	local PRIORITY_SCOUTS = 1000

	local isAntiAirWeapon = {}

	-- Pre-compute direct unitDefID → priority multiplier for all air units
	local airPriorityMultiplier = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
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

		-- Set watch on vtol-targeting weapons so AllowWeaponTarget gets called
		for i = 1, #weapons do
			if weapons[i].onlyTargets.vtol then
				isAntiAirWeapon[weapons[i].weaponDef] = true
				Script.SetWatchAllowTarget(weapons[i].weaponDef, true)
			end
		end
	end

	function gadget:AllowWeaponTarget(unitID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
		-- No input priority means we are not returning a new priority value.
		if defPriority and isAntiAirWeapon[attackerWeaponDefID] then
			local mult = airPriorityMultiplier[spGetUnitDefID(targetID)]
			if mult then
				return true, defPriority * mult
			end
		end
		return true, defPriority
	end
end

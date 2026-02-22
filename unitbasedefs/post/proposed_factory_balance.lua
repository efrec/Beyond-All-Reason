local unitDefAdjustments = {
	[{ "armmoho", "cormoho", "cormexp" }] = function(unitDef)
		unitDef.metalcost = unitDef.metalcost + 50
		unitDef.energycost = unitDef.energycost + 2000
	end,
	[{ "armageo", "corageo" }] = function(unitDef)
		unitDef.metalcost = unitDef.metalcost + 100
		unitDef.energycost = unitDef.energycost + 4000
	end,
	[{ "armavp", "coravp", "armalab", "coralab", "armaap", "coraap", "armasy", "corasy" }] = function(unitDef)
		unitDef.metalcost = unitDef.metalcost - 1000
		unitDef.workertime = 600
		unitDef.buildtime = unitDef.buildtime * 2
	end,
	[{ "armvp", "corvp", "armlab", "corlab", "armsy", "corsy" }] = function(unitDef)
		unitDef.metalcost = unitDef.metalcost - 50
		unitDef.energycost = unitDef.energycost - 280
		unitDef.buildtime = unitDef.buildtime - 1500
	end,
	[{ "armap", "corap", "armhp", "corhp", "armfhp", "corfhp", "armplat", "corplat" }] = function(unitDef)
		unitDef.metalcost = unitDef.metalcost - 100
		unitDef.energycost = unitDef.energycost - 600
		unitDef.buildtime = unitDef.buildtime - 100
	end,
	[{ "armshltx", "corgant", "armshltxuw", "corgantuw" }] = function(unitDef)
		unitDef.buildtime = unitDef.buildtime * 1.33
	end,
	[{ "armnanotc", "cornanotc", "armnanotcplat", "cornanotcplat" }] = function(unitDef)
		unitDef.metalcost = unitDef.metalcost - 100
	end,
}

local unitDefNames = {}
for names in pairs(unitDefAdjustments) do
	table.appendArray(unitDefNames, names)
end

local unitDefReworks = {}
for names, adjustments in pairs(unitDefAdjustments) do
	unitDefReworks[table.invert(names)] = adjustments
end

local skipTechLevelCosts = {
	armavp = true,
	coravp = true,
	armalab = true,
	coralab = true,
	armaap = true,
	coraap = true,
	armasy = true,
	corasy = true,
}

local function factoryCostTweaks(name, unitDef)
	if unitDefNames[name] then
		for unitNameHashSet, adjust in pairs(unitDefReworks) do
			if unitNameHashSet[name] then
				adjust(unitDef)
				break
			end
		end
	end
	if not skipTechLevelCosts[name] and (unitDef.energycost and unitDef.metalcost and unitDef.buildtime) then
		local techLevel = tonumber(unitDef.customparams.techlevel or 1)
		if techLevel == 2 then
			unitDef.buildtime = math.ceil(unitDef.buildtime * 0.015 / 5) * 500
		elseif techLevel == 3 then
			unitDef.buildtime = math.ceil(unitDef.buildtime * 0.0015) * 1000
		end
	end
	return unitDef
end

return {
	factoryCostTweaks = factoryCostTweaks,
}
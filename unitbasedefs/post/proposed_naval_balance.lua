local buildOptionReplacements = {
	armcs = { armfhlt = "armnavaldefturret" },
	armch = { armfhlt = "armnavaldefturret" },
	armbeaver = { armfhlt = "armnavaldefturret" },
	armcsa = { armfhlt = "armnavaldefturret" },
	armacsub = { armkraken = "armanavaldefturret" },
	armmls = {
		armfhlt   = "armnavaldefturret",
		armkraken = "armanavaldefturret",
	},
	--
	corcs = { corfhlt = "cornavaldefturret" },
	corch = { corfhlt = "cornavaldefturret" },
	cormuskrat = { corfhlt = "cornavaldefturret" },
	corcsa = { corfhlt = "cornavaldefturret" },
	coracsub = { corfdoom = "coranavaldefturret" },
	cormls = {
		corfhlt  = "cornavaldefturret",
		corfdoom = "coranavaldefturret",
	},
	--
	legnavyconship = { legfmg = "legnavaldefturret" },
	legch = { legfmg = "legnavaldefturret" },
	legotter = { legfmg = "legnavaldefturret" },
	legspcon = { legfmg = "legnavaldefturret" },
	leganavyengineer = { legfmg = "legnavaldefturret" },
}

local radarSightDistance = { sightdistance = 800 }

local unitDefReworks = {
	armfrad = radarSightDistance,
	corfrad = radarSightDistance,
	legfrad = radarSightDistance,
}

local function navalBalanceTweaks(name, unitDef)
	if buildOptionReplacements[name] then
		local buildoptions = unitDef.buildoptions or {}
		local replacements = buildOptionReplacements[name]
		for i, buildOption in ipairs(buildoptions) do
			if replacements[buildOption] then
				buildoptions[i] = replacements[buildOption]
			end
		end
	end
	if unitDefReworks[name] then
		table.mergeInPlace(unitDef, unitDefReworks[name])
	end
	return unitDef
end

return {
	navalBalanceTweaks = navalBalanceTweaks,
}

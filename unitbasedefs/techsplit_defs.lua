-- Unit categories

local commanders = {
	corcom = true,
	armcom = true,
	legcom = true,
}

local labHover = {
	armhp = true, armfhp = true,
	corhp = true, corfhp = true,
	leghp = true, legfhp = true,
}

local labTier2 = {
	armaap = true, armasy = true, armalab = true, armavp = true,
	coraap = true, corasy = true, coralab = true, coravp = true,
}

local conTier2 = {
	armch = true, armack = true, armacv = true, armaca = true, armacsub = true,
	corch = true, corack = true, coracv = true, coraca = true, coracsub = true,
	legch = true, legack = true, legacv = true, legaca = true,
}

local conTier3 = {
	armhaca = true, armhack = true, armhacv = true, armhacs = true,
	corhaca = true, corhack = true, corhacv = true, corhacs = true,
	leghaca = true, leghack = true, leghacv = true,
}

local transportHeavy = {
	legatrans = true,
}

local jammerMobileT3 = {
	armaser = true, armjam = true,
	corspec = true, coreter = true,
	legajamk = true, legavjam = true,
}

local pinpointers = {
	armtarg = true, armfatf = true,
	cortarg = true, corfatf = true,
	legtarg = true,
}

local lolmechs = {
	armbanth = true,
	corjugg = true,
	corkorg = true,
	legeheatraymech = true,
	legelrpcmech = true,
}

local extractorT2 = {
	armmoho = true, armuwmme = true,
	cormoho = true, coruwmme = true,
	legmoho = true,
}

local isNowTier2 = {
	armch = true, armsh = true, armanac = true, armah = true, armmh = true, armcsa = true, armsaber = true, armsb = true, armseap = true, armsfig = true, armsehak = true, armhvytrans = true,
	corch = true, corsh = true, corsnap = true, corah = true, cormh = true, corhal = true, corcsa = true, corcut = true, corsb = true, corseap = true, corsfig = true, corhunt = true, corhvytrans = true,
}

local isNowTier3 = {
	armsnipe = true, armfboy = true, armaser = true, armdecom = true, armscab = true, armbull = true, armmerl = true, armmanni = true, armyork = true, armjam = true, armserp = true, armbats = true, armepoch = true, armantiship = true, armaas = true, armhawk = true, armpnix = true, armlance = true, armawac = true, armdfly = true, armliche = true, armblade = true, armbrawl = true, armstil = true,
	corsumo = true, cordecom = true, corsktl = true, corspec = true, corgol = true, corvroc = true, cortrem = true, corsent = true, coreter = true, corparrow = true, corssub = true, corbats = true, corblackhy = true, corarch = true, corantiship = true, corape = true, corhurc = true, cortitan = true, corvamp = true, corseah = true, corawac = true, corcrwh = true,
}

---Convert a unitDef into its tech-split counterpart.
---@param name string
---@param unitDef table
---@return table
local function techsplitTweaks(name, unitDef)
	------------------------------
	-- Land Split

	-- T2 Labs

	if name == "coralab" then
		unitDef.buildoptions = {
			"corack",
			"coraak",
			"cormort",
			"corcan",
			"corpyro",
			"corspy",
			"coramph",
			"cormando",
			"cortermite",
			"corhrk",
			"corvoyr",
			"corroach",
		}
	elseif name == "armalab" then
		unitDef.buildoptions = {
			"armack",
			"armfido",
			"armaak",
			"armzeus",
			"armmav",
			"armamph",
			"armspid",
			"armfast",
			"armvader",
			"armmark",
			"armsptk",
			"armspy",
		}
	elseif name == "armavp" then
		unitDef.buildoptions = {
			"armacv",
			"armch",
			"armcroc",
			"armlatnk",
			"armah",
			"armmart",
			"armseer",
			"armmh",
			"armanac",
			"armsh",
			"armgremlin"
		}
	elseif name == "coravp" then
		unitDef.buildoptions = {
			"corch",
			"coracv",
			"corsala",
			"correap",
			"cormart",
			"corhal",
			"cormh",
			"corsnap",
			"corah",
			"corsh",
			"corvrad",
			"corban"
		}
	end

	-- Land Cons

	if name == "armck" then
		unitDef.buildoptions = {
			"armsolar",
			"armwin",
			"armmex",
			"armmstor",
			"armestor",
			"armamex",
			"armmakr",
			"armalab",
			"armlab",
			"armvp",
			"armap",
			"armnanotc",
			"armeyes",
			"armrad",
			"armdrag",
			"armllt",
			"armrl",
			"armdl",
			"armjamt",
			"armsy",
			"armgeo",
			"armbeamer",
			"armhlt",
			"armferret",
			"armclaw",
			"armjuno",
			"armadvsol",
			"armguard"
		}
	elseif name == "corck" then
		unitDef.buildoptions = {
			"corsolar",
			"corwin",
			"cormstor",
			"corestor",
			"cormex",
			"cormakr",
			"corlab",
			"coralab",
			"corvp",
			"corap",
			"cornanotc",
			"coreyes",
			"cordrag",
			"corllt",
			"corrl",
			"corrad",
			"cordl",
			"corjamt",
			"corsy",
			"corexp",
			"corgeo",
			"corhllt",
			"corhlt",
			"cormaw",
			"cormadsam",
			"coradvsol",
			"corpun"
		}
	elseif name == "armack" then
		unitDef.buildoptions = {
			"armadvsol",
			"armmoho",
			"armbeamer",
			"armhlt",
			"armguard",
			"armferret",
			"armcir",
			"armjuno",
			"armpb",
			"armarad",
			"armveil",
			"armfus",
			"armgmm",
			"armhalab",
			"armlab",
			"armalab",
			"armsd",
			"armmakr",
			"armestor",
			"armmstor",
			"armageo",
			"armckfus",
			"armdl",
			"armdf",
			"armvp",
			"armsy",
			"armap",
			"armnanotc",
			"armamd",
		}
	elseif name == "corack" then
		unitDef.buildoptions = {
			"coradvsol",
			"cormoho",
			"corvipe",
			"corhllt",
			"corpun",
			"cormadsam",
			"corerad",
			"corjuno",
			"corfus",
			"corarad",
			"corshroud",
			"corsd",
			"corlab",
			"corhalab",
			"coralab",
			"cormakr",
			"corestor",
			"cormstor",
			"corageo",
			"corhlt",
			"cordl",
			"corvp",
			"corap",
			"corsy",
			"cornanotc",
			"corfmd",
		}
	elseif name == "armcv" then
		unitDef.buildoptions = {
			"armsolar",
			"armwin",
			"armmex",
			"armmstor",
			"armestor",
			"armamex",
			"armmakr",
			"armavp",
			"armlab",
			"armvp",
			"armap",
			"armnanotc",
			"armeyes",
			"armrad",
			"armdrag",
			"armllt",
			"armrl",
			"armdl",
			"armjamt",
			"armsy",
			"armgeo",
			"armbeamer",
			"armhlt",
			"armferret",
			"armclaw",
			"armjuno",
			"armadvsol",
			"armguard"
		}
	elseif name == "armbeaver" then
		unitDef.buildoptions = {
			"armsolar",
			"armwin",
			"armmex",
			"armmstor",
			"armestor",
			"armamex",
			"armmakr",
			"armavp",
			"armlab",
			"armvp",
			"armap",
			"armnanotc",
			"armeyes",
			"armrad",
			"armdrag",
			"armllt",
			"armrl",
			"armdl",
			"armjamt",
			"armsy",
			"armtide",
			"armfmkr",
			"armasy",
			"armfrt",
			"armtl",
			"armgeo",
			"armbeamer",
			"armhlt",
			"armferret",
			"armclaw",
			"armjuno",
			"armfrad",
			"armadvsol",
			"armguard"
		}
	elseif name == "corcv" then
		unitDef.buildoptions = {
			"corsolar",
			"corwin",
			"cormstor",
			"corestor",
			"cormex",
			"cormakr",
			"corlab",
			"coravp",
			"corvp",
			"corap",
			"cornanotc",
			"coreyes",
			"cordrag",
			"corllt",
			"corrl",
			"corrad",
			"cordl",
			"corjamt",
			"corsy",
			"corexp",
			"corgeo",
			"corhllt",
			"corhlt",
			"cormaw",
			"cormadsam",
			"coradvsol",
			"corpun"
		}
	elseif name == "cormuskrat" then
		unitDef.buildoptions = {
			"corsolar",
			"corwin",
			"cormstor",
			"corestor",
			"cormex",
			"cormakr",
			"corlab",
			"coravp",
			"corvp",
			"corap",
			"cornanotc",
			"coreyes",
			"cordrag",
			"corllt",
			"corrl",
			"corrad",
			"cordl",
			"corjamt",
			"corsy",
			"corexp",
			"corgeo",
			"corhllt",
			"corhlt",
			"cormaw",
			"cormadsam",
			"corfrad",
			"cortide",
			"corasy",
			"cortl",
			"coradvsol",
			"corpun"
		}
	elseif name == "armacv" then
		unitDef.buildoptions = {
			"armadvsol",
			"armmoho",
			"armbeamer",
			"armhlt",
			"armguard",
			"armferret",
			"armcir",
			"armjuno",
			"armpb",
			"armarad",
			"armveil",
			"armfus",
			"armgmm",
			"armhavp",
			"armlab",
			"armavp",
			"armsd",
			"armmakr",
			"armestor",
			"armmstor",
			"armageo",
			"armckfus",
			"armdl",
			"armdf",
			"armvp",
			"armsy",
			"armap",
			"armnanotc",
			"armamd",
		}
	elseif name == "coracv" then
		unitDef.buildoptions = {
			"coradvsol",
			"cormoho",
			"corvipe",
			"corhllt",
			"corpun",
			"cormadsam",
			"corerad",
			"corjuno",
			"corfus",
			"corarad",
			"corshroud",
			"corsd",
			"corvp",
			"corhavp",
			"coravp",
			"cormakr",
			"corestor",
			"cormstor",
			"corageo",
			"corhlt",
			"cordl",
			"corlab",
			"corap",
			"corsy",
			"cornanotc",
			"corfmd",
		}
	end

	------------------------------
	-- Air Split

	-- Air Labs

	if name == "armaap" then
		unitDef.buildpic = "ARMHAAP.DDS"
		unitDef.objectname = "Units/ARMAAPLAT.s3o"
		unitDef.script = "Units/techsplit/ARMHAAP.cob"
		unitDef.customparams.buildinggrounddecaltype = "decals/armamsub_aoplane.dds"
		unitDef.customparams.buildinggrounddecalsizex = 13
		unitDef.customparams.buildinggrounddecalsizey = 13
		unitDef.featuredefs.dead["object"] = "Units/armaaplat_dead.s3o"
		unitDef.buildoptions = {
			"armaca",
			"armseap",
			"armsb",
			"armsfig",
			"armsehak",
			"armsaber",
			"armhvytrans"
		}
		unitDef.sfxtypes = {
			explosiongenerators = {
				"custom:radarpulse_t1_slow",
			},
			pieceexplosiongenerators = {
				"deathceg2",
				"deathceg3",
				"deathceg4",
			},
		}
		unitDef.sounds = {
			build = "seaplok1",
			canceldestruct = "cancel2",
			underattack = "warning1",
			unitcomplete = "untdone",
			count = {
				"count6",
				"count5",
				"count4",
				"count3",
				"count2",
				"count1",
			},
			select = {
				"seaplsl1",
			},
		}
	elseif name == "coraap" then
		unitDef.buildpic = "CORHAAP.DDS"
		unitDef.objectname = "Units/CORAAPLAT.s3o"
		unitDef.script = "Units/CORHAAP.cob"
		unitDef.buildoptions = {
			"coraca",
			"corhunt",
			"corcut",
			"corsb",
			"corseap",
			"corsfig",
			"corhvytrans",
		}
		unitDef.featuredefs.dead["object"] = "Units/coraaplat_dead.s3o"
		unitDef.customparams.buildinggrounddecaltype = "decals/coraap_aoplane.dds"
		unitDef.customparams.buildinggrounddecalsizex = 6
		unitDef.customparams.buildinggrounddecalsizey = 6
		unitDef.customparams.sfxtypes = {
			pieceexplosiongenerators = {
				"deathceg2",
				"deathceg3",
				"deathceg4",
			},
		}
		unitDef.customparams.sounds = {
			build = "seaplok2",
			canceldestruct = "cancel2",
			underattack = "warning1",
			unitcomplete = "untdone",
			count = {
				"count6",
				"count5",
				"count4",
				"count3",
				"count2",
				"count1",
			},
			select = {
				"seaplsl2",
			},
		}
	elseif name == "armap" then
		unitDef.buildoptions = {
			"armca",
			"armpeep",
			"armfig",
			"armthund",
			"armatlas",
			"armkam",
		}
	elseif name == "corap" then
		unitDef.buildoptions = {
			"corca",
			"corfink",
			"corveng",
			"corshad",
			"corvalk",
			"corbw",
		}
	end

	-- Air Cons

	if name == "armca" then
		unitDef.buildoptions = {
			"armsolar",
			"armwin",
			"armmstor",
			"armestor",
			"armmex",
			"armmakr",
			"armaap",
			"armlab",
			"armvp",
			"armap",
			"armnanotc",
			"armeyes",
			"armrad",
			"armdrag",
			"armllt",
			"armrl",
			"armdl",
			"armjamt",
			"armsy",
			"armamex",
			"armgeo",
			"armbeamer",
			"armhlt",
			"armferret",
			"armclaw",
			"armjuno",
			"armadvsol",
			"armguard",
			"armnanotc",
		}
	elseif name == "corca" then
		unitDef.buildoptions = {
			"corsolar",
			"corwin",
			"cormstor",
			"corestor",
			"cormex",
			"cormakr",
			"corlab",
			"coraap",
			"corvp",
			"corap",
			"cornanotc",
			"coreyes",
			"cordrag",
			"corllt",
			"corrl",
			"corrad",
			"cordl",
			"corjamt",
			"corsy",
			"corexp",
			"corgeo",
			"corhllt",
			"corhlt",
			"cormaw",
			"cormadsam",
			"coradvsol",
			"corpun",
			"cornanotc",
		}
	elseif name == "armaca" then
		unitDef.buildpic = "ARMCSA.DDS"
		unitDef.objectname = "Units/ARMCSA.s3o"
		unitDef.script = "units/ARMCSA.cob"
		unitDef.buildoptions = {
			"armadvsol",
			"armmoho",
			"armbeamer",
			"armhlt",
			"armguard",
			"armferret",
			"armcir",
			"armjuno",
			"armpb",
			"armarad",
			"armveil",
			"armfus",
			"armgmm",
			"armhaap",
			"armlab",
			"armaap",
			"armsd",
			"armmakr",
			"armestor",
			"armmstor",
			"armageo",
			"armckfus",
			"armdl",
			"armdf",
			"armvp",
			"armsy",
			"armap",
			"armnanotc",
			"armamd",
		}
	elseif name == "coraca" then
		unitDef.buildpic = "CORCSA.DDS"
		unitDef.objectname = "Units/CORCSA.s3o"
		unitDef.script = "units/CORCSA.cob"
		unitDef.buildoptions = {
			"coradvsol",
			"cormoho",
			"corvipe",
			"corhllt",
			"corpun",
			"cormadsam",
			"corerad",
			"corjuno",
			"corfus",
			"corarad",
			"corshroud",
			"corsd",
			"corap",
			"corhaap",
			"coraap",
			"cormakr",
			"corestor",
			"cormstor",
			"corageo",
			"corhlt",
			"cordl",
			"corvp",
			"corlab",
			"corsy",
			"cornanotc",
			"corfmd",
		}
	end

	------------
	-- Sea Split

	-- Sea Labs

	if name == "armhasy" or name == "corhasy" then
		unitDef.metalcost = unitDef.metalcost - 1200
	elseif name == "armsy" then
		table.removeAll(unitDef.buildoptions, "armbeaver")
	elseif name == "corsy" then
		table.removeAll(unitDef.buildoptions, "cormuskrat")
	elseif name == "armasy" then
		unitDef.metalcost = unitDef.metalcost + 400
		unitDef.buildoptions = {
			"armacsub",
			"armmship",
			"armcrus",
			"armsubk",
			"armah",
			"armlship",
			"armcroc",
			"armsh",
			"armanac",
			"armch",
			"armmh",
			"armsjam"
		}
	elseif name == "corasy" then
		unitDef.metalcost = unitDef.metalcost + 400
		unitDef.buildoptions = {
			"coracsub",
			"corcrus",
			"corshark",
			"cormship",
			"corfship",
			"corah",
			"corsala",
			"corsnap",
			"corsh",
			"corch",
			"cormh",
			"corsjam",
		}
	end

	-- Sea Cons

	if name == "armcs" then
		unitDef.buildoptions = {
			"armmex",
			"armvp",
			"armap",
			"armlab",
			"armeyes",
			"armdl",
			"armdrag",
			"armtide",
			"armuwgeo",
			"armfmkr",
			"armuwms",
			"armuwes",
			"armsy",
			"armnanotcplat",
			"armasy",
			"armfrad",
			"armfdrag",
			"armtl",
			"armfrt",
			"armfhlt",
			"armbeamer",
			"armclaw",
			"armferret",
			"armjuno",
			"armguard",
		}
	elseif name == "corcs" then
		unitDef.buildoptions = {
			"cormex",
			"corvp",
			"corap",
			"corlab",
			"coreyes",
			"cordl",
			"cordrag",
			"cortide",
			"corfmkr",
			"coruwms",
			"coruwes",
			"corsy",
			"cornanotcplat",
			"corasy",
			"corfrad",
			"corfdrag",
			"cortl",
			"corfrt",
			"cormadsam",
			"corfhlt",
			"corhllt",
			"cormaw",
			"coruwgeo",
			"corjuno",
			"corpun"
		}
	elseif name == "armacsub" then
		unitDef.buildoptions = {
			"armtide",
			"armuwageo",
			"armveil",
			"armarad",
			"armpb",
			"armasy",
			"armguard",
			"armfhlt",
			"armhasy",
			"armfmkr",
			"armason",
			"armuwfus",
			"armfdrag",
			"armsy",
			"armuwmme",
			"armatl",
			"armkraken",
			"armfrt",
			"armuwes",
			"armuwms",
			"armhaapuw",
			"armvp",
			"armlab",
			"armap",
			"armferret",
			"armcir",
			"armsd",
			"armnanotcplat",
			"armamd",
		}
	elseif name == "coracsub" then
		unitDef.buildoptions = {
			"cortide",
			"coruwmme",
			"corshroud",
			"corarad",
			"corvipe",
			"corsy",
			"corasy",
			"corhasy",
			"corfhlt",
			"corpun",
			"corason",
			"coruwfus",
			"corfmkr",
			"corfdrag",
			"corfrt",
			"coruwes",
			"coruwms",
			"coruwageo",
			"corhaapuw",
			"coratl",
			"corsd",
			"corvp",
			"corlab",
			"corsy",
			"corasy",
			"cornanotcplat",
			"corfdoom",
			"cormadsam",
			"corerad",
			"corfmd",
		}
	end

	-- T4 Gantries

	if name == "armshltx" then
		unitDef.footprintx = 15
		unitDef.footprintz = 15
		unitDef.collisionvolumescales = "225 150 205"
		unitDef.yardmap =
		"ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee eeeeeeeeeeeeeee"
		unitDef.objectname = "Units/ARMSHLTXBIG.s3o"
		unitDef.script = "Units/techsplit/ARMSHLTXBIG.cob"
		unitDef.featuredefs.armshlt_dead.object = "Units/armshltxbig_dead.s3o"
		unitDef.featuredefs.armshlt_dead.footprintx = 11
		unitDef.featuredefs.armshlt_dead.footprintz = 11
		unitDef.featuredefs.armshlt_dead.collisionvolumescales = "155 95 180"
		unitDef.customparams.buildinggrounddecalsizex = 18
		unitDef.customparams.buildinggrounddecalsizez = 18
	elseif name == "corgant" then
		unitDef.footprintx = 15
		unitDef.footprintz = 15
		unitDef.collisionvolumescales = "245 131 245"
		unitDef.yardmap =
		"oooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo"
		unitDef.objectname = "Units/CORGANTBIG.s3o"
		unitDef.script = "Units/techsplit/CORGANTBIG.cob"
		unitDef.featuredefs.dead.object = "Units/corgant_dead.s3o"
		unitDef.featuredefs.dead.footprintx = 15
		unitDef.featuredefs.dead.footprintz = 15
		unitDef.featuredefs.dead.collisionvolumescales = "238 105 238"
		unitDef.customparams.buildinggrounddecalsizex = 18
		unitDef.customparams.buildinggrounddecalsizez = 18
	elseif name == "leggant" then
		unitDef.footprintx = 15
		unitDef.footprintz = 15
		unitDef.collisionvolumescales = "245 135 245"
		unitDef.yardmap =
		"oooooooooooooo ooooooooooooooo ooooooooooooooo ooooooooooooooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo oooeeeeeeeeeooo yooeeeeeeeeeooy"
		unitDef.objectname = "Units/LEGGANTBIG.s3o"
		unitDef.script = "Units/techsplit/LEGGANTBIG.cob"
		unitDef.featuredefs.dead.object = "Units/leggant_dead.s3o"
		unitDef.featuredefs.dead.footprintx = 15
		unitDef.featuredefs.dead.footprintz = 15
		unitDef.featuredefs.dead.collisionvolumescales = "145 90 160"
		unitDef.customparams.buildinggrounddecalsizex = 18
		unitDef.customparams.buildinggrounddecalsizez = 18
	end

	if conTier3[name] then
		table.removeIf(unitDef.buildoptions, function(v) return lolmechs[v] end)
	elseif commanders[name] then
		table.removeIf(unitDef.buildoptions, function (v) return labHover[v] end)
	end

	if labTier2[name] then
		-- T2 labs are priced as t1.5 but require more BP
		-- ! Multiple changes to the same stats on the units?
		unitDef.metalcost = unitDef.metalcost - 1300
		unitDef.energycost = unitDef.energycost - 5000
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.015) * 100
	elseif isNowTier2[name] and (name == "armch" or name == "corch" or name == "legch") then
		-- Hover cons are priced as t2 (they are, literally, t2)
		unitDef.metalcost = unitDef.metalcost * 2
		unitDef.energycost = unitDef.energycost * 2
		unitDef.buildtime = unitDef.buildtime * 2
		unitDef.customparams.techlevel = 2
	elseif conTier2[name] then
		-- T2 cons are priced as t1.5 (excludes hovers, see above)
		unitDef.metalcost = unitDef.metalcost - 200
		unitDef.energycost = unitDef.energycost - 2000
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.008) * 100
	end

	----------------------------------------------
	-- T2 mexes upkeep increased, health decreased

	if extractorT2[name] then
		unitDef.energyupkeep = 40
		unitDef.health = unitDef.health - 1200
	elseif name == "cormexp" then
		unitDef.energyupkeep = 40
	end

	-- T3 mobile jammers have radar

	if jammerMobileT3[name] then
		unitDef.metalcost = unitDef.metalcost + 100
		unitDef.energycost = unitDef.energycost + 1250
		unitDef.buildtime = unitDef.buildtime + 3800
		unitDef.radardistance = 2500
		unitDef.sightdistance = 1000
	end

	-- T2 ship jammers get radar

	if name == "armsjam" or name == "corsjam" then
		unitDef.metalcost = unitDef.metalcost + 90
		unitDef.energycost = unitDef.energycost + 1050
		unitDef.buildtime = unitDef.buildtime + 3000
		unitDef.radarDistance = 2200
		unitDef.sightdistance = 900
	elseif name == "armantiship" or name == "corantiship" then
		-- And somewhat vice-versa
		unitDef.radardistancejam = 450
	end

	-- Pinpointers are T3 radar/jammers

	if pinpointers[name] then
		unitDef.radardistance = 5000
		unitDef.sightdistance = 1200
		unitDef.radardistancejam = 900
	end

	-- Correct Tier for Announcer

	if isNowTier2[name] then
		unitDef.customparams.techlevel = 2
	elseif isNowTier3[name] then
		unitDef.customparams.techlevel = 3
	end

	-----------------------------------------
	-- Hovers, Sea Planes and Amphibious Labs

	if name == "armch" then
		unitDef.buildoptions = {
			"armadvsol",
			"armmoho",
			"armbeamer",
			"armhlt",
			"armguard",
			"armferret",
			"armcir",
			"armjuno",
			"armpb",
			"armarad",
			"armveil",
			"armfus",
			"armgmm",
			"armhavp",
			"armlab",
			"armsd",
			"armmakr",
			"armestor",
			"armmstor",
			"armageo",
			"armckfus",
			"armdl",
			"armdf",
			"armvp",
			"armsy",
			"armap",
			"armavp",
			"armasy",
			"armhasy",
			"armtl",
			"armason",
			"armdrag",
			"armfdrag",
			"armuwmme",
			"armguard",
			"armnanotc",
			"armamd",
		}
	elseif name == "corch" then
		unitDef.buildoptions = {
			"coradvsol",
			"cormoho",
			"corvipe",
			"corhllt",
			"corpun",
			"cormadsam",
			"corerad",
			"corjuno",
			"corfus",
			"corarad",
			"corshroud",
			"corsd",
			"corvp",
			"corhavp",
			"coravp",
			"cormakr",
			"corestor",
			"cormstor",
			"corageo",
			"cordl",
			"coruwmme",
			"cordrag",
			"corfdrag",
			"corason",
			"corlab",
			"corap",
			"corsy",
			"corasy",
			"corhlt",
			"cortl",
			"corhasy",
			"corpun",
			"corfmd",
		}
	end

	----------------------------------------------
	-- Tech Split Balance

	-- Seaplane Platforms removed, become T2 air labs.
	-- T2 air labs have sea variants
	-- Made by hover cons and enhanced ship cons
	-- Enhanced ships given seaplanes instead of static AA

	if name == "corthud" then
		unitDef.speed = 54
		unitDef.weapondefs.arm_ham.range = 300
		unitDef.weapondefs.arm_ham.predictboost = 0.8
		unitDef.weapondefs.arm_ham.damage = {
			default = 150,
			subs = 50,
			vtol = 15,
		}
		unitDef.weapondefs.arm_ham.reloadtime = 1.73
		unitDef.weapondefs.arm_ham.areaofeffect = 51
	elseif name == "armwar" then
		unitDef.speed = 56
		unitDef.weapondefs.armwar_laser.range = 290
	elseif name == "corstorm" then
		unitDef.speed = 42
		unitDef.weapondefs.cor_bot_rocket.accuracy = 150
		unitDef.weapondefs.cor_bot_rocket.range = 600
		unitDef.weapondefs.cor_bot_rocket.reloadtime = 5.5
		unitDef.weapondefs.cor_bot_rocket.damage.default = 198
		unitDef.health = 250
	elseif name == "armrock" then
		unitDef.health = 240
		unitDef.speed = 48
		unitDef.weapondefs.arm_bot_rocket.reloadtime = 5.4
		unitDef.weapondefs.arm_bot_rocket.range = 575
		unitDef.weapondefs.arm_bot_rocket.damage.default = 190
	elseif name == "armhlt" then
		unitDef.health = 4640
		unitDef.metalcost = 535
		unitDef.energycost = 5700
		unitDef.buildtime = 13700
		unitDef.weapondefs.arm_laserh1.range = 750
		unitDef.weapondefs.arm_laserh1.reloadtime = 2.9
		unitDef.weapondefs.arm_laserh1.damage = {
			commanders = 801,
			default = 534,
			vtol = 48,
		}
	elseif name == "armfhlt" then
		unitDef.health = 7600
		unitDef.metalcost = 570
		unitDef.energycost = 7520
		unitDef.buildtime = 11700
		unitDef.weapondefs.armfhlt_laser.range = 750
		unitDef.weapondefs.armfhlt_laser.reloadtime = 1.45
		unitDef.weapondefs.armfhlt_laser.damage = {
			commanders = 414,
			default = 290,
			vtol = 71,
		}
	elseif name == "corhlt" then
		unitDef.health = 4640
		unitDef.metalcost = 580
		unitDef.energycost = 5700
		unitDef.buildtime = 13800
		unitDef.weapondefs.cor_laserh1.range = 750
		unitDef.weapondefs.cor_laserh1.reloadtime = 1.8
		unitDef.weapondefs.cor_laserh1.damage = {
			commanders = 540,
			default = 360,
			vtol = 41,
		}
	elseif name == "corfhlt" then
		unitDef.health = 7340
		unitDef.metalcost = 580
		unitDef.energycost = 7520
		unitDef.buildtime = 13800
		unitDef.weapondefs.corfhlt_laser.range = 750
		unitDef.weapondefs.corfhlt_laser.reloadtime = 1.5
		unitDef.weapondefs.corfhlt_laser.damage = {
			commanders = 482,
			default = 319,
			vtol = 61,
		}
	elseif name == "armart" then
		unitDef.speed = 65
		unitDef.turnrate = 210
		unitDef.maxacc = 0.018
		unitDef.maxdec = 0.081
		unitDef.weapondefs.tawf113_weapon.accuracy = 150
		unitDef.weapondefs.tawf113_weapon.range = 830
		unitDef.weapondefs.tawf113_weapon.damage = {
			default = 182,
			subs = 61,
			vtol = 20,
		}
		unitDef.weapons[1].maxangledif = 120
	elseif name == "corwolv" then
		unitDef.speed = 62
		unitDef.turnrate = 250
		unitDef.maxacc = 0.015
		unitDef.maxdec = 0.0675
		unitDef.weapondefs.corwolv_gun.accuracy = 150
		unitDef.weapondefs.corwolv_gun.range = 850
		unitDef.weapondefs.corwolv_gun.damage = {
			default = 375,
			subs = 95,
			vtol = 38,
		}
		unitDef.weapons[1].maxangledif = 120
	elseif name == "armmart" then
		unitDef.metalcost = 400
		unitDef.energycost = 5500
		unitDef.buildtime = 7500
		unitDef.speed = 47
		unitDef.turnrate = 120
		unitDef.maxacc = 0.005
		unitDef.health = 750
		unitDef.weapondefs.arm_artillery.accuracy = 75
		unitDef.weapondefs.arm_artillery.areaofeffect = 60
		unitDef.weapondefs.arm_artillery.hightrajectory = 1
		unitDef.weapondefs.arm_artillery.range = 1050
		unitDef.weapondefs.arm_artillery.reloadtime = 3.05
		unitDef.weapondefs.arm_artillery.weaponvelocity = 500
		unitDef.weapondefs.arm_artillery.damage = {
			default = 488,
			subs = 163,
			vtol = 49,
		}
		unitDef.weapons[1].maxangledif = 120
	elseif name == "cormart" then
		unitDef.metalcost = 600
		unitDef.energycost = 6600
		unitDef.buildtime = 6500
		unitDef.speed = 45
		unitDef.turnrate = 100
		unitDef.maxacc = 0.005
		unitDef.weapondefs.cor_artillery = {
			accuracy = 75,
			areaofeffect = 75,
			avoidfeature = false,
			cegtag = "arty-heavy",
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.65,
			explosiongenerator = "custom:genericshellexplosion-large-bomb",
			gravityaffected = "true",
			mygravity = 0.1,
			hightrajectory = 1,
			impulsefactor = 0.123,
			name = "PlasmaCannon",
			noselfdamage = true,
			range = 1150,
			reloadtime = 5,
			soundhit = "xplomed4",
			soundhitwet = "splsmed",
			soundstart = "cannhvy2",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 349.5354,
			damage = {
				default = 1200,
				subs = 400,
				vtol = 120,
			},
		}
		unitDef.weapons[1].maxangledif = 120
	elseif name == "armfido" then
		unitDef.speed = 74
		unitDef.weapondefs.bfido.range = 500
		unitDef.weapondefs.bfido.weaponvelocity = 400
	elseif name == "cormort" then
		unitDef.metalcost = 400
		unitDef.health = 800
		unitDef.speed = 47
		unitDef.weapondefs.cor_mort.range = 650
		unitDef.weapondefs.cor_mort.damage = {
			default = 250,
			subs = 83,
			vtol = 25,
		}
		unitDef.weapondefs.cor_mort.reloadtime = 3
		unitDef.weapondefs.cor_mort.areaofeffect = 64
	elseif name == "corhrk" then
		unitDef.turnrate = 600
		unitDef.weapondefs.corhrk_rocket.range = 900
		unitDef.weapondefs.corhrk_rocket.weaponvelocity = 600
		unitDef.weapondefs.corhrk_rocket.flighttime = 22
		unitDef.weapondefs.corhrk_rocket.reloadtime = 8
		unitDef.weapondefs.corhrk_rocket.turnrate = 30000
		unitDef.weapondefs.corhrk_rocket.weapontimer = 4
		unitDef.weapondefs.corhrk_rocket.damage = {
			default = 1200,
			subs = 400,
			vtol = 120,
		}
		unitDef.weapondefs.corhrk_rocket.areaofeffect = 128
		unitDef.weapons[1].maxangledif = 120
		unitDef.weapons[1].maindir = "0 0 1"
	elseif name == "armsptk" then
		unitDef.metalcost = 500
		unitDef.speed = 43
		unitDef.health = 450
		unitDef.turnrate = 600
		unitDef.weapondefs.adv_rocket.range = 775
		unitDef.weapondefs.adv_rocket.trajectoryheight = 1
		unitDef.weapondefs.adv_rocket.customparams.overrange_distance = 800
		unitDef.weapondefs.adv_rocket.weapontimer = 8
		unitDef.weapondefs.adv_rocket.flighttime = 4
		unitDef.weapons[1].maxangledif = 120
		unitDef.weapons[1].maindir = "0 0 1"
	elseif name == "corshiva" then
		unitDef.speed = 55
		unitDef.weapondefs.shiva_gun.range = 475
		unitDef.weapondefs.shiva_gun.areaofeffect = 180
		unitDef.weapondefs.shiva_gun.weaponvelocity = 372
		unitDef.weapondefs.shiva_rocket.areaofeffect = 96
		unitDef.weapondefs.shiva_rocket.range = 900
		unitDef.weapondefs.shiva_rocket.reloadtime = 14
		unitDef.weapondefs.shiva_rocket.damage.default = 1500
	elseif name == "armmar" then
		unitDef.health = 3920
		unitDef.weapondefs.armmech_cannon.areaofeffect = 48
		unitDef.weapondefs.armmech_cannon.range = 275
		unitDef.weapondefs.armmech_cannon.reloadtime = 1.25
		unitDef.weapondefs.armmech_cannon.damage = {
			default = 525,
			vtol = 134,
		}
	elseif name == "corban" then
		unitDef.speed = 69
		unitDef.turnrate = 500
		unitDef.weapondefs.banisher.areaofeffect = 180
		unitDef.weapondefs.banisher.weaponvelocity = 864
		unitDef.weapondefs.banisher.range = 450
	elseif name == "armcroc" then
		unitDef.health = 5250
		unitDef.turnrate = 270
		unitDef.weapondefs.arm_triton.reloadtime = 1.5
		unitDef.weapondefs.arm_triton.damage = {
			default = 250,
			subs = 111,
			vtol = 44
		}
		unitDef.weapons[2] = {
			def = "",
		}
	end

	----------------------------------------------
	-- Tech Split Hotfixes 3

	if name == "armhack" or name == "armhacv" or name == "armhaca" then
		table.insert(unitDef.buildoptions, "armnanotc")
	elseif name == "armhacs" then
		table.insert(unitDef.buildoptions, "armnanotcplat")
	elseif name == "corhack" or name == "corhacv" or name == "corhaca" then
		table.insert(unitDef.buildoptions, "cornanotc")
	elseif name == "corhacs" then
		table.insert(unitDef.buildoptions, "cornanotcplat")
	elseif name == "correap" then
		unitDef.speed = 74
		unitDef.turnrate = 250
		unitDef.weapondefs.cor_reap.areaofeffect = 92
		unitDef.weapondefs.cor_reap.damage = {
			default = 150,
			vtol = 48,
		}
		unitDef.weapondefs.cor_reap.range = 305
	elseif name == "armbull" then
		unitDef.health = 6000
		unitDef.metalcost = 1100
		unitDef.weapondefs.arm_bull.range = 400
		unitDef.weapondefs.arm_bull.damage = {
			default = 600,
			subs = 222,
			vtol = 67
		}
		unitDef.weapondefs.arm_bull.reloadtime = 2
		unitDef.weapondefs.arm_bull.areaofeffect = 96
	elseif name == "corsumo" then
		unitDef.weapondefs.corsumo_weapon.range = 750
		unitDef.weapondefs.corsumo_weapon.damage = {
			commanders = 350,
			default = 700,
			vtol = 165,
		}
		unitDef.weapondefs.corsumo_weapon.reloadtime = 1
	elseif name == "corgol" then
		unitDef.speed = 37
		unitDef.weapondefs.cor_gol.damage = {
			default = 1600,
			subs = 356,
			vtol = 98,
		}
		unitDef.weapondefs.cor_gol.reloadtime = 4
		unitDef.weapondefs.cor_gol.range = 700
	elseif name == "armguard" then
		unitDef.health = 6000
		unitDef.metalcost = 800
		unitDef.energycost = 8000
		unitDef.buildtime = 16000
		unitDef.weapondefs.plasma.areaofeffect = 150
		unitDef.weapondefs.plasma.range = 1000
		unitDef.weapondefs.plasma.reloadtime = 2.3
		unitDef.weapondefs.plasma.weaponvelocity = 550
		unitDef.weapondefs.plasma.damage = {
			default = 140,
			subs = 70,
			vtol = 42,
		}
		unitDef.weapondefs.plasma_high.areaofeffect = 150
		unitDef.weapondefs.plasma_high.range = 1000
		unitDef.weapondefs.plasma_high.reloadtime = 2.3
		unitDef.weapondefs.plasma_high.weaponvelocity = 700
		unitDef.weapondefs.plasma_high.damage = {
			default = 140,
			subs = 70,
			vtol = 42,
		}
	elseif name == "corpun" then
		unitDef.health = 6400
		unitDef.metalcost = 870
		unitDef.energycost = 8700
		unitDef.buildtime = 16400
		unitDef.weapondefs.plasma.areaofeffect = 180
		unitDef.weapondefs.plasma.range = 1020
		unitDef.weapondefs.plasma.reloadtime = 2.3
		unitDef.weapondefs.plasma.weaponvelocity = 550
		unitDef.weapondefs.plasma.damage = {
			default = 163,
			lboats = 163,
			subs = 21,
			vtol = 22,
		}
		unitDef.weapondefs.plasma_high.areaofeffect = 180
		unitDef.weapondefs.plasma_high.range = 1020
		unitDef.weapondefs.plasma_high.reloadtime = 2.3
		unitDef.weapondefs.plasma_high.weaponvelocity = 700
		unitDef.weapondefs.plasma_high.damage = {
			default = 163,
			lboats = 163,
			subs = 21,
			vtol = 22,
		}
	elseif name == "armpb" then
		unitDef.health = 3360
		unitDef.weapondefs.armpb_weapon.range = 500
		unitDef.weapondefs.armpb_weapon.reloadtime = 1.2
	elseif name == "corvipe" then
		unitDef.health = 3600
		unitDef.weapondefs.vipersabot.areaofeffect = 96
		unitDef.weapondefs.vipersabot.edgeeffectiveness = 0.8
		unitDef.weapondefs.vipersabot.range = 480
		unitDef.weapondefs.vipersabot.reloadtime = 3
	end


	-- Legion Update

	-- T2 labs
	if name == "legalab" then
		unitDef.buildoptions = {
			"legack",
			"legadvaabot",
			"legstr",
			"legshot",
			"leginfestor",
			"legamph",
			"legsnapper",
			"legbart",
			"leghrk",
			"legaspy",
			"legaradk",
		}
	elseif name == "legavp" then
		unitDef.buildoptions = {
			"legacv",
			"legch",
			"legavrad",
			"legsh",
			"legmrv",
			"legfloat",
			"legaskirmtank",
			"legamcluster",
			"legvcarry",
			"legner",
			"legmh",
			"legah"
		}
	elseif name == "legaap" then
		unitDef.buildoptions = {
			"legaca",
			"corhunt",
			"corcut",
			"corsb",
			"corseap",
			"corsfig",
			"legatrans",
		}
	elseif name == "legap" then
		table.removeIf(unitDef.buildoptions, function(v) return transportHeavy[v] end)
	elseif name == "legaap" or name == "legasy" or name == "legalab" or name == "legavp" then
		unitDef.metalcost = unitDef.metalcost - 1300
		unitDef.energycost = unitDef.energycost - 5000
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.015) * 100
	elseif name == "legch" then
		unitDef.metalcost = unitDef.metalcost * 2
		unitDef.energycost = unitDef.energycost * 2
		unitDef.buildtime = unitDef.buildtime * 2
		unitDef.customparams.techlevel = 2
	end

	-- T1 Cons

	if name == "legck" then
		unitDef.buildoptions = {
			"legsolar",
			"legwin",
			"leggeo",
			"legmstor",
			"legestor",
			"legmex",
			"legeconv",
			"leglab",
			"legalab",
			"legvp",
			"legap",
			"legnanotc",
			"legeyes",
			"legrad",
			"legdrag",
			"leglht",
			"legrl",
			"legctl",
			"legjam",
			"corsy",
			"legadvsol",
			"legmext15",
			"legcluster",
			"legrhapsis",
			"legmg",
			"legdtr",
			"leghive",
			"legjuno",
		}
	elseif name == "legca" then
		unitDef.buildoptions = {
			"legsolar",
			"legwin",
			"leggeo",
			"legmstor",
			"legestor",
			"legmex",
			"legeconv",
			"leglab",
			"legaap",
			"legvp",
			"legap",
			"legnanotc",
			"legeyes",
			"legrad",
			"legdrag",
			"leglht",
			"legrl",
			"legctl",
			"legjam",
			"corsy",
			"legadvsol",
			"legmext15",
			"legcluster",
			"legrhapsis",
			"legmg",
			"legdtr",
			"leghive",
			"legjuno",
		}
	elseif name == "legcv" then
		unitDef.buildoptions = {
			"legsolar",
			"legwin",
			"leggeo",
			"legmstor",
			"legestor",
			"legmex",
			"legeconv",
			"leglab",
			"legavp",
			"legvp",
			"legap",
			"legnanotc",
			"legeyes",
			"legrad",
			"legdrag",
			"leglht",
			"legrl",
			"legctl",
			"legjam",
			"corsy",
			"legadvsol",
			"legmext15",
			"legcluster",
			"legrhapsis",
			"legmg",
			"legdtr",
			"leghive",
			"legjuno",
		}
	elseif name == "legotter" then
		unitDef.buildoptions = {
			"legsolar",
			"legwin",
			"leggeo",
			"legmstor",
			"legestor",
			"legmex",
			"legeconv",
			"leglab",
			"legavp",
			"legvp",
			"legap",
			"legnanotc",
			"legeyes",
			"legrad",
			"legdrag",
			"leglht",
			"legrl",
			"legctl",
			"legjam",
			"corsy",
			"legadvsol",
			"legmext15",
			"legcluster",
			"legrhapsis",
			"legmg",
			"legdtr",
			"leghive",
			"legtide",
			"legtl",
			"legfrad",
			"corasy",
			"legjuno",
		}
	end

	--------------------------
	-- Legion Air Placeholders

	if name == "legch" then
		unitDef.buildoptions = {
			"legadvsol",
			"legmoho",
			"legapopupdef",
			"legmg",
			"legrhapsis",
			"leglupara",
			"legjuno",
			"leghive",
			"legfus",
			"legarad",
			"legajam",
			"legsd",
			"leglab",
			"legavp",
			"leghavp",
			"legcluster",
			"legeconv",
			"legageo",
			"legrampart",
			"legmstor",
			"legestor",
			"legcluster",
			"legmg",
			"legctl",
			"legvp",
			"legap",
			"corsy",
			"legnanotc",
			"coruwmme",
			"legtl",
			"corasy",
			"legabm",
		}
	elseif name == "legacv" then
		unitDef.buildoptions = {
			"legadvsol",
			"legmoho",
			"legapopupdef",
			"legmg",
			"legrhapsis",
			"leglupara",
			"legjuno",
			"leghive",
			"legfus",
			"legarad",
			"legajam",
			"legsd",
			"leglab",
			"legavp",
			"leghavp",
			"legcluster",
			"legeconv",
			"legageo",
			"legrampart",
			"legmstor",
			"legestor",
			"legcluster",
			"legmg",
			"legdl",
			"legvp",
			"legap",
			"corsy",
			"legnanotc",
			"legabm",
			"legctl",
		}
	elseif name == "legack" then
		unitDef.buildoptions = {
			"legadvsol",
			"legmoho",
			"legapopupdef",
			"legmg",
			"legrhapsis",
			"leglupara",
			"legjuno",
			"leghive",
			"legfus",
			"legarad",
			"legajam",
			"legsd",
			"leglab",
			"legalab",
			"leghalab",
			"legcluster",
			"legeconv",
			"legageo",
			"legrampart",
			"legmstor",
			"legestor",
			"legcluster",
			"legmg",
			"legdl",
			"legvp",
			"legap",
			"corsy",
			"legnanotc",
			"legabm",
			"legctl",
		}
	elseif name == "legaca" then
		unitDef.buildpic = "CORCSA.DDS"
		unitDef.objectname = "Units/CORCSA.s3o"
		unitDef.script = "Units/CORCSA.cob"
		unitDef.buildoptions = {
			"legadvsol",
			"legmoho",
			"legapopupdef",
			"legmg",
			"legrhapsis",
			"leglupara",
			"legjuno",
			"leghive",
			"legfus",
			"legarad",
			"legajam",
			"legsd",
			"leglab",
			"legaap",
			"leghaap",
			"legcluster",
			"legeconv",
			"legageo",
			"legrampart",
			"legmstor",
			"legestor",
			"legcluster",
			"legmg",
			"legdl",
			"legvp",
			"legap",
			"corsy",
			"legnanotc",
			"legabm",
			"legctl",
		}
	end

	----------------------------------------------
	-- Legion Unit Tweaks

	if name == "legapopupdef" then
		unitDef.weapondefs.advanced_riot_cannon.range = 480
		unitDef.weapondefs.advanced_riot_cannon.reloadtime = 1.5
		unitDef.weapondefs.standard_minigun.range = 400
	elseif name == "legmg" then
		unitDef.weapondefs.armmg_weapon.range = 650
	end

	return unitDef
end

return {
	techsplitTweaks = techsplitTweaks,
}

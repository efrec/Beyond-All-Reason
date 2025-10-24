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
	armhvytrans = true,
	corhvytrans = true,
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
	corjugg = true, corkorg = true,
	legeheatraymech = true, legelrpcmech = true,
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
	elseif name == "legalab" then
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
	elseif name == "legck" then
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
	elseif name:match("^...ap$") then
		table.removeIf(unitDef.buildoptions, function(v) return transportHeavy[v] end)
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

	-- General changes
	-- Costs, remove some build options

	if commanders[name] then
		table.removeIf(unitDef.buildoptions, function(v) return labHover[v] end)
	elseif labTier2[name] then
		-- T2 labs are priced as t1.5 but require more BP
		unitDef.metalcost = unitDef.metalcost - 1300
		unitDef.energycost = unitDef.energycost - 5000
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.015) * 100
	elseif isNowTier2[name] and name:match("^...ch$") then
		-- Hover cons are priced as t2 (they are, literally, t2)
		unitDef.metalcost = unitDef.metalcost * 2
		unitDef.energycost = unitDef.energycost * 2
		unitDef.buildtime = unitDef.buildtime * 2
	elseif conTier2[name] then
		-- T2 cons are priced as t1.5 (excludes hovers, see above)
		unitDef.metalcost = unitDef.metalcost - 200
		unitDef.energycost = unitDef.energycost - 2000
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.008) * 100
	elseif conTier3[name] then
		table.removeIf(unitDef.buildoptions, function(v) return lolmechs[v] end)
	end

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

	if name:match("sjam$") then
		unitDef.metalcost = unitDef.metalcost + 90
		unitDef.energycost = unitDef.energycost + 1050
		unitDef.buildtime = unitDef.buildtime + 3000
		unitDef.radarDistance = 2200
		unitDef.sightdistance = 900
	elseif name:match("antiship$") then
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
	elseif name == "legch" then
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
	end

	return unitDef
end

return {
	techsplitTweaks = techsplitTweaks,
}

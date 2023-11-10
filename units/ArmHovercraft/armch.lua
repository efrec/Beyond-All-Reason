return {
	armch = {
		acceleration = 0.04318,
		brakerate = 0.12,
		buildcostenergy = 2700,
		buildcostmetal = 200,
		builddistance = 150,
		builder = true,
		buildpic = "ARMCH.DDS",
		buildtime = 4470,
		canmove = true,
		category = "ALL HOVER MOBILE NOTSUB NOWEAPON NOTSHIP NOTAIR SURFACE EMPABLE",
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "31 12 31",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energymake = 11,
		energystorage = 75,
		energyuse = 11,
		explodeas = "smallexplosiongeneric-builder",
		footprintx = 3,
		footprintz = 3,
		idleautoheal = 5,
		idletime = 1800,
		maxdamage = 1440,
		maxslope = 16,
		maxvelocity = 2.23,
		maxwaterdepth = 0,
		movementclass = "HOVER2",
		objectname = "Units/ARMCH.s3o",
		radardistance = 50,
		script = "Units/ARMCH.cob",
		seismicsignature = 0,
		selfdestructas = "smallExplosionGenericSelfd-builder",
		sightdistance = 351,
		terraformspeed = 550,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.6698,
		turnrate = 425,
		workertime = 110,
		buildoptions = {
			[1] = "armsolar",
			[2] = "armadvsol",
			[3] = "armwin",
			[4] = "armgeo",
			[5] = "armmstor",
			[6] = "armestor",
			[7] = "armmex",
			[8] = "armamex",
			[9] = "armmakr",
			[10] = "armlab",
			[11] = "armvp",
			[12] = "armap",
			[13] = "armhp",
			[14] = "armnanotc",
			[15] = "armnanotcplat",
			[16] = "armeyes",
			[17] = "armrad",
			[18] = "armdrag",
			[19] = "armclaw",
			[20] = "armllt",
			[21] = "armbeamer",
			[22] = "armhlt",
			[23] = "armguard",
			[24] = "armrl",
			[25] = "armferret",
			[26] = "armcir",
			[27] = "armdl",
			[28] = "armjamt",
			[29] = "armjuno",
			[30] = "armfhp",
			[31] = "armsy",
			[32] = "armamsub",
			[33] = "armplat",
			[34] = "armtide",
			--[35] = "armuwmex",
			[36] = "armfmkr",
			[37] = "armuwms",
			[38] = "armuwes",
			[39] = "armfdrag",
			[40] = "armfrad",
			[41] = "armfhlt",
			[42] = "armfrt",
			[43] = "armtl",
		},
		customparams = {
			unitgroup = 'builder',
			area_mex_def = "armmex",
			model_author = "Beherith",
			normaltex = "unittextures/Arm_normal.dds",
			subfolder = "armhovercraft",
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "0 0 0",
				collisionvolumescales = "31 12 31",
				collisionvolumetype = "Box",
				damage = 778,
				energy = 0,
				featuredead = "HEAP",
				footprintx = 3,
				footprintz = 3,
				height = 20,
				hitdensity = 100,
				metal = 88,
				object = "Units/armch_dead.s3o",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "55.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 389,
				energy = 0,
				footprintx = 3,
				footprintz = 3,
				height = 4,
				hitdensity = 100,
				metal = 35,
				object = "Units/arm3X3A.s3o",
				reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:waterwake-small-hover",
				[2] = "custom:bowsplash-small-hover",
				[3] = "custom:hover-wake-tiny",
			},
			pieceexplosiongenerators = {
				[1] = "deathceg2-builder",
				[2] = "deathceg3-builder",
				[3] = "deathceg4-builder",
			},
		},
		sounds = {
			build = "nanlath1",
			canceldestruct = "cancel2",
			repair = "repair1",
			underattack = "warning1",
			working = "reclaim1",
			cant = {
				[1] = "cantdo4",
			},
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			ok = {
				[1] = "hovt1conok",
			},
			select = {
				[1] = "hovt1consel",
			},
		},
	},
}

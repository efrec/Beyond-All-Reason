return {
	coratl = {
		acceleration = 0,
		activatewhenbuilt = true,
		brakerate = 0,
		buildangle = 16384,
		buildcostenergy = 8500,
		buildcostmetal = 1050,
		buildpic = "CORATL.DDS",
		buildtime = 10875,
		canrepeat = false,
		category = "ALL NOTLAND WEAPON NOTSHIP NOTAIR NOTHOVER NOTSUB SURFACE",
		corpse = "DEAD",
		description = "Advanced Torpedo Launcher",
		energymake = 0.1,
		energyuse = 0.1,
		explodeas = "smallBuildingExplosionGeneric",
		footprintx = 3,
		footprintz = 3,
		icontype = "building",
		idleautoheal = 5,
		idletime = 1800,
		maxdamage = 2500,
		minwaterdepth = 12,
		name = "Lamprey",
		objectname = "CORATL",
		seismicsignature = 0,
		selfdestructas = "smallBuildingExplosionGenericSelfd",
		sightdistance = 585,
		waterline = 10,
		yardmap = "ooooooooo",
		customparams = {
			bar_waterline = 2,
			techlevel = 2,
			removewait = true,
			removestop = true,
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "0.0 -1.2890625003e-06 -0.0",
				collisionvolumescales = "44.8439941406 14.7038574219 41.8139953613",
				collisionvolumetype = "Box",
				damage = 337,
				description = "Lamprey Wreckage",
				energy = 0,
				footprintx = 3,
				footprintz = 3,
				height = 20,
				hitdensity = 100,
				metal = 676,
				object = "CORATL_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		},
		sfxtypes = { 
 			pieceExplosionGenerators = { 
				"deathceg2",
				"deathceg3",
				"deathceg4",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
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
				[1] = "torpadv2",
			},
			select = {
				[1] = "torpadv2",
			},
		},
		weapondefs = {
			coratl_torpedo = {
				areaofeffect = 16,
				avoidfriendly = false,
				burnblow = true,
				collidefriendly = false,
				craterboost = 0,
				cratermult = 0,
				explosiongenerator = "custom:genericshellexplosion-large-uw",
				impulseboost = 0.12300000339746,
				impulsefactor = 0.12300000339746,
				model = "Advtorpedo",
				name = "Long-range advanced torpedo launcher",
				noselfdamage = true,
				range = 890,
				reloadtime = 3.16,
				soundhit = "xplodep1",
				soundstart = "torpedo1",
				startvelocity = 100,
				tracks = true,
				turnrate = 20000,
				turret = true,
				waterweapon = true,
				weaponacceleration = 80,
				weapontimer = 3,
				weapontype = "TorpedoLauncher",
				weaponvelocity = 580,
				damage = {
					default = 1400,
				},
				customparams = {
					bar_model = "torpedo.s3o",
				}
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "HOVER NOTSHIP",
				def = "CORATL_TORPEDO",
				onlytargetcategory = "NOTHOVER",
			},
		},
	},
}

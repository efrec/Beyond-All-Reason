return {
	legcen = {
		maxacc = 0.25,
		activatewhenbuilt = true,
		maxdec = 1.29375,
		energycost = 2400,
		metalcost = 150,
		buildpic = "LEGCEN.DDS",
		buildtime = 3000,
		canmove = true,
		category = "BOT MOBILE WEAPON ALL NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE EMPABLE",
		collisionvolumeoffsets = "0 -1 1",
		collisionvolumescales = "18 20 30",
		collisionvolumetype = "box",
		corpse = "DEAD",
		explodeas = "mediumExplosionGeneric",
		footprintx = 2,
		footprintz = 2,
		idleautoheal = 5,
		idletime = 1800,
		health = 750,
		maxslope = 14,
		speed = 93.0,
		maxwaterdepth = 12,
		movementclass = "BOT3",
		nochasecategory = "VTOL",
		objectname = "Units/LEGCEN.s3o",
		script = "Units/LEGCEN.cob",
		seismicsignature = 0,
		selfdestructas = "mediumExplosionGenericSelfd",
		sightdistance = 400,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.518,
		turnrate = 720,
		customparams = {
			firingceg = "barrelshot-tiny",
			unitgroup = 'weapon',
			model_author = "Zecrus",
			normaltex = "unittextures/Arm_normal.dds",
			subfolder = "armbots",
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "-2.33637237549 -5.01163688965 -4.31414794922",
				collisionvolumescales = "32.719619751 19.6731262207 35.1108398438",
				collisionvolumetype = "Box",
				damage = 500,
				featuredead = "HEAP",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				metal = 100,
				object = "Units/legcen_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 600,
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 40,
				object = "Units/arm2X2A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:barrelshot-tiny",
			},
			pieceexplosiongenerators = {
				[1] = "deathceg2",
				[2] = "deathceg3",
				[3] = "deathceg4",
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
				[1] = "kbarmmov",
			},
			select = {
				[1] = "kbarmsel",
			},
		},
		weapondefs = {
			gauss = {
				areaofeffect = 8,
				avoidfeature = false,
				burst = 3,
				burstrate = 0.1,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-small",
				impactonly = 1,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				name = "Close-quarters g2g gauss-cannon",
				noselfdamage = true,
				range = 180,
				reloadtime = 2.25,
				size = 2,
				soundhit = "xplomed1",
				soundhitwet = "splsmed",
				soundstart = "cannhvy1",
				soundstartvolume = 2,
				sprayangle = 1000,
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 550,
				damage = {
					default = 75,
					vtol = 25,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL",
				def = "GAUSS",
				onlytargetcategory = "NOTSUB",
			},
		},
	},
}

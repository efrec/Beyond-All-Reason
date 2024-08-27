return {
	armcroc = {
		maxacc = 0.03252,
		activatewhenbuilt = true,
		maxdec = 0.06504,
		energycost = 15000,
		metalcost = 750,
		buildpic = "ARMCROC.DDS",
		buildtime = 16000,
		canmove = true,
		category = "ALL TANK MOBILE WEAPON NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW EMPABLE",
		collisionvolumeoffsets = "0 0 -3",
		collisionvolumescales = "40 30 56",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		explodeas = "largeExplosionGeneric-phib",
		footprintx = 3,
		footprintz = 3,
		idleautoheal = 5,
		idletime = 1800,
		leavetracks = true,
		health = 5000,
		maxslope = 12,
		speed = 54.0,
		maxwaterdepth = 255,
		movementclass = "ATANK3",
		nochasecategory = "VTOL",
		objectname = "Units/ARMCROC.s3o",
		script = "Units/ARMCROC.cob",
		seismicsignature = 0,
		selfdestructas = "largeExplosionGenericSelfd-phib",
		sightdistance = 372,
		sonardistance = 279,
		trackoffset = 16,
		trackstrength = 5,
		tracktype = "armcroc_tracks",
		trackwidth = 44,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.35,
		turnrate = 360,
		customparams = {
			unitgroup = 'weapon',
			basename = "base",
			firingceg = "barrelshot-medium",
			kickback = "-2.4",
			model_author = "FireStorm",
			normaltex = "unittextures/Arm_normal.dds",
			paralyzemultiplier = 0.25,
			subfolder = "armvehicles/t2",
			techlevel = 2,
			weapon1turretx = 45,
			weapon1turrety = 75,
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "0 0 -3",
				collisionvolumescales = "40 30 56",
				collisionvolumetype = "Box",
				damage = 2000,
				featuredead = "HEAP",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				metal = 400,
				object = "Units/armcroc_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 1500,
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 200,
				object = "Units/arm2X2A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:barrelshot-large",
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
				[1] = "tarmmove",
			},
			select = {
				[1] = "tarmsel",
			},
		},
		weapondefs = {
			arm_triton = {
				areaofeffect = 8,
				avoidfeature = false,
				craterareaofeffect = 8,
				craterboost = 0,
				cratermult = 0,
				cylindertargeting = 1,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-small",
				impactonly = 1, -- gauss with overpen_exp_def gets impactonly
				impulseboost = (3/2) * 0.123,
				impulsefactor = (3/2) * 0.123,
				name = "Medium g2g gauss-cannon",
				noselfdamage = true,
				predictboost = 1,
				range = 480,
				reloadtime = 1.6,
				soundhit = "xplomed4",
				soundhitwet = "splsmed",
				soundstart = "cannon2",
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 450,
				customparams = {
					overpen = true,
					overpen_exp_def = "armcroc_arm_triton_explosion",
				},
				damage = {
					default = (2/3) * 225,
					subs    = (2/3) * 100,
					vtol    = (2/3) * 40,
				},
			},
			arm_triton_explosion = {
				areaofeffect = 84,
				craterareaofeffect = 84,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.2,
				explosiongenerator = "custom:genericshellexplosion-medium",
				impactonly = 1, -- gauss with overpen_exp_def gets impactonly
				impulseboost = (3/2) * 0.123,
				impulsefactor = (3/2) * 0.123,
				name = "Gauss impact explosion",
				noselfdamage = true,
				weapontype = "Cannon",
				damage = {
					default = (1/3) * 225,
					subs    = (1/3) * 100,
					vtol    = (1/3) * 40,
				},
			},

			armcl_missile = {
				areaofeffect = 48,
				avoidfeature = false,
				burnblow = true,
				canattackground = false,
				cegtag = "missiletrailaa",
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-tiny-aa",
				firestarter = 70,
				flighttime = 1.9,
				fixedLauncher = true,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				metalpershot = 0,
				model = "cormissile.s3o",
				name = "Light g2a missile launcher",
				noselfdamage = true,
				range = 765,
				reloadtime = 1.7,
				smoketrail = true,
				smokePeriod = 6,
				smoketime = 12,
				smokesize = 4.8,
				smokecolor = 0.95,
				smokeTrailCastShadow = false,
				castshadow = false,
				soundhit = "xplomed2",
				soundhitwet = "splshbig",
				soundstart = "rockhvy2",
				texture1 = "null",
				texture2 = "smoketrailaa",
				tolerance = 10000,
				tracks = true,
				turnrate = 63000,
				turret = true,
				startvelocity = 300,
				weaponacceleration = 200,
				weapontimer = 5,
				weapontype = "MissileLauncher",
				weaponvelocity = 800,
				damage = {
					vtol = 60,
				},
			},

		},
		weapons = {
			[1] = {
				def = "ARM_TRITON",
				onlytargetcategory = "SURFACE",
			},
			[2] = {
				badtargetcategory = "NOTAIR LIGHTAIRSCOUT",
				def = "ARMCL_MISSILE",
				onlytargetcategory = "VTOL",
				fastautoretargeting = true,
			},

		},
	},
}

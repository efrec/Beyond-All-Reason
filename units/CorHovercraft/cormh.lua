return {
	cormh = {
		maxacc = 0.04415,
		maxdec = 0.04415,
		energycost = 3300,
		metalcost = 200,
		buildpic = "CORMH.DDS",
		buildtime = 3500,
		canmove = true,
		category = "ALL HOVER MOBILE WEAPON NOTSUB NOTSHIP NOTAIR SURFACE EMPABLE",
		collisionvolumeoffsets = "0 -3 0",
		collisionvolumescales = "38 20 38",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		explodeas = "mediumexplosiongeneric",
		footprintx = 3,
		footprintz = 3,
		idleautoheal = 5,
		idletime = 1800,
		health = 550,
		maxslope = 16,
		speed = 63.9,
		maxwaterdepth = 0,
		movementclass = "HOVER3",
		movestate = 0,
		nochasecategory = "VTOL",
		objectname = "Units/CORMH.s3o",
		script = "Units/CORMH.cob",
		seismicsignature = 0,
		selfdestructas = "mediumExplosionGenericSelfd",
		sightdistance = 509,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.5972,
		turnrate = 455,
		customparams = {
			unitgroup = 'weapon',
			model_author = "Beherith",
			normaltex = "unittextures/cor_normal.dds",
			subfolder = "corhovercraft",
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "0 1 0",
				collisionvolumescales = "38 17 38",
				collisionvolumetype = "Box",
				damage = 297,
				featuredead = "HEAP",
				footprintx = 3,
				footprintz = 3,
				height = 20,
				metal = 119,
				object = "Units/cormh_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "55.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 149,
				footprintx = 3,
				footprintz = 3,
				height = 4,
				metal = 48,
				object = "Units/cor3X3C.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:waterwake-small-hover",
				[2] = "custom:bowsplash-small-hover",
				[3] = "custom:hover-wake-small",
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
				[1] = "hovmdok2",
			},
			select = {
				[1] = "hovmdsl2",
			},
		},
		weapondefs = {
			cormh_weapon = {
				areaofeffect = 80,
				avoidfeature = false,
				cegtag = "missiletrailsmall-starburst",
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-medium-bomb",
				firestarter = 100,
				firesubmersed = true,
				flighttime = 10,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				metalpershot = 0,
				model = "corkbmissl1.s3o",
				name = "Rocket",
				noselfdamage = true,
				range = 700,
				reloadtime = 9,
				smoketrail = true,
				smokePeriod = 9,
				smoketime = 28,
				smokesize = 10,
				smokecolor = 0.7,
				smokeTrailCastShadow = false,
				castshadow = true, --projectile
				soundhit = "xplomed4",
				soundhitwet = "splssml",
				soundstart = "Rockhvy1",
				texture1 = "null",
				texture2 = "smoketrailbar",
				texture3 = "null",
				tolerance = 4000,
				turnrate = 15000,
				weaponacceleration = 70,
				weapontimer = 2.9,
				weapontype = "StarburstLauncher",
				weaponvelocity = 480,
				damage = {
					default = 550,
					subs = 250,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "MOBILE",
				def = "CORMH_WEAPON",
				onlytargetcategory = "SURFACE",
			},
		},
	},
}

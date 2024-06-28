return {
	raptor_air_gunship_acid_t2_v1 = {
		acceleration = 0.8,
		airhoverfactor = 0,
		attackrunlength = 32,
		maxdec = 0.1,
		energycost = 4550,
		metalcost = 212,
		builder = false,
		buildpic = "raptors/raptorf1.DDS",
		buildtime = 9375,
		canattack = true,
		canfly = true,
		canguard = true,
		canland = true,
		canloopbackattack = true,
		canmove = true,
		canpatrol = true,
		canstop = "1",
		cansubmerge = true,
		capturable = false,
		category = "ALL MOBILE WEAPON NOTLAND VTOL NOTSUB NOTSHIP NOTHOVER RAPTOR",
		collide = true,
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "70 70 70",
		collisionvolumetype = "sphere",
		cruisealtitude = 220,
		defaultmissiontype = "Standby",
		explodeas = "TALON_DEATH",
		footprintx = 3,
		footprintz = 3,
		hidedamage = 1,
		idleautoheal = 5,
		idletime = 0,
		maneuverleashlength = "20000",
		mass = 227.5,
		maxacc = 0.25,
		maxaileron = 0.025,
		maxbank = 0.8,
		health = 350,
		maxelevator = 0.025,
		maxpitch = 0.75,
		maxrudder = 0.025,
		speed = 240.0,
		moverate1 = "32",
		noautofire = false,
		nochasecategory = "VTOL SPACE",
		objectname = "Raptors/raptorf1.s3o",
		script = "Raptors/raptorf1.cob",
		seismicsignature = 0,
		selfdestructas = "TALON_DEATH",
		side = "THUNDERBIRDS",
		sightdistance = 1000,
		smoothanim = true,
		speedtofront = 0.07,
		turninplace = true,
		turnradius = 64,
		turnrate = 1600,
		usesmoothmesh = true,
		wingangle = 0.06593,
		wingdrag = 0.835,
		workertime = 0,
        hoverAttack = true,
		customparams = {
			subfolder = "other/raptors",
			model_author = "KDR_11k, Beherith",
			normalmaps = "yes",
			normaltex = "unittextures/chicken_l_normals.png",
			paralyzemultiplier = 0,
		},
		sfxtypes = {
			crashexplosiongenerators = {
				[1] = "crashing-small",
				[2] = "crashing-small",
				[3] = "crashing-small2",
				[4] = "crashing-small3",
				[5] = "crashing-small3",
			},
			explosiongenerators = {
				[1] = "custom:blood_spray",
				[2] = "custom:blood_explode",
				[3] = "custom:dirt",
			},
			pieceexplosiongenerators = {
				[1] = "blood_spray",
				[2] = "blood_spray",
				[3] = "blood_spray",
			},
		},
		weapondefs = {
			acidspit = {
				accuracy = 1024,
				areaofeffect = 150,
				collidefriendly = 0,
				collidefeature = 0,
				avoidfeature = 0,
				avoidfriendly = 0,
				burst = 2,
				burstrate = 0.5,
				cegtag = "blob_trail_green",
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.63,
				explosiongenerator = "custom:acid-explosion-xl",
				impulseboost = 0,
				impulsefactor = 0.4,
				intensity = 0.7,
				interceptedbyshieldtype = 1,
				name = "GOOLAUNCHER",
				noselfdamage = true,
				range = 500,
				reloadtime = 3.6,
				rgbcolor = "0.8 0.99 0.11",
				nogap = false,
				size = 8,
				sizedecay = 0.03,
				alphaDecay = 0.14,
				stages = 9,
				soundhit = "bloodsplash3",
				soundstart = "alien_bombrel",
				sprayangle = 92,
				tolerance = 5000,
				turret = true,
				weapontimer = 0.2,
				weaponvelocity = 520,
				damage = {
					default = 1,
					shields = 160,
				},
				customparams = {
					area_duration = 10,
					area_ongoingCEG = "acid-area-150",
					area_damagedCEG = "acid-damage-gen",
					area_damageType = "acid",
				},
			},
			-- Note: Was previously missing its area damage.
			-- Values are assumed from other, similar units.
			acidspit_area_timed_damage = {
				areaofeffect = 150 * 2,
				explosiongenerator = "acid-damage", -- replace me
				damage = {
					default = 100,
					subs    = 100 / 10,
					vtol    = 100 / 10,
					walls   = 100 /  3,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL SPACE",
				def = "acidspit",
				maindir = "0 0 1",
				maxangledif = 125,
				onlytargetcategory = "NOTAIR",
			},
		},
	},
}

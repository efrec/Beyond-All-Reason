local unitDefReworks = {
	armstil = {
		weapons = {
			stiletto_bomb = {
				areaofeffect = 250,
				burst = 3,
				burstrate = 0.3333,
				edgeeffectiveness = 0.30,
				paralyzetime = 1,
				damage = { default = 3000 },
			},
		},
	},
	armspid = {
		weapons = {
			spider = {
				paralyzetime = 2,
				reloadtime = 1.495,
				damage = { vtol = 100, default = 600 },
			},
		},
	},
	armdfly = {
		weapons = {
			armdfly_paralyzer = {
				paralyzetime = 1,
				beamdecay = 0.05,
				beamtime = 0.1,
				areaofeffect = 8,
				targetmoveerror = 0.05,
			},
		},
	},
	armemp = {
		weapons = {
			armemp_weapon = {
				areaofeffect = 512,
				burstrate = 0.3333,
				edgeeffectiveness = -0.10,
				paralyzetime = 22,
				damage = { default = 60000 },
			},
		},
	},
	armshockwave = {
		weapons = {
			hllt_bottom = {
				areaofeffect = 150,
				edgeeffectiveness = 0.15,
				reloadtime = 1.4,
				paralyzetime = 5,
				damage = { default = 800 },
			},
		},
	},
	armthor = {
		weapons = {
			empmissile = {
				areaofeffect = 250,
				edgeeffectiveness = -0.50,
				paralyzetime = 5,
				damage = { default = 20000 },
			},
			emp = {
				reloadtime = 0.5,
				paralyzetime = 1,
				damage = { default = 200 },
			},
		},
	},
	corbw = {
		weapons = {
			bladewing_lyzer = {
				paralyzetime = 1,
				damage = { default = 300 },
			},
		},
	},
	--
	corfmd = { paralyzemultiplier = 1.5 },
	armamd = { paralyzemultiplier = 1.5 },
	cormabm = { paralyzemultiplier = 1.5 },
	armscab = { paralyzemultiplier = 1.5 },
	armvulc = { paralyzemultiplier = 2 },
	corbuzz = { paralyzemultiplier = 2 },
	legstarfall = { paralyzemultiplier = 2 },
	corsilo = { paralyzemultiplier = 2 },
	armsilo = { paralyzemultiplier = 2 },
	armmar = { paralyzemultiplier = 0.8 },
	armbanth = { paralyzemultiplier = 1.6 },
}

local weaponDefReworks = {
	empblast = {
		areaofeffect = 350,
		edgeeffectiveness = 0.6,
		paralyzetime = 12,
		damage = {
			default = 50000,
		},
	},
	spybombx = {
		areaofeffect = 350,
		edgeeffectiveness = 0.4,
		paralyzetime = 20,
		damage = {
			default = 16000,
		},
	},
	spybombxscav = {
		edgeeffectiveness = 0.50,
		paralyzetime = 12,
		damage = {
			default = 35000,
		},
	},
}

return {
	unitDefReworks = unitDefReworks,
	weaponDefReworks = weaponDefReworks,
}

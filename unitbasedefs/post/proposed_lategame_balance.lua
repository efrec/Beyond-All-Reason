local unitDefReworks = {
	armamb = {
		weapons = {
			armamb_gun = { reloadtime = 2 },
			armamb_gun_high = { reloadtime = 7.7 },
		},
	},
	cortoast = {
		weapons = {
			cortoast_gun = { reloadtime = 2.35 },
			cortoast_gun_high = { reloadtime = 8.8 },
		},
	},
	armpb = {
		weapons = {
			armpb_weapon = { reloadtime = 1.7, range = 700 },
		},
	},
	corvipe = {
		weapons = {
			vipersabot = { reloadtime = 2.1, range = 700 },
		},
	},
	armanni = { metalcost = 4000, energycost = 85000, buildtime = 59000 },
	corbhmth = { metalcost = 3600, energycost = 40000, buildtime = 70000 },
	armbrtha = { metalcost = 5000, energycost = 71000, buildtime = 94000 },
	corint = { metalcost = 5100, energycost = 74000, buildtime = 103000 },
	armvulc = { metalcost = 75600, energycost = 902400, buildtime = 1680000 },
	corbuzz = { metalcost = 73200, energycost = 861600, buildtime = 1680000 },
	armmar = { metalcost = 1070, energycost = 23000, buildtime = 28700 },
	armraz = { metalcost = 4200, energycost = 75000, buildtime = 97000 },
	armthor = { metalcost = 9450, energycost = 255000, buildtime = 265000 },
	corshiva = {
		metalcost = 1800,
		energycost = 26500,
		buildtime = 35000,
		speed = 50.8,
		weapons = {
			shiva_rocket = { tracks = true, turnrate = 7500 },
		},
	},
	corkarg = { metalcost = 2625, energycost = 60000, buildtime = 79000 },
	cordemon = { metalcost = 6300, energycost = 94500, buildtime = 94500 },
	armstil = {
		health = 1300,
		weapons = {
			stiletto_bomb = {
				burst = 3,
				burstrate = 0.2333,
				damage = { default = 3000 },
			},
		},
	},
	armlance = { health = 1750 },
	cortitan = { health = 1800 },
	armyork = {
		weapons = {
			mobileflak = { reloadtime = 0.8333 },
		},
	},
	corsent = {
		weapons = {
			mobileflak = { reloadtime = 0.8333 },
		},
	},
	armaas = {
		weapons = {
			mobileflak = { reloadtime = 0.8333 },
		},
	},
	corarch = {
		weapons = {
			mobileflak = { reloadtime = 0.8333 },
		},
	},
	armflak = {
		weapons = {
			armflak_gun = { reloadtime = 0.6 },
		},
	},
	corflak = {
		weapons = {
			armflak_gun = { reloadtime = 0.6 },
		},
	},
	armmercury = {
		weapons = {
			arm_advsam = { reloadtime = 11, stockpile = false },
		},
	},
	corscreamer = {
		weapons = {
			cor_advsam = { reloadtime = 11, stockpile = false },
		},
	},
	armfig = { metalcost = 77, energycost = 3100, buildtime = 3700 },
	armsfig = { metalcost = 95, energycost = 4750, buildtime = 5700 },
	armhawk = { metalcost = 155, energycost = 6300, buildtime = 9800 },
	corveng = { metalcost = 77, energycost = 3000, buildtime = 3600 },
	corsfig = { metalcost = 95, energycost = 4850, buildtime = 5400 },
	corvamp = { metalcost = 150, energycost = 5250, buildtime = 9250 },
}

return {
	unitDefReworks = unitDefReworks,
}

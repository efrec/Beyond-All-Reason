local armadaBasicSea = {
	"armgplat", -- Gun Platform - Light Plasma Defense
	"armfrock", -- Scumbag - Anti Air Missile Battery
}
local armadaAdvancedLand = {
	"armshockwave", -- Shockwave - T2 EMP Armed Metal Extractor
	"armwint2", -- T2 Wind Generator
	"armnanotct2", -- T2 Constructor Turret
	"armlwall", -- Dragon's Fury - T2 Pop-up Wall Turret
	"armgatet3", -- Asylum - Advanced Shield Generator
}
local armadaExperimental = {
	"armmeatball", -- Meatball - Amphibious Assault Mech
	"armassimilator", -- Assimilator - Amphibious Battle Mech
}
--
local cortexBasicSea = {
	"corgplat", -- Gun Platform - Light Plasma Defense
	"corfrock", -- Janitor - Anti Air Missile Battery
}
local cortexAdvancedLand = {
	"corwint2", -- T2 Wind Generator
	"cornanotct2", -- T2 Constructor Turret
	"cormwall", -- Dragon's Rage - T2 Pop-up Wall Turret
	"corgatet3", -- Sanctuary - Advanced Shield Generator
}
--
local legionAdvancedLand = {
	"legwint2", -- T2 Wind Generator
	"legnanotct2", -- T2 Constructor Turret
	"legrwall", -- Dragon's Constitution - T2 (not Pop-up) Wall Turret
	"leggatet3", -- Elysium - Advanced Shield Generator
}

local buildOptionsLists = {
	armcs = armadaBasicSea,
	armcsa = armadaBasicSea,
	armvp = { "armzapper" }, -- Zapper - Light EMP Vehicle
	armap = { "armfify" }, -- Firefly - Resurrection Aircraft
	armaca = armadaAdvancedLand,
	armack = armadaAdvancedLand,
	armacv = armadaAdvancedLand,
	armacsub = {
		"armfgate", -- Aurora - Floating Plasma Deflector
		"armnanotc2plat", -- Floating T2 Constructor Turret
	},
	armasy = {
		"armexcalibur", -- Excalibur - Coastal Assault Submarine
		"armseadragon", -- Seadragon - Nuclear ICBM Submarine
	},
	armshltx = armadaExperimental,
	armshltxuw = armadaExperimental,
	--
	corcs = cortexBasicSea,
	corcsa = cortexBasicSea,
	coraca = cortexAdvancedLand,
	corack = cortexAdvancedLand,
	coracv = cortexAdvancedLand,
	coracsub = {
		"corfgate", -- Atoll - Floating Plasma Deflector
		"cornanotc2plat", -- Floating T2 Constructor Turret
	},
	coralab = { "cordeadeye" }, -- Deadeye - Heavy Blaster Bot
	coravp = {
		"corvac", -- Printer - Armored Field Engineer
		"corphantom", -- Phantom - Amphibious Stealth Scout
		"corsiegebreaker", -- Siegebreaker - Heavy Long Range Destroyer
		"corforge", -- Forge - Flamethrower Combat Engineer
		"cortorch", -- Torch - Fast Flamethrower Tank
	},
	corasy = {
		"coresuppt3", -- Adjudictator - Heavy Heatray Battleship
		"coronager", -- Onager - Coastal Assault Submarine
		"cordesolator", -- Desolator - Nuclear ICBM Submarine
		"corprince", -- Black Prince - Shore bombardment battleship
	},
	--
	legaca = legionAdvancedLand,
	legack = legionAdvancedLand,
	lecacv = legionAdvancedLand,
	leganavyconsub = {
		"corfgate", -- Atoll - Floating Plasma Deflector
		"legnanotct2plat", -- Floating T2 Constructor Turret
	},
	leggant = { "legbunk" }, -- Pilum - Fast Assault Mech
}

return {
	buildOptionsLists = buildOptionsLists,
}
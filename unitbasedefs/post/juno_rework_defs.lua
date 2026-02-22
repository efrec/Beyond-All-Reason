local newJunoDefs = {
	metalcost = 500,
	energycost = 12000,
	buildtime = 15000,
	weapondefs = {
		juno_pulse = {
			energypershot = 7000,
			metalpershot = 100,
		},
	},
}

local unitDefReworks = {
	armjuno = newJunoDefs,
	corjuno = newJunoDefs,
	legjuno = newJunoDefs,
}

return {
	unitDefReworks = unitDefReworks,
}

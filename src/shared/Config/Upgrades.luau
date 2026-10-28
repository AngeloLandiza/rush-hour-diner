--!strict
-- The 13 upgrade levels (spec: station speed ×4, patience, seating ×3, tips ×2, auto-server, decor ×2).
-- Data only. Owner: agent B (costs/effects), balance pass G.
local Types = require("../Contracts/Types")

local Upgrades = {
	Defs = {
		GrillSpeed = {
			id = "GrillSpeed",
			displayName = "Turbo Grill",
			description = "Burgers cook faster.",
			order = 1,
			maxLevel = 1,
			costs = { 60 },
			effect = { kind = "StationSpeed", stationId = "Grill", multiplierPerLevel = 0.5 },
		},
		FryerSpeed = {
			id = "FryerSpeed",
			displayName = "Hot Oil",
			description = "Fries cook faster.",
			order = 2,
			maxLevel = 1,
			costs = { 350 },
			effect = { kind = "StationSpeed", stationId = "Fryer", multiplierPerLevel = 0.5 },
		},
		OvenSpeed = {
			id = "OvenSpeed",
			displayName = "Brick Oven",
			description = "Pizzas bake faster.",
			order = 3,
			maxLevel = 1,
			costs = { 1000 },
			effect = { kind = "StationSpeed", stationId = "Oven", multiplierPerLevel = 0.5 },
		},
		SodaSpeed = {
			id = "SodaSpeed",
			displayName = "Fizz Pump",
			description = "Drinks pour faster.",
			order = 4,
			maxLevel = 1,
			costs = { 200 },
			effect = { kind = "StationSpeed", stationId = "Soda", multiplierPerLevel = 0.5 },
		},
		Patience = {
			id = "Patience",
			displayName = "Comfy Music",
			description = "Customers wait longer before leaving.",
			order = 5,
			maxLevel = 1,
			costs = { 1100 },
			effect = { kind = "Patience", bonusPerLevel = 0.4 },
		},
		Seating = {
			id = "Seating",
			displayName = "More Seats",
			description = "Three more seats: more customers at once.",
			order = 6,
			maxLevel = 3,
			costs = { 700, 3000, 9000 },
			effect = { kind = "Seats", seatsPerLevel = 3 },
		},
		Tips = {
			id = "Tips",
			displayName = "Charm School",
			description = "Customers tip more.",
			order = 7,
			maxLevel = 2,
			costs = { 1800, 12000 },
			effect = { kind = "TipMultiplier", bonusPerLevel = 0.25 },
		},
		AutoServer = {
			id = "AutoServer",
			displayName = "Robo-Waiter",
			description = "A bot carries ready dishes to waiting customers.",
			order = 8,
			maxLevel = 1,
			costs = { 12500 },
			effect = { kind = "AutoServer" },
		},
		Decor = {
			id = "Decor",
			displayName = "Diner Makeover",
			description = "A fancier diner. Customers tip a bigger percentage.",
			order = 9,
			maxLevel = 2,
			costs = { 4000, 26000 },
			effect = { kind = "Decor", tipPctPerLevel = 0.1 },
		},
	} :: { [Types.UpgradeId]: Types.UpgradeDef },
}

return Upgrades

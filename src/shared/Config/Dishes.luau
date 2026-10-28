--!strict
-- Dish definitions and cook timings. Data only. Owner: agent B (numbers), balance pass G.
local Types = require("../Contracts/Types")

export type DishDef = {
	id: Types.DishId,
	displayName: string,
	stationId: Types.StationId,
	basePrice: number, -- coins before customer multiplier and tip
	cookSeconds: number, -- Cooking phase (before flip) at speed level 0
	flipWindowSeconds: number, -- NeedsFlip window; missing it burns the dish
	perfectSeconds: number, -- flip within this many seconds of the window opening = Perfect
	finishSeconds: number, -- Finishing phase (after flip) at speed level 0
	burnSeconds: number, -- Ready → Burnt if not collected
	unlockOrder: number,
}

local Dishes = {
	Defs = {
		Burger = {
			id = "Burger",
			displayName = "Burger",
			stationId = "Grill",
			basePrice = 10,
			cookSeconds = 3,
			flipWindowSeconds = 2.5,
			perfectSeconds = 0.8,
			finishSeconds = 2,
			burnSeconds = 8,
			unlockOrder = 1,
		},
		Fries = {
			id = "Fries",
			displayName = "Fries",
			stationId = "Fryer",
			basePrice = 8,
			cookSeconds = 2.5,
			flipWindowSeconds = 2.5,
			perfectSeconds = 0.8,
			finishSeconds = 1.5,
			burnSeconds = 8,
			unlockOrder = 2,
		},
		Pizza = {
			id = "Pizza",
			displayName = "Pizza",
			stationId = "Oven",
			basePrice = 16,
			cookSeconds = 5,
			flipWindowSeconds = 2.5,
			perfectSeconds = 0.8,
			finishSeconds = 3,
			burnSeconds = 8,
			unlockOrder = 3,
		},
		Drink = {
			id = "Drink",
			displayName = "Soda",
			stationId = "Soda",
			basePrice = 5,
			cookSeconds = 1.5,
			flipWindowSeconds = 2.5,
			perfectSeconds = 0.8,
			finishSeconds = 1,
			burnSeconds = 10,
			unlockOrder = 4,
		},
	} :: { [Types.DishId]: DishDef },
}

return Dishes

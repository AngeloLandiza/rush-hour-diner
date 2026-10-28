--!strict
-- Customer kinds, legendary customers and outfit pools. Data only. Owner: agent B (numbers).
-- The WeeklyMeme legendary is driven entirely by this table: edit it for each weekly content drop.
-- Colors are Palette keys (Config/Palette), never raw values.
local Types = require("../Contracts/Types")

export type KindDef = {
	kind: Types.CustomerKind,
	displayName: string,
	spawnWeight: number, -- relative weight among non-legendary spawns
	payMultiplier: number,
	patienceMultiplier: number,
}

export type LegendaryDef = {
	id: Types.LegendaryId,
	displayName: string,
	announcement: string, -- "{owner}" is replaced with the plot owner's name
	payMultiplier: number,
	tipBonus: number, -- extra tip fraction added on top of the normal tip
	patienceMultiplier: number,
	scale: number, -- character scale (Giant Chef is big)
	bodyColor: string, -- Palette key
	accentColor: string, -- Palette key
	favoriteDish: Types.DishId?, -- always orders this if set
	enabled: boolean,
}

local Customers = {
	Kinds = {
		Regular = {
			kind = "Regular",
			displayName = "Customer",
			spawnWeight = 80,
			payMultiplier = 1,
			patienceMultiplier = 1,
		},
		Hungry = {
			kind = "Hungry",
			displayName = "Hungry Customer",
			spawnWeight = 15,
			payMultiplier = 1.5,
			patienceMultiplier = 0.6,
		},
		VIP = { kind = "VIP", displayName = "VIP", spawnWeight = 5, payMultiplier = 3, patienceMultiplier = 1 },
	} :: { [string]: KindDef },

	-- Chance per spawn that the customer is legendary (Rush Hour multiplies it by RushLegendaryMultiplier).
	LegendaryChance = 0.005,
	RushLegendaryMultiplier = 3,

	Legendary = {
		GiantChef = {
			id = "GiantChef",
			displayName = "The Giant Chef",
			announcement = "THE GIANT CHEF has arrived at {owner}'s diner!",
			payMultiplier = 10,
			tipBonus = 2,
			patienceMultiplier = 1.5,
			scale = 2.2,
			bodyColor = "Cream",
			accentColor = "Ketchup",
			favoriteDish = "Burger",
			enabled = true,
		},
		SpaceAlien = {
			id = "SpaceAlien",
			displayName = "Space Alien",
			announcement = "A SPACE ALIEN landed at {owner}'s diner!",
			payMultiplier = 12,
			tipBonus = 2.5,
			patienceMultiplier = 1.5,
			scale = 1.1,
			bodyColor = "Mint",
			accentColor = "NeonPink",
			favoriteDish = "Drink",
			enabled = true,
		},
		WeeklyMeme = {
			id = "WeeklyMeme",
			displayName = "Sir Sandwich",
			announcement = "SIR SANDWICH demands a table at {owner}'s diner!",
			payMultiplier = 15,
			tipBonus = 3,
			patienceMultiplier = 1.5,
			scale = 1.3,
			bodyColor = "Mustard",
			accentColor = "Ink",
			favoriteDish = nil,
			enabled = true,
		},
	} :: { [Types.LegendaryId]: LegendaryDef },

	-- Free catalog items for randomized Regular outfits (asset ids, 0 = skip). Agent C fills.
	OutfitPools = {
		Shirts = { 0 },
		Pants = { 0 },
		Hats = { 0 },
		SkinTones = { "Cream", "Mustard" }, -- Palette keys
	},
}

return Customers

--!strict
-- Game passes and developer products. id = 0 is a placeholder until created in the Creator Hub.
-- PurchaseService must treat id 0 as "not configured" (never prompt, never grant).
local Types = require("../Contracts/Types")

local Products = {
	Passes = {
		TipsX2 = {
			id = 2056805455,
			displayName = "2× Tips",
			description = "Double every tip, forever.",
			priceRobux = 199,
		},
		AutoChef = {
			id = 2058335526,
			displayName = "Auto-Chef",
			description = "Your diner earns coins while you are AFK in game.",
			priceRobux = 299,
		},
		ExtraStation = {
			id = 2058521453,
			displayName = "Extra Station Slot",
			description = "A second grill in your kitchen.",
			priceRobux = 249,
		},
		VIPBooth = {
			id = 2060776676,
			displayName = "VIP Booth",
			description = "A glowing VIP booth and a VIP chat tag.",
			priceRobux = 149,
		},
	} :: { [Types.PassKey]: Types.PassDef },

	Products = {
		InstantRestock = {
			id = 3723283330,
			displayName = "Instant Restock",
			description = "Collect a full 8 hours of restock earnings now.",
			priceRobux = 49,
		},
		RushHourNow = {
			id = 3723283333,
			displayName = "Rush Hour Now!",
			description = "Start a Rush Hour for the whole server. Everyone sees your name.",
			priceRobux = 99,
		},
		TipPotion = {
			id = 3723283335,
			displayName = "Tip Potion",
			description = "+50% tips for 15 minutes.",
			priceRobux = 39,
			boost = "TipPotion",
			boostSeconds = 15 * 60,
		},
		CoinsSmall = {
			id = 3723283327,
			displayName = "Pile of Coins",
			description = "500 coins to spend on your diner.",
			priceRobux = 25,
			coins = 500,
		},
		CoinsMedium = {
			id = 3723283326,
			displayName = "Bag of Coins",
			description = "2,500 coins to spend on your diner.",
			priceRobux = 99,
			coins = 2500,
		},
		CoinsLarge = {
			id = 3723283323,
			displayName = "Vault of Coins",
			description = "11,000 coins to spend on your diner.",
			priceRobux = 399,
			coins = 11000,
		},
		-- Reward for an opt-in rewarded video ad. Only ever granted through AdService (never listed in the
		-- shop); Roblox requires a price above 0, so it is set to the minimum.
		AdTipBoost = {
			id = 3723283881,
			displayName = "Ad Tip Boost",
			description = "+25% tips for 10 minutes.",
			priceRobux = 1,
			boost = "AdTipBoost",
			boostSeconds = 10 * 60,
		},
	} :: { [Types.ProductKey]: Types.ProductDef },

	-- Tip fraction each boost adds while active.
	BoostTipPct = {
		TipPotion = 0.5,
		AdTipBoost = 0.25,
	} :: { [Types.BoostKey]: number },
}

return Products

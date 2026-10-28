--!strict
-- Game passes and developer products. id = 0 is a placeholder until created in the Creator Hub.
-- PurchaseService must treat id 0 as "not configured" (never prompt, never grant).
local Types = require("../Contracts/Types")

local Products = {
	Passes = {
		TipsX2 = { id = 0, displayName = "2× Tips", description = "Double every tip, forever.", priceRobux = 199 },
		AutoChef = {
			id = 0,
			displayName = "Auto-Chef",
			description = "Your diner earns coins while you are AFK in game.",
			priceRobux = 299,
		},
		ExtraStation = {
			id = 0,
			displayName = "Extra Station Slot",
			description = "A second grill in your kitchen.",
			priceRobux = 249,
		},
		VIPBooth = {
			id = 0,
			displayName = "VIP Booth",
			description = "A glowing VIP booth and a VIP chat tag.",
			priceRobux = 149,
		},
	} :: { [Types.PassKey]: Types.PassDef },

	Products = {
		InstantRestock = {
			id = 0,
			displayName = "Instant Restock",
			description = "Collect a full 8 hours of restock earnings now.",
			priceRobux = 49,
		},
		RushHourNow = {
			id = 0,
			displayName = "Rush Hour Now!",
			description = "Start a Rush Hour for the whole server. Everyone sees your name.",
			priceRobux = 99,
		},
		TipPotion = {
			id = 0,
			displayName = "Tip Potion",
			description = "+50% tips for 15 minutes.",
			priceRobux = 39,
			boost = "TipPotion",
			boostSeconds = 15 * 60,
		},
		CoinsSmall = { id = 0, displayName = "Pile of Coins", description = "", priceRobux = 25, coins = 500 },
		CoinsMedium = { id = 0, displayName = "Bag of Coins", description = "", priceRobux = 99, coins = 2500 },
		CoinsLarge = { id = 0, displayName = "Vault of Coins", description = "", priceRobux = 399, coins = 11000 },
		-- Free product used as the reward for an opt-in rewarded video ad.
		AdTipBoost = {
			id = 0,
			displayName = "Ad Tip Boost",
			description = "+25% tips for 10 minutes.",
			priceRobux = 0,
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

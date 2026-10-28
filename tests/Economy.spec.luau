--!strict
local TestLib = require("../tools/testlib")
local describe, it, expect = TestLib.describe, TestLib.it, TestLib.expect
local Economy = require("../src/shared/Logic/Economy")
local EconomyConfig = require("../src/shared/Config/Economy")
local Customers = require("../src/shared/Config/Customers")
local Dishes = require("../src/shared/Config/Dishes")
local Products = require("../src/shared/Config/Products")
local Types = require("../src/shared/Contracts/Types")

local tip = EconomyConfig.Tip
local PATIENCE = 40

-- Slow serve, Good quality, regular customer, solo, no boosts: the tip is BaseFraction × MinSpeedFactor.
local function ctx(overrides: { [string]: any }?): Types.PayoutContext
	local c: any = {
		dishId = "Burger",
		kind = "Regular",
		legendaryId = nil,
		waitSeconds = PATIENCE,
		patienceSeconds = PATIENCE,
		quality = "Good",
		combo = 0,
		ownerUpgrades = {},
		crewSize = 1,
		rushHour = false,
		hasTipsPass = false,
		tipBoostPct = 0,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

local slowFraction = tip.BaseFraction * tip.MinSpeedFactor
local fastFraction = tip.BaseFraction * tip.MaxSpeedFactor
local price = Dishes.Defs.Burger.basePrice

describe("Economy.computePayout base", function()
	it("regular slow serve", function()
		local p = Economy.computePayout(ctx())
		expect(p.base).toBe(price)
		expect(p.tip).toBeNear(price * slowFraction)
		expect(p.tipFraction).toBeNear(slowFraction)
		expect(p.total).toBe(math.floor(price * (1 + slowFraction) + 0.5))
	end)
	it("hungry pays its multiplier and VIP too", function()
		expect(Economy.computePayout(ctx({ kind = "Hungry" })).base).toBe(price * Customers.Kinds.Hungry.payMultiplier)
		expect(Economy.computePayout(ctx({ kind = "VIP" })).base).toBe(price * Customers.Kinds.VIP.payMultiplier)
	end)
	it("legendary uses its multiplier and tip bonus", function()
		local def = Customers.Legendary.GiantChef
		local p = Economy.computePayout(ctx({ kind = "Legendary", legendaryId = "GiantChef" }))
		expect(p.base).toBe(price * def.payMultiplier)
		expect(p.tipFraction).toBeNear(slowFraction + def.tipBonus)
	end)
	it("legendary tips dwarf normal tips", function()
		local normal = Economy.computePayout(ctx({ waitSeconds = 0 }))
		local legend = Economy.computePayout(ctx({ kind = "Legendary", legendaryId = "SpaceAlien", waitSeconds = 0 }))
		expect(legend.tip).toBeGreaterThan(normal.tip * 20)
	end)
end)

describe("Economy.computePayout tip", function()
	it("instant serve gets the max speed factor", function()
		expect(Economy.computePayout(ctx({ waitSeconds = 0 })).tipFraction).toBeNear(fastFraction)
	end)
	it("serve at the fast fraction keeps the max factor", function()
		local p = Economy.computePayout(ctx({ waitSeconds = PATIENCE * tip.FastFraction }))
		expect(p.tipFraction).toBeNear(fastFraction)
	end)
	it("speed factor falls linearly to the minimum", function()
		local mid = PATIENCE * (tip.FastFraction + 1) / 2
		local p = Economy.computePayout(ctx({ waitSeconds = mid }))
		expect(p.tipFraction).toBeNear(tip.BaseFraction * (tip.MaxSpeedFactor + tip.MinSpeedFactor) / 2)
	end)
	it("waiting beyond patience clamps at the minimum", function()
		expect(Economy.computePayout(ctx({ waitSeconds = PATIENCE * 5 })).tipFraction).toBeNear(slowFraction)
	end)
	it("zero patience does not divide by zero", function()
		local p = Economy.computePayout(ctx({ patienceSeconds = 0, waitSeconds = 0 }))
		expect(p.tipFraction).toBeNear(slowFraction)
	end)
	it("Perfect adds a bonus", function()
		local p = Economy.computePayout(ctx({ quality = "Perfect" }))
		expect(p.tipFraction).toBeNear(slowFraction + tip.PerfectBonus)
	end)
	it("Burnt dishes earn no tip", function()
		local p = Economy.computePayout(ctx({ quality = "Burnt", waitSeconds = 0 }))
		expect(p.tip).toBe(0)
		expect(p.total).toBe(price)
	end)
	it("combo scales the tip", function()
		local p = Economy.computePayout(ctx({ combo = 5 }))
		expect(p.tipFraction).toBeNear(slowFraction * (1 + EconomyConfig.Combo.BonusPerStep * 5))
	end)
	it("combo bonus is capped at MaxCombo", function()
		local a = Economy.computePayout(ctx({ combo = EconomyConfig.Combo.MaxCombo }))
		local b = Economy.computePayout(ctx({ combo = EconomyConfig.Combo.MaxCombo + 50 }))
		expect(b.tipFraction).toBeNear(a.tipFraction)
	end)
	it("decor and tips upgrades apply", function()
		local p = Economy.computePayout(ctx({ ownerUpgrades = { Decor = 2, Tips = 2 } }))
		local decor = 2 * 0.1
		local expected = (slowFraction + decor) * (1 + 2 * 0.25)
		expect(p.tipFraction).toBeNear(expected, 1e-9)
	end)
	it("TipsX2 pass doubles the tip but not the base", function()
		local a = Economy.computePayout(ctx())
		local b = Economy.computePayout(ctx({ hasTipsPass = true }))
		expect(b.base).toBe(a.base)
		expect(b.tip).toBeNear(a.tip * EconomyConfig.TipsPassMultiplier)
	end)
	it("tip boosts add to tips", function()
		local a = Economy.computePayout(ctx())
		local b = Economy.computePayout(ctx({ tipBoostPct = 0.75 }))
		expect(b.tip).toBeNear(a.tip * 1.75)
	end)
	it("negative boosts are ignored", function()
		local a = Economy.computePayout(ctx())
		local b = Economy.computePayout(ctx({ tipBoostPct = -3 }))
		expect(b.tip).toBeNear(a.tip)
	end)
end)

describe("Economy.computePayout totals", function()
	it("rush hour doubles pay", function()
		local a = Economy.computePayout(ctx({ waitSeconds = 0 }))
		local b = Economy.computePayout(ctx({ waitSeconds = 0, rushHour = true }))
		expect(b.total).toBe(math.floor((a.base + a.tip) * EconomyConfig.RushHour.PayMultiplier + 0.5))
		expect(b.tip).toBeNear(a.tip) -- tip itself is not scaled; total is
	end)
	it("crew multiplier applies to the total", function()
		local solo = Economy.computePayout(ctx({ kind = "VIP", waitSeconds = 0 }))
		local crew = Economy.computePayout(ctx({ kind = "VIP", waitSeconds = 0, crewSize = 4 }))
		expect(crew.total).toBe(math.floor((solo.base + solo.tip) * 1.3 + 0.5))
	end)
	it("rounds half up and is an integer", function()
		-- Burnt: tip 0, so total = round(base * mults).
		local p = Economy.computePayout(ctx({ quality = "Burnt", dishId = "Drink", crewSize = 2 })) -- 5 * 1.1 = 5.5
		expect(p.total).toBe(6)
		expect(p.total % 1).toBe(0)
	end)
	it("total is at least 1", function()
		local original = Dishes.Defs.Drink.basePrice
		Dishes.Defs.Drink.basePrice = 0.1
		local p = Economy.computePayout(ctx({ dishId = "Drink", quality = "Burnt" }))
		Dishes.Defs.Drink.basePrice = original
		expect(p.total).toBe(1)
	end)
	it("combo output follows nextCombo", function()
		expect(Economy.computePayout(ctx({ waitSeconds = 1, combo = 3 })).combo).toBe(4)
		expect(Economy.computePayout(ctx({ waitSeconds = PATIENCE, combo = 3 })).combo).toBe(0)
	end)
	it("stacks everything", function()
		local c = ctx({
			kind = "VIP",
			waitSeconds = 0,
			quality = "Perfect",
			combo = 2,
			ownerUpgrades = { Tips = 1, Decor = 1 },
			crewSize = 3,
			rushHour = true,
			hasTipsPass = true,
			tipBoostPct = 0.5,
		})
		local p = Economy.computePayout(c)
		local base = price * 3
		local frac = (fastFraction + tip.PerfectBonus + 0.1) * 1.2 * 1.25 * 2 * 1.5
		expect(p.base).toBe(base)
		expect(p.tipFraction).toBeNear(frac, 1e-9)
		expect(p.total).toBe(math.floor((base + base * frac) * 2 * 1.2 + 0.5))
	end)
end)

describe("Economy.crewMultiplier", function()
	it("solo is 1, each member adds 10%", function()
		expect(Economy.crewMultiplier(1)).toBe(1)
		expect(Economy.crewMultiplier(2)).toBeNear(1.1)
		expect(Economy.crewMultiplier(3)).toBeNear(1.2)
		expect(Economy.crewMultiplier(4)).toBeNear(1.3)
	end)
	it("caps at +30%", function()
		expect(Economy.crewMultiplier(10)).toBeNear(1.3)
	end)
	it("never goes below 1", function()
		expect(Economy.crewMultiplier(0)).toBe(1)
		expect(Economy.crewMultiplier(-3)).toBe(1)
	end)
end)

describe("Economy.nextCombo", function()
	it("increments on a fast serve", function()
		expect(Economy.nextCombo(0, 5, 40)).toBe(1)
		expect(Economy.nextCombo(4, 5, 40)).toBe(5)
	end)
	it("the window boundary is inclusive", function()
		expect(Economy.nextCombo(1, 40 * EconomyConfig.Combo.WindowFraction, 40)).toBe(2)
		expect(Economy.nextCombo(1, 40 * EconomyConfig.Combo.WindowFraction + 0.01, 40)).toBe(0)
	end)
	it("resets on a slow serve", function()
		expect(Economy.nextCombo(7, 39, 40)).toBe(0)
	end)
	it("caps at MaxCombo", function()
		expect(Economy.nextCombo(EconomyConfig.Combo.MaxCombo, 1, 40)).toBe(EconomyConfig.Combo.MaxCombo)
		expect(Economy.nextCombo(EconomyConfig.Combo.MaxCombo - 1, 1, 40)).toBe(EconomyConfig.Combo.MaxCombo)
	end)
end)

describe("Economy.tipBoostPct", function()
	it("sums active boosts", function()
		local boosts: { [Types.BoostKey]: number } = { TipPotion = 200, AdTipBoost = 200 }
		expect(Economy.tipBoostPct(boosts, 100)).toBeNear(
			Products.BoostTipPct.TipPotion + Products.BoostTipPct.AdTipBoost
		)
	end)
	it("ignores expired boosts, expiry is exclusive", function()
		local boosts: { [Types.BoostKey]: number } = { TipPotion = 100, AdTipBoost = 99 }
		expect(Economy.tipBoostPct(boosts, 100)).toBe(0)
		expect(Economy.tipBoostPct({ TipPotion = 101 }, 100)).toBeNear(Products.BoostTipPct.TipPotion)
	end)
	it("empty is zero", function()
		expect(Economy.tipBoostPct({}, 5)).toBe(0)
	end)
end)

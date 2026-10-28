--!strict
local TestLib = require("../tools/testlib")
local describe, it, expect = TestLib.describe, TestLib.it, TestLib.expect

local Orders = require("../src/shared/Logic/Orders")
local Customers = require("../src/shared/Config/Customers")
local Timings = require("../src/shared/Config/Timings")

local function seq(values: { number }): () -> number
	local i = 0
	return function()
		i += 1
		return values[math.min(i, #values)]
	end
end

describe("Orders.rollKind", function()
	it("rolls legendary below the chance", function()
		local kind, id = Orders.rollKind(seq({ Customers.LegendaryChance - 0.0001, 0 }), false)
		expect(kind).toBe("Legendary")
		expect(id).toBe("GiantChef")
	end)
	it("does not roll legendary at exactly the chance", function()
		local kind, id = Orders.rollKind(seq({ Customers.LegendaryChance, 0 }), false)
		expect(kind).toBe("Regular")
		expect(id).toBe(nil)
	end)
	it("rush multiplies the legendary chance", function()
		local roll = Customers.LegendaryChance * 2
		local calm = Orders.rollKind(seq({ roll, 0 }), false)
		local rush, id = Orders.rollKind(seq({ roll, 0.99 }), true)
		expect(calm).toBe("Regular")
		expect(rush).toBe("Legendary")
		expect(id).toBe("WeeklyMeme")
	end)
	it("picks each legendary by the second roll", function()
		local _, a = Orders.rollKind(seq({ 0, 0 }), false)
		local _, b = Orders.rollKind(seq({ 0, 0.5 }), false)
		local _, c = Orders.rollKind(seq({ 0, 0.99 }), false)
		expect(a).toBe("GiantChef")
		expect(b).toBe("SpaceAlien")
		expect(c).toBe("WeeklyMeme")
	end)
	it("skips disabled legendaries", function()
		local def = Customers.Legendary.GiantChef
		def.enabled = false
		local _, id = Orders.rollKind(seq({ 0, 0 }), false)
		def.enabled = true
		expect(id).toBe("SpaceAlien")
	end)
	it("never returns legendary when none are enabled", function()
		local saved = {}
		for id, def in Customers.Legendary do
			saved[id] = def.enabled
			def.enabled = false
		end
		local kind = Orders.rollKind(seq({ 0, 0 }), true)
		for id, def in Customers.Legendary do
			def.enabled = saved[id]
		end
		expect(kind).toBe("Regular")
	end)
	it("weighted kinds follow spawn weights", function()
		local hi = 0.99
		expect((Orders.rollKind(seq({ hi, 0 }), false))).toBe("Regular")
		expect((Orders.rollKind(seq({ hi, 0.79 }), false))).toBe("Regular")
		expect((Orders.rollKind(seq({ hi, 0.85 }), false))).toBe("Hungry")
		expect((Orders.rollKind(seq({ hi, 0.999 }), false))).toBe("VIP")
	end)
	it("distribution roughly matches weights over a seeded run", function()
		local state = 12345
		local counts = { Regular = 0, Hungry = 0, VIP = 0, Legendary = 0 }
		for _ = 1, 20000 do
			local kind = Orders.rollKind(function()
				state = (state * 1103515245 + 12345) % 2147483648
				return state / 2147483648
			end, false)
			counts[kind] += 1
		end
		expect(counts.Regular).toBeGreaterThan(15000)
		expect(counts.Hungry).toBeGreaterThan(2000)
		expect(counts.VIP).toBeGreaterThan(500)
	end)
end)

describe("Orders.pickDish", function()
	local all = { "Burger", "Fries", "Pizza", "Drink" } :: { any }
	it("legendary orders its favorite when available", function()
		expect(Orders.pickDish(seq({ 0 }), "Legendary", "SpaceAlien", all)).toBe("Drink")
	end)
	it("legendary falls back to random when the favorite is unavailable", function()
		expect(Orders.pickDish(seq({ 0 }), "Legendary", "SpaceAlien", { "Burger", "Pizza" } :: any)).toBe("Burger")
	end)
	it("legendary without favorite picks randomly", function()
		expect(Orders.pickDish(seq({ 0.99 }), "Legendary", "WeeklyMeme", all)).toBe("Drink")
	end)
	it("regular picks uniformly by rng", function()
		expect(Orders.pickDish(seq({ 0 }), "Regular", nil, all)).toBe("Burger")
		expect(Orders.pickDish(seq({ 0.26 }), "Regular", nil, all)).toBe("Fries")
		expect(Orders.pickDish(seq({ 0.999999 }), "VIP", nil, all)).toBe("Drink")
	end)
end)

describe("Orders.patienceSeconds", function()
	it("regular is the base", function()
		expect(Orders.patienceSeconds("Regular", nil, {})).toBe(Timings.Customers.BasePatienceSeconds)
	end)
	it("hungry is shorter", function()
		expect(Orders.patienceSeconds("Hungry", nil, {})).toBeLessThan(Timings.Customers.BasePatienceSeconds)
	end)
	it("legendary uses its multiplier", function()
		local def = Customers.Legendary.GiantChef
		expect(Orders.patienceSeconds("Legendary", "GiantChef", {})).toBeNear(
			Timings.Customers.BasePatienceSeconds * def.patienceMultiplier
		)
	end)
	it("patience upgrade stretches it", function()
		expect(Orders.patienceSeconds("Regular", nil, { Patience = 1 })).toBeGreaterThan(
			Orders.patienceSeconds("Regular", nil, {})
		)
	end)
end)

describe("Orders.spawnInterval", function()
	it("includes the rush multiplier", function()
		expect(Orders.spawnInterval(false)).toBe(Timings.Customers.SpawnIntervalSeconds)
		expect(Orders.spawnInterval(true)).toBeNear(
			Timings.Customers.SpawnIntervalSeconds / Timings.RushHour.SpawnMultiplier
		)
	end)
end)

describe("Orders.remainingPatience", function()
	it("counts down and goes negative", function()
		local order = { dishId = "Burger" :: any, placedAt = 100, patienceSeconds = 45 }
		expect(Orders.remainingPatience(order, 100)).toBe(45)
		expect(Orders.remainingPatience(order, 130)).toBe(15)
		expect(Orders.remainingPatience(order, 150)).toBe(-5)
	end)
end)

--!strict
-- Smoke test: every Logic and Config module loads in Lune (no Roblox services allowed in Logic).
local TestLib = require("../tools/testlib")
local describe, it, expect = TestLib.describe, TestLib.it, TestLib.expect

describe("smoke", function()
	it("loads all Logic modules", function()
		for _, name in { "Economy", "Orders", "Upgrades", "Offline", "Streak", "Schedule", "Cooking" } do
			expect(type(require(`../src/shared/Logic/{name}`))).toBe("table")
		end
	end)

	it("loads pure Config modules", function()
		for _, name in { "Stations", "Dishes", "Upgrades", "Customers", "Economy", "Products", "Timings", "Audio" } do
			expect(type(require(`../src/shared/Config/{name}`))).toBe("table")
		end
	end)

	it("has 13 upgrade levels in total", function()
		local Upgrades = require("../src/shared/Config/Upgrades")
		local total = 0
		for _, def in Upgrades.Defs do
			total += def.maxLevel
			expect(#def.costs).toBe(def.maxLevel)
		end
		expect(total).toBe(13)
	end)
end)

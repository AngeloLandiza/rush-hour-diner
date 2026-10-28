--!strict
local TestLib = require("../tools/testlib")
local describe, it, expect = TestLib.describe, TestLib.it, TestLib.expect

local Streak = require("../src/shared/Logic/Streak")
local EconomyConfig = require("../src/shared/Config/Economy")

local DAY = 86400
local T0 = 100 * DAY + 5000

describe("Streak", function()
	it("dayIndex floors to UTC days", function()
		expect(Streak.dayIndex(0)).toBe(0)
		expect(Streak.dayIndex(DAY - 1)).toBe(0)
		expect(Streak.dayIndex(DAY)).toBe(1)
	end)
	it("a new player can claim and starts at day 1", function()
		local fresh = { day = 0, lastClaimDay = 0 }
		expect(Streak.canClaim(fresh, T0)).toBe(true)
		local s, reward = Streak.claim(fresh, T0)
		expect(s.day).toBe(1)
		expect(s.lastClaimDay).toBe(100)
		expect(reward).toBe(EconomyConfig.StreakRewards[1])
	end)
	it("cannot claim twice the same day and returns the same streak", function()
		local s = { day = 3, lastClaimDay = 100 }
		expect(Streak.canClaim(s, T0 + 10)).toBe(false)
		local s2, reward = Streak.claim(s, T0 + 10)
		expect(s2).toBe(s)
		expect(reward).toBe(0)
	end)
	it("consecutive day advances", function()
		local s, reward = Streak.claim({ day = 2, lastClaimDay = 99 }, T0)
		expect(s.day).toBe(3)
		expect(reward).toBe(EconomyConfig.StreakRewards[3])
	end)
	it("missing a day resets to day 1", function()
		local s, reward = Streak.claim({ day = 5, lastClaimDay = 98 }, T0)
		expect(s.day).toBe(1)
		expect(reward).toBe(EconomyConfig.StreakRewards[1])
	end)
	it("day 7 cycles back to day 1", function()
		local s, reward = Streak.claim({ day = 7, lastClaimDay = 99 }, T0)
		expect(s.day).toBe(1)
		expect(reward).toBe(EconomyConfig.StreakRewards[1])
	end)
	it("reaches day 7 reward", function()
		local s, reward = Streak.claim({ day = 6, lastClaimDay = 99 }, T0)
		expect(s.day).toBe(7)
		expect(reward).toBe(EconomyConfig.StreakRewards[7])
	end)
	it("does not mutate the input", function()
		local input = { day = 2, lastClaimDay = 99 }
		Streak.claim(input, T0)
		expect(input.day).toBe(2)
		expect(input.lastClaimDay).toBe(99)
	end)
	it("walks a full 8 day run", function()
		local s = { day = 0, lastClaimDay = 0 }
		local days = {}
		for i = 0, 7 do
			local reward
			s, reward = Streak.claim(s, (100 + i) * DAY)
			table.insert(days, s.day)
		end
		expect(days).toEqual({ 1, 2, 3, 4, 5, 6, 7, 1 })
	end)
end)

--!strict
-- PURE daily streak rules (days 1..7, then cycles). No Roblox services. Owner: agent B.
local Types = require("../Contracts/Types")
local EconomyConfig = require("../Config/Economy")

local Streak = {}

-- Unix day index (UTC).
function Streak.dayIndex(now: number): number
	return now // EconomyConfig.Time.SecondsPerDay
end

-- True if a reward can be claimed today.
function Streak.canClaim(streak: Types.StreakData, now: number): boolean
	return streak.lastClaimDay < Streak.dayIndex(now)
end

-- Claims today's reward. Missing a day resets to day 1. Day 7 cycles back to day 1.
-- Returns the new streak and coins rewarded; the unchanged streak and 0 if already claimed today.
function Streak.claim(streak: Types.StreakData, now: number): (Types.StreakData, number)
	if not Streak.canClaim(streak, now) then
		return streak, 0
	end
	local today = Streak.dayIndex(now)
	local rewards = EconomyConfig.StreakRewards
	local day = 1
	if streak.day >= 1 and streak.lastClaimDay == today - 1 then
		day = streak.day % #rewards + 1
	end
	return { day = day, lastClaimDay = today }, rewards[day]
end

return Streak

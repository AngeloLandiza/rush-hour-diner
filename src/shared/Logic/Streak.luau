--!strict
-- PURE daily streak rules (days 1..7, then cycles). No Roblox services. Owner: agent B.
local Types = require("../Contracts/Types")

local Streak = {}

-- Unix day index (UTC).
function Streak.dayIndex(now: number): number
	return now // 86400
end

-- True if a reward can be claimed today.
function Streak.canClaim(streak: Types.StreakData, now: number): boolean
	return streak.lastClaimDay < Streak.dayIndex(now)
end

-- Claims today's reward. Missing a day resets to day 1. Returns the new streak and coins rewarded.
-- Returns the unchanged streak and 0 if already claimed today.
function Streak.claim(streak: Types.StreakData, now: number): (Types.StreakData, number)
	return streak, 0
end

return Streak

--!strict
-- PURE wall-clock schedules: hourly Rush Hour and the weekly menu drop. No Roblox services. Owner: agent B.
local Types = require("../Contracts/Types")
local Timings = require("../Config/Timings")
local EconomyConfig = require("../Config/Economy")

local Schedule = {}

-- Scheduled Rush Hour state at time now (ignores purchased "Rush Hour Now"; RushHourService layers that).
function Schedule.rushHourState(now: number): Types.RushHourState
	local cfg = Timings.RushHour
	local into = (now - cfg.OffsetSeconds) % cfg.IntervalSeconds
	local startedAt = now - into
	local nextAt = startedAt + cfg.IntervalSeconds
	if into < cfg.DurationSeconds then
		return { active = true, startedAt = startedAt, endsAt = startedAt + cfg.DurationSeconds, nextAt = nextAt }
	end
	return { active = false, nextAt = nextAt }
end

-- Unix time of the next scheduled Rush Hour start strictly after now.
function Schedule.nextRushHourAt(now: number): number
	return Schedule.rushHourState(now).nextAt
end

-- Unix time of the next weekly menu drop strictly after now (Config/Timings.MenuDrop).
function Schedule.nextMenuDropAt(now: number): number
	local t = EconomyConfig.Time
	local dayStart = now // t.SecondsPerDay * t.SecondsPerDay
	local weekday = (now // t.SecondsPerDay + t.EpochWeekday) % t.DaysPerWeek
	local daysUntil = (Timings.MenuDrop.Weekday - weekday) % t.DaysPerWeek
	local candidate = dayStart + daysUntil * t.SecondsPerDay + Timings.MenuDrop.HourUTC * t.SecondsPerHour
	if candidate <= now then
		candidate += t.DaysPerWeek * t.SecondsPerDay
	end
	return candidate
end

return Schedule

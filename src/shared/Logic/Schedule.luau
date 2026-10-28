--!strict
-- PURE wall-clock schedules: hourly Rush Hour and the weekly menu drop. No Roblox services. Owner: agent B.
local Types = require("../Contracts/Types")

local Schedule = {}

-- Scheduled Rush Hour state at time now (ignores purchased "Rush Hour Now"; RushHourService layers that).
function Schedule.rushHourState(now: number): Types.RushHourState
	return { active = false, nextAt = now + 3600 }
end

-- Unix time of the next scheduled Rush Hour start strictly after now.
function Schedule.nextRushHourAt(now: number): number
	return now + 3600
end

-- Unix time of the next weekly menu drop strictly after now (Config/Timings.MenuDrop).
function Schedule.nextMenuDropAt(now: number): number
	return now + 7 * 86400
end

return Schedule

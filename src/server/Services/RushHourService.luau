--!strict
-- Hourly Rush Hour scheduler (+ purchased "Rush Hour Now"). Owner: agent C.
-- Fires Events.RushHourStarted/Ended and broadcasts RushHourState.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local RushHourService = {}

function RushHourService.Init() end

function RushHourService.Start() end

function RushHourService.GetState(): Types.RushHourState
	return { active = false, nextAt = os.time() + 3600 }
end

function RushHourService.IsActive(): boolean
	return false
end

-- Starts a Rush Hour now (purchased). Returns false if one is already active.
function RushHourService.TriggerNow(buyer: Player?): boolean
	return false
end

-- Spawn-rate multiplier right now (1, or Timings.RushHour.SpawnMultiplier while active).
function RushHourService.GetSpawnMultiplier(): number
	return 1
end

return RushHourService

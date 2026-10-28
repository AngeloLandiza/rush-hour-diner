--!strict
-- Global lifetime-coins OrderedDataStore + per-server best Rush Hour. Owner: agent A.
-- Broadcasts LeaderboardUpdate. Maintains leaderstats (Coins).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local LeaderboardService = {}

function LeaderboardService.Init() end

function LeaderboardService.Start() end

function LeaderboardService.GetSnapshot(): Types.LeaderboardSnapshot
	return { lifetime = {}, rushHour = {} }
end

return LeaderboardService

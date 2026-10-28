--!strict
-- PURE offline-earnings ("ingredient restock") math. No Roblox services. Owner: agent B.
local Types = require("../Contracts/Types")
local EconomyConfig = require("../Config/Economy")
local Upgrades = require("./Upgrades")

type Levels = { [Types.UpgradeId]: number }

local Offline = {}

local function perMinute(levels: Levels): number
	local cfg = EconomyConfig.Offline
	return cfg.BaseCoinsPerMinute + cfg.CoinsPerMinutePerUpgradeLevel * Upgrades.totalLevels(levels)
end

local function accrue(levels: Levels, seconds: number): number
	return math.floor(math.max(seconds, 0) / EconomyConfig.Time.SecondsPerMinute * perMinute(levels))
end

function Offline.coinsPerMinute(levels: Levels): number
	return perMinute(levels)
end

-- Coins collectable now, capped at Config/Economy.Offline.CapSeconds of accrual. Integer >= 0.
function Offline.pending(lastRestock: number, now: number, levels: Levels): number
	local elapsed = math.clamp(now - lastRestock, 0, EconomyConfig.Offline.CapSeconds)
	return accrue(levels, elapsed)
end

-- A full capped restock (Instant Restock product).
function Offline.fullRestock(levels: Levels): number
	return accrue(levels, EconomyConfig.Offline.CapSeconds)
end

-- In-game AFK income for the Auto-Chef pass over `seconds`. Integer >= 0.
function Offline.autoChefIncome(levels: Levels, seconds: number): number
	return math.floor(accrue(levels, seconds) * EconomyConfig.Offline.AutoChefMultiplier)
end

return Offline

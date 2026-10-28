--!strict
-- PURE offline-earnings ("ingredient restock") math. No Roblox services. Owner: agent B.
local Types = require("../Contracts/Types")

type Levels = { [Types.UpgradeId]: number }

local Offline = {}

function Offline.coinsPerMinute(levels: Levels): number
	return 0
end

-- Coins collectable now, capped at Config/Economy.Offline.CapSeconds of accrual. Integer >= 0.
function Offline.pending(lastRestock: number, now: number, levels: Levels): number
	return 0
end

-- A full capped restock (Instant Restock product).
function Offline.fullRestock(levels: Levels): number
	return 0
end

-- In-game AFK income for the Auto-Chef pass over `seconds`. Integer >= 0.
function Offline.autoChefIncome(levels: Levels, seconds: number): number
	return 0
end

return Offline

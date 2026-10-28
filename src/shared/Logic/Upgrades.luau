--!strict
-- PURE upgrade rules and derived effects. No Roblox services. Owner: agent B. Signatures are a contract.
local Types = require("../Contracts/Types")

type Levels = { [Types.UpgradeId]: number }

local Upgrades = {}

function Upgrades.getLevel(levels: Levels, id: Types.UpgradeId): number
	return levels[id] or 0
end

-- Price of the next level, or nil if maxed / unknown id.
function Upgrades.nextCost(levels: Levels, id: Types.UpgradeId): number?
	return nil
end

-- Whether the player can buy the next level of id. reason: "Unknown" | "Maxed" | "TooPoor".
function Upgrades.canBuy(levels: Levels, coins: number, id: Types.UpgradeId): (boolean, string?)
	return false, "Unknown"
end

-- Cook-time divisor for a station (1 = base speed).
function Upgrades.stationSpeedMultiplier(levels: Levels, stationId: Types.StationId): number
	return 1
end

function Upgrades.seatCount(levels: Levels): number
	return 2
end

function Upgrades.patienceMultiplier(levels: Levels): number
	return 1
end

function Upgrades.tipMultiplier(levels: Levels): number
	return 1
end

-- 0..2
function Upgrades.decorTier(levels: Levels): number
	return levels.Decor or 0
end

-- Extra tip fraction from decor.
function Upgrades.decorTipPct(levels: Levels): number
	return 0
end

function Upgrades.hasAutoServer(levels: Levels): boolean
	return (levels.AutoServer or 0) > 0
end

-- Sum of all purchased levels (0..13).
function Upgrades.totalLevels(levels: Levels): number
	local n = 0
	for _, level in levels do
		n += level
	end
	return n
end

return Upgrades

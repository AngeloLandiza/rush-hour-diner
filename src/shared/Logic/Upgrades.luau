--!strict
-- PURE upgrade rules and derived effects. No Roblox services. Owner: agent B. Signatures are a contract.
local Types = require("../Contracts/Types")
local UpgradeConfig = require("../Config/Upgrades")
local Timings = require("../Config/Timings")

type Levels = { [Types.UpgradeId]: number }

local Upgrades = {}

function Upgrades.getLevel(levels: Levels, id: Types.UpgradeId): number
	return levels[id] or 0
end

-- Purchased level of id, clamped to the def's max (guards against corrupt saves).
local function effectiveLevel(levels: Levels, def: Types.UpgradeDef): number
	return math.clamp(levels[def.id] or 0, 0, def.maxLevel)
end

-- Price of the next level, or nil if maxed / unknown id.
function Upgrades.nextCost(levels: Levels, id: Types.UpgradeId): number?
	local def = UpgradeConfig.Defs[id]
	if def == nil then
		return nil
	end
	local level = Upgrades.getLevel(levels, id)
	if level >= def.maxLevel then
		return nil
	end
	return def.costs[level + 1]
end

-- Whether the player can buy the next level of id. reason: "Unknown" | "Maxed" | "TooPoor".
function Upgrades.canBuy(levels: Levels, coins: number, id: Types.UpgradeId): (boolean, string?)
	local def = UpgradeConfig.Defs[id]
	if def == nil then
		return false, "Unknown"
	end
	local cost = Upgrades.nextCost(levels, id)
	if cost == nil then
		return false, "Maxed"
	end
	if coins < cost then
		return false, "TooPoor"
	end
	return true, nil
end

-- Cook-time divisor for a station (1 = base speed).
function Upgrades.stationSpeedMultiplier(levels: Levels, stationId: Types.StationId): number
	local mult = 1
	for _, def in UpgradeConfig.Defs do
		local effect = def.effect
		if effect.kind == "StationSpeed" and effect.stationId == stationId then
			mult += effect.multiplierPerLevel * effectiveLevel(levels, def)
		end
	end
	return mult
end

function Upgrades.seatCount(levels: Levels): number
	local seats = Timings.Seats.Base
	for _, def in UpgradeConfig.Defs do
		local effect = def.effect
		if effect.kind == "Seats" then
			seats += effect.seatsPerLevel * effectiveLevel(levels, def)
		end
	end
	return math.min(seats, Timings.Seats.Max)
end

function Upgrades.patienceMultiplier(levels: Levels): number
	local mult = 1
	for _, def in UpgradeConfig.Defs do
		local effect = def.effect
		if effect.kind == "Patience" then
			mult += effect.bonusPerLevel * effectiveLevel(levels, def)
		end
	end
	return mult
end

function Upgrades.tipMultiplier(levels: Levels): number
	local mult = 1
	for _, def in UpgradeConfig.Defs do
		local effect = def.effect
		if effect.kind == "TipMultiplier" then
			mult += effect.bonusPerLevel * effectiveLevel(levels, def)
		end
	end
	return mult
end

-- 0..2
function Upgrades.decorTier(levels: Levels): number
	local tier = 0
	for _, def in UpgradeConfig.Defs do
		if def.effect.kind == "Decor" then
			tier += effectiveLevel(levels, def)
		end
	end
	return tier
end

-- Extra tip fraction from decor.
function Upgrades.decorTipPct(levels: Levels): number
	local pct = 0
	for _, def in UpgradeConfig.Defs do
		local effect = def.effect
		if effect.kind == "Decor" then
			pct += effect.tipPctPerLevel * effectiveLevel(levels, def)
		end
	end
	return pct
end

function Upgrades.hasAutoServer(levels: Levels): boolean
	for _, def in UpgradeConfig.Defs do
		if def.effect.kind == "AutoServer" and effectiveLevel(levels, def) > 0 then
			return true
		end
	end
	return false
end

-- Sum of all purchased levels (0..13).
function Upgrades.totalLevels(levels: Levels): number
	local n = 0
	for _, def in UpgradeConfig.Defs do
		n += effectiveLevel(levels, def)
	end
	return n
end

return Upgrades

--!strict
-- PURE payout math. No Roblox services. Owner: agent B. Signatures are a contract (see ARCHITECTURE.md).
local Types = require("../Contracts/Types")
local Customers = require("../Config/Customers")
local Dishes = require("../Config/Dishes")
local EconomyConfig = require("../Config/Economy")
local Products = require("../Config/Products")
local Upgrades = require("./Upgrades")

local Economy = {}

local function kindMultiplier(kind: Types.CustomerKind, legendaryId: Types.LegendaryId?): (number, number)
	if kind == "Legendary" and legendaryId ~= nil then
		local def = Customers.Legendary[legendaryId]
		if def then
			return def.payMultiplier, def.tipBonus
		end
	end
	local def = Customers.Kinds[kind]
	if def then
		return def.payMultiplier, 0
	end
	return 1, 0
end

-- Tip speed factor: MaxSpeedFactor for fast serves, easing down to MinSpeedFactor at the end of patience.
local function speedFactor(waitSeconds: number, patienceSeconds: number): number
	local tip = EconomyConfig.Tip
	if patienceSeconds <= 0 then
		return tip.MinSpeedFactor
	end
	local ratio = math.clamp(waitSeconds / patienceSeconds, 0, 1)
	if ratio <= tip.FastFraction then
		return tip.MaxSpeedFactor
	end
	local t = (ratio - tip.FastFraction) / (1 - tip.FastFraction)
	return tip.MaxSpeedFactor + (tip.MinSpeedFactor - tip.MaxSpeedFactor) * t
end

-- Full payout for one serve. total is an integer >= 1.
function Economy.computePayout(ctx: Types.PayoutContext): Types.Payout
	local tipCfg = EconomyConfig.Tip
	local dish = Dishes.Defs[ctx.dishId]
	local payMult, legendaryTip = kindMultiplier(ctx.kind, ctx.legendaryId)
	local base = dish.basePrice * payMult

	local fraction = tipCfg.BaseFraction * speedFactor(ctx.waitSeconds, ctx.patienceSeconds)
	if ctx.quality == "Perfect" then
		fraction += tipCfg.PerfectBonus
	end
	fraction += legendaryTip + Upgrades.decorTipPct(ctx.ownerUpgrades)
	fraction *= 1 + EconomyConfig.Combo.BonusPerStep * math.clamp(ctx.combo, 0, EconomyConfig.Combo.MaxCombo)
	fraction *= Upgrades.tipMultiplier(ctx.ownerUpgrades)
	if ctx.hasTipsPass then
		fraction *= EconomyConfig.TipsPassMultiplier
	end
	fraction *= 1 + math.max(ctx.tipBoostPct, 0)
	if ctx.quality == "Burnt" then
		fraction *= 1 - tipCfg.BurntPenalty
	end

	local tip = base * fraction
	local rush = if ctx.rushHour then EconomyConfig.RushHour.PayMultiplier else 1
	local total = math.max(1, math.floor((base + tip) * rush * Economy.crewMultiplier(ctx.crewSize) + 0.5))

	return {
		base = base,
		tip = tip,
		total = total,
		tipFraction = tip / base,
		combo = Economy.nextCombo(ctx.combo, ctx.waitSeconds, ctx.patienceSeconds),
	}
end

-- Coin multiplier for players on a plot (1 = solo). crewSize includes the owner.
function Economy.crewMultiplier(crewSize: number): number
	local crew = EconomyConfig.Crew
	local members = math.max(crewSize - 1, 0)
	return 1 + math.min(members * crew.BonusPerMember, crew.MaxBonus)
end

-- Combo after a serve: increments when served fast enough, else resets to 0. Capped.
function Economy.nextCombo(combo: number, waitSeconds: number, patienceSeconds: number): number
	local cfg = EconomyConfig.Combo
	if waitSeconds <= patienceSeconds * cfg.WindowFraction then
		return math.min(combo + 1, cfg.MaxCombo)
	end
	return 0
end

-- Sum of active timed tip boosts (Config/Products.BoostTipPct) at time now.
function Economy.tipBoostPct(boosts: { [Types.BoostKey]: number }, now: number): number
	local sum = 0
	for key, expiry in boosts do
		local pct: number? = (Products.BoostTipPct :: any)[key]
		if pct ~= nil and expiry > now then
			sum += pct
		end
	end
	return sum
end

return Economy

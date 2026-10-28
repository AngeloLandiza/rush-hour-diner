--!strict
-- PURE payout math. No Roblox services. Owner: agent B. Signatures are a contract (see ARCHITECTURE.md).
local Types = require("../Contracts/Types")

local Economy = {}

-- Full payout for one serve. total is an integer >= 1.
function Economy.computePayout(ctx: Types.PayoutContext): Types.Payout
	-- TODO(agent B): implement per Config/Economy + Config/Customers + Logic/Upgrades.
	return { base = 1, tip = 0, total = 1, tipFraction = 0, combo = 0 }
end

-- Coin multiplier for players on a plot (1 = solo). crewSize includes the owner.
function Economy.crewMultiplier(crewSize: number): number
	return 1
end

-- Combo after a serve: increments when served fast enough, else resets to 0. Capped.
function Economy.nextCombo(combo: number, waitSeconds: number, patienceSeconds: number): number
	return 0
end

-- Sum of active timed tip boosts (Config/Products.BoostTipPct) at time now.
function Economy.tipBoostPct(boosts: { [Types.BoostKey]: number }, now: number): number
	return 0
end

return Economy

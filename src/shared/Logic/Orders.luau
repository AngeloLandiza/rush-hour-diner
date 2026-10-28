--!strict
-- PURE customer/order rules. No Roblox services. Owner: agent B. Signatures are a contract.
-- rng is a function returning a float in [0, 1) so tests can be deterministic.
local Types = require("../Contracts/Types")

local Orders = {}

-- Roll the kind of the next customer. Returns a LegendaryId when kind == "Legendary".
function Orders.rollKind(rng: () -> number, rushHour: boolean): (Types.CustomerKind, Types.LegendaryId?)
	return "Regular", nil
end

-- Pick the dish a customer orders from the dishes the plot can cook.
function Orders.pickDish(
	rng: () -> number,
	kind: Types.CustomerKind,
	legendaryId: Types.LegendaryId?,
	available: { Types.DishId }
): Types.DishId
	return available[1]
end

-- Total patience for a new order given the plot owner's upgrades.
function Orders.patienceSeconds(
	kind: Types.CustomerKind,
	legendaryId: Types.LegendaryId?,
	ownerUpgrades: { [Types.UpgradeId]: number }
): number
	return 45
end

-- Seconds between customer spawns on one plot.
function Orders.spawnInterval(rushHour: boolean): number
	return 8
end

-- Seconds of patience left (can be negative once expired).
function Orders.remainingPatience(order: Types.Order, now: number): number
	return order.placedAt + order.patienceSeconds - now
end

return Orders

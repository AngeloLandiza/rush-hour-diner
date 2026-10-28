--!strict
-- PURE customer/order rules. No Roblox services. Owner: agent B. Signatures are a contract.
-- rng is a function returning a float in [0, 1) so tests can be deterministic.
local Types = require("../Contracts/Types")
local Customers = require("../Config/Customers")
local Timings = require("../Config/Timings")
local Upgrades = require("./Upgrades")

local Orders = {}

local function enabledLegendaries(): { string }
	local ids = {}
	for id, def in Customers.Legendary do
		if def.enabled then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

-- Kinds ordered by weight (heaviest first, then name) so rolls are deterministic.
local function orderedKinds(): { Customers.KindDef }
	local list = {}
	for _, def in Customers.Kinds do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		if a.spawnWeight ~= b.spawnWeight then
			return a.spawnWeight > b.spawnWeight
		end
		return a.kind < b.kind
	end)
	return list
end

-- Roll the kind of the next customer. Returns a LegendaryId when kind == "Legendary".
function Orders.rollKind(rng: () -> number, rushHour: boolean): (Types.CustomerKind, Types.LegendaryId?)
	local chance = Customers.LegendaryChance * (if rushHour then Customers.RushLegendaryMultiplier else 1)
	local legendaries = enabledLegendaries()
	if #legendaries > 0 and rng() < chance then
		local index = math.min(math.floor(rng() * #legendaries) + 1, #legendaries)
		return "Legendary", legendaries[index]
	end
	local kinds = orderedKinds()
	local total = 0
	for _, def in kinds do
		total += def.spawnWeight
	end
	local roll = rng() * total
	for _, def in kinds do
		roll -= def.spawnWeight
		if roll < 0 then
			return def.kind, nil
		end
	end
	return kinds[#kinds].kind, nil
end

-- Pick the dish a customer orders from the dishes the plot can cook.
function Orders.pickDish(
	rng: () -> number,
	kind: Types.CustomerKind,
	legendaryId: Types.LegendaryId?,
	available: { Types.DishId }
): Types.DishId
	assert(#available > 0, "pickDish needs at least one available dish")
	if kind == "Legendary" and legendaryId ~= nil then
		local def = Customers.Legendary[legendaryId]
		local favorite = if def then def.favoriteDish else nil
		if favorite ~= nil and table.find(available, favorite) ~= nil then
			return favorite :: Types.DishId
		end
	end
	local index = math.min(math.floor(rng() * #available) + 1, #available)
	return available[index]
end

-- Total patience for a new order given the plot owner's upgrades.
function Orders.patienceSeconds(
	kind: Types.CustomerKind,
	legendaryId: Types.LegendaryId?,
	ownerUpgrades: { [Types.UpgradeId]: number }
): number
	local multiplier = 1
	if kind == "Legendary" and legendaryId ~= nil then
		local def = Customers.Legendary[legendaryId]
		if def then
			multiplier = def.patienceMultiplier
		end
	else
		local def = Customers.Kinds[kind]
		if def then
			multiplier = def.patienceMultiplier
		end
	end
	return Timings.Customers.BasePatienceSeconds * multiplier * Upgrades.patienceMultiplier(ownerUpgrades)
end

-- Seconds between customer spawns on one plot (includes the Rush Hour spawn multiplier).
function Orders.spawnInterval(rushHour: boolean): number
	local interval = Timings.Customers.SpawnIntervalSeconds
	if rushHour then
		return interval / Timings.RushHour.SpawnMultiplier
	end
	return interval
end

-- Seconds of patience left (can be negative once expired).
function Orders.remainingPatience(order: Types.Order, now: number): number
	return order.placedAt + order.patienceSeconds - now
end

return Orders

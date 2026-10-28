--!strict
-- Deterministic economy simulator. Run: lune run tools/econ_sim
-- Models ONE solo player on one plot using the real Logic modules and Config, and prints the
-- time to each upgrade for a free player and a TipsX2-pass player. Exits non-zero if the
-- free-player targets (first upgrade < 2 min, all 13 in 6-8 h, first cycle < 3 min) are missed.
--
-- Assumptions (all documented here, tweak the constants below):
--  * One cook at a time. Each serve cycle = WalkSeconds + HoldSeconds + cook + FlipReactionSeconds
--    + finish + serve overhead. The player always flips inside the Perfect window (reaction < perfect).
--  * With the Robo-Waiter (AutoServer) the carry/serve walk overhead is removed (bot delivers).
--  * Customers arrive every Orders.spawnInterval(rush) seconds, limited by seatCount; a full diner
--    drops the arrival. Seats stay occupied for EatSeconds after a serve.
--  * The player serves the customer with the least remaining patience that they can still reach.
--  * Rush Hour is the real hourly 4-minute window starting at a fixed fake UTC time (the join
--    offset below). Free play starts at SessionStartOffsetSeconds into the hour.
--  * No streak, no restock, no purchases other than greedy cheapest-affordable upgrades.
--  * Player is continuously active (an upper bound on pace; real play has breaks, so the target
--    window 6-8 h is for ~ continuous play).
local process = require("@lune/process")
local Economy = require("../src/shared/Logic/Economy")
local Orders = require("../src/shared/Logic/Orders")
local Cooking = require("../src/shared/Logic/Cooking")
local Schedule = require("../src/shared/Logic/Schedule")
local Upgrades = require("../src/shared/Logic/Upgrades")
local UpgradeConfig = require("../src/shared/Config/Upgrades")
local Dishes = require("../src/shared/Config/Dishes")
local Timings = require("../src/shared/Config/Timings")
local Stations = require("../src/shared/Config/Stations")

-- ── Sim constants (not game tuning) ─────────────────────────────────────────
local WALK_SECONDS = 4 -- walk customer -> station and pick up the order
local HOLD_SECONDS = 0.5 -- press-and-hold to start
local FLIP_REACTION_SECONDS = 0.5 -- reaction time to the flip prompt (< perfectSeconds => Perfect)
local SERVE_WALK_SECONDS = 4 -- carry the dish to the customer (0 with AutoServer)
local SEED = 20240601
local SESSION_START_OFFSET = 1800 -- join half an hour into the hour
local HORIZON_SECONDS = 24 * 3600
local EPOCH = 1700000000 - (1700000000 % Timings.RushHour.IntervalSeconds)

-- Targets
local FIRST_UPGRADE_MAX = 120
local FIRST_CYCLE_MAX = 180
local ALL_MIN = 6 * 3600
local ALL_MAX = 8 * 3600

type Customer = { arrive: number, patience: number, kind: any, legendaryId: string?, dish: any, freeAt: number? }
type Result = {
	purchases: { { id: string, level: number, at: number } },
	firstCycleDone: number?,
	allAt: number?,
	coinsEarned: number,
	served: number,
	legendary: number,
}

-- xorshift-free LCG so runs are identical everywhere
local function makeRng(seed: number): () -> number
	local state = seed % 2147483647
	return function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function cycleSeconds(dishId: any, levels: { [string]: number }): number
	local sched = Cooking.schedule(dishId, levels)
	local serveWalk = if Upgrades.hasAutoServer(levels) then 0 else SERVE_WALK_SECONDS
	return WALK_SECONDS + HOLD_SECONDS + sched.cookSeconds + FLIP_REACTION_SECONDS + sched.finishSeconds + serveWalk
end

local function simulate(hasPass: boolean): Result
	local rng = makeRng(SEED)
	local levels: { [string]: number } = {}
	local result: Result =
		{ purchases = {}, firstCycleDone = nil, allAt = nil, coinsEarned = 0, served = 0, legendary = 0 }
	local dishes: { any } = {}
	for _, def in Stations.Defs do
		table.insert(dishes, def.dishId)
	end
	table.sort(dishes, function(a, b)
		return Dishes.Defs[a].unlockOrder < Dishes.Defs[b].unlockOrder
	end)

	local function isRush(t: number): boolean
		return Schedule.rushHourState(EPOCH + SESSION_START_OFFSET + t).active
	end

	local coins = 0
	local combo = 0
	local t = 0
	local seated: { Customer } = {}
	local nextArrival = Timings.Customers.FirstCustomerDelaySeconds

	local function admit(upTo: number)
		while nextArrival <= upTo do
			local at = nextArrival
			for i = #seated, 1, -1 do
				local c = seated[i]
				local free = c.freeAt
				if (free ~= nil and free <= at) or (free == nil and c.arrive + c.patience <= at) then
					table.remove(seated, i)
				end
			end
			if #seated < Upgrades.seatCount(levels) then
				local rush = isRush(at)
				local kind, legendaryId = Orders.rollKind(rng, rush)
				table.insert(seated, {
					arrive = at,
					patience = Orders.patienceSeconds(kind, legendaryId, levels),
					kind = kind,
					legendaryId = legendaryId,
					dish = Orders.pickDish(rng, kind, legendaryId, dishes),
					freeAt = nil,
				})
			end
			nextArrival = at + Orders.spawnInterval(isRush(at))
		end
	end

	local function buyUpgrades()
		while true do
			local bestId: string? = nil
			local bestCost = math.huge
			for id in UpgradeConfig.Defs do
				local cost = Upgrades.nextCost(levels, id)
				if cost ~= nil and cost <= coins and cost < bestCost then
					bestId, bestCost = id, cost
				end
			end
			if bestId == nil then
				return
			end
			coins -= bestCost
			levels[bestId] = (levels[bestId] or 0) + 1
			table.insert(result.purchases, { id = bestId, level = levels[bestId], at = t })
			if Upgrades.totalLevels(levels) == 13 and result.allAt == nil then
				result.allAt = t
			end
		end
	end

	while t < HORIZON_SECONDS and result.allAt == nil do
		admit(t)
		-- candidates: waiting (not eating) customers we can still finish in time
		local pick: Customer? = nil
		local pickDeadline = math.huge
		for _, c in seated do
			if c.freeAt == nil then
				local deadline = c.arrive + c.patience
				if deadline > t + cycleSeconds(c.dish, levels) and deadline < pickDeadline then
					pick, pickDeadline = c, deadline
				end
			end
		end
		if pick == nil then
			-- idle until something happens (next arrival), also drop expired
			for i = #seated, 1, -1 do
				local c = seated[i]
				if c.freeAt == nil and c.arrive + c.patience <= t then
					table.remove(seated, i)
				end
			end
			t = math.max(nextArrival, t + 0.01)
			continue
		end
		local customer: Customer = pick
		t += cycleSeconds(customer.dish, levels)
		local wait = t - customer.arrive
		local payout = Economy.computePayout({
			dishId = customer.dish,
			kind = customer.kind,
			legendaryId = customer.legendaryId,
			waitSeconds = wait,
			patienceSeconds = customer.patience,
			quality = "Perfect",
			combo = combo,
			ownerUpgrades = levels,
			crewSize = 1,
			rushHour = isRush(t),
			hasTipsPass = hasPass,
			tipBoostPct = 0,
		})
		combo = payout.combo
		coins += payout.total
		result.coinsEarned += payout.total
		result.served += 1
		if customer.kind == "Legendary" then
			result.legendary += 1
		end
		if result.firstCycleDone == nil then
			result.firstCycleDone = t
		end
		customer.freeAt = t + Timings.Customers.EatSeconds
		buyUpgrades()
	end
	return result
end

local function fmtTime(s: number?): string
	if s == nil then
		return "never"
	end
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = math.floor(s % 60)
	return string.format("%dh%02dm%02ds", h, m, sec)
end

local free = simulate(false)
local pass = simulate(true)

print("Rush Hour Diner economy sim (solo, continuous play, seed " .. SEED .. ")")
print(string.format("%-3s %-12s %-3s %-12s %-12s", "#", "Upgrade", "Lv", "Free", "TipsX2"))
for i, p in free.purchases do
	local other = pass.purchases[i]
	print(
		string.format(
			"%-3d %-12s %-3d %-12s %-12s",
			i,
			p.id,
			p.level,
			fmtTime(p.at),
			other and fmtTime(other.at) or "-"
		)
	)
end
print(string.format("Time to all 13: free %s | TipsX2 %s", fmtTime(free.allAt), fmtTime(pass.allAt)))
print(
	string.format(
		"Served: free %d (%d legendary) | pass %d | first cycle done at %s",
		free.served,
		free.legendary,
		pass.served,
		fmtTime(free.firstCycleDone)
	)
)

local failures = {}
local first = free.purchases[1]
if first == nil or first.at > FIRST_UPGRADE_MAX then
	table.insert(failures, `first upgrade must come in under {FIRST_UPGRADE_MAX}s`)
end
if free.firstCycleDone == nil or free.firstCycleDone > FIRST_CYCLE_MAX then
	table.insert(failures, `first cook-to-serve cycle must finish under {FIRST_CYCLE_MAX}s`)
end
if free.allAt == nil or free.allAt < ALL_MIN or free.allAt > ALL_MAX then
	table.insert(failures, "all 13 upgrades must take 6-8h for a free player")
end
if pass.allAt ~= nil and free.allAt ~= nil and pass.allAt > free.allAt then
	table.insert(failures, "the TipsX2 pass must not be slower than free")
end
if #failures > 0 then
	for _, f in failures do
		print("TARGET MISSED: " .. f)
	end
	process.exit(1)
end
print("All targets met.")

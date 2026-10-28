--!strict
-- Deterministic economy simulator. Run: lune run tools/econ_sim
-- Models ONE solo player on one plot using the real Logic modules and Config, and prints the
-- time to each upgrade for a free player and a TipsX2-pass player. Exits non-zero if the
-- free-player targets (first upgrade < 2 min, all 13 in 6-8 h, first cycle < 3 min) are missed.
--
-- Assumptions (all documented here, tweak the constants below):
--  * One cook at a time. Each serve cycle = PICKUP + HOLD + cook + FLIP_REACTION + finish + serve
--    overhead. The player always flips inside the Perfect window (reaction < perfect).
--  * GEOMETRY (110x90 plots, WalkSpeed Timings.Customers.WalkSpeed = 12): CustomerSpawn -> Door is
--    SPAWN_TO_DOOR studs; Door -> seat is DOOR_TO_STOOL (seat 1) up to DOOR_TO_FARTHEST (seat 12),
--    interpolated by seat index. A customer takes its seat slot the moment it spawns, starts its
--    patience clock when it sits (spawn + walk time) and can be served only once seated.
--  * Seats 1..STOOL_SEATS are counter stools served across the counter (STOOL_REACH studs from the
--    pass, the player barely moves). Seats above that are booths / a high-top: the player walks
--    TABLE_WALK studs each way (return trip included in the serve overhead). Customers take the
--    lowest free seat, so stools fill first.
--  * With the Robo-Waiter (AutoServer) the serve overhead is removed (the bot delivers).
--  * Customers arrive every Orders.spawnInterval(rush) seconds, limited by the real seat count from
--    the upgrades (Upgrades.seatCount); a full diner drops the arrival (the real game also queues
--    MaxQueuedPerPlot customers; ignored here, which is slightly pessimistic). Seats stay occupied
--    for EatSeconds after a serve.
--  * The player serves the seated customer with the least remaining patience that they can still reach.
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
local Offline = require("../src/shared/Logic/Offline")
local EconomyConfig = require("../src/shared/Config/Economy")
local CustomerConfig = require("../src/shared/Config/Customers")
local Products = require("../src/shared/Config/Products")

-- ── Sim constants (not game tuning) ─────────────────────────────────────────
local PICKUP_SECONDS = 3 -- hop between stations, collect the dish, check the next ticket
local HOLD_SECONDS = 0.5 -- press-and-hold to start
local FLIP_REACTION_SECONDS = 0.5 -- reaction time to the flip prompt (< perfectSeconds => Perfect)
local SERVE_INTERACT_SECONDS = 0.5 -- the serve prompt itself
local SPAWN_TO_DOOR = 40 -- studs, CustomerSpawn -> Door
local DOOR_TO_STOOL = 18 -- studs, Door -> counter stool (seat 1)
local DOOR_TO_FARTHEST = 33 -- studs, Door -> farthest seat (seat 12)
local STOOL_SEATS = 5 -- seats 1..5 are counter stools
local STOOL_REACH = 7 -- studs, kitchen pass -> stool (served across the counter)
local TABLE_WALK = 16.5 -- studs, one way, counter end -> booth / high-top (15-18)
local SEED = 20240601
local SESSION_START_OFFSET = 1800 -- join half an hour into the hour
local HORIZON_SECONDS = 24 * 3600
local EPOCH = 1700000000 - (1700000000 % Timings.RushHour.IntervalSeconds)

-- Targets
local FIRST_UPGRADE_MAX = 120
local FIRST_CYCLE_MAX = 180
local FIRST_COOK_MAX = 60 -- FirstCustomerDelay + walk to the first stool
local LEGEND_MIN_LO = 2.5 -- "about 3-5 minutes", measured against a noisy smoothed rate
local LEGEND_MIN_HI = 5.5
local ALL_MIN = 6 * 3600
local ALL_MAX = 8 * 3600

type Customer = {
	arrive: number,
	seatedAt: number,
	seat: number,
	patience: number,
	kind: any,
	legendaryId: string?,
	dish: any,
	freeAt: number?,
}
type Result = {
	purchases: { { id: string, level: number, at: number, earned: number, levels: { [string]: number } } },
	firstCycleDone: number?,
	arrivals: number,
	bySeats: { [number]: { arrivals: number, dropped: number } },
	dropped: number,
	abandoned: number,
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

local WALK_SPEED = Timings.Customers.WalkSpeed

-- Seconds from spawn until a customer is sitting in `seat` (1-based).
local function arrivalWalkSeconds(seat: number): number
	local frac = (seat - 1) / math.max(Timings.Seats.Max - 1, 1)
	local doorToSeat = DOOR_TO_STOOL + (DOOR_TO_FARTHEST - DOOR_TO_STOOL) * frac
	return (SPAWN_TO_DOOR + doorToSeat) / WALK_SPEED
end

-- Player time to hand a dish to `seat` and be ready for the next ticket (0 with the bot).
local function serveSeconds(seat: number, levels: { [string]: number }): number
	if Upgrades.hasAutoServer(levels) then
		return 0
	end
	local studsRoundTrip = if seat <= STOOL_SEATS then 2 * STOOL_REACH else 2 * TABLE_WALK
	return studsRoundTrip / WALK_SPEED + SERVE_INTERACT_SECONDS
end

local function cycleSeconds(dishId: any, seat: number, levels: { [string]: number }): number
	local sched = Cooking.schedule(dishId, levels)
	return PICKUP_SECONDS
		+ HOLD_SECONDS
		+ sched.cookSeconds
		+ FLIP_REACTION_SECONDS
		+ sched.finishSeconds
		+ serveSeconds(seat, levels)
end

local function simulate(hasPass: boolean): Result
	local rng = makeRng(SEED)
	local levels: { [string]: number } = {}
	local result: Result = {
		purchases = {},
		firstCycleDone = nil,
		arrivals = 0,
		bySeats = {},
		dropped = 0,
		abandoned = 0,
		allAt = nil,
		coinsEarned = 0,
		served = 0,
		legendary = 0,
	}
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

	-- Remove customers who finished eating or ran out of patience by time `at`.
	local function reap(at: number)
		for i = #seated, 1, -1 do
			local c = seated[i]
			local free = c.freeAt
			if free ~= nil and free <= at then
				table.remove(seated, i)
			elseif free == nil and c.seatedAt + c.patience <= at then
				result.abandoned += 1
				table.remove(seated, i)
			end
		end
	end

	local function admit(upTo: number)
		while nextArrival <= upTo do
			local at = nextArrival
			reap(at)
			result.arrivals += 1
			local seatCount = Upgrades.seatCount(levels)
			local taken: { [number]: boolean } = {}
			for _, c in seated do
				taken[c.seat] = true
			end
			local bucket = result.bySeats[seatCount] or { arrivals = 0, dropped = 0 }
			result.bySeats[seatCount] = bucket
			bucket.arrivals += 1
			local seat = 0
			for i = 1, seatCount do
				if not taken[i] then
					seat = i
					break
				end
			end
			if seat > 0 then
				local rush = isRush(at)
				local kind, legendaryId = Orders.rollKind(rng, rush)
				table.insert(seated, {
					arrive = at,
					seatedAt = at + arrivalWalkSeconds(seat),
					seat = seat,
					patience = Orders.patienceSeconds(kind, legendaryId, levels),
					kind = kind,
					legendaryId = legendaryId,
					dish = Orders.pickDish(rng, kind, legendaryId, dishes),
					freeAt = nil,
				})
			else
				result.dropped += 1
				bucket.dropped += 1
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
			local snapshot: { [string]: number } = {}
			for k, v in levels do
				snapshot[k] = v
			end
			table.insert(
				result.purchases,
				{ id = bestId, level = levels[bestId], at = t, earned = result.coinsEarned, levels = snapshot }
			)
			if Upgrades.totalLevels(levels) == 13 and result.allAt == nil then
				result.allAt = t
			end
		end
	end

	while t < HORIZON_SECONDS and result.allAt == nil do
		admit(t)
		reap(t)
		-- candidates: seated, waiting (not eating) customers we can still finish in time
		local pick: Customer? = nil
		local pickDeadline = math.huge
		local nextEvent = nextArrival
		for _, c in seated do
			if c.freeAt == nil then
				if c.seatedAt > t then
					nextEvent = math.min(nextEvent, c.seatedAt)
				else
					local deadline = c.seatedAt + c.patience
					if deadline > t + cycleSeconds(c.dish, c.seat, levels) and deadline < pickDeadline then
						pick, pickDeadline = c, deadline
					end
				end
			end
		end
		if pick == nil then
			t = math.max(nextEvent, t + 0.01)
			continue
		end
		local customer: Customer = pick
		t += cycleSeconds(customer.dish, customer.seat, levels)
		local wait = t - customer.seatedAt
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

-- ── Lever reports ───────────────────────────────────────────────────────────
-- Stage k = the period after purchase k-1 (stage 1 = before the first upgrade). Income/min is the
-- measured coins earned during that stage; rate for levers is the stage the player is IN.
local FIRST_RATE_WINDOW = 120 -- stage 1 rate is measured over its own length
type Stage = { index: number, from: number, to: number, perMin: number, levels: { [string]: number } }
local stages: { Stage } = {}
do
	local prevT, prevE, prevLevels = 0, 0, {}
	for i, p in free.purchases do
		if p.at > prevT then
			table.insert(stages, {
				index = i,
				from = prevT,
				to = p.at,
				perMin = (p.earned - prevE) / (p.at - prevT) * 60, -- raw; smoothed below
				levels = prevLevels,
			})
		end
		prevT, prevE, prevLevels = p.at, p.earned, p.levels
	end
end
-- Rush Hour windows make single stages noisy, so levers use a 3-stage moving average (by time).
do
	local raw: { number } = {}
	for i, st in stages do
		raw[i] = st.perMin
	end
	for i, st in stages do
		local lo, hi = math.max(1, i - 1), math.min(#stages, i + 1)
		local coins, secs = 0, 0
		for j = lo, hi do
			local len = stages[j].to - stages[j].from
			coins += raw[j] * len / 60
			secs += len
		end
		st.perMin = coins / (secs / 60)
	end
end
local function stageAt(t: number): Stage
	for _, st in stages do
		if t < st.to then
			return st
		end
	end
	return stages[#stages]
end

print("")
print("Income per minute by stage (free, stage = period before purchase #n)")
print(string.format("%-3s %-12s %-10s %-10s", "n", "Next buy", "Coins/min", "Length"))
for _, st in stages do
	print(
		string.format(
			"%-3d %-12s %-10.0f %-10s",
			st.index,
			free.purchases[st.index].id,
			st.perMin,
			fmtTime(st.to - st.from)
		)
	)
end

local totalCost = 0
for id, def in UpgradeConfig.Defs do
	for _, c in def.costs do
		totalCost += c
	end
end

-- Streak: day d is claimed roughly d-1 days in; assume ~1 day of play per ~1h of progression.
print("")
print("Streak value (minutes of income at the stage reached after (day-1) hours of free play)")
local streakMin: { number } = {}
for day, reward in EconomyConfig.StreakRewards do
	local st = stageAt((day - 1) * 3600)
	local mins = reward / st.perMin
	streakMin[day] = mins
	print(string.format("  day %d: %5d coins = %.1f min (stage %d, %.0f/min)", day, reward, mins, st.index, st.perMin))
end

print("")
print("Offline restock at cap (value in minutes of active income at each stage)")
local restockMin: { number } = {}
for _, st in stages do
	local coins = Offline.fullRestock(st.levels)
	local mins = coins / st.perMin
	restockMin[st.index] = mins
	print(string.format("  stage %-2d: %6d coins = %.1f min active", st.index, coins, mins))
end

print("")
print("Legendary tip value (avg of enabled legendaries, fast Perfect serve, combo 3): minutes of income")
local legendMin: { number } = {}
for _, st in stages do
	local sum, n = 0, 0
	for id, def in CustomerConfig.Legendary do
		if def.enabled then
			local dish = def.favoriteDish or "Burger"
			local patience = Orders.patienceSeconds("Legendary", id, st.levels)
			local pay = Economy.computePayout({
				dishId = dish,
				kind = "Legendary",
				legendaryId = id,
				waitSeconds = patience * 0.2,
				patienceSeconds = patience,
				quality = "Perfect",
				combo = 3,
				ownerUpgrades = st.levels,
				crewSize = 1,
				rushHour = false,
				hasTipsPass = false,
				tipBoostPct = 0,
			})
			sum += pay.tip
			n += 1
		end
	end
	local mins = (sum / n) / st.perMin
	legendMin[st.index] = mins
	print(string.format("  stage %-2d: tip %7.0f coins = %.1f min", st.index, sum / n, mins))
end

print("")
print("Coin packs (minutes of income at each stage; share of total upgrade cost " .. totalCost .. ")")
local largestPack = 0
for key, def in Products.Products do
	local coins = (def :: any).coins
	if coins ~= nil then
		largestPack = math.max(largestPack, coins)
		local row = {}
		for _, i in { 1, 4, 7, 10, #stages } do
			local st = stages[math.min(i, #stages)]
			table.insert(row, string.format("s%d=%.0fm", st.index, coins / st.perMin))
		end
		print(
			string.format(
				"  %-12s %6d coins (%.1f%% of total): %s",
				key,
				coins,
				coins / totalCost * 100,
				table.concat(row, " ")
			)
		)
	end
end

-- Rush Hour lever: measured share of income earned during the 4-minute window.
local rushMult = Timings.RushHour.SpawnMultiplier * EconomyConfig.RushHour.PayMultiplier
print("")
print(
	string.format(
		"Rush Hour: %dx spawn, %dx pay for %ds each hour (up to %dx income if seats/cooking keep up)",
		Timings.RushHour.SpawnMultiplier,
		EconomyConfig.RushHour.PayMultiplier,
		Timings.RushHour.DurationSeconds,
		rushMult
	)
)

local failures = {}
local firstCook = Timings.Customers.FirstCustomerDelaySeconds + arrivalWalkSeconds(1)
print(string.format("New player can start cooking at %.1fs (first customer sits on stool 1)", firstCook))
if firstCook > FIRST_COOK_MAX then
	table.insert(failures, `a new player must be cooking within {FIRST_COOK_MAX}s`)
end
do
	local allLevels: { [string]: number } = {}
	for id, def in UpgradeConfig.Defs do
		allLevels[id] = def.maxLevel
	end
	if Upgrades.seatCount(allLevels) ~= Timings.Seats.Max then
		table.insert(failures, `maxed Seating must reach Timings.Seats.Max ({Timings.Seats.Max}) seats`)
	end
end
print(
	string.format(
		"Diner flow (free): %d arrivals, %.0f%% turned away (full), %.0f%% of seated customers walked out",
		free.arrivals,
		free.dropped / math.max(free.arrivals, 1) * 100,
		free.abandoned / math.max(free.arrivals - free.dropped, 1) * 100
	)
)
for n = Timings.Seats.Base, Timings.Seats.Max do
	local b = free.bySeats[n]
	if b ~= nil then
		print(
			string.format("  %2d seats: %5d arrivals, %.0f%% turned away", n, b.arrivals, b.dropped / b.arrivals * 100)
		)
	end
end
print("Seats by stage: " .. (function()
	local parts = {}
	for _, st in stages do
		table.insert(parts, tostring(Upgrades.seatCount(st.levels)))
	end
	return table.concat(parts, " ")
end)())
local maxGap, gapAt = 0, 0
do
	local prev = 0
	for i, p in free.purchases do
		if p.at - prev > maxGap then
			maxGap, gapAt = p.at - prev, i
		end
		prev = p.at
	end
end
print(
	string.format(
		"Longest wait between upgrades: %s (before #%d) = %.0f%% of total",
		fmtTime(maxGap),
		gapAt,
		free.allAt and maxGap / free.allAt * 100 or 0
	)
)
if free.allAt ~= nil and maxGap > free.allAt * 0.25 then
	table.insert(failures, "no single wait may exceed 25% of total progression")
end
if free.allAt ~= nil and pass.allAt ~= nil then
	local ratio = pass.allAt / free.allAt
	print(string.format("TipsX2 pass finishes in %.0f%% of free time", ratio * 100))
	if ratio < 0.60 or ratio > 0.75 then
		table.insert(failures, "TipsX2 pass should reach all 13 in 60-75% of free time")
	end
end
if largestPack > totalCost * 0.18 then
	table.insert(failures, "largest coin pack must be under 18% of total upgrade cost")
end
if streakMin[1] < 2 or streakMin[1] > 5 then
	table.insert(failures, "streak day 1 should be worth 2-5 minutes of income")
end
if streakMin[7] > 6 then
	table.insert(failures, "streak day 7 should stay modest (<= 6 minutes of income)")
end
for _, st in stages do
	if st.index >= 2 and (restockMin[st.index] < 20 or restockMin[st.index] > 40) then
		table.insert(failures, `restock at stage {st.index} should be 20-40 min of income`)
	end
	if st.index >= 2 and (legendMin[st.index] < LEGEND_MIN_LO or legendMin[st.index] > LEGEND_MIN_HI) then
		table.insert(
			failures,
			`legendary tip at stage {st.index} should be about 3-5 min of income (tolerance {LEGEND_MIN_LO}-{LEGEND_MIN_HI})`
		)
	end
end
local perHour = free.legendary / ((free.allAt or HORIZON_SECONDS) / 3600)
print(string.format("Legendaries served per hour: %.1f", perHour))
if perHour < 1 or perHour > 3 then
	table.insert(failures, "legendary customers should appear 1-3 times per hour")
end
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

--!strict
-- ⚠ CONTRACT — owned by the orchestrator. Agents request changes in their report; never edit directly.
-- Shared data shapes for server, client and pure Logic. Type-only module (returns an empty table).
-- All timestamps are unix seconds (server: os.time()/workspace:GetServerTimeNow(), client: GetServerTimeNow()).

-- ── Identifiers ─────────────────────────────────────────────────────────────

export type StationId = "Grill" | "Fryer" | "Oven" | "Soda"
export type DishId = "Burger" | "Fries" | "Pizza" | "Drink"
export type CustomerKind = "Regular" | "Hungry" | "VIP" | "Legendary"
-- Keys of Config/Customers.Legendary ("GiantChef", "SpaceAlien", "WeeklyMeme").
export type LegendaryId = string
-- Keys of Config/Upgrades.Defs.
export type UpgradeId = string
-- Keys of Config/Products.Passes.
export type PassKey = "TipsX2" | "AutoChef" | "ExtraStation" | "VIPBooth"
-- Keys of Config/Products.Products.
export type ProductKey =
	"InstantRestock"
	| "RushHourNow"
	| "TipPotion"
	| "CoinsSmall"
	| "CoinsMedium"
	| "CoinsLarge"
	| "AdTipBoost"
-- Timed boosts stored in PlayerData.boosts (value = expiry unix time).
export type BoostKey = "TipPotion" | "AdTipBoost"

-- ── Persistent profile (ProfileStore data, schema v1) ──────────────────────

export type StreakData = {
	day: number, -- 0 = never claimed, 1..7 = last claimed reward day in the current cycle
	lastClaimDay: number, -- unix day index (floor(time / 86400)) of last claim, 0 = never
}

export type PlayerData = {
	schemaVersion: number,
	coins: number,
	lifetimeCoins: number,
	upgrades: { [UpgradeId]: number }, -- upgrade id -> purchased level (absent = 0)
	streak: StreakData,
	lastRestock: number, -- unix time of last restock collection (offline earnings accrue from here)
	lastOnline: number, -- unix time of last leave/save
	bestRushHour: number, -- best coins earned during a single Rush Hour
	receipts: { [string]: number }, -- PurchaseId -> unix time granted (capped list, newest kept)
	boosts: { [BoostKey]: number }, -- boost -> expiry unix time
	tutorialDone: boolean,
	stats: {
		dishesServed: number,
		legendaryServed: number,
		rushHoursPlayed: number,
	},
	settings: {
		music: boolean,
		sfx: boolean,
	},
}

-- Replicated subset of PlayerData plus derived values, pushed to the owning client via DataSync.
export type PlayerDataView = {
	coins: number,
	lifetimeCoins: number,
	upgrades: { [UpgradeId]: number },
	streak: StreakData,
	streakClaimable: boolean,
	lastRestock: number,
	restockPending: number, -- coins collectable right now (offline earnings, already capped)
	bestRushHour: number,
	boosts: { [BoostKey]: number },
	passes: { [PassKey]: boolean },
	tutorialDone: boolean,
	settings: { music: boolean, sfx: boolean },
}

-- ── Plots & crew ────────────────────────────────────────────────────────────

export type PlotInfo = {
	plotId: number, -- 1..Timings.Plots.Count
	ownerUserId: number?, -- nil = free
	ownerName: string?,
	crewUserIds: { number }, -- excludes owner
	crewName: string?, -- filtered display name of the diner
	decorTier: number, -- 0..2, owner's Decor upgrade level
	seatCount: number,
	stationSlots: number, -- 4, or 5 with the ExtraStation pass
}

-- ── Stations & cooking ──────────────────────────────────────────────────────

-- Cook minigame: Start (hold) -> Cooking -> NeedsFlip (flip window) -> Finishing -> Ready -> (Burnt).
export type StationPhase = "Idle" | "Cooking" | "NeedsFlip" | "Finishing" | "Ready" | "Burnt"
export type CookAction = "Start" | "Flip" | "Collect" | "Clear"
export type CookQuality = "Perfect" | "Good" | "Burnt"

export type StationState = {
	plotId: number,
	slot: number, -- 1..stationSlots
	stationId: StationId,
	phase: StationPhase,
	dishId: DishId,
	cookerUserId: number?, -- who started the current cook
	phaseStartedAt: number, -- unix time the current phase began
	phaseEndsAt: number?, -- unix time the current phase auto-advances (nil for Idle)
	flipQuality: CookQuality?, -- set after the flip
}

-- Timing schedule for one cook, produced by Logic/Cooking.schedule.
export type CookSchedule = {
	cookSeconds: number, -- Cooking phase length (before flip)
	flipWindowSeconds: number, -- NeedsFlip length; flipping in the first PerfectFraction is Perfect
	perfectSeconds: number, -- flip within this many seconds of NeedsFlip start = Perfect
	finishSeconds: number, -- Finishing phase length (after flip)
	burnSeconds: number, -- Ready -> Burnt after this long uncollected
}

export type HeldItem = {
	kind: "Dish",
	dishId: DishId,
	quality: CookQuality,
}

-- ── Customers & orders ──────────────────────────────────────────────────────

export type CustomerPhase = "Walking" | "Waiting" | "Eating" | "Leaving"

export type Order = {
	dishId: DishId,
	placedAt: number, -- unix time the order bubble appeared
	patienceSeconds: number, -- total patience for this order
}

export type Customer = {
	id: number, -- unique per server
	plotId: number,
	kind: CustomerKind,
	legendaryId: LegendaryId?,
	seatIndex: number,
	phase: CustomerPhase,
	order: Order?,
	spawnedAt: number,
}

-- What the client needs to render a customer's bubble (sent in CustomerUpdate).
export type CustomerView = {
	id: number,
	plotId: number,
	kind: CustomerKind,
	legendaryId: LegendaryId?,
	displayName: string, -- legendary display name or kind name
	phase: CustomerPhase,
	dishId: DishId?,
	placedAt: number?,
	patienceSeconds: number?,
}

export type LeaveReason = "Served" | "Impatient" | "PlotReleased"

-- ── Economy ─────────────────────────────────────────────────────────────────

-- Everything Logic/Economy.computePayout needs. Built server-side at serve time.
export type PayoutContext = {
	dishId: DishId,
	kind: CustomerKind,
	legendaryId: LegendaryId?,
	waitSeconds: number, -- time from order placed to served
	patienceSeconds: number,
	quality: CookQuality,
	combo: number, -- consecutive fast serves by this player before this one (0 = none)
	ownerUpgrades: { [UpgradeId]: number }, -- plot owner's upgrades (tip/decor upgrades apply)
	crewSize: number, -- players on the plot including owner (1..4)
	rushHour: boolean,
	hasTipsPass: boolean, -- serving player owns TipsX2
	tipBoostPct: number, -- sum of active timed tip boosts for the serving player, e.g. 0.5 + 0.25
}

export type Payout = {
	base: number, -- dish price × customer kind multiplier
	tip: number, -- tip after all tip multipliers
	total: number, -- (base + tip) × rush × crew, integer, >= 1
	tipFraction: number, -- tip / base, drives the tip "explosion" VFX size
	combo: number, -- combo after this serve
}

export type ServeResult = {
	player: Player,
	plotId: number,
	customerId: number,
	kind: CustomerKind,
	legendaryId: LegendaryId?,
	dishId: DishId,
	payout: Payout,
	byBot: boolean,
}

-- ── Upgrades ────────────────────────────────────────────────────────────────

export type UpgradeEffect =
	{ kind: "StationSpeed", stationId: StationId, multiplierPerLevel: number } -- cook time ÷ (1 + m×level)
	| { kind: "Patience", bonusPerLevel: number } -- patience × (1 + b×level)
	| { kind: "Seats", seatsPerLevel: number }
	| { kind: "TipMultiplier", bonusPerLevel: number } -- tip × (1 + b×level)
	| { kind: "AutoServer" }
	| { kind: "Decor", tipPctPerLevel: number } -- tip fraction + p×level

export type UpgradeDef = {
	id: UpgradeId,
	displayName: string,
	description: string,
	order: number, -- shop sort order
	maxLevel: number,
	costs: { number }, -- costs[level] = price of buying that level
	effect: UpgradeEffect,
}

-- ── Rush Hour & schedule ────────────────────────────────────────────────────

export type RushHourState = {
	active: boolean,
	startedAt: number?,
	endsAt: number?, -- set while active
	nextAt: number, -- next scheduled start
	triggeredByName: string?, -- display name of the "Rush Hour Now" buyer, nil if scheduled
}

-- ── Monetization ────────────────────────────────────────────────────────────

export type PassDef = { id: number, displayName: string, description: string, priceRobux: number }
export type ProductDef = {
	id: number,
	displayName: string,
	description: string,
	priceRobux: number,
	coins: number?, -- coin packs
	boost: BoostKey?, -- timed boosts
	boostSeconds: number?,
}

-- ── Client notifications ────────────────────────────────────────────────────

export type ToastKind = "Info" | "Success" | "Warning" | "Error" | "Reward"

export type LegendaryAnnouncement = {
	legendaryId: LegendaryId,
	displayName: string,
	plotId: number,
	ownerName: string,
	servedByName: string?, -- nil when announcing arrival, set when served
	tip: number?,
	text: string, -- banner text: config announcement with {owner} replaced
}

export type LeaderboardEntry = { userId: number, name: string, value: number }
export type LeaderboardSnapshot = {
	lifetime: { LeaderboardEntry }, -- global top (OrderedDataStore), refreshed periodically
	rushHour: { LeaderboardEntry }, -- this server, best single Rush Hour
}

return {}

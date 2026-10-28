--!strict
-- ⚠ CONTRACT — owned by the orchestrator. Agents request changes in their report; never edit directly.
-- Every RemoteEvent/RemoteFunction in the game. Instances are created by Shared/Net at server boot.
--
-- Rules:
--   • Client→server remotes take exactly ONE argument: a payload table (or nothing). The server
--     validates type, range, rate limit (Config/Timings.RateLimits[name]) and plot/station ownership
--     via Server/Util/Guard before acting. Never trust anything else the client sends.
--   • Server→client remotes carry the payload types below.
local Types = require("./Types")

type DishId = Types.DishId
type UpgradeId = Types.UpgradeId

-- ── Client → Server (RemoteEvent) ───────────────────────────────────────────

export type JoinCrewPayload = { ownerUserId: number } -- must be friends with the owner
export type SetCrewNamePayload = { name: string } -- ≤ Timings.Text.MaxCrewNameLength, filtered
export type CookActionPayload = { plotId: number, slot: number, action: Types.CookAction }
export type ServeCustomerPayload = { customerId: number }
export type BuyUpgradePayload = { upgradeId: UpgradeId }
export type SetSettingPayload = { key: "music" | "sfx", value: boolean }

-- ── Server → Client (RemoteEvent) ───────────────────────────────────────────

export type ToastPayload = { text: string, kind: Types.ToastKind }
export type OrderServedPayload = {
	customerId: number,
	plotId: number,
	servedByUserId: number,
	kind: Types.CustomerKind,
	legendaryId: Types.LegendaryId?,
	dishId: DishId,
	total: number,
	tip: number,
	tipFraction: number,
	combo: number,
	byBot: boolean,
}
export type CustomerRemovedPayload = { id: number, reason: Types.LeaveReason }
export type HeldItemPayload = { item: Types.HeldItem? }
export type PurchaseGrantedPayload = { key: string, kind: "Pass" | "Product" }
export type CoinsAwardedPayload = { amount: number, reason: string } -- non-serve coin gains (streak, restock, packs)

-- ── Client → Server (RemoteFunction) ────────────────────────────────────────

-- GetSnapshot: called once by the client after boot. Returns everything needed to render.
export type Snapshot = {
	data: Types.PlayerDataView?, -- nil if the profile failed to load
	plots: { Types.PlotInfo },
	myPlotId: number?, -- plot the player currently works on (owned or crew)
	stations: { Types.StationState },
	customers: { Types.CustomerView },
	rushHour: Types.RushHourState,
	leaderboard: Types.LeaderboardSnapshot,
	serverTime: number,
}

local Remotes = {
	-- Client → Server events. Value = payload type name (documentation only).
	ClientToServer = {
		JoinCrew = "JoinCrewPayload",
		LeaveCrew = "nil",
		SetCrewName = "SetCrewNamePayload",
		CookAction = "CookActionPayload",
		ServeCustomer = "ServeCustomerPayload",
		BuyUpgrade = "BuyUpgradePayload",
		ClaimStreak = "nil",
		CollectRestock = "nil",
		RequestRewardedAd = "nil", -- opt-in only; server calls AdService and grants via AdTipBoost product
		CompleteTutorial = "nil",
		SetSetting = "SetSettingPayload",
	},

	-- Server → Client events. Value = payload type name (documentation only).
	ServerToClient = {
		DataSync = "PlayerDataView", -- full view, sent on any change to the owner only
		PlotsChanged = "{ PlotInfo }", -- all plots, broadcast on claim/release/crew/decor change
		StationUpdate = "StationState", -- broadcast to players whose plot it is (owner + crew)
		HeldItemChanged = "HeldItemPayload", -- to the holder only
		CustomerUpdate = "CustomerView", -- broadcast (all clients render bubbles they can see)
		CustomerRemoved = "CustomerRemovedPayload", -- broadcast
		OrderServed = "OrderServedPayload", -- broadcast (coin burst + tip explosion FX)
		RushHourState = "RushHourState", -- broadcast on start/end/trigger
		LegendaryAnnounce = "LegendaryAnnouncement", -- broadcast server-wide banner
		LeaderboardUpdate = "LeaderboardSnapshot", -- broadcast periodically
		Toast = "ToastPayload", -- to one player
		CoinsAwarded = "CoinsAwardedPayload", -- to one player
		PurchaseGranted = "PurchaseGrantedPayload", -- to the buyer
	},

	-- Client → Server functions.
	Functions = {
		GetSnapshot = "Snapshot",
	},
}

return Remotes

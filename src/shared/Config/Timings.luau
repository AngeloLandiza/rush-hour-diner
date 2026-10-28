--!strict
-- Timers, limits and schedule constants. Data only. Owner: orchestrator (tunable by balance pass G).
local Timings = {
	Plots = {
		Count = 6,
		MaxCrew = 3, -- crew members per plot, excluding owner (4 players total)
	},

	Seats = {
		Base = 2,
		Max = 6, -- Base + Seating upgrade levels (+ VIP booth seat)
	},

	Customers = {
		SpawnIntervalSeconds = 8, -- per plot, divided by Rush Hour spawn multiplier
		BasePatienceSeconds = 45,
		WalkSpeed = 12,
		EatSeconds = 4,
		FirstCustomerDelaySeconds = 3, -- after plot claim, so a new player cooks within 60s
		MaxQueuedPerPlot = 2, -- customers waiting for a free seat
	},

	RushHour = {
		IntervalSeconds = 3600, -- every hour at :00 server time (UTC)
		OffsetSeconds = 0,
		DurationSeconds = 4 * 60,
		SpawnMultiplier = 3,
	},

	MenuDrop = {
		Weekday = 6, -- 0 = Sunday … 6 = Saturday (UTC)
		HourUTC = 16,
	},

	AutoServer = {
		DeliverSeconds = 3, -- bot travel time per delivery
	},

	AutoChef = {
		TickSeconds = 60, -- AFK income payout interval
	},

	Station = {
		InteractRange = 12, -- studs between character root and station Interact part
	},

	Serve = {
		InteractRange = 14, -- studs between character root and customer
	},

	Tutorial = {
		DurationSeconds = 60,
	},

	Text = {
		MaxCrewNameLength = 24,
	},

	Data = {
		MaxStoredReceipts = 100,
		ProfileStoreName = "PlayerData_v1",
		LeaderboardStoreName = "LifetimeCoins_v1",
		LeaderboardRefreshSeconds = 120,
		LeaderboardSize = 10,
	},

	Ads = {
		CooldownSeconds = 60,
	},

	-- Max calls per player per second for each client→server remote (Server/Util/Guard).
	RateLimits = {
		JoinCrew = 0.5,
		LeaveCrew = 0.5,
		SetCrewName = 0.2,
		CookAction = 8,
		ServeCustomer = 6,
		BuyUpgrade = 4,
		ClaimStreak = 0.5,
		CollectRestock = 0.5,
		RequestRewardedAd = 0.2,
		CompleteTutorial = 0.5,
		SetSetting = 2,
		GetSnapshot = 0.5,
	} :: { [string]: number },
}

return Timings

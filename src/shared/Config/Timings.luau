--!strict
-- Timers, limits and schedule constants. Data only. Owner: orchestrator (tunable by balance pass G).
local Timings = {
	Plots = {
		Count = 6,
		MaxCrew = 3, -- crew members per plot, excluding owner (4 players total)
		SpawnLiftStuds = 3, -- characters are placed this high above Spawn
		CharacterWaitSeconds = 10,
	},

	Seats = {
		Base = 3,
		Max = 12, -- counter stools first, then tables; Base + Seating upgrade seats (VIP booth adds none)
	},

	Customers = {
		SpawnIntervalSeconds = 8, -- per plot, divided by Rush Hour spawn multiplier
		BasePatienceSeconds = 45,
		WalkSpeed = 12,
		EatSeconds = 4,
		FirstCustomerDelaySeconds = 3, -- after plot claim, so a new player cooks within 60s
		MaxQueuedPerPlot = 2, -- customers waiting for a free seat
		LoopSeconds = 0.5, -- central spawn / bot loop period
		WaitPollSeconds = 0.25, -- patience check period for a seated customer
		SpawnLiftStuds = 3,
		SitRootLiftStuds = 1.2, -- root height above the seat's Sit attachment while seated
		Walk = {
			ArriveDistance = 4, -- horizontal studs that count as "reached"
			TimeoutFactor = 1.5, -- allowed time = straight-line time × this
			TimeoutSlackSeconds = 2,
			ReissueSeconds = 1, -- re-issue MoveTo this often
		},
	},

	RushHour = {
		IntervalSeconds = 3600, -- every hour at :00 server time (UTC)
		OffsetSeconds = 0,
		DurationSeconds = 4 * 60,
		SpawnMultiplier = 3,
		PollSeconds = 1,
	},

	MenuDrop = {
		Weekday = 6, -- 0 = Sunday … 6 = Saturday (UTC)
		HourUTC = 16,
	},

	AutoServer = {
		DeliverSeconds = 3, -- bot travel time per delivery
		LiftStuds = 2,
		StandOffStuds = 3, -- bot stops this far short of the customer
	},

	AutoChef = {
		TickSeconds = 60, -- AFK income payout interval
	},

	Station = {
		InteractRange = 12, -- studs between character root and station Interact part
		TickSeconds = 0.1, -- cook state machine tick (~10 Hz)
		CharacterWaitSeconds = 5,
		HeldDishOffset = { X = 0, Y = -0.5, Z = -0.8 }, -- grip offset from RightHand (studs)
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
		SchemaVersion = 1,
		SaveConfirmTimeoutSeconds = 20,
		DataWaitTimeoutSeconds = 60,
		ReceiptDataWaitSeconds = 30,
		LoadWaitSeconds = 60, -- PlotService waits this long for a profile before claiming
		OwnershipRetryAttempts = 3,
		OwnershipRetryDelaySeconds = 2,
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

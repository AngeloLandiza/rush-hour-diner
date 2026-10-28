--!strict
-- Economy tuning constants used by Shared/Logic. Data only. Owner: agent B, balance pass G.
local Economy = {
	StartingCoins = 0,

	Tip = {
		BaseFraction = 0.2, -- tip = base × BaseFraction × speedFactor (before multipliers)
		FastFraction = 0.25, -- serve within this fraction of patience = max speed factor
		MaxSpeedFactor = 2, -- speed factor at instant serve
		MinSpeedFactor = 0.25, -- speed factor at the last second of patience
		PerfectBonus = 0.25, -- extra tip fraction for a Perfect flip
		BurntPenalty = 1, -- burnt dishes cannot be served (StationService discards them)
	},

	Combo = {
		WindowFraction = 0.5, -- serve within this fraction of patience to keep the combo going
		BonusPerStep = 0.1, -- tip × (1 + BonusPerStep × combo)
		MaxCombo = 10,
	},

	Crew = {
		BonusPerMember = 0.1, -- +10% coins per crew member (excluding owner)
		MaxBonus = 0.3,
	},

	RushHour = {
		PayMultiplier = 2,
	},

	TipsPassMultiplier = 2, -- TipsX2 game pass: tip × 2

	Offline = {
		CapSeconds = 8 * 3600,
		BaseCoinsPerMinute = 2, -- offline rate before upgrades
		CoinsPerMinutePerUpgradeLevel = 1,
		AutoChefMultiplier = 1, -- Auto-Chef pass in-game AFK income = offline rate × this
	},

	-- Daily streak rewards for days 1..7 (day 7 then cycles back to 1).
	StreakRewards = { 50, 100, 150, 250, 400, 600, 1000 },
}

return Economy

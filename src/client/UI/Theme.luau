--!strict
-- UI theme: fonts, sizes, Palette-derived colors, tween presets. Owner: agent D.
-- Every raw UI number lives in Theme.UI; every color comes from Config/Palette.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local Colors = Palette.Color

local Theme = {
	Font = Enum.Font.FredokaOne,
	MinTouchTarget = 44, -- px, mobile-first
	Colors = Colors,
	Hex = Palette.Hex,

	-- Toast kind -> background color.
	ToastColor = {
		Info = Colors.Ink,
		Success = Colors.Mint,
		Warning = Colors.Mustard,
		Error = Colors.Ketchup,
		Reward = Colors.NeonPink,
	} :: { [Types.ToastKind]: Color3 },

	-- Keyboard / gamepad equivalents of touch buttons.
	Keys = {
		Primary = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
		Back = { Enum.KeyCode.ButtonB },
		Shop = { Enum.KeyCode.B },
		Leaderboard = { Enum.KeyCode.L },
		Crew = { Enum.KeyCode.C },
		Settings = { Enum.KeyCode.O },
		Daily = { Enum.KeyCode.R },
	},

	UI = {
		-- Layout. Design space is 360x640; UIScale grows it on larger viewports.
		RefWidth = 360,
		RefHeight = 640,
		MinScale = 1,
		MaxScale = 1.6,
		Margin = 8,
		Gap = 6,
		Corner = 12,
		SmallCorner = 8,
		Stroke = 3,
		ThinStroke = 2,
		GradientShade = 0.18, -- how far the button gradient darkens toward Ink
		DisabledShade = 0.55,

		-- Text sizes.
		TextSmall = 14,
		TextBody = 18,
		TextLarge = 24,
		TextHuge = 36,

		-- Z layers.
		ZHud = 1,
		ZPanels = 5,
		ZStation = 6,
		ZToasts = 10,
		ZBanner = 12,

		-- Tweens.
		PopInSeconds = 0.4,
		PopFromScale = 0.6,
		PressSeconds = 0.08,
		ReleaseSeconds = 0.35,
		PressScale = 0.92,
		BounceScale = 1.15,
		BounceSeconds = 0.5,
		FadeSeconds = 0.25,
		CoinCountSeconds = 0.6,
		PulseSeconds = 0.5,

		-- HUD.
		TopBarHeight = 36,
		CoinPillWidth = 132,
		HudColumnWidth = 176,
		RowHeight = 44,
		BoostLineHeight = 20,
		MaxBoostLines = 4,
		ClockSeconds = 0.25, -- how often slow text (timers) refreshes
		SnapshotRetrySeconds = 2,
		MenuButtonWidth = 46,
		CollectButtonWidth = 76,

		-- Panels.
		PanelMaxWidth = 420,
		PanelMaxHeight = 520,
		PanelTopInset = 96,
		PanelBottomInset = 16,
		TitleBarHeight = 48,
		TabHeight = 44,
		ListRowHeight = 64,
		LeaderboardRows = 10,
		ShopHintSeconds = 2.5,

		-- Toasts / banner.
		ToastSeconds = 3,
		ToastMax = 4,
		ToastHeight = 40,
		BannerSeconds = 4.5,
		BannerHeight = 96,
		BannerYScale = 0.3,

		-- Station panel.
		StationPanelHeight = 214,
		StationPanelMaxWidth = 380,
		StationBigButtonHeight = 72,
		StationBarHeight = 22,
		StationCloseDistanceFactor = 1.6, -- close panel past InteractRange * this
		StationCheckSeconds = 0.25,
		FlipMarkerWidth = 6,

		-- Customer bubbles.
		BubbleWidth = 96,
		BubbleHeight = 84,
		BubbleOffsetY = 3,
		BubbleMaxDistance = 90,
		BubbleBarHeight = 10,
		BubbleLowPatience = 0.25,
		BubbleMidPatience = 0.55,
		LegendaryShimmerSeconds = 2,

		-- Tutorial.
		TutorialBeamWidth = 0.5,
		TutorialArrowSize = 64,
		TutorialArrowBobStuds = 1.2,
		TutorialArrowHeight = 7,
		TutorialTextHeight = 52,

		-- Settings.
		SettingRowHeight = 52,
		CrewNameBoxWidth = 190,
		PopupWidth = 220,
		PopupHeight = 60,
		PopupSeconds = 1.4,
	},

	FX = {
		FloatTextRiseStuds = 5,
		FloatTextSeconds = 1.4,
		FloatTextOffsetY = 5,
		FloatTextWidth = 140,
		FloatTextHeight = 50,
		CoinBurstBaseScale = 1,
		CoinBurstPerCoin = 0.01,
		CoinBurstMaxScale = 3,
		TipBaseScale = 0.8,
		TipPerFraction = 1.5,
		TipMaxScale = 5,
		LegendaryBurstScale = 2.5,
	},
}

-- Darkens a palette color toward Ink (for gradients, disabled states).
function Theme.shade(color: Color3, amount: number): Color3
	return color:Lerp(Colors.Ink, amount)
end

-- Lightens a palette color toward White.
function Theme.tint(color: Color3, amount: number): Color3
	return color:Lerp(Colors.White, amount)
end

return Theme

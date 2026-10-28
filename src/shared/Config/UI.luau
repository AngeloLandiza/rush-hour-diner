--!strict
-- UI design tokens and image ids. Pure data (no Roblox globals) so Lune can load it. Owner: UI agent.
-- Spec: docs/UI_STYLE.md. Colors are never raw values here: each role names a Palette key and may mix
-- it toward a second Palette key by t (Theme resolves them at runtime with Color3:Lerp).

export type ColorSpec = { base: string, mix: string?, t: number? }
export type MotionSpec = { seconds: number, style: string, direction: string? }
export type VariantSpec = {
	face: string, -- color role names (keys of UI.Colors)
	lip: string,
	edge: string,
	text: string,
	textStroke: string?, -- outline for light text on saturated faces
}

local UI = {
	-- Image ids for hero icons (rbxassetid). 0 = use the code-built vector icon from UI/Icons.
	Images = {
		Coin = 0,
		Shop = 0,
		Trophy = 0,
		Crew = 0,
		Gear = 0,
		Clock = 0,
		Flame = 0,
		Calendar = 0,
		Crate = 0,
		Burger = 0,
		Fries = 0,
		Pizza = 0,
		Drink = 0,
	} :: { [string]: number },

	-- Enum.Font item names. Display = chunky rounded headings and numbers, Body = readable copy.
	Fonts = {
		Display = "FredokaOne",
		Body = "BuilderSansBold",
		Heavy = "BuilderSansExtraBold",
	},

	-- Color roles (see docs/UI_STYLE.md, "Color roles").
	Colors = {
		-- Paper (modals, cards)
		Surface = { base = "Cream" },
		Raised = { base = "White" },
		Sunken = { base = "CreamShade" },
		SunkenDeep = { base = "CreamShade", mix = "Ink", t = 0.18 },
		-- HUD glass (counters and chips over the 3D world)
		Glass = { base = "NightInk" },
		GlassEdge = { base = "White" },
		-- Text
		Text = { base = "Ink" },
		TextMuted = { base = "Ink", mix = "Cream", t = 0.38 },
		TextInverse = { base = "White" },
		TextOnGlassMuted = { base = "PinkGlow", mix = "Cream", t = 0.4 },
		Outline = { base = "NightInk" },
		Shadow = { base = "NightInk" },
		Scrim = { base = "NightInk" },
		Highlight = { base = "White" },
		-- Actions
		Primary = { base = "Mustard" },
		PrimaryDeep = { base = "MustardDeep" },
		PrimaryEdge = { base = "MustardDeep", mix = "Ink", t = 0.25 },
		PrimaryLight = { base = "Mustard", mix = "White", t = 0.55 },
		Success = { base = "Mint" },
		SuccessDeep = { base = "MintDeep" },
		SuccessEdge = { base = "MintDeep", mix = "Ink", t = 0.3 },
		SuccessLight = { base = "Mint", mix = "White", t = 0.6 },
		Danger = { base = "Ketchup" },
		DangerDeep = { base = "KetchupDeep" },
		DangerEdge = { base = "KetchupDeep", mix = "Ink", t = 0.3 },
		DangerLight = { base = "Ketchup", mix = "White", t = 0.65 },
		Accent = { base = "NeonPink" },
		AccentDeep = { base = "NeonPink", mix = "KetchupDeep", t = 0.45 },
		AccentEdge = { base = "NeonPink", mix = "Ink", t = 0.45 },
		AccentLight = { base = "PinkGlow" },
		Info = { base = "InkSoft" },
		InfoDeep = { base = "Ink" },
		InfoEdge = { base = "NightInk" },
		Neutral = { base = "White" },
		NeutralDeep = { base = "CreamShade" },
		NeutralEdge = { base = "CreamShade", mix = "Ink", t = 0.25 },
		Disabled = { base = "CreamShade", mix = "White", t = 0.25 },
		DisabledDeep = { base = "CreamShade", mix = "Ink", t = 0.22 },
		DisabledText = { base = "Ink", mix = "CreamShade", t = 0.55 },
		-- Currency
		Gold = { base = "Mustard" },
		GoldDeep = { base = "MustardDeep" },
		GoldLight = { base = "Mustard", mix = "Cream", t = 0.55 },
		Bronze = { base = "MustardDeep", mix = "KetchupDeep", t = 0.45 },
		BronzeDeep = { base = "KetchupDeep", mix = "Ink", t = 0.3 },
		-- Patience ring
		PatienceHigh = { base = "Mint" },
		PatienceMid = { base = "Mustard" },
		PatienceLow = { base = "Ketchup" },
		-- Rush Hour
		RushHot = { base = "NeonPink" },
		RushWarm = { base = "Mustard" },
		RushDeep = { base = "NeonPink", mix = "NightInk", t = 0.55 },
	} :: { [string]: ColorSpec },

	-- Button variants: face / lip / edge / text roles.
	Variants = {
		primary = { face = "Primary", lip = "PrimaryDeep", edge = "PrimaryEdge", text = "Text" },
		secondary = { face = "Neutral", lip = "NeutralDeep", edge = "NeutralEdge", text = "Text" },
		success = {
			face = "Success",
			lip = "SuccessDeep",
			edge = "SuccessEdge",
			text = "TextInverse",
			textStroke = "Outline",
		},
		premium = {
			face = "Success",
			lip = "SuccessDeep",
			edge = "SuccessEdge",
			text = "TextInverse",
			textStroke = "Outline",
		},
		danger = {
			face = "Danger",
			lip = "DangerDeep",
			edge = "DangerEdge",
			text = "TextInverse",
			textStroke = "Outline",
		},
		accent = {
			face = "Accent",
			lip = "AccentDeep",
			edge = "AccentEdge",
			text = "TextInverse",
			textStroke = "Outline",
		},
		info = { face = "Info", lip = "InfoDeep", edge = "InfoEdge", text = "TextInverse", textStroke = "Outline" },
		disabled = { face = "Disabled", lip = "DisabledDeep", edge = "DisabledDeep", text = "DisabledText" },
		ghost = { face = "Neutral", lip = "Neutral", edge = "Neutral", text = "Text" },
	} :: { [string]: VariantSpec },

	-- Spacing scale (design px at 360x640).
	Space = { XS = 4, SM = 8, MD = 12, LG = 16, XL = 24 },

	-- Corner radii (px). Pills use scale 0.5 instead.
	Radius = { SM = 8, MD = 12, LG = 16, XL = 20 },

	-- Stroke weights (px).
	Stroke = { Hair = 1, Thin = 2, Base = 2.5, Bold = 3.5 },

	-- Depth recipe: lip under faces, soft drop shadow, glossy top highlight.
	Depth = {
		Lip = 4, -- button bottom lip height
		SmallLip = 3,
		ShadowOffset = 4,
		ShadowTransparency = 0.78,
		HighlightTransparency = 0.72,
		HighlightHeight = 0.42, -- fraction of face height
		BevelDarken = 0.1, -- gradient bottom darkening (toward Ink)
		GlassTransparency = 0.18,
		GlassEdgeTransparency = 0.8,
		ScrimTransparency = 0.45,
		DisabledTextTransparency = 0.15,
	},

	-- Type scale (px): Display font for headings and numbers, Body font for copy.
	Type = {
		Micro = 11,
		Caption = 12,
		Small = 14,
		Body = 16,
		Title = 20,
		Heading = 24,
		Display = 32,
		Hero = 48,
		MinScaled = 10,
	},

	-- Motion specs. style/direction are Enum.EasingStyle / Enum.EasingDirection item names.
	Motion = {
		Press = { seconds = 0.07, style = "Quad", direction = "Out" },
		Release = { seconds = 0.28, style = "Back", direction = "Out" },
		Hover = { seconds = 0.12, style = "Quad", direction = "Out" },
		PopIn = { seconds = 0.32, style = "Back", direction = "Out" },
		PopOut = { seconds = 0.14, style = "Quad", direction = "In" },
		Bounce = { seconds = 0.42, style = "Back", direction = "Out" },
		Fade = { seconds = 0.2, style = "Quad", direction = "Out" },
		Slide = { seconds = 0.3, style = "Quint", direction = "Out" },
		Count = { seconds = 0.6, style = "Quad", direction = "Out" },
		Pulse = { seconds = 0.6, style = "Sine", direction = "InOut" },
		CoinBurst = { seconds = 0.2, style = "Back", direction = "Out" },
		CoinTravel = { seconds = 0.5, style = "Quad", direction = "In" },
		BannerIn = { seconds = 0.45, style = "Back", direction = "Out" },
		BannerOut = { seconds = 0.3, style = "Back", direction = "In" },
		CameraIntro = { seconds = 1.2, style = "Cubic", direction = "InOut" },
		Shimmer = { seconds = 1.1, style = "Linear", direction = "In" },
		Purchase = { seconds = 0.5, style = "Back", direction = "Out" },
		Sparkle = { seconds = 0.28, style = "Back", direction = "Out" },
		SparkleOut = { seconds = 0.32, style = "Quad", direction = "In" },
		SpendFloat = { seconds = 0.9, style = "Quad", direction = "Out" },
	} :: { [string]: MotionSpec },

	-- Scales used by the motion helpers.
	MotionScale = {
		Press = 0.94,
		Hover = 1.04,
		PopFrom = 0.55,
		PopOutTo = 0.85,
		Bounce = 1.18,
		Pulse = 0.05,
		PressSink = 0.75, -- fraction of the lip the face sinks on press
		Purchase = 1.1, -- shop card pop on a level-up
		SpendDip = 0.92, -- coin counter squash while it ticks down
	},

	-- Gameplay camera (studs / degrees). The intro frames the player's own diner on spawn, respawn and
	-- plot change, then hands the same angle to the Custom camera. Plot-local +Z faces the street.
	Camera = {
		Zoom = 24, -- default orbit distance (landscape / desktop)
		PortraitZoomMax = 32, -- narrow screens zoom out until FrameHalfWidth fits, up to this
		FrameHalfWidth = 11, -- studs either side of the player that must stay in view
		ZoomMin = 10,
		ZoomMax = 45,
		PitchDegrees = 38, -- look-down angle of the default orbit
		YawDegrees = 20, -- 3/4 offset from the plot's street axis toward plot +X
		IntroZoom = 50, -- establishing shot from over the street
		IntroPitchDegrees = 26,
		IntroYawDegrees = -18,
		IntroFocus = { X = 0, Y = 4, Z = -6 }, -- plot-local point the establishing shot looks at
		SubjectHeight = 1.5, -- Custom camera focus above the HumanoidRootPart (R15 head offset)
		ArriveDistance = 20, -- character counts as "on the plot" within this many studs of Spawn
		ArriveTimeoutSeconds = 6,
		HandoffFrames = 6, -- frames the framing is re-applied (and zoom pinned) after handing back to Custom
		CounterMargin = 1.2, -- guard box around the counter (studs)
		CounterClearance = 1.5, -- the camera is lifted to this height above the counter top
	},

	-- Loading skeletons (shown until the first snapshot / data arrives).
	Skeleton = {
		Clock = "--:--",
		Number = "--",
		DimTransparency = 0.55, -- placeholder text transparency outside the shimmer band
		BandTransparency = 0.05,
		BandWidth = 0.12, -- fraction of the label the shimmer band covers (each side of center)
	},

	-- Layout (design px) and UI timers. Theme.UI exposes this table.
	Layout = {
		RefWidth = 360,
		RefHeight = 640,
		MinScale = 1,
		MaxScale = 1.5,
		NarrowWidth = 560, -- below this the top row splits into two rows
		ShortHeight = 360, -- below this the HUD hides secondary chips while the station panel is open
		Margin = 8,
		Gap = 6,

		-- Z layers.
		ZWorld = 1,
		ZHud = 2,
		ZPanels = 5,
		ZStation = 6,
		ZTutorial = 4, -- under modals so the scrim covers the coach mark
		ZToasts = 10,
		ZFly = 11,
		ZBanner = 12,
		ZTooltip = 13,

		-- HUD.
		TopRowHeight = 44,
		CoinPillWidth = 176,
		CoinIconSize = 46,
		RushPillWidth = 156,
		RushPillHeight = 42,
		RushBarWidth = 320,
		RushBarHeight = 50,
		RushSoonSeconds = 60,
		ChipHeight = 28,
		ChipWidth = 132,
		MaxBoostChips = 3,
		RailTile = 54,
		RailIcon = 34,
		RailGap = 12,
		RailLabelHeight = 16,
		BadgeSize = 22,
		HeldChipWidth = 196,
		HeldChipHeight = 46,
		MenuChipWidth = 74,
		GearSize = 44,
		EdgeGlowSize = 70,
		EdgeGlowTransparency = 0.45,
		RestockGlowFraction = 0.25, -- restock tile glows once pending >= this fraction of the cap
		ClockSeconds = 0.25, -- how often slow text (timers) refreshes
		SnapshotRetrySeconds = 2,
		MinTouchTarget = 44,

		-- Coin fly.
		FlyCoinSize = 26,
		FlyMinCoins = 3,
		FlyMaxCoins = 12,
		FlyBurstRadius = 46,
		FlyStagger = 0.04,

		-- Panels.
		PanelMaxWidth = 480,
		PanelMaxHeight = 470,
		PanelTopInset = 58,
		PanelBottomInset = 10,
		PanelHeaderHeight = 50,
		PanelBadgeSize = 54,
		PanelRadius = 18,
		TabHeight = 44,
		CardHeight = 80,
		CardIcon = 54,
		PriceButtonWidth = 104,
		PriceButtonHeight = 44,
		PriceProgressHeight = 12, -- "24 / 60" bar under an unaffordable price
		PipSize = 9,
		SparkleCount = 7,
		SparkleSize = 18,
		ShopBalanceWidth = 112,
		ShopBalanceHeight = 32,
		ShopBalanceIcon = 34,
		LeaderboardRows = 10,
		LeaderRowHeight = 50,
		SettingRowHeight = 58,
		ToggleWidth = 64,
		ToggleHeight = 34,
		CrewNameBoxWidth = 190,

		-- Toasts / banner / stamps.
		ToastSeconds = 3,
		ToastMax = 3,
		ToastHeight = 42,
		ToastWidth = 330,
		BannerSeconds = 4.5,
		BannerHeight = 120,
		BannerYScale = 0.32,
		BannerRaySeconds = 8,
		ConfettiCount = 36,
		StampSeconds = 1.4,
		TooltipWidth = 140,
		TooltipHeight = 30,

		-- Station panel.
		StationPanelWidth = 344,
		StationPanelHeight = 186,
		StationBadgeSize = 56,
		StationTrackHeight = 26,
		StationActHeight = 66,
		StationCloseDistanceFactor = 1, -- close past InteractRange * this (server rejects beyond 1x)
		StationCheckSeconds = 0.25,
		FlipNeedleWidth = 8,
		StripePeriodSeconds = 0.6,

		-- Customer bubbles.
		BubbleWidth = 96,
		BubbleHeight = 116,
		BubbleFace = 84,
		BubbleRing = 70,
		BubbleRingThickness = 8,
		BubbleIcon = 44,
		BubbleOffsetY = 3.4,
		BubbleMaxDistance = 90,
		BubbleLowPatience = 0.25,
		BubbleMidPatience = 0.55,
		BubbleWiggleDegrees = 6,
		BubbleWiggleSpeed = 18,
		BubbleServedSeconds = 0.4,
		LegendaryRaySeconds = 6,

		-- Custom proximity prompts.
		PromptWidth = 176,
		PromptHeight = 52,
		PromptKeySize = 36,
		PromptStudsOffsetY = 2.2,
		CustomerPromptStudsOffsetY = -0.6,

		-- Tutorial coach mark.
		CoachHeight = 50,
		CoachMaxWidth = 340,
		TutorialBeamWidth = 0.35,
		TutorialArrowSize = 72,
		TutorialArrowBobStuds = 0.8,
		TutorialArrowHeight = 6.5,
		TutorialBobSpeed = 4,
	},

	-- World-space FX numbers (floating "+N" text, bursts).
	FX = {
		FloatTextRiseStuds = 5,
		FloatTextSeconds = 1.5,
		FloatTextOffsetY = 5,
		FloatTextWidth = 220,
		FloatTextHeight = 90,
		CoinBurstBaseScale = 1,
		CoinBurstPerCoin = 0.01,
		CoinBurstMaxScale = 3,
		TipBaseScale = 0.8,
		TipPerFraction = 1.5,
		TipMaxScale = 5,
		LegendaryBurstScale = 2.5,
		BigTipFraction = 0.5, -- show the "BIG TIP!" kicker above this tip fraction
	},
}

return UI

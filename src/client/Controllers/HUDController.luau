--!strict
-- HUDController: the always-on HUD (layout in docs/UI_STYLE.md).
--   top-left  coin counter (+ opens shop products)      top-right  settings gear
--   top-center Rush Hour widget, then boost/combo chips (second row on narrow screens)
--   left rail Shop / Crew / Top icon tiles               right rail Daily / Restock tiles, menu drop
--   bottom-center held-dish chip (rises above the station panel)
-- Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badge = require(script.Parent.Parent.UI.Components.Badge)
local Button = require(script.Parent.Parent.UI.Components.Button)
local Card = require(script.Parent.Parent.UI.Components.Card)
local CoinFly = require(script.Parent.Parent.UI.CoinFly)
local CrewPanel = require(script.Parent.Parent.UI.Screens.CrewPanel)
local CurrencyCounter = require(script.Parent.Parent.UI.Components.CurrencyCounter)
local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Icons = require(script.Parent.Parent.UI.Icons)
local InputController = require(script.Parent.InputController)
local LeaderboardPanel = require(script.Parent.Parent.UI.Screens.LeaderboardPanel)
local Net = require(ReplicatedStorage.Shared.Net)
local Offline = require(ReplicatedStorage.Shared.Logic.Offline)
local Panel = require(script.Parent.Parent.UI.Components.Panel)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Root = require(script.Parent.Parent.UI.Root)
local RushHud = require(script.Parent.Parent.UI.Screens.RushHud)
local Schedule = require(ReplicatedStorage.Shared.Logic.Schedule)
local SettingsPanel = require(script.Parent.Parent.UI.Screens.SettingsPanel)
local ShopController = require(script.Parent.ShopController)
local ShopPanel = require(script.Parent.Parent.UI.Screens.ShopPanel)
local State = require(script.Parent.Parent.State)
local StationPanel = require(script.Parent.Parent.UI.Screens.StationPanel)
local Streak = require(ReplicatedStorage.Shared.Logic.Streak)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ticker = require(script.Parent.Parent.UI.Ticker)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Tooltip = require(script.Parent.Parent.UI.Components.Tooltip)
local Tween = require(script.Parent.Parent.UI.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)

local HUDController = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local LABEL_OVERLAP = 8
local BOOST_ICON: { [string]: string } = { TipPotion = "Potion", AdTipBoost = "Ad" }
local QUALITY_LOOK: { [Types.CookQuality]: { text: string, color: Color3, textColor: Color3 } } = {
	Perfect = { text = "PERFECT", color = C.Primary, textColor = C.Text },
	Good = { text = "GOOD", color = C.Success, textColor = C.TextInverse },
	Burnt = { text = "BURNT", color = C.Info, textColor = C.TextInverse },
}

type Tile = { root: Frame, button: Button.Button, label: TextLabel }

-- Icon tile with a stroked caption overlapping its bottom edge.
local function tile(
	parent: Instance,
	order: number,
	icon: string,
	caption: string,
	variant: Theme.VariantName,
	onActivated: () -> ()
): Tile
	local root = Util.frame(parent, {
		Name = caption .. "Tile",
		Size = UDim2.fromOffset(U.RailTile, U.RailTile + LABEL_OVERLAP),
		LayoutOrder = order,
	})
	local b = Button.new({
		parent = root,
		variant = variant,
		icon = icon,
		iconSize = U.RailIcon,
		radius = Theme.Radius.LG,
		size = UDim2.fromOffset(U.RailTile, U.RailTile),
		onActivated = onActivated,
	})
	b.content.Position = UDim2.fromOffset(0, -4)
	local label = Util.display(root, caption, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, U.RailTile - LABEL_OVERLAP - 2),
		Size = UDim2.new(1, Space.LG, 0, U.RailLabelHeight),
		TextSize = Theme.Type.Caption + 1,
		TextColor3 = C.TextInverse,
		ZIndex = 10,
	}, C.Outline)
	label.Name = "Caption"
	return { root = root, button = b, label = label }
end

local function rail(parent: Instance, name: string, anchorX: number): Frame
	local f = Util.frame(parent, {
		Name = name,
		AnchorPoint = Vector2.new(anchorX, 0.5),
		Size = UDim2.fromOffset(U.RailTile + Space.LG, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Util.list(f, Enum.FillDirection.Vertical, U.RailGap, Enum.HorizontalAlignment.Center)
	return f
end

local function chip(
	parent: Instance,
	order: number,
	variant: "glass" | "accent",
	color: Color3?
): (Card.Card, Frame, TextLabel)
	local card = Card.new({
		parent = parent,
		variant = variant,
		color = color,
		edge = if variant == "accent" then C.Outline else nil,
		radius = math.huge,
		size = UDim2.fromOffset(U.ChipWidth, U.ChipHeight),
		layoutOrder = order,
		shadow = variant == "accent",
	})
	local iconHost = Util.frame(card.face, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(U.ChipHeight - 4, U.ChipHeight - 4),
		ZIndex = 3,
	})
	local label = Util.display(card.face, "", {
		Position = UDim2.fromOffset(U.ChipHeight, 0),
		Size = UDim2.new(1, -(U.ChipHeight + Space.SM), 1, 0),
		TextSize = Theme.Type.Small,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, C.Outline)
	Util.fit(label, Theme.Type.Small)
	return card, iconHost, label
end

function HUDController.Init() end

function HUDController.Start()
	State.waitReady()
	local layer = Root.layer("HUD", U.ZHud)

	-- ── Top-left: coins ─────────────────────────────────────────────────────
	local coins = CurrencyCounter.new({
		parent = layer,
		icon = "Coin",
		width = U.CoinPillWidth,
		height = U.TopRowHeight,
		position = UDim2.fromOffset(U.Margin, U.Margin),
		onPlus = function()
			ShopController.Open(ShopPanel.Tabs.Products)
		end,
	})
	CoinFly.setTarget(coins.icon, function()
		coins:Punch()
	end)

	-- ── Top-right: settings ─────────────────────────────────────────────────
	local settings = SettingsPanel.new()
	local gear = Button.new({
		parent = layer,
		name = "Settings",
		variant = "secondary",
		icon = "Gear",
		iconSize = 26,
		radius = math.huge,
		lip = Theme.Depth.SmallLip,
		size = UDim2.fromOffset(U.GearSize, U.GearSize),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -U.Margin, 0, U.Margin),
		onActivated = function()
			settings:Toggle()
		end,
	})
	Tooltip.attach(gear.instance, function()
		return "Settings (O)"
	end, "left")

	-- ── Top-center: Rush Hour + chips ───────────────────────────────────────
	local status = Util.frame(layer, {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, U.Margin),
		Size = UDim2.new(1, -U.Margin * 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Util.list(status, Enum.FillDirection.Vertical, U.Gap + 2, Enum.HorizontalAlignment.Center)
	local rushHost = Util.frame(status, {
		Name = "RushHost",
		Size = UDim2.new(1, 0, 0, U.RushPillHeight),
		LayoutOrder = 1,
	})
	local rush = RushHud.new(rushHost)
	rush.instance.Position = UDim2.fromScale(0.5, 0)
	local chips = Util.frame(status, {
		Name = "Chips",
		Size = UDim2.new(1, 0, 0, U.ChipHeight),
		LayoutOrder = 2,
		Visible = false,
	})
	Util.list(chips, Enum.FillDirection.Horizontal, U.Gap, Enum.HorizontalAlignment.Center)

	local comboCard, comboIcon, comboLabel = chip(chips, 0, "accent", C.Accent)
	Icons.build("Flame", comboIcon, U.ChipHeight - 4, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	comboCard.instance.Visible = false
	comboCard.instance.Size = UDim2.fromOffset(U.ChipWidth - 20, U.ChipHeight)

	local boostChips: { { card: Card.Card, icon: Frame, label: TextLabel, key: string? } } = {}
	for i = 1, U.MaxBoostChips do
		local card, iconHost, label = chip(chips, i, "glass")
		card.instance.Visible = false
		table.insert(boostChips, { card = card, icon = iconHost, label = label, key = nil })
	end

	-- ── Rails ───────────────────────────────────────────────────────────────
	local leaderboard = LeaderboardPanel.new()
	local crew = CrewPanel.new()
	local left = rail(layer, "LeftRail", 0)
	local right = rail(layer, "RightRail", 1)

	local shopTile = tile(left, 1, "Shop", "SHOP", "primary", ShopController.Toggle)
	local shopBadge = Badge.new(shopTile.button.instance)
	local crewTile = tile(left, 2, "Crew", "CREW", "secondary", function()
		crew:Toggle()
	end)
	local topTile = tile(left, 3, "Trophy", "TOP", "secondary", function()
		leaderboard:Toggle()
	end)
	Tooltip.attach(shopTile.button.instance, function()
		return "Shop (B)"
	end)
	Tooltip.attach(crewTile.button.instance, function()
		return "Crew (C)"
	end)
	Tooltip.attach(topTile.button.instance, function()
		return "Leaderboard (L)"
	end)

	local function claimStreak()
		local data = State.data
		if not data then
			return
		end
		if data.streakClaimable then
			Net.event("ClaimStreak"):FireServer()
		else
			local now = State.now()
			local nextAt = (Streak.dayIndex(now) + 1) * Economy.Time.SecondsPerDay
			Toast.show(`Next daily reward in {Util.longClock(nextAt - now)}`, "Info")
		end
	end
	local dailyTile = tile(right, 1, "Calendar", "DAILY", "secondary", claimStreak)
	local dailyBadge = Badge.new(dailyTile.button.instance)

	local function collectRestock()
		local data = State.data
		if not data then
			return
		end
		local pending = math.max(data.restockPending, Offline.pending(data.lastRestock, State.now(), data.upgrades))
		if pending > 0 then
			Net.event("CollectRestock"):FireServer()
		else
			Toast.show("Your restock fills up while you're away", "Info")
		end
	end
	local restockTile = tile(right, 2, "Crate", "0", "secondary", collectRestock)
	local restockTrack = Util.solid(restockTile.button.face, C.SunkenDeep, 0, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -14, 0, 5),
		ZIndex = 8,
	})
	Util.pill(restockTrack)
	local restockFill = Util.solid(restockTrack, C.Success, 0, { Size = UDim2.fromScale(0, 1), ZIndex = 9 })
	Util.pill(restockFill)

	local menuChip = Card.new({
		parent = right,
		variant = "glass",
		radius = Theme.Radius.MD,
		size = UDim2.fromOffset(U.MenuChipWidth, 40),
		layoutOrder = 3,
		shadow = false,
	})
	Util.display(menuChip.face, "NEW MENU", {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 14),
		TextSize = Theme.Type.Micro,
		TextColor3 = C.TextOnGlassMuted,
		ZIndex = 3,
	})
	local dropLabel = Util.display(menuChip.face, "", {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = Theme.Type.Small + 1,
		TextColor3 = C.TextInverse,
		ZIndex = 3,
	}, C.Outline)

	-- ── Bottom-center: held dish ────────────────────────────────────────────
	local held = Card.new({
		parent = layer,
		variant = "raised",
		radius = math.huge,
		edge = C.Outline,
		name = "HeldChip",
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -U.Margin),
		size = UDim2.fromOffset(U.HeldChipWidth, U.HeldChipHeight),
	})
	held.instance.Visible = false
	local heldIcon = Util.frame(held.face, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(U.HeldChipHeight - 6, U.HeldChipHeight - 6),
		ZIndex = 3,
	})
	local heldCaption = Util.display(held.face, "HOLDING", {
		Position = UDim2.fromOffset(U.HeldChipHeight + 2, 5),
		Size = UDim2.fromOffset(80, 12),
		TextSize = Theme.Type.Micro,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	heldCaption.Name = "Caption"
	local heldName = Util.display(held.face, "", {
		Position = UDim2.fromOffset(U.HeldChipHeight + 2, 17),
		Size = UDim2.fromOffset(80, 22),
		TextSize = Theme.Type.Body + 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(heldName, Theme.Type.Body + 1)
	local qualityTag = Util.solid(held.face, C.Primary, 0, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(62, 22),
		ZIndex = 3,
	})
	Util.pill(qualityTag)
	Util.stroke(qualityTag, C.Outline, Theme.Stroke.Thin)
	local qualityLabel = Util.display(qualityTag, "", { TextSize = Theme.Type.Micro, ZIndex = 4 })

	-- ── Layout ──────────────────────────────────────────────────────────────
	local stationOpen = false
	local function heldOffset(): number
		return if stationOpen then U.StationPanelHeight + U.Margin * 2 else U.Margin
	end
	local function layout()
		local size = Root.size()
		local narrow = size.X < U.NarrowWidth
		local topRow = U.Margin + U.TopRowHeight
		local statusY = if narrow then topRow + U.Gap else U.Margin
		status.Position = UDim2.new(0.5, 0, 0, statusY)
		rush:SetWidth(size.X - U.Margin * 2)
		rushHost.Size = UDim2.new(1, 0, 0, rush:Height())
		local statusBottom = statusY + rush:Height() + (if chips.Visible then U.ChipHeight + U.Gap + 2 else 0)
		Toast.setTop(statusBottom + U.Gap)
		local railTop = math.max(topRow, if narrow then statusBottom else topRow) + U.Margin
		local collide = (size.X - U.StationPanelWidth) / 2 < U.RailTile + U.Margin * 3
		local bottom = if collide then U.StationPanelHeight + U.Margin * 3 else U.Margin
		local centerY = (railTop + size.Y - bottom) / 2
		left.Position = UDim2.fromOffset(U.Margin - Space.SM, centerY)
		right.Position = UDim2.new(1, -(U.Margin - Space.SM), 0, centerY)
		held.instance.Position = UDim2.new(0.5, 0, 1, -heldOffset())
	end
	Root.onResize(function()
		layout()
	end)
	StationPanel.OpenChanged:Connect(function(open)
		stationOpen = open
		local hideForSpace = open and Root.isShort()
		held.instance.Visible = State.held ~= nil and not hideForSpace
		Tween.play(held.instance, { Position = UDim2.new(0.5, 0, 1, -heldOffset()) }, Theme.Motion.Slide)
	end)

	-- ── Menu buttons / keys ────────────────────────────────────────────────
	local binds: { { id: string, keys: { Enum.KeyCode }, action: () -> () } } = {
		{ id = "Shop", keys = Theme.Keys.Shop, action = ShopController.Toggle },
		{
			id = "Leaderboard",
			keys = Theme.Keys.Leaderboard,
			action = function()
				leaderboard:Toggle()
			end,
		},
		{
			id = "Crew",
			keys = Theme.Keys.Crew,
			action = function()
				crew:Toggle()
			end,
		},
		{
			id = "Settings",
			keys = Theme.Keys.Settings,
			action = function()
				settings:Toggle()
			end,
		},
	}
	for _, m in binds do
		InputController.Bind("RHD_" .. m.id, m.keys, function(pressed)
			if pressed then
				m.action()
			end
		end)
	end
	InputController.Bind("RHD_Back", Theme.Keys.Back, function(pressed)
		if pressed then
			Panel.closeAll()
		end
	end)
	InputController.Bind("RHD_Daily", Theme.Keys.Daily, function(pressed)
		local data = State.data
		if pressed and data and data.streakClaimable then
			Net.event("ClaimStreak"):FireServer()
		end
	end)

	-- ── State → HUD ─────────────────────────────────────────────────────────
	local function refreshHeld(item: Types.HeldItem?)
		Util.clear(heldIcon)
		if item then
			Icons.build(item.dishId, heldIcon, U.HeldChipHeight - 6, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
			heldName.Text = Dishes.Defs[item.dishId].displayName
			local q = QUALITY_LOOK[item.quality]
			qualityTag.BackgroundColor3 = q.color
			qualityLabel.Text = q.text
			qualityLabel.TextColor3 = q.textColor
			heldCaption.Text = if item.quality == "Burnt" then "CLEAR IT" else "SERVE IT!"
			held.instance.Visible = not (stationOpen and Root.isShort())
			Tween.bounce(held.instance)
		else
			held.instance.Visible = false
		end
	end

	local function refreshCombo(n: number)
		comboCard.instance.Visible = n >= 1
		comboLabel.Text = `COMBO ×{n}`
		comboCard:SetColor(if n >= 3 then C.Accent else C.Primary)
		comboLabel.TextColor3 = C.TextInverse
		if n >= 1 then
			Tween.bounce(comboCard.instance, 1.3)
		end
	end

	local lastClaimable = false
	local function refreshStatic()
		local data = State.data
		if not data then
			return
		end
		local cycle = #Economy.StreakRewards
		if data.streakClaimable then
			local consecutive = data.streak.day >= 1 and data.streak.lastClaimDay == Streak.dayIndex(State.now()) - 1
			local nextDay = if consecutive then data.streak.day % cycle + 1 else 1
			dailyTile.label.Text = `DAY {nextDay}!`
			dailyTile.button:SetVariant("accent")
			dailyBadge:Set(true)
			if not lastClaimable then
				Tween.bounce(dailyTile.root)
			end
		else
			dailyTile.label.Text = `DAY {math.max(1, data.streak.day)}`
			dailyTile.button:SetVariant("secondary")
			dailyBadge:Set(nil)
		end
		lastClaimable = data.streakClaimable
		shopBadge:Set(ShopPanel.affordableCount())
	end
	Tooltip.attach(dailyTile.button.instance, function()
		local data = State.data
		if data and data.streakClaimable then
			local cycle = #Economy.StreakRewards
			local consecutive = data.streak.day >= 1 and data.streak.lastClaimDay == Streak.dayIndex(State.now()) - 1
			local nextDay = if consecutive then data.streak.day % cycle + 1 else 1
			return `Claim +{Util.comma(Economy.StreakRewards[nextDay])} coins (R)`
		end
		return "Daily streak: come back tomorrow"
	end, "left")
	Tooltip.attach(restockTile.button.instance, function()
		return "Restock: earnings while you're away"
	end, "left")

	local function refreshCoins(animate: boolean)
		local data = State.data
		if not data then
			return
		end
		local target = data.coins
		local wait = if target > coins:Value() then CoinFly.untilArrival() else 0
		if animate and wait > 0 then
			task.delay(wait, function()
				local latest = State.data
				if latest then
					coins:Set(latest.coins, true)
				end
			end)
		else
			coins:Set(target, animate)
		end
	end

	State.Changed.Data:Connect(function()
		refreshCoins(true)
		refreshStatic()
	end)
	State.Changed.Held:Connect(refreshHeld)
	State.Changed.Combo:Connect(refreshCombo)
	refreshCoins(false)
	refreshStatic()
	refreshHeld(State.held)
	refreshCombo(State.combo)
	layout()

	-- ── Per-frame / per-tick ────────────────────────────────────────────────
	local sinceSlow = math.huge
	local lastRushHeight = rush:Height()
	local restockGlow = false
	Ticker.add(function(now, dt)
		rush:Step(now)
		if rush:Height() ~= lastRushHeight then
			lastRushHeight = rush:Height()
			layout()
		end

		sinceSlow += dt
		if sinceSlow < U.ClockSeconds then
			return
		end
		sinceSlow = 0
		local data = State.data
		if not data then
			return
		end

		-- Restock
		local pending = math.max(data.restockPending, Offline.pending(data.lastRestock, now, data.upgrades))
		local cap = Offline.fullRestock(data.upgrades)
		restockTile.label.Text = Util.short(pending)
		local f = if cap > 0 then Util.clamp01(pending / cap) else 0
		restockFill.Size = UDim2.fromScale(f, 1)
		local glow = f >= U.RestockGlowFraction
		if glow ~= restockGlow then
			restockGlow = glow
			restockTile.button:SetVariant(if glow then "success" else "secondary")
			restockFill.BackgroundColor3 = if glow then C.Primary else C.Success
			if glow then
				Tween.bounce(restockTile.root)
			end
		end

		-- Menu drop
		dropLabel.Text = Util.longClock(Schedule.nextMenuDropAt(now) - now)

		-- Boosts
		local shown = 0
		for key, expiry in data.boosts do
			if expiry > now and shown < #boostChips then
				shown += 1
				local line = boostChips[shown]
				local name: string = key
				if line.key ~= name then
					line.key = name
					Util.clear(line.icon)
					Icons.build(BOOST_ICON[name] or "Potion", line.icon, U.ChipHeight - 4, {
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
					})
					Tween.popIn(line.card.instance)
				end
				local pct = math.floor((Products.BoostTipPct[key :: any] or 0) * 100 + 0.5)
				line.label.Text = `+{pct}% · {Util.mmss(expiry - now)}`
			end
		end
		for i, line in boostChips do
			local vis = i <= shown
			line.card.instance.Visible = vis
			if not vis then
				line.key = nil
			end
		end
		local anyChip = shown > 0 or State.combo >= 1
		if anyChip ~= chips.Visible then
			chips.Visible = anyChip
			layout()
		end
	end)
end

return HUDController

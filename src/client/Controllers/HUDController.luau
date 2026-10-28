--!strict
-- HUDController: coins, always-on Rush Hour countdown, daily streak, restock, menu drop, boosts,
-- combo, held dish and the menu buttons. Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.UI.Components.Button)
local Countdown = require(script.Parent.Parent.UI.Components.Countdown)
local CrewPanel = require(script.Parent.Parent.UI.Screens.CrewPanel)
local DishIcon = require(script.Parent.Parent.UI.DishIcon)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local InputController = require(script.Parent.InputController)
local LeaderboardPanel = require(script.Parent.Parent.UI.Screens.LeaderboardPanel)
local Net = require(ReplicatedStorage.Shared.Net)
local Offline = require(ReplicatedStorage.Shared.Logic.Offline)
local Panel = require(script.Parent.Parent.UI.Components.Panel)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Root = require(script.Parent.Parent.UI.Root)
local Schedule = require(ReplicatedStorage.Shared.Logic.Schedule)
local SettingsPanel = require(script.Parent.Parent.UI.Screens.SettingsPanel)
local ShopController = require(script.Parent.ShopController)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ticker = require(script.Parent.Parent.UI.Ticker)
local Tween = require(script.Parent.Parent.UI.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)

local HUDController = {}

local C = Theme.Colors
local U = Theme.UI

local function smallCard(parent: Instance, order: number, height: number, color: Color3): Frame
	return Util.card(parent, color, {
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
	})
end

function HUDController.Init() end

function HUDController.Start()
	State.waitReady()
	local layer = Root.layer("HUD", U.ZHud)

	-- Rush Hour bar (always visible)
	local rushBar = Util.card(layer, C.Mint, {
		Name = "RushBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, U.Margin),
		Size = UDim2.new(1, -U.Margin * 2, 0, U.TopBarHeight),
	})
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(U.PanelMaxWidth, math.huge) }, rushBar)
	local rushLabel = Util.label(rushBar, "", { TextSize = U.TextBody, TextColor3 = C.Ink })
	local rushCountdown = Countdown.new(rushLabel, function(s)
		return `Rush Hour in {Util.mmss(s)}`
	end)
	local stopPulse: (() -> ())? = nil

	-- Row 2: coins + menu buttons
	local row2 = Util.frame(layer, {
		Name = "Row2",
		Position = UDim2.fromOffset(U.Margin, U.Margin * 2 + U.TopBarHeight),
		Size = UDim2.new(1, -U.Margin * 2, 0, U.RowHeight),
	})
	local coinPill = Util.card(row2, C.Mustard, { Size = UDim2.fromOffset(U.CoinPillWidth, U.RowHeight) })
	local disc = Util.card(coinPill, C.White, {
		Size = UDim2.fromOffset(U.RowHeight - U.Gap * 2, U.RowHeight - U.Gap * 2),
		Position = UDim2.fromOffset(U.Gap, U.Gap),
	})
	Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	Util.label(disc, "$", { TextSize = U.TextLarge })
	local coinLabel = Util.label(coinPill, "0", {
		Position = UDim2.fromOffset(U.RowHeight, 0),
		Size = UDim2.new(1, -U.RowHeight - U.Gap, 1, 0),
		TextSize = U.TextLarge,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local displayedCoins = 0
	local cancelCount: (() -> ())? = nil
	local function setCoins(target: number, animate: boolean)
		if cancelCount then
			cancelCount()
			cancelCount = nil
		end
		if not animate or target == displayedCoins then
			displayedCoins = target
			coinLabel.Text = Util.comma(target)
			return
		end
		if target > displayedCoins then
			Tween.bounce(coinPill)
		end
		cancelCount = Tween.number(displayedCoins, target, U.CoinCountSeconds, function(v)
			displayedCoins = v
			coinLabel.Text = Util.comma(v)
		end)
	end

	local menu = Util.frame(row2, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1, -U.CoinPillWidth - U.Gap, 1, 0),
	})
	Util.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, U.Gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, menu)

	local leaderboard = LeaderboardPanel.new()
	local crew = CrewPanel.new()
	local settings = SettingsPanel.new()
	local menuButtons: { { text: string, keys: { Enum.KeyCode }, id: string, action: () -> () } } = {
		{ text = "Shop", id = "Shop", keys = Theme.Keys.Shop, action = ShopController.Toggle },
		{
			text = "Top",
			id = "Leaderboard",
			keys = Theme.Keys.Leaderboard,
			action = function()
				leaderboard:Toggle()
			end,
		},
		{
			text = "Crew",
			id = "Crew",
			keys = Theme.Keys.Crew,
			action = function()
				crew:Toggle()
			end,
		},
		{
			text = "Opts",
			id = "Settings",
			keys = Theme.Keys.Settings,
			action = function()
				settings:Toggle()
			end,
		},
	}
	for i, m in menuButtons do
		Button.new({
			text = m.text,
			parent = menu,
			color = C.Cream,
			textSize = U.TextSmall,
			size = UDim2.fromOffset(U.MenuButtonWidth, U.RowHeight),
			layoutOrder = i,
			onActivated = m.action,
		})
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

	-- Left column
	local column = Util.frame(layer, {
		Name = "Column",
		Position = UDim2.fromOffset(U.Margin, U.Margin * 3 + U.TopBarHeight + U.RowHeight),
		Size = UDim2.fromOffset(U.HudColumnWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Util.list(column, Enum.FillDirection.Vertical, U.Gap)

	-- Restock
	local restock = smallCard(column, 1, U.RowHeight + U.Gap, C.Cream)
	local restockLabel = Util.label(restock, "", {
		Size = UDim2.new(1, -84, 1, 0),
		Position = UDim2.fromOffset(U.Gap, 0),
		TextSize = U.TextSmall,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local collect = Button.new({
		text = "Collect",
		parent = restock,
		color = C.Mint,
		textSize = U.TextSmall,
		size = UDim2.fromOffset(U.CollectButtonWidth, U.RowHeight),
		onActivated = function()
			Net.event("CollectRestock"):FireServer()
		end,
	})
	collect.instance.AnchorPoint = Vector2.new(1, 0.5)
	collect.instance.Position = UDim2.new(1, -U.Gap / 2, 0.5, 0)

	-- Daily streak
	local streak = Button.new({
		text = "",
		parent = column,
		color = C.Mustard,
		textSize = U.TextSmall,
		size = UDim2.new(1, 0, 0, U.RowHeight),
		layoutOrder = 2,
		onActivated = function()
			Net.event("ClaimStreak"):FireServer()
		end,
	})
	InputController.Bind("RHD_Daily", Theme.Keys.Daily, function(pressed)
		local data = State.data
		if pressed and data and data.streakClaimable then
			Net.event("ClaimStreak"):FireServer()
		end
	end)

	-- Menu drop
	local dropCard = smallCard(column, 3, U.BoostLineHeight + U.Gap, C.Cream)
	local dropLabel = Util.label(dropCard, "", { TextSize = U.TextSmall })

	-- Boosts
	local boostBox = Util.frame(column, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
	})
	Util.list(boostBox, Enum.FillDirection.Vertical, U.Gap)
	local boostLines: { { card: Frame, label: TextLabel } } = {}
	for i = 1, U.MaxBoostLines do
		local card = smallCard(boostBox, i, U.BoostLineHeight + U.Gap, C.Mint)
		card.Visible = false
		table.insert(boostLines, { card = card, label = Util.label(card, "", { TextSize = U.TextSmall }) })
	end

	-- Combo
	local comboCard = smallCard(column, 5, U.RowHeight - U.Gap, C.NeonPink)
	local comboLabel = Util.label(comboCard, "", { TextColor3 = C.White, TextSize = U.TextBody })
	comboCard.Visible = false

	-- Held dish
	local heldCard = smallCard(column, 6, U.RowHeight, C.White)
	local heldIconHost = Util.frame(heldCard, {
		Position = UDim2.fromOffset(U.Gap, U.Gap),
		Size = UDim2.fromOffset(U.RowHeight - U.Gap * 2, U.RowHeight - U.Gap * 2),
	})
	local heldLabel = Util.label(heldCard, "", {
		Position = UDim2.fromOffset(U.RowHeight, 0),
		Size = UDim2.new(1, -U.RowHeight - U.Gap, 1, 0),
		TextSize = U.TextSmall,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	heldCard.Visible = false

	local function refreshHeld(item: Types.HeldItem?)
		for _, c in heldIconHost:GetChildren() do
			c:Destroy()
		end
		if item then
			DishIcon.create(item.dishId, heldIconHost)
			heldLabel.Text = `Holding {item.dishId} ({item.quality})`
			heldCard.Visible = true
			Tween.bounce(heldCard)
		else
			heldCard.Visible = false
		end
	end

	local function refreshCombo(n: number)
		comboCard.Visible = n >= 1
		comboLabel.Text = `Combo x{n}`
		if n >= 1 then
			Tween.bounce(comboCard)
		end
	end

	local lastStreakClaimable = false
	local function refreshStatic()
		local data = State.data
		if not data then
			return
		end
		-- Streak
		local cycle = #Economy.StreakRewards
		if data.streakClaimable then
			local nextDay = data.streak.day % cycle + 1
			streak:SetText(`Claim day {nextDay}: +{Economy.StreakRewards[nextDay]}`)
			streak:SetColor(C.Mustard)
			streak:SetEnabled(true)
			if not lastStreakClaimable then
				Tween.bounce(streak.instance)
			end
		else
			streak:SetText(`Streak: day {data.streak.day}`)
			streak:SetColor(C.Cream)
			streak:SetEnabled(false)
		end
		lastStreakClaimable = data.streakClaimable
	end

	local function refreshCoins(animate: boolean)
		local data = State.data
		if data then
			setCoins(data.coins, animate)
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

	-- Per-frame / per-tick text
	local sinceSlow = math.huge
	Ticker.add(function(now, dt)
		-- Rush Hour bar
		local rh = State.rushHour
		if rh and rh.active and rh.endsAt and now < rh.endsAt then
			local by = if rh.triggeredByName then ` · started by {rh.triggeredByName}` else ""
			rushLabel.Text = `RUSH HOUR! {Util.mmss(rh.endsAt - now)}{by}`
			rushBar.BackgroundColor3 = C.NeonPink
			rushLabel.TextColor3 = C.White
			if not stopPulse then
				stopPulse = Tween.pulse(rushBar, 0.04)
			end
		else
			if stopPulse then
				stopPulse()
				stopPulse = nil
			end
			rushBar.BackgroundColor3 = C.Mint
			rushLabel.TextColor3 = C.Ink
			local target = if rh and rh.nextAt > now then rh.nextAt else Schedule.nextRushHourAt(now)
			rushCountdown:SetTarget(target)
			rushCountdown:Step(now)
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
		restockLabel.Text = if cap > 0
			then `Restock {Util.comma(pending)}/{Util.comma(cap)}`
			else `Restock {Util.comma(pending)}`
		collect:SetEnabled(pending > 0)

		-- Menu drop
		dropLabel.Text = `Next menu drop {Util.longClock(Schedule.nextMenuDropAt(now) - now)}`

		-- Boosts
		local shown = 0
		for key, expiry in data.boosts do
			if expiry > now and shown < #boostLines then
				shown += 1
				local name: string = key
				local product = Products.Products[key :: Types.ProductKey]
				if product then
					name = product.displayName
				end
				local pct = math.floor((Products.BoostTipPct[key :: any] or 0) * 100 + 0.5)
				boostLines[shown].label.Text = `{name} +{pct}% · {Util.mmss(expiry - now)}`
			end
		end
		for i, line in boostLines do
			line.card.Visible = i <= shown
		end
	end)
end

return HUDController

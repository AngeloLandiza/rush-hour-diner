--!strict
-- Shop modal: Upgrades / Passes / Products tabs of item cards (icon tile, name, effect, level pips,
-- price button), plus the opt-in rewarded ad as a featured "free" card. Coin prices are mustard,
-- Robux prices are mint, free rewards are pink, so paid and earned never look alike.
-- Upgrade cards spell out the exact effect (UI/UpgradeText, derived from Config + Logic), show level
-- pips and a MAXED state, and track progress toward an unaffordable price ("24 / 60" bar). Buying
-- pops the card with a sparkle while the header coin balance ticks down. Owner: UI agent.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Card = require(script.Parent.Parent.Components.Card)
local Confetti = require(script.Parent.Parent.Components.Confetti)
local CurrencyCounter = require(script.Parent.Parent.Components.CurrencyCounter)
local Icons = require(script.Parent.Parent.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local Root = require(script.Parent.Parent.Root)
local Skeleton = require(script.Parent.Parent.Components.Skeleton)
local Sparkle = require(script.Parent.Parent.Components.Sparkle)
local State = require(script.Parent.Parent.Parent.State)
local StationPanel = require(script.Parent.StationPanel)
local Ticker = require(script.Parent.Parent.Ticker)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Theme = require(script.Parent.Parent.Theme)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Toast = require(script.Parent.Parent.Components.Toast)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local UpgradeLogic = require(ReplicatedStorage.Shared.Logic.Upgrades)
local UpgradeText = require(script.Parent.Parent.UpgradeText)
local Util = require(script.Parent.Parent.Util)

local ShopPanel = {}

export type Shop = {
	panel: Panel.Panel,
	SelectTab: (name: string) -> (),
}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local UPGRADES = "Upgrades"
local PASSES = "Passes"
local PRODUCTS = "Products"

local PASS_ORDER: { string } = { "TipsX2", "AutoChef", "ExtraStation", "VIPBooth" }
local PRODUCT_ORDER: { string } =
	{ "TipPotion", "AdTipBoost", "InstantRestock", "RushHourNow", "CoinsSmall", "CoinsMedium", "CoinsLarge" }

local UPGRADE_ICON: { [string]: string } = {
	GrillSpeed = "Burger+Bolt",
	FryerSpeed = "Fries+Bolt",
	OvenSpeed = "Pizza+Bolt",
	SodaSpeed = "Drink+Bolt",
	Patience = "Music",
	Seating = "Stool",
	Tips = "Coin+Plus",
	AutoServer = "Robot",
	Decor = "Star",
}
local PASS_ICON: { [string]: string } = {
	TipsX2 = "Coins2",
	AutoChef = "ChefHat",
	ExtraStation = "Flame",
	VIPBooth = "Crown",
}
local PRODUCT_ICON: { [string]: string } = {
	TipPotion = "Potion",
	AdTipBoost = "Potion",
	InstantRestock = "Crate",
	RushHourNow = "Clock+Flame",
	CoinsSmall = "Coin",
	CoinsMedium = "Coins2",
	CoinsLarge = "Coins3",
}

local PIP = U.PipSize
local CONFETTI_SMALL = 18
local LEVEL_LABEL_W = 56
local ONE_LINE = 18
local TWO_LINES = 30
-- Rich-text colors for effect numbers: current value in ink, the gain in deep mint.
local EFFECT_COLORS: UpgradeText.Colors = { value = C.Text:ToHex(), gain = C.SuccessEdge:ToHex() }

type Row = { card: Card.Card, name: TextLabel, desc: TextLabel, pips: Frame, textWidth: number }

local function itemCard(
	parent: Instance,
	order: number,
	icon: string,
	tileColor: Color3,
	title: string,
	desc: string
): Row
	local card = Card.new({
		parent = parent,
		variant = "raised",
		size = UDim2.new(1, 0, 0, U.CardHeight),
		layoutOrder = order,
		name = title,
	})
	local face = card.face
	local tile = Util.solid(face, tileColor, Theme.Radius.MD, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Space.SM + 2, 0.5, 0),
		Size = UDim2.fromOffset(U.CardIcon, U.CardIcon),
		ZIndex = 3,
	})
	Util.bevel(tile)
	Util.stroke(tile, Theme.shade(tileColor, 0.2), Theme.Stroke.Thin)
	Icons.build(icon, tile, U.CardIcon * 0.74, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
	})
	local textX = U.CardIcon + Space.SM * 2 + 4
	local textW = -(textX + U.PriceButtonWidth + Space.MD + Space.SM)
	local name = Util.display(face, title, {
		Position = UDim2.fromOffset(textX, Space.SM + 2),
		Size = UDim2.new(1, textW, 0, 22),
		TextSize = Theme.Type.Title - 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(name, Theme.Type.Title - 2)
	local sub = Util.label(face, desc, {
		Position = UDim2.fromOffset(textX, 32),
		Size = UDim2.new(1, textW, 0, 30),
		TextSize = Theme.Type.Caption + 1,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
	})
	Util.fit(sub, Theme.Type.Caption + 1)
	local pips = Util.frame(face, {
		Position = UDim2.fromOffset(textX, U.CardHeight - PIP - Space.SM - 2),
		Size = UDim2.new(1, textW, 0, PIP),
		ZIndex = 3,
		Visible = false,
	})
	Util.list(pips, Enum.FillDirection.Horizontal, Space.XS, nil, Enum.VerticalAlignment.Center)
	return { card = card, name = name, desc = sub, pips = pips, textWidth = textW }
end

local function priceButton(row: Row, variant: Theme.VariantName, onActivated: () -> ()): Button.Button
	return Button.new({
		parent = row.card.face,
		variant = variant,
		textSize = Theme.Type.Title - 2,
		iconSize = 20,
		size = UDim2.fromOffset(U.PriceButtonWidth, U.PriceButtonHeight + Theme.Depth.Lip),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -Space.SM - 2, 0.5, 0),
		onActivated = onActivated,
	})
end

-- Level row for multi-level upgrades: pips (●●○) plus "2/3", turning mint with "MAXED" once every
-- level is bought. Single-level upgrades skip the row (their price button reads MAX) and get a
-- two-line effect instead.
local function setPips(row: Row, level: number, maxLevel: number, levelLabel: TextLabel)
	levelLabel.Parent = nil
	Util.clear(row.pips)
	local maxed = level >= maxLevel
	local show = maxLevel > 1
	row.pips.Visible = show
	-- One-line effect when the level row is shown, two lines otherwise.
	row.desc.Size = UDim2.new(1, row.textWidth, 0, if show then ONE_LINE else TWO_LINES)
	if not show then
		return
	end
	for i = 1, maxLevel do
		local on = i <= level
		local fillColor = if maxed then C.Success elseif on then C.Primary else C.Sunken
		local edgeColor = if maxed then C.SuccessEdge elseif on then C.PrimaryEdge else C.SunkenDeep
		local dot = Util.solid(row.pips, fillColor, 0, {
			Size = UDim2.fromOffset(PIP * 2, PIP),
			LayoutOrder = i,
			ZIndex = 3,
		})
		Util.pill(dot)
		Util.stroke(dot, edgeColor, Theme.Stroke.Hair + 0.5)
	end
	levelLabel.Parent = row.pips
	levelLabel.LayoutOrder = maxLevel + 1
	levelLabel.Text = if maxed then "MAXED" else `{level}/{maxLevel}`
	levelLabel.TextColor3 = if maxed then C.SuccessEdge else C.TextMuted
end

local function celebrate(inst: GuiObject)
	Tween.bounce(inst, 1.06)
	local center = Root.toLocal(inst.AbsolutePosition + inst.AbsoluteSize / 2)
	Confetti.burst(center, CONFETTI_SMALL)
end

-- The purchase moment on an upgrade card: a springy pop, a mint flash on the face and a sparkle.
local function purchasePop(row: Row)
	local s = Tween.scaleOf(row.card.instance)
	s.Scale = Theme.MotionScale.Purchase
	Tween.play(s, { Scale = 1 }, Theme.Motion.Purchase)
	local face = row.card.face
	face.BackgroundColor3 = C.SuccessLight
	Tween.play(face, { BackgroundColor3 = C.Raised }, Theme.Motion.Purchase)
	Sparkle.burst(row.card.instance)
	local center = Root.toLocal(row.card.instance.AbsolutePosition + row.card.instance.AbsoluteSize / 2)
	Confetti.burst(center, CONFETTI_SMALL)
end

local function buildUpgrades(parent: Frame): (() -> (), () -> number)
	local defs: { Types.UpgradeDef } = {}
	for _, def in UpgradeConfig.Defs do
		table.insert(defs, def)
	end
	table.sort(defs, function(a, b)
		return a.order < b.order
	end)
	local refreshers: { () -> () } = {}
	local affordable = 0
	for i, def in defs do
		local row =
			itemCard(parent, i, UPGRADE_ICON[def.id] or "Star", C.PrimaryLight, def.displayName, def.description)
		row.desc.RichText = true
		local levelLabel = Util.display(nil, "", {
			Name = "Level",
			Size = UDim2.fromOffset(LEVEL_LABEL_W, PIP + 4),
			TextSize = Theme.Type.Micro,
			TextColor3 = C.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		row.pips.Size = UDim2.new(1, row.textWidth, 0, PIP + 4)
		row.pips.Position = UDim2.fromOffset(row.pips.Position.X.Offset, U.CardHeight - PIP - Space.SM - 4)
		local lastLevel = -1
		local buy = priceButton(row, "primary", function()
			local data = State.data
			if not data then
				return
			end
			local ok, reason = UpgradeLogic.canBuy(data.upgrades, data.coins, def.id)
			if ok then
				Net.event("BuyUpgrade"):FireServer({ upgradeId = def.id })
			elseif reason == "TooPoor" then
				local cost = UpgradeLogic.nextCost(data.upgrades, def.id) or 0
				Toast.show(`Need {Util.coins(math.max(0, cost - data.coins))} more coins`, "Warning")
				Tween.shake(row.card.instance)
			end
		end)
		-- Progress toward an unaffordable price, under the (red) price button.
		local priceBlock = U.PriceButtonHeight + Theme.Depth.Lip
		local progress = ProgressBar.new(
			row.card.face,
			UDim2.fromOffset(U.PriceButtonWidth, U.PriceProgressHeight),
			C.Primary,
			U.PriceProgressHeight,
			U.PriceButtonWidth
		)
		progress.instance.Name = "PriceProgress"
		progress.instance.AnchorPoint = Vector2.new(1, 0)
		progress.instance.ZIndex = 3
		progress.Caption.TextSize = Theme.Type.Micro
		progress.instance.Visible = false
		local stackTop = (U.CardHeight - (priceBlock + Space.XS + U.PriceProgressHeight)) / 2
		progress.instance.Position = UDim2.new(1, -Space.SM - 2, 0, stackTop + priceBlock + Space.XS)
		local raised: boolean? = nil
		local function placePrice(withProgress: boolean)
			if raised == withProgress then
				return
			end
			local first = raised == nil
			raised = withProgress
			progress.instance.Visible = withProgress
			local y = if withProgress then stackTop + priceBlock / 2 else U.CardHeight / 2
			local target = UDim2.new(1, -Space.SM - 2, 0, y)
			if first then
				buy.instance.Position = target
			else
				Tween.play(buy.instance, { Position = target }, Theme.Motion.Slide)
			end
		end
		local function refresh()
			local data = State.data
			if not data then
				return
			end
			local level = UpgradeLogic.getLevel(data.upgrades, def.id)
			local cost = UpgradeLogic.nextCost(data.upgrades, def.id)
			local ok = UpgradeLogic.canBuy(data.upgrades, data.coins, def.id)
			setPips(row, level, def.maxLevel, levelLabel)
			row.desc.Text = UpgradeText.effect(def, data.upgrades, EFFECT_COLORS)
			if row.card.stroke then
				row.card.stroke.Color = if cost then C.NeutralEdge else C.SuccessEdge
			end
			if cost then
				buy:SetIcon("Coin")
				buy:SetText(Util.short(cost))
				buy:SetVariant(if ok then "primary" else "secondary")
				if not ok then
					buy.label.TextColor3 = C.Danger
					progress:SetFraction(if cost > 0 then data.coins / cost else 1)
					progress:SetCaption(`{Util.short(data.coins)} / {Util.short(cost)}`)
				end
				if ok then
					affordable += 1
				end
				placePrice(not ok)
			else
				buy:SetVariant("success")
				buy:SetIcon("CheckWhite")
				buy:SetText("MAX")
				placePrice(false)
			end
			if lastLevel >= 0 and level > lastLevel then
				purchasePop(row)
				buy:Bounce()
				Toast.show(`{def.displayName} upgraded!`, "Success")
			end
			lastLevel = level
		end
		table.insert(refreshers, refresh)
	end
	return function()
		affordable = 0
		for _, fn in refreshers do
			fn()
		end
	end, function()
		return affordable
	end
end

local function buildPurchases(
	parent: Frame,
	order: { string },
	defs: { [string]: Types.PassDef | Types.ProductDef },
	icons: { [string]: string },
	kind: "Pass" | "Product"
): () -> ()
	local refreshers: { () -> () } = {}
	for i, key in order do
		local def = defs[key]
		local row = itemCard(parent, i + 1, icons[key] or "Star", C.SuccessLight, def.displayName, def.description)
		local b = priceButton(row, "premium", function()
			if def.id == 0 then
				return -- placeholder ids are never prompted
			end
			local owned = kind == "Pass" and State.data ~= nil and (State.data.passes :: any)[key] == true
			if owned then
				return
			end
			if kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.id)
			else
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.id)
			end
		end)
		local function refresh()
			local owned = kind == "Pass" and State.data ~= nil and (State.data.passes :: any)[key] == true
			if owned then
				b:SetEnabled(true)
				b:SetVariant("success")
				b:SetIcon("CheckWhite")
				b:SetText("Owned")
			elseif def.id == 0 then
				b:SetIcon(nil)
				b:SetText("Soon")
				b:SetEnabled(false)
			else
				b:SetEnabled(true)
				b:SetVariant("premium")
				b:SetIcon(nil)
				b:SetText(`R$ {def.priceRobux}`)
			end
		end
		table.insert(refreshers, refresh)
		refresh()
	end
	return function()
		for _, fn in refreshers do
			fn()
		end
	end
end

-- Why the rewarded ad can't be offered right now (nil = it can). Ads must never interrupt service:
-- not during Rush Hour, not while cooking (a station panel open, or a cook this player started still
-- in progress) and not while carrying a dish.
local BUSY_PHASES: { [Types.StationPhase]: boolean } =
	{ Cooking = true, NeedsFlip = true, Finishing = true, Ready = true }

local function adBlockedReason(now: number): string?
	local rh = State.rushHour
	if rh and rh.active and (rh.endsAt == nil or now < rh.endsAt) then
		return "Not during Rush Hour"
	end
	if State.held then
		return "Serve your dish first"
	end
	if StationPanel.isAnyOpen() then
		return "Finish cooking first"
	end
	local me = Players.LocalPlayer.UserId
	for _, st in State.stations do
		if st.cookerUserId == me and BUSY_PHASES[st.phase] then
			return "Finish cooking first"
		end
	end
	return nil
end

-- The opt-in rewarded ad. Its reward is the AdTipBoost developer product, which is also sold as a
-- normal card in this tab; the copy states the reward before the ad plays.
local function buildAd(parent: Frame)
	local adKey: Types.ProductKey = "AdTipBoost"
	local adBoost: Types.BoostKey = "AdTipBoost"
	local boost = Products.Products[adKey]
	local pct = math.floor((Products.BoostTipPct[adBoost] or 0) * 100 + 0.5)
	local minutes = math.floor((boost.boostSeconds or 0) / 60 + 0.5)
	local reward = `+{pct}% tips for {minutes} min`
	local offer = `Watch a short ad: {reward}`
	local row = itemCard(parent, 1, "Ad", C.AccentLight, "Free Tip Boost", offer)
	row.desc.RichText = true
	row.card:SetColor(C.AccentLight)
	if row.card.stroke then
		row.card.stroke.Color = C.Accent
		row.card.stroke.Thickness = Theme.Stroke.Base
	end
	local ad: Button.Button
	local cooling = false
	local blocked: string? = nil
	local shown: string? = "init"
	local function apply()
		local reason = if cooling then "cooldown" else blocked
		if reason == shown then
			return
		end
		shown = reason
		ad:SetEnabled(reason == nil)
		ad:SetText(if cooling then "Wait" elseif blocked then "Busy" else "Watch")
		if blocked and not cooling then
			row.desc.Text = `{reward}\n<font color="#{C.Danger:ToHex()}">{blocked}</font>`
		else
			row.desc.Text = offer
		end
	end
	ad = priceButton(row, "accent", function()
		if cooling or adBlockedReason(State.now()) ~= nil then
			return
		end
		cooling = true
		apply()
		Net.event("RequestRewardedAd"):FireServer() -- explicit opt-in tap only
		task.delay(Timings.Ads.CooldownSeconds, function()
			cooling = false
			apply()
		end)
	end)
	ad:SetIcon("Ad")
	local since = math.huge
	Ticker.add(function(now, dt)
		since += dt
		if since < U.ClockSeconds then
			return
		end
		since = 0
		blocked = adBlockedReason(now)
		apply()
	end)
	blocked = adBlockedReason(State.now())
	apply()
end

function ShopPanel.new(): Shop
	local panel = Panel.new("Shop", { icon = "Shop", accent = C.Danger })
	-- Coin balance in the header so prices read against it, and purchases visibly tick it down.
	local balance = CurrencyCounter.new({
		parent = panel.Header,
		icon = "Coin",
		iconSize = U.ShopBalanceIcon,
		textSize = Theme.Type.Title,
		width = U.ShopBalanceWidth,
		height = U.ShopBalanceHeight,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -(Theme.MinTouchTarget + Space.MD), 0.5, 0),
	})
	balance.instance.Name = "ShopBalance"
	balance.instance.ZIndex = 4
	local balanceSkeleton = Skeleton.text(balance.label, Theme.Skeleton.Number)
	local function refreshBalance()
		local data = State.data
		if not data then
			return
		end
		if balanceSkeleton:IsLoading() then
			balanceSkeleton:Reveal()
			balance:Set(data.coins, false)
		else
			balance:Set(data.coins, panel:IsOpen())
		end
	end
	local tabs = Tabs.new(panel, {
		{ name = UPGRADES, icon = "Bolt" },
		{ name = PASSES, icon = "Crown" },
		{ name = PRODUCTS, icon = "Coin" },
	})
	local refreshUpgrades, affordable = buildUpgrades(tabs.content[UPGRADES])
	local refreshPasses = buildPurchases(tabs.content[PASSES], PASS_ORDER, Products.Passes :: any, PASS_ICON, "Pass")
	buildAd(tabs.content[PRODUCTS])
	local refreshProducts =
		buildPurchases(tabs.content[PRODUCTS], PRODUCT_ORDER, Products.Products :: any, PRODUCT_ICON, "Product")

	local function refresh()
		refreshBalance()
		refreshUpgrades()
		refreshPasses()
		refreshProducts()
		tabs:SetBadge(UPGRADES, affordable() > 0)
	end
	State.Changed.Data:Connect(refresh)
	State.Changed.Snapshot:Connect(refresh)
	State.Changed.PurchaseGranted:Connect(function()
		Toast.show("Purchase complete! Thank you!", "Success")
		if panel:IsOpen() then
			celebrate(panel.instance)
		end
		refresh()
	end)
	panel.OnOpen = refresh
	refresh()
	return {
		panel = panel,
		SelectTab = function(name: string)
			tabs:Select(name)
		end,
	}
end

-- Number of upgrades the player can afford right now (drives the HUD shop badge).
function ShopPanel.affordableCount(): number
	local data = State.data
	if not data then
		return 0
	end
	local n = 0
	for id in UpgradeConfig.Defs do
		if UpgradeLogic.canBuy(data.upgrades, data.coins, id) then
			n += 1
		end
	end
	return n
end

ShopPanel.Tabs = { Upgrades = UPGRADES, Passes = PASSES, Products = PRODUCTS }

return ShopPanel

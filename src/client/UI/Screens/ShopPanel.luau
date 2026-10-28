--!strict
-- Shop modal: Upgrades / Passes / Products tabs of item cards (icon tile, name, effect, level pips,
-- price button), plus the opt-in rewarded ad as a featured "free" card. Coin prices are mustard,
-- Robux prices are mint, free rewards are pink, so paid and earned never look alike. Owner: UI agent.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Card = require(script.Parent.Parent.Components.Card)
local Confetti = require(script.Parent.Parent.Components.Confetti)
local Icons = require(script.Parent.Parent.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Root = require(script.Parent.Parent.Root)
local State = require(script.Parent.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Theme = require(script.Parent.Parent.Theme)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Toast = require(script.Parent.Parent.Components.Toast)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local UpgradeLogic = require(ReplicatedStorage.Shared.Logic.Upgrades)
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
	{ "TipPotion", "InstantRestock", "RushHourNow", "CoinsSmall", "CoinsMedium", "CoinsLarge" }

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
	InstantRestock = "Crate",
	RushHourNow = "Clock+Flame",
	CoinsSmall = "Coin",
	CoinsMedium = "Coins2",
	CoinsLarge = "Coins3",
}

local PIP = 9
local CONFETTI_SMALL = 18

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
	Util.list(pips, Enum.FillDirection.Horizontal, Space.XS)
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

local function setPips(row: Row, level: number, maxLevel: number)
	Util.clear(row.pips)
	row.pips.Visible = maxLevel > 1
	if maxLevel <= 1 then
		return
	end
	for i = 1, maxLevel do
		local on = i <= level
		local dot = Util.solid(row.pips, if on then C.Primary else C.Sunken, 0, {
			Size = UDim2.fromOffset(PIP * 2, PIP),
			LayoutOrder = i,
			ZIndex = 3,
		})
		Util.pill(dot)
		Util.stroke(dot, if on then C.PrimaryEdge else C.SunkenDeep, Theme.Stroke.Hair + 0.5)
	end
	-- Leave room for the pips under a one-line description.
	row.desc.Size = UDim2.new(1, row.textWidth, 0, 18)
end

local function celebrate(inst: GuiObject)
	Tween.bounce(inst, 1.06)
	local center = Root.toLocal(inst.AbsolutePosition + inst.AbsoluteSize / 2)
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
		local function refresh()
			local data = State.data
			if not data then
				return
			end
			local level = UpgradeLogic.getLevel(data.upgrades, def.id)
			local cost = UpgradeLogic.nextCost(data.upgrades, def.id)
			local ok = UpgradeLogic.canBuy(data.upgrades, data.coins, def.id)
			setPips(row, level, def.maxLevel)
			if cost then
				buy:SetIcon("Coin")
				buy:SetText(Util.short(cost))
				buy:SetVariant(if ok then "primary" else "secondary")
				if not ok then
					buy.label.TextColor3 = C.Danger
				end
				if ok then
					affordable += 1
				end
			else
				buy:SetVariant("success")
				buy:SetIcon("CheckWhite")
				buy:SetText("MAX")
			end
			if lastLevel >= 0 and level > lastLevel then
				celebrate(row.card.instance)
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

local function buildAd(parent: Frame)
	local adKey: Types.ProductKey = "AdTipBoost"
	local adBoost: Types.BoostKey = "AdTipBoost"
	local boost = Products.Products[adKey]
	local pct = math.floor((Products.BoostTipPct[adBoost] or 0) * 100 + 0.5)
	local minutes = math.floor((boost.boostSeconds or 0) / 60 + 0.5)
	local row = itemCard(
		parent,
		1,
		"Ad",
		C.AccentLight,
		"Free Tip Boost",
		`Watch a short video for +{pct}% tips, {minutes} min`
	)
	row.card:SetColor(C.AccentLight)
	if row.card.stroke then
		row.card.stroke.Color = C.Accent
		row.card.stroke.Thickness = Theme.Stroke.Base
	end
	local ad: Button.Button
	local cooling = false
	ad = priceButton(row, "accent", function()
		if cooling then
			return
		end
		cooling = true
		ad:SetEnabled(false)
		ad:SetText("Wait")
		Net.event("RequestRewardedAd"):FireServer() -- explicit opt-in tap only
		task.delay(Timings.Ads.CooldownSeconds, function()
			cooling = false
			ad:SetEnabled(true)
			ad:SetText("Watch")
		end)
	end)
	ad:SetText("Watch")
	ad:SetIcon("Ad")
end

function ShopPanel.new(): Shop
	local panel = Panel.new("Shop", { icon = "Shop", accent = C.Danger })
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
		refreshUpgrades()
		refreshPasses()
		refreshProducts()
		tabs:SetBadge(UPGRADES, affordable() > 0)
	end
	State.Changed.Data:Connect(refresh)
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

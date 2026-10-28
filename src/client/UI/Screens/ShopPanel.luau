--!strict
-- Shop panel: Upgrades, Passes and Products tabs, plus the opt-in rewarded ad button.
-- Owner: agent D.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local Products = require(ReplicatedStorage.Shared.Config.Products)
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

local COMING_SOON = "Coming soon"
local PASS_ORDER: { string } = { "TipsX2", "AutoChef", "ExtraStation", "VIPBooth" }
local PRODUCT_ORDER: { string } =
	{ "TipPotion", "InstantRestock", "RushHourNow", "CoinsSmall", "CoinsMedium", "CoinsLarge" }

local function itemRow(parent: Instance, order: number, title: string, desc: string): (Frame, TextLabel)
	local row = Util.card(parent, Theme.Colors.White, {
		Size = UDim2.new(1, 0, 0, Theme.UI.ListRowHeight + Theme.UI.Gap),
		LayoutOrder = order,
	})
	Util.label(row, title, {
		Size = UDim2.new(1, -110, 0, 24),
		Position = UDim2.fromOffset(Theme.UI.Gap, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = Theme.UI.TextBody,
	})
	local sub = Util.label(row, desc, {
		Size = UDim2.new(1, -110, 1, -30),
		Position = UDim2.fromOffset(Theme.UI.Gap, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextSize = Theme.UI.TextSmall,
	})
	return row, sub
end

local function placeRight(b: Button.Button)
	b.instance.AnchorPoint = Vector2.new(1, 0.5)
	b.instance.Position = UDim2.new(1, -Theme.UI.Gap, 0.5, 0)
end

local function buildUpgrades(parent: Frame): () -> ()
	local defs: { Types.UpgradeDef } = {}
	for _, def in UpgradeConfig.Defs do
		table.insert(defs, def)
	end
	table.sort(defs, function(a, b)
		return a.order < b.order
	end)
	local refreshers: { () -> () } = {}
	for i, def in defs do
		local row, sub = itemRow(parent, i, def.displayName, def.description)
		local lastLevel = -1
		local buy: Button.Button
		buy = Button.new({
			text = "",
			parent = row,
			color = Theme.Colors.Mustard,
			size = UDim2.fromOffset(96, Theme.MinTouchTarget),
			onActivated = function()
				local data = State.data
				if not data then
					return
				end
				local ok, reason = UpgradeLogic.canBuy(data.upgrades, data.coins, def.id)
				if ok then
					Net.event("BuyUpgrade"):FireServer({ upgradeId = def.id })
				elseif reason == "TooPoor" then
					Toast.show("Not enough coins yet", "Warning")
				end
			end,
		})
		placeRight(buy)
		local function refresh()
			local data = State.data
			if not data then
				return
			end
			local level = UpgradeLogic.getLevel(data.upgrades, def.id)
			local cost = UpgradeLogic.nextCost(data.upgrades, def.id)
			local ok = UpgradeLogic.canBuy(data.upgrades, data.coins, def.id)
			sub.Text = `{def.description}  Lv {level}/{def.maxLevel}`
			if cost then
				buy:SetText(Util.comma(cost))
				buy:SetColor(if ok then Theme.Colors.Mustard else Theme.Colors.Cream)
				buy:SetEnabled(true) -- stay tappable so a too-poor tap explains itself
			else
				buy:SetText("MAX")
				buy:SetColor(Theme.Colors.Mint)
				buy:SetEnabled(false)
			end
			if lastLevel >= 0 and level > lastLevel then
				Tween.bounce(row)
				buy:Bounce()
			end
			lastLevel = level
		end
		table.insert(refreshers, refresh)
	end
	return function()
		for _, fn in refreshers do
			fn()
		end
	end
end

local function buildPurchases(
	parent: Frame,
	order: { string },
	defs: { [string]: Types.PassDef | Types.ProductDef },
	kind: "Pass" | "Product"
): () -> ()
	local refreshers: { () -> () } = {}
	for i, key in order do
		local def = defs[key]
		local desc = def.description
		local row, sub = itemRow(parent, i + 1, def.displayName, desc)
		local b = Button.new({
			text = "",
			parent = row,
			color = Theme.Colors.Mint,
			size = UDim2.fromOffset(96, Theme.MinTouchTarget),
			onActivated = function()
				if def.id == 0 then
					return -- placeholder ids are never prompted
				end
				if kind == "Pass" then
					MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.id)
				else
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.id)
				end
			end,
		})
		placeRight(b)
		local function refresh()
			sub.Text = desc
			local owned = kind == "Pass" and State.data ~= nil and (State.data.passes :: any)[key] == true
			if owned then
				b:SetText("Owned")
				b:SetEnabled(false)
			elseif def.id == 0 then
				b:SetText(COMING_SOON)
				b:SetEnabled(false)
			else
				b:SetText(`R$ {def.priceRobux}`)
				b:SetEnabled(true)
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
	local ad: Button.Button
	local cooling = false
	ad = Button.new({
		text = `Watch an ad: +{pct}% tips for {minutes} min`,
		parent = parent,
		color = Theme.Colors.NeonPink,
		textColor = Theme.Colors.White,
		size = UDim2.new(1, 0, 0, Theme.UI.RowHeight + Theme.UI.Gap),
		layoutOrder = 1,
		onActivated = function()
			if cooling then
				return
			end
			cooling = true
			ad:SetEnabled(false)
			Net.event("RequestRewardedAd"):FireServer() -- explicit opt-in tap only
			task.delay(Timings.Ads.CooldownSeconds, function()
				cooling = false
				ad:SetEnabled(true)
			end)
		end,
	})
end

function ShopPanel.new(): Panel.Panel
	local panel = Panel.new("Shop")
	local tabs = Tabs.new(panel.Body, { "Upgrades", "Passes", "Products" })
	local refreshUpgrades = buildUpgrades(tabs.content.Upgrades)
	local refreshPasses = buildPurchases(tabs.content.Passes, PASS_ORDER, Products.Passes :: any, "Pass")
	buildAd(tabs.content.Products)
	local refreshProducts = buildPurchases(tabs.content.Products, PRODUCT_ORDER, Products.Products :: any, "Product")

	local function refresh()
		refreshUpgrades()
		refreshPasses()
		refreshProducts()
	end
	State.Changed.Data:Connect(refresh)
	State.Changed.PurchaseGranted:Connect(function(p)
		Toast.show("Purchase complete! Thank you!", "Success")
		Tween.bounce(panel.instance)
		refresh()
	end)
	panel.OnOpen = refresh
	refresh()
	return panel
end

return ShopPanel

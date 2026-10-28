--!strict
-- NotifyController: Toast remote, CoinsAwarded (coin fly + big "+N" popup + reward toast) and the
-- legendary banner. Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinFly = require(script.Parent.Parent.UI.CoinFly)
local Icons = require(script.Parent.Parent.UI.Icons)
local LegendaryBanner = require(script.Parent.Parent.UI.Screens.LegendaryBanner)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require(ReplicatedStorage.Shared.Contracts.Remotes)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Tween = require(script.Parent.Parent.UI.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)

local NotifyController = {}

local C = Theme.C
local U = Theme.UI

local POPUP_W = 260
local POPUP_H = 64
local POPUP_RISE = 70
local POPUP_SECONDS = 1.3
local POPUP_ICON = 48

local function coinPopup(amount: number)
	local layer = Root.layer("Popups", U.ZToasts)
	local size = Root.size()
	local origin = Vector2.new(size.X / 2, size.Y * 0.45)
	local root = Util.frame(layer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(origin.X, origin.Y),
		Size = UDim2.fromOffset(POPUP_W, POPUP_H),
	})
	Util.list(
		root,
		Enum.FillDirection.Horizontal,
		Theme.Space.SM,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	Icons.build("Coin", root, POPUP_ICON, { LayoutOrder = 1 })
	local label = Util.display(root, `+{Util.coins(amount)}`, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = Theme.Type.Hero,
		TextColor3 = C.Gold,
		LayoutOrder = 2,
	})
	local stroke = Util.textStroke(label, C.Outline, Theme.Stroke.Bold)
	Util.gradient(label, C.Highlight, C.GoldLight)
	Tween.bounce(root, 1.5)
	Tween.to(
		root,
		{ Position = UDim2.fromOffset(origin.X, origin.Y - POPUP_RISE) },
		POPUP_SECONDS,
		Enum.EasingStyle.Quad
	)
	CoinFly.fromLocal(origin, amount)
	task.delay(POPUP_SECONDS / 2, function()
		Tween.to(label, { TextTransparency = 1 }, POPUP_SECONDS / 2)
		Tween.to(stroke, { Transparency = 1 }, POPUP_SECONDS / 2)
		Tween.popOut(root)
	end)
	task.delay(POPUP_SECONDS, function()
		root:Destroy()
	end)
end

function NotifyController.Init() end

function NotifyController.Start()
	State.waitReady()
	Net.event("Toast").OnClientEvent:Connect(function(p: Remotes.ToastPayload)
		if typeof(p) == "table" and typeof(p.text) == "string" then
			Toast.show(p.text, p.kind)
		end
	end)
	Net.event("CoinsAwarded").OnClientEvent:Connect(function(p: Remotes.CoinsAwardedPayload)
		if typeof(p) == "table" and typeof(p.amount) == "number" then
			coinPopup(p.amount)
			Toast.show(`+{Util.comma(p.amount)} coins: {p.reason}`, "Reward")
		end
	end)
	Net.event("LegendaryAnnounce").OnClientEvent:Connect(function(a: Types.LegendaryAnnouncement)
		if typeof(a) == "table" then
			LegendaryBanner.show(a)
		end
	end)
end

return NotifyController

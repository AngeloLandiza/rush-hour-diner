--!strict
-- NotifyController: Toast remote, CoinsAwarded popups, legendary banner. Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local U = Theme.UI

local function coinPopup(amount: number)
	local layer = Root.layer("Popups", U.ZToasts)
	local label = Util.label(layer, `+{Util.comma(amount)}`, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(U.PopupWidth, U.PopupHeight),
		TextSize = U.TextHuge,
		TextColor3 = Theme.Colors.Mustard,
	})
	local stroke = Util.new("UIStroke", {
		Color = Theme.Colors.Ink,
		Thickness = U.Stroke,
	}, label)
	Tween.bounce(label)
	Tween.to(label, { Position = UDim2.fromScale(0.5, 0.3) }, U.PopupSeconds, Enum.EasingStyle.Quad)
	task.delay(U.PopupSeconds / 2, function()
		Tween.to(label, { TextTransparency = 1 }, U.PopupSeconds / 2)
		Tween.to(stroke, { Transparency = 1 }, U.PopupSeconds / 2)
	end)
	task.delay(U.PopupSeconds, function()
		label:Destroy()
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

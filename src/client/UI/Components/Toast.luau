--!strict
-- Stacked, auto-dismissing toast notifications with a bouncy pop-in. Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local Toast = {}

local host: Frame? = nil
local live: { Frame } = {}

local function getHost(): Frame
	if host then
		return host
	end
	local layer = Root.layer("Toasts", Theme.UI.ZToasts)
	local h = Util.frame(layer, {
		Name = "ToastHost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.UI.TopBarHeight + Theme.UI.Margin * 2 + Theme.UI.RowHeight),
		Size = UDim2.new(1, -Theme.UI.Margin * 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Util.list(h, Enum.FillDirection.Vertical, Theme.UI.Gap, Enum.HorizontalAlignment.Center)
	host = h
	return h
end

local function dismiss(toast: Frame)
	local i = table.find(live, toast)
	if i then
		table.remove(live, i)
	end
	local scale = Tween.scaleOf(toast)
	local t = Tween.to(scale, { Scale = 0 }, Theme.UI.FadeSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	t.Completed:Once(function()
		toast:Destroy()
	end)
end

function Toast.show(text: string, kind: Types.ToastKind?)
	local h = getHost()
	local k: Types.ToastKind = kind or "Info"
	local color = Theme.ToastColor[k]
	local toast = Util.card(h, color, {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, Theme.UI.ToastHeight),
	})
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(Theme.UI.PanelMaxWidth, math.huge) }, toast)
	local textColor = if k == "Warning" or k == "Success" then Theme.Colors.Ink else Theme.Colors.White
	Util.label(toast, text, { TextColor3 = textColor, TextSize = Theme.UI.TextBody })
	Tween.popIn(toast)

	table.insert(live, toast)
	while #live > Theme.UI.ToastMax do
		local oldest = live[1]
		table.remove(live, 1)
		oldest:Destroy()
	end
	task.delay(Theme.UI.ToastSeconds, function()
		if toast.Parent then
			dismiss(toast)
		end
	end)
end

return Toast

--!strict
-- Toast stack: white pills with a kind-colored icon disc and edge, stacked top-center under the
-- status row, newest on top, max Theme.UI.ToastMax. Pop in, shrink out. Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Card = require(script.Parent.Card)
local Icons = require(script.Parent.Parent.Icons)
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local Toast = {}

local C = Theme.C
local U = Theme.UI

local host: Frame? = nil
local live: { Frame } = {}
local counter = 0
local topOffset = U.Margin + U.RushPillHeight + U.ChipHeight + U.Gap * 3

local function getHost(): Frame
	if host then
		return host
	end
	local layer = Root.layer("Toasts", U.ZToasts)
	local h = Util.frame(layer, {
		Name = "ToastHost",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, topOffset),
		Size = UDim2.new(1, -U.Margin * 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Util.maxSize(h, U.ToastWidth)
	Util.list(h, Enum.FillDirection.Vertical, U.Gap, Enum.HorizontalAlignment.Center)
	host = h
	return h
end

-- The HUD moves the stack below whatever is showing at the top (two rows on narrow screens).
function Toast.setTop(y: number)
	topOffset = y
	local h = host
	if h then
		h.Position = UDim2.new(0.5, 0, 0, y)
	end
end

local function dismiss(toast: Frame)
	local i = table.find(live, toast)
	if i then
		table.remove(live, i)
	end
	Tween.popOut(toast, function()
		toast:Destroy()
	end)
end

function Toast.show(text: string, kind: Types.ToastKind?)
	local h = getHost()
	local k: Types.ToastKind = kind or "Info"
	local kinds: { [string]: { color: Color3, deep: Color3, icon: string } } = Theme.ToastKinds :: any
	local look = kinds[k] or kinds.Info
	counter += 1
	local card = Card.new({
		parent = h,
		variant = "raised",
		radius = math.huge,
		edge = look.deep,
		size = UDim2.new(1, 0, 0, U.ToastHeight),
		layoutOrder = -counter,
		name = "Toast",
	})
	if card.stroke then
		card.stroke.Thickness = Theme.Stroke.Base
	end
	local disc = U.ToastHeight - 10
	Icons.build(look.icon, card.face, disc, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		ZIndex = 3,
	})
	local label = Util.label(card.face, text, {
		Position = UDim2.fromOffset(disc + 14, 0),
		Size = UDim2.new(1, -(disc + 26), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = Theme.Type.Body,
		ZIndex = 3,
	})
	Util.fit(label, Theme.Type.Body)
	Tween.popIn(card.instance)

	local toast = card.instance
	table.insert(live, toast)
	while #live > U.ToastMax do
		local oldest = table.remove(live, 1)
		if oldest then
			dismiss(oldest)
		end
	end
	task.delay(U.ToastSeconds, function()
		if toast.Parent and table.find(live, toast) then
			dismiss(toast)
		end
	end)
end

return Toast

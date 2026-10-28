--!strict
-- Hover tooltip for mouse users: small dark glass bubble beside a GuiObject. Touch devices skip it
-- (the tile labels carry the same information). Owner: UI agent.
local UserInputService = game:GetService("UserInputService")

local Card = require(script.Parent.Card)
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

local Tooltip = {}

local C = Theme.C
local U = Theme.UI

local bubble: Card.Card? = nil
local text: TextLabel? = nil

local function get(): (Card.Card, TextLabel)
	local b, t = bubble, text
	if b and t then
		return b, t
	end
	local layer = Root.layer("Tooltip", U.ZTooltip)
	local card = Card.new({
		parent = layer,
		variant = "glass",
		radius = Theme.Radius.SM,
		size = UDim2.fromOffset(U.TooltipWidth, U.TooltipHeight),
		name = "Tooltip",
	})
	card.instance.Visible = false
	local label = Util.label(card.face, "", {
		TextColor3 = C.TextInverse,
		TextSize = Theme.Type.Small,
		ZIndex = 3,
	})
	Util.fit(label, Theme.Type.Small)
	Util.padding(card.face, 2, Theme.Space.SM)
	bubble, text = card, label
	return card, label
end

function Tooltip.hide()
	local b = bubble
	if b then
		b.instance.Visible = false
	end
end

-- side: "right" (default) or "left" of the target.
function Tooltip.attach(target: GuiObject, getText: () -> string, side: string?)
	target.MouseEnter:Connect(function()
		if not UserInputService.MouseEnabled then
			return
		end
		local card, label = get()
		label.Text = getText()
		local pos = Root.toLocal(target.AbsolutePosition)
		local size = target.AbsoluteSize / Root.scale()
		local inst = card.instance
		if side == "left" then
			inst.AnchorPoint = Vector2.new(1, 0.5)
			inst.Position = UDim2.fromOffset(pos.X - Theme.Space.SM, pos.Y + size.Y / 2)
		else
			inst.AnchorPoint = Vector2.new(0, 0.5)
			inst.Position = UDim2.fromOffset(pos.X + size.X + Theme.Space.SM, pos.Y + size.Y / 2)
		end
		inst.Visible = true
		Tween.popIn(inst)
	end)
	target.MouseLeave:Connect(Tooltip.hide)
	if target:IsA("GuiButton") then
		target.MouseButton1Down:Connect(Tooltip.hide)
	end
end

return Tooltip

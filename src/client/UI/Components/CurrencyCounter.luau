--!strict
-- HUD currency pill: dark glass capsule, oversized coin icon breaking the left edge, Fredoka number
-- that counts up (never jumps), a punch on each arriving coin and an optional "+" shortcut button.
-- Spending ticks the number down with a ketchup flash, a small squash and a floating "−N".
-- Owner: UI agent.
local Button = require(script.Parent.Button)
local Card = require(script.Parent.Card)
local Icons = require(script.Parent.Parent.Icons)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Options = {
	parent: Instance,
	icon: string,
	iconSize: number?, -- defaults to Theme.UI.CoinIconSize
	textSize: number?, -- defaults to Theme.Type.Heading
	width: number,
	height: number,
	position: UDim2?,
	anchor: Vector2?,
	onPlus: (() -> ())?,
}

export type CurrencyCounter = {
	instance: Frame,
	icon: Frame,
	label: TextLabel,
	Set: (self: CurrencyCounter, value: number, animate: boolean) -> (),
	Punch: (self: CurrencyCounter) -> (),
	Value: (self: CurrencyCounter) -> number,
}

local CurrencyCounter = {}

local C = Theme.C
local PUNCH_COOLDOWN = 0.06

function CurrencyCounter.new(opts: Options): CurrencyCounter
	local h = opts.height
	local iconPx = opts.iconSize or Theme.UI.CoinIconSize
	local textSize = opts.textSize or Theme.Type.Heading
	local root = Util.frame(opts.parent, {
		Name = "CurrencyCounter",
		Size = UDim2.fromOffset(opts.width, h),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
	})
	local pill = Card.new({
		parent = root,
		variant = "glass",
		radius = math.huge,
		position = UDim2.fromOffset(iconPx * 0.45, 0),
		size = UDim2.new(1, -iconPx * 0.45, 1, 0),
	})
	local plusW = if opts.onPlus then Theme.MinTouchTarget else 0
	local label = Util.display(pill.face, "0", {
		Name = "Value",
		Position = UDim2.fromOffset(iconPx * 0.6, 0),
		Size = UDim2.new(1, -(iconPx * 0.6 + plusW + Theme.Space.SM), 1, 0),
		TextSize = textSize,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, C.Outline)
	Util.fit(label, textSize)
	local icon = Icons.build(opts.icon, root, iconPx, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -2, 0.5, 0),
		ZIndex = 5,
	})
	if opts.onPlus then
		local plus = Button.new({
			parent = pill.face,
			variant = "success",
			icon = "Plus",
			iconSize = 14,
			radius = math.huge,
			lip = Theme.Depth.SmallLip,
			size = UDim2.fromOffset(plusW, plusW),
			anchor = Vector2.new(1, 0.5),
			position = UDim2.fromScale(1, 0.5),
			onActivated = opts.onPlus,
		})
		plus.instance.ZIndex = 4
	end

	local shown = 0
	local cancel: (() -> ())? = nil
	local lastPunch = 0
	local restColor = label.TextColor3

	local function spend(amount: number)
		label.TextColor3 = C.Danger
		Tween.play(label, { TextColor3 = restColor }, Theme.Motion.Count)
		local s = Tween.scaleOf(label)
		s.Scale = Theme.MotionScale.SpendDip
		Tween.play(s, { Scale = 1 }, Theme.Motion.Release)
		local float = Util.display(root, `−{Util.coins(amount)}`, {
			Name = "SpendFloat",
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, iconPx * 0.6, 1, 0),
			Size = UDim2.new(1, -iconPx * 0.6, 0, Theme.Type.Body + 2),
			TextSize = Theme.Type.Body + 2,
			TextColor3 = C.Danger,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		}, C.Outline)
		local fade = Tween.play(float, {
			Position = UDim2.new(0, iconPx * 0.6, 1, Theme.Space.LG),
			TextTransparency = 1,
		}, Theme.Motion.SpendFloat)
		local stroke = float:FindFirstChildOfClass("UIStroke")
		if stroke then
			Tween.play(stroke, { Transparency = 1 }, Theme.Motion.SpendFloat)
		end
		fade.Completed:Once(function()
			float:Destroy()
		end)
	end

	local self: CurrencyCounter = {
		instance = root,
		icon = icon,
		label = label,
		Set = function(_, value: number, animate: boolean)
			if cancel then
				cancel()
				cancel = nil
			end
			if not animate or value == shown then
				shown = value
				label.Text = Util.coins(value)
				return
			end
			if value > shown then
				Tween.bounce(label, 1.12)
			else
				spend(shown - value)
			end
			cancel = Tween.number(shown, value, Theme.MotionSeconds.Count.seconds, function(v)
				shown = v
				label.Text = Util.coins(v)
			end)
		end,
		Punch = function(_)
			local t = os.clock()
			if t - lastPunch < PUNCH_COOLDOWN then
				return
			end
			lastPunch = t
			Tween.bounce(icon, 1.25)
		end,
		Value = function(_)
			return shown
		end,
	}
	return self
end

return CurrencyCounter

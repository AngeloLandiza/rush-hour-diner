--!strict
-- Chunky bouncy button: rounded, outlined, gradient, min 44px, press/release spring. Owner: agent D.
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Options = {
	text: string,
	parent: Instance?,
	size: UDim2?,
	color: Color3?,
	textColor: Color3?,
	textSize: number?,
	layoutOrder: number?,
	onActivated: (() -> ())?,
	onDown: (() -> ())?, -- fires on press (touch/mouse down), for hold-style buttons
}

export type Button = {
	instance: TextButton,
	SetText: (self: Button, text: string) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	SetColor: (self: Button, color: Color3) -> (),
	Bounce: (self: Button) -> (),
	_color: Color3,
	_enabled: boolean,
	_gradient: UIGradient,
}

local Button = {}

local function applyLook(b: Button)
	local base = if b._enabled then b._color else Theme.shade(b._color, Theme.UI.DisabledShade)
	b.instance.BackgroundColor3 = base
	b._gradient.Color = ColorSequence.new(Theme.Colors.White, Theme.shade(Theme.Colors.White, Theme.UI.GradientShade))
	b.instance.TextTransparency = if b._enabled then 0 else 0.35
	b.instance.Selectable = b._enabled
end

function Button.new(opts: Options): Button
	local color = opts.color or Theme.Colors.Mustard
	local inst = Util.new("TextButton", {
		Name = "Button",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = Theme.Font,
		Text = opts.text,
		TextSize = opts.textSize or Theme.UI.TextBody,
		TextColor3 = opts.textColor or Theme.Colors.Ink,
		TextWrapped = true,
		BackgroundColor3 = color,
		Size = opts.size or UDim2.fromOffset(Theme.MinTouchTarget * 2, Theme.MinTouchTarget),
		LayoutOrder = opts.layoutOrder or 0,
		Selectable = true,
	}, opts.parent) :: TextButton
	Util.corner(inst)
	Util.stroke(inst)
	local gradient = Util.new("UIGradient", { Rotation = 90 }, inst) :: UIGradient
	Util.new("UISizeConstraint", {
		MinSize = Vector2.new(Theme.MinTouchTarget, Theme.MinTouchTarget),
	}, inst)

	local self: Button = {
		instance = inst,
		_color = color,
		_enabled = true,
		_gradient = gradient,
		SetText = function(this: Button, text: string)
			this.instance.Text = text
		end,
		SetEnabled = function(this: Button, enabled: boolean)
			this._enabled = enabled
			applyLook(this)
		end,
		SetColor = function(this: Button, c: Color3)
			this._color = c
			applyLook(this)
		end,
		Bounce = function(this: Button)
			Tween.bounce(this.instance)
		end,
	}
	applyLook(self)

	inst.MouseButton1Down:Connect(function()
		if self._enabled then
			Tween.press(inst)
			if opts.onDown then
				opts.onDown()
			end
		end
	end)
	local function release()
		Tween.release(inst)
	end
	inst.MouseButton1Up:Connect(release)
	inst.MouseLeave:Connect(release)
	inst.Activated:Connect(function()
		if self._enabled and opts.onActivated then
			opts.onActivated()
		end
	end)
	return self
end

return Button

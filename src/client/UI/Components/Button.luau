--!strict
-- Chunky 3D button: soft shadow > darker lip > beveled face with a glossy highlight. Press sinks the
-- face into the lip and squashes; release springs back with a Back overshoot. Variants come from
-- Config/UI.Variants (primary, secondary, success, premium, danger, accent, info, ghost); disabled is a
-- state. Min touch target 44px. Text auto-shrinks to fit. Owner: UI agent.
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Icons = require(script.Parent.Parent.Icons)
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Options = {
	text: string?,
	icon: string?,
	iconSize: number?,
	variant: Theme.VariantName?,
	parent: Instance?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	radius: number?, -- px; math.huge = pill / circle
	lip: number?,
	layoutOrder: number?,
	name: string?,
	shadow: boolean?,
	onActivated: (() -> ())?,
	onDown: (() -> ())?, -- fires on press (touch/mouse down), for hold-style buttons
	onUp: (() -> ())?,
}

export type Button = {
	instance: TextButton,
	face: Frame,
	content: Frame,
	label: TextLabel,
	SetText: (self: Button, text: string) -> (),
	SetIcon: (self: Button, icon: string?) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	SetVariant: (self: Button, variant: Theme.VariantName) -> (),
	SetColor: (self: Button, face: Color3, lip: Color3?) -> (),
	Bounce: (self: Button) -> (),
	IsEnabled: (self: Button) -> boolean,
}

local Button = {}

local C = Theme.C
local Depth = Theme.Depth
local MS = Theme.MotionScale
local PAD = Theme.Space.SM
local ICON_GAP = Theme.Space.XS + 2

local function round(f: GuiObject, radius: number?)
	if radius == math.huge then
		Util.pill(f)
	else
		Util.corner(f, radius or Theme.Radius.MD)
	end
end

function Button.new(opts: Options): Button
	local variantName: Theme.VariantName = opts.variant or "primary"
	local ghost = variantName == "ghost"
	local lip = if ghost then 0 else (opts.lip or Depth.Lip)
	local textSize = opts.textSize or Theme.Type.Title
	local iconSize = opts.iconSize or math.floor(textSize * 1.35)

	local inst = Util.new("TextButton", {
		Name = opts.name or "Button",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Size = opts.size or UDim2.fromOffset(Theme.MinTouchTarget * 2, Theme.MinTouchTarget),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		LayoutOrder = opts.layoutOrder or 0,
		Selectable = true,
	}, opts.parent) :: TextButton
	Util.new("UISizeConstraint", { MinSize = Vector2.new(Theme.MinTouchTarget, Theme.MinTouchTarget) }, inst)

	local shadow: Frame? = nil
	if not ghost and opts.shadow ~= false then
		local s = Util.frame(inst, {
			Name = "Shadow",
			BackgroundTransparency = Depth.ShadowTransparency,
			BackgroundColor3 = C.Shadow,
			Position = UDim2.fromOffset(0, lip + 2),
			Size = UDim2.new(1, 0, 1, -lip),
			ZIndex = 1,
		})
		round(s, opts.radius)
		shadow = s
	end
	local lipFrame = Util.frame(inst, {
		Name = "Lip",
		BackgroundTransparency = if ghost then 1 else 0,
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = 2,
	})
	round(lipFrame, opts.radius)
	local face = Util.frame(inst, {
		Name = "Face",
		BackgroundTransparency = if ghost then 1 else 0,
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = 3,
	})
	round(face, opts.radius)
	local edge = Util.stroke(face, C.Outline, Theme.Stroke.Thin, if ghost then 1 else 0)
	if not ghost then
		Util.bevel(face)
		local hl = Util.frame(face, {
			Name = "Highlight",
			BackgroundTransparency = Depth.HighlightTransparency,
			BackgroundColor3 = C.Highlight,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.new(1, -PAD, Depth.HighlightHeight, -2),
		})
		round(hl, if opts.radius == math.huge then math.huge else Theme.Radius.SM)
	end

	local content = Util.frame(face, { Name = "Content", Size = UDim2.fromScale(1, 1) })
	Util.list(
		content,
		Enum.FillDirection.Horizontal,
		ICON_GAP,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	local iconHost = Util.frame(content, {
		Name = "IconHost",
		Size = UDim2.fromOffset(iconSize, iconSize),
		LayoutOrder = 1,
		Visible = false,
	})
	local label = Util.display(content, opts.text or "", {
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = textSize,
		LayoutOrder = 2,
	})
	local labelStroke = Util.textStroke(label, C.Outline, Theme.Stroke.Thin)

	local enabled = true
	local faceOverride: Color3? = nil
	local lipOverride: Color3? = nil
	local hovering = false
	local pressed = false

	local function applyLook()
		local v = Theme.variant(if enabled then variantName else "disabled")
		if not ghost then
			face.BackgroundColor3 = if enabled and faceOverride then faceOverride else v.face
			lipFrame.BackgroundColor3 = if enabled and lipOverride then lipOverride else v.lip
			edge.Color = if enabled and lipOverride then Theme.shade(lipOverride, 0.25) else v.edge
		end
		label.TextColor3 = v.text
		label.TextTransparency = if enabled then 0 else Depth.DisabledTextTransparency
		labelStroke.Enabled = v.textStroke ~= nil
		if v.textStroke then
			labelStroke.Color = v.textStroke
		end
		inst.Selectable = enabled
		if shadow then
			shadow.Visible = enabled
		end
	end

	local function refit()
		local text = label.Text
		label.Visible = text ~= ""
		if text == "" then
			return
		end
		local scale = Root.scale() * Tween.scaleOf(inst).Scale
		local width = inst.AbsoluteSize.X / math.max(scale, 0.01)
		if width <= 0 then
			return
		end
		local avail = width - PAD * 2 - (if iconHost.Visible then iconSize + ICON_GAP else 0)
		local size = textSize
		while size > Theme.Type.MinScaled do
			local bounds = TextService:GetTextSize(text, size, Theme.DisplayEnum, Vector2.new(math.huge, math.huge))
			if bounds.X <= avail then
				break
			end
			size -= 1
		end
		label.TextSize = size
	end

	local function setIcon(name: string?)
		Util.clear(iconHost)
		iconHost.Visible = name ~= nil
		if name then
			Icons.build(name, iconHost, iconSize, { Size = UDim2.fromScale(1, 1) })
		end
		refit()
	end

	local self: Button = {
		instance = inst,
		face = face,
		content = content,
		label = label,
		SetText = function(_, text: string)
			if label.Text ~= text then
				label.Text = text
				refit()
			end
		end,
		SetIcon = function(_, name: string?)
			setIcon(name)
		end,
		SetEnabled = function(_, on: boolean)
			if enabled ~= on then
				enabled = on
				applyLook()
			end
		end,
		SetVariant = function(_, name: Theme.VariantName)
			variantName = name
			faceOverride, lipOverride = nil, nil
			applyLook()
		end,
		SetColor = function(_, faceColor: Color3, lipColor: Color3?)
			faceOverride = faceColor
			lipOverride = lipColor or Theme.shade(faceColor, 0.25)
			applyLook()
		end,
		Bounce = function(_)
			Tween.bounce(inst)
		end,
		IsEnabled = function(_)
			return enabled
		end,
	}
	applyLook()
	setIcon(opts.icon)

	local sink = math.floor(lip * MS.PressSink + 0.5)
	local function down()
		pressed = true
		Tween.press(inst)
		Tween.play(face, { Position = UDim2.fromOffset(0, sink) }, Theme.Motion.Press)
	end
	local function up()
		if not pressed then
			return
		end
		pressed = false
		Tween.play(face, { Position = UDim2.fromOffset(0, 0) }, Theme.Motion.Release)
		if hovering then
			Tween.hover(inst, true)
		else
			Tween.release(inst)
		end
	end

	inst.MouseButton1Down:Connect(function()
		if enabled then
			down()
			if opts.onDown then
				opts.onDown()
			end
		end
	end)
	inst.MouseButton1Up:Connect(function()
		up()
		if enabled and opts.onUp then
			opts.onUp()
		end
	end)
	inst.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		hovering = true
		if enabled and not pressed then
			Tween.hover(inst, true)
		end
	end)
	inst.MouseLeave:Connect(function()
		hovering = false
		up()
		Tween.hover(inst, false)
	end)
	inst.Activated:Connect(function()
		if enabled and opts.onActivated then
			opts.onActivated()
		end
	end)
	inst:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	return self
end

return Button

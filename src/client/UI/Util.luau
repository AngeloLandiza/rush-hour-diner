--!strict
-- UI construction primitives and number/time formatting. Owner: UI agent.
local Theme = require(script.Parent.Theme)

local Util = {}

local C = Theme.C
local Depth = Theme.Depth

-- Create an instance, apply props, parent last.
function Util.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst: any = Instance.new(className)
	if props then
		for key, value in props do
			inst[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function merge(base: { [string]: any }, extra: { [string]: any }?): { [string]: any }
	if extra then
		for k, v in extra do
			base[k] = v
		end
	end
	return base
end

-- Sets (or creates) the frame's single UICorner.
local function setCorner(parent: Instance, radius: UDim): UICorner
	local existing = parent:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = radius
		return existing
	end
	return Util.new("UICorner", { CornerRadius = radius }, parent)
end

function Util.corner(parent: Instance, radius: number?): UICorner
	return setCorner(parent, UDim.new(0, radius or Theme.Radius.MD))
end

-- Fully rounded ends (pill / circle).
function Util.pill(parent: Instance): UICorner
	return setCorner(parent, UDim.new(0.5, 0))
end

-- Border stroke around a frame.
function Util.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Util.new("UIStroke", {
		Color = color or C.Outline,
		Thickness = thickness or Theme.Stroke.Base,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- Outline around text glyphs (white text over busy backgrounds).
function Util.textStroke(label: Instance, color: Color3?, thickness: number?): UIStroke
	return Util.new("UIStroke", {
		Color = color or C.Outline,
		Thickness = thickness or Theme.Stroke.Thin,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, label)
end

-- Vertical gradient (top -> bottom) multiplied over the background color.
function Util.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return Util.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	}, parent)
end

-- The standard bevel: lighter top, slightly darker bottom.
function Util.bevel(parent: Instance): UIGradient
	return Util.gradient(parent, C.Highlight, Theme.shade(C.Highlight, Depth.BevelDarken))
end

function Util.padding(parent: Instance, top: number, right: number?, bottom: number?, left: number?): UIPadding
	return Util.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	}, parent)
end

function Util.list(
	parent: Instance,
	direction: Enum.FillDirection?,
	gap: number?,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	return Util.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.UI.Gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	}, parent)
end

function Util.aspect(parent: Instance, ratio: number?): UIAspectRatioConstraint
	return Util.new("UIAspectRatioConstraint", { AspectRatio = ratio or 1 }, parent)
end

function Util.maxSize(parent: Instance, x: number, y: number?): UISizeConstraint
	return Util.new("UISizeConstraint", { MaxSize = Vector2.new(x, y or math.huge) }, parent)
end

function Util.frame(parent: Instance?, props: { [string]: any }?): Frame
	return Util.new("Frame", merge({ BackgroundTransparency = 1, BorderSizePixel = 0 }, props), parent)
end

-- Solid rounded frame (no shadow). For layered cards use Components/Card.
function Util.solid(parent: Instance?, color: Color3, radius: number?, props: { [string]: any }?): Frame
	local f = Util.frame(parent, merge({ BackgroundTransparency = 0, BackgroundColor3 = color }, props))
	Util.corner(f, radius)
	return f
end

-- Body copy label (Builder Sans Bold, Ink).
function Util.label(parent: Instance?, text: string, props: { [string]: any }?): TextLabel
	return Util.new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = Theme.Fonts.Body,
			Text = text,
			TextSize = Theme.Type.Body,
			TextColor3 = C.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Size = UDim2.fromScale(1, 1),
		}, props),
		parent
	)
end

-- Heading / number label (Fredoka One). stroke = outline color for light text on color.
function Util.display(parent: Instance?, text: string, props: { [string]: any }?, stroke: Color3?): TextLabel
	local label = Util.label(
		parent,
		text,
		merge({ FontFace = Theme.Fonts.Display, TextSize = Theme.Type.Title, TextWrapped = false }, props)
	)
	if stroke then
		Util.textStroke(label, stroke, Theme.Stroke.Thin)
	end
	return label
end

-- Label that shrinks to fit its box (between MinScaled and maxSize).
function Util.fit(label: TextLabel, maxSize: number): TextLabel
	label.TextScaled = true
	Util.new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = Theme.Type.MinScaled }, label)
	return label
end

function Util.clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- ── Formatting ──────────────────────────────────────────────────────────────

-- "m:ss" for a number of seconds (rounded up, clamped at zero).
function Util.mmss(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Long countdowns: "6d 4h", "3h 20m", else "m:ss".
function Util.longClock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days = s // 86400
	local hours = (s % 86400) // 3600
	local minutes = (s % 3600) // 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return Util.mmss(s)
end

-- 12345 -> "12,345"
function Util.comma(n: number): string
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local reversed = string.reverse(s)
	local withCommas = string.gsub(reversed, "(%d%d%d)", "%1,")
	local out = string.reverse(withCommas)
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return if n < 0 then "-" .. out else out
end

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi" }

-- Abbreviated with 3 significant digits, rounded down: 999, 1.23K, 12.3K, 123K, 4.56M.
function Util.short(n: number): string
	local sign = if n < 0 then "-" else ""
	local v = math.abs(n)
	if v < 1000 then
		return sign .. tostring(math.floor(v + 0.5))
	end
	local i = 0
	while v >= 1000 and i < #SUFFIXES do
		v /= 1000
		i += 1
	end
	local s: string
	if v >= 100 then
		s = tostring(math.floor(v))
	elseif v >= 10 then
		s = string.format("%.1f", math.floor(v * 10) / 10)
	else
		s = string.format("%.2f", math.floor(v * 100) / 100)
	end
	if string.find(s, ".", 1, true) then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return sign .. s .. SUFFIXES[i]
end

-- Coin amounts: full digits while they fit (< 100,000), abbreviated after.
function Util.coins(n: number): string
	if math.abs(n) < 100000 then
		return Util.comma(n)
	end
	return Util.short(n)
end

function Util.clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

-- Attribute from the instance or its nearest ancestor that has it.
function Util.findAttribute(inst: Instance?, name: string): any
	local node = inst
	while node and node ~= workspace do
		local v = node:GetAttribute(name)
		if v ~= nil then
			return v
		end
		node = node.Parent
	end
	return nil
end

return Util

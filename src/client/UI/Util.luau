--!strict
-- Small UI construction and formatting helpers. Owner: agent D.
local Theme = require(script.Parent.Theme)

local Util = {}

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

function Util.corner(parent: Instance, radius: number?): UICorner
	return Util.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.UI.Corner) }, parent)
end

function Util.stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Util.new("UIStroke", {
		Color = color or Theme.Colors.Ink,
		Thickness = thickness or Theme.UI.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Util.padding(parent: Instance, pad: number): UIPadding
	local p = UDim.new(0, pad)
	return Util.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p }, parent)
end

function Util.list(
	parent: Instance,
	direction: Enum.FillDirection?,
	gap: number?,
	hAlign: Enum.HorizontalAlignment?
): UIListLayout
	return Util.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.UI.Gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
	}, parent)
end

function Util.frame(parent: Instance?, props: { [string]: any }?): Frame
	local merged: { [string]: any } = { BackgroundTransparency = 1, BorderSizePixel = 0 }
	if props then
		for k, v in props do
			merged[k] = v
		end
	end
	return Util.new("Frame", merged, parent)
end

function Util.label(parent: Instance?, text: string, props: { [string]: any }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.Font,
		Text = text,
		TextSize = Theme.UI.TextBody,
		TextColor3 = Theme.Colors.Ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}
	if props then
		for k, v in props do
			merged[k] = v
		end
	end
	return Util.new("TextLabel", merged, parent)
end

-- Rounded, outlined card in a palette color.
function Util.card(parent: Instance?, color: Color3, props: { [string]: any }?): Frame
	local merged: { [string]: any } = { BackgroundColor3 = color, BackgroundTransparency = 0 }
	if props then
		for k, v in props do
			merged[k] = v
		end
	end
	local f = Util.frame(parent, merged)
	Util.corner(f)
	Util.stroke(f)
	return f
end

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
	local s = tostring(math.floor(n + 0.5))
	local reversed = string.reverse(s)
	local withCommas = string.gsub(reversed, "(%d%d%d)", "%1,")
	local out = string.reverse(withCommas)
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return out
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

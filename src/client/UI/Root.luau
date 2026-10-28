--!strict
-- The single ScreenGui, a UIScale driven by viewport size, and named z-layers. Owner: agent D.
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Root = {}

local content: Frame? = nil
local uiScale: UIScale? = nil
local layers: { [string]: Frame } = {}

local function computeScale(viewport: Vector2): number
	local s = math.min(viewport.X / Theme.UI.RefWidth, viewport.Y / Theme.UI.RefHeight)
	return math.clamp(s, Theme.UI.MinScale, Theme.UI.MaxScale)
end

local function build(): Frame
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local g = Util.new("ScreenGui", {
		Name = "RushHourDiner",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, -- safe-area aware on phones
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui) :: ScreenGui
	local frame = Util.frame(g, { Name = "Content", Size = UDim2.fromScale(1, 1) })
	local scale = Util.new("UIScale", { Scale = 1 }, frame) :: UIScale
	local function refresh()
		local s = computeScale(g.AbsoluteSize)
		scale.Scale = s
		frame.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	refresh()
	content = frame
	uiScale = scale
	return frame
end

function Root.content(): Frame
	return content or build()
end

-- Current UI scale (design px -> screen px).
function Root.scale(): number
	Root.content()
	return if uiScale then uiScale.Scale else 1
end

-- A full-size transparent layer with a fixed ZIndex.
function Root.layer(name: string, z: number): Frame
	local existing = layers[name]
	if existing then
		return existing
	end
	local layer = Util.frame(Root.content(), { Name = name, Size = UDim2.fromScale(1, 1), ZIndex = z })
	layers[name] = layer
	return layer
end

return Root

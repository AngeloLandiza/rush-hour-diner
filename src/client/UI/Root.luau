--!strict
-- The single ScreenGui, a UIScale driven by viewport size, named z-layers and a resize signal that
-- reports the design-space size (screen px / scale). Owner: UI agent.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Parent.Signal)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Root = {
	-- Fires with the content size in design px whenever the viewport changes.
	Resized = Signal.new() :: Signal.Signal<Vector2>,
}

local U = Theme.UI

local gui: ScreenGui? = nil
local content: Frame? = nil
local uiScale: UIScale? = nil
local layers: { [string]: Frame } = {}
local designSize = Vector2.new(U.RefWidth, U.RefHeight)

local function computeScale(viewport: Vector2): number
	local s = math.min(viewport.X / U.RefWidth, viewport.Y / U.RefHeight)
	return math.clamp(s, U.MinScale, U.MaxScale)
end

local function build(): Frame
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local g = Util.new("ScreenGui", {
		Name = "RushHourDiner",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	-- Keep clear of the Roblox top bar and device notches.
	g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	g.Parent = playerGui
	local frame = Util.frame(g, { Name = "Content", Size = UDim2.fromScale(1, 1) })
	local scale = Util.new("UIScale", { Scale = 1 }, frame) :: UIScale
	local function refresh()
		local abs = g.AbsoluteSize
		local s = computeScale(abs)
		local size = Vector2.new(abs.X / s, abs.Y / s)
		-- Studio-only: ScreenGui attribute DebugViewport (Vector2, design px) previews a small screen.
		local debugSize = g:GetAttribute("DebugViewport")
		if RunService:IsStudio() and typeof(debugSize) == "Vector2" then
			s = 1
			size = debugSize
			frame.Size = UDim2.fromOffset(debugSize.X, debugSize.Y)
			frame.ClipsDescendants = true
		else
			frame.Size = UDim2.fromScale(1 / s, 1 / s)
			frame.ClipsDescendants = false
		end
		scale.Scale = s
		if size ~= designSize then
			designSize = size
			Root.Resized:Fire(size)
		end
	end
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	g:GetAttributeChangedSignal("DebugViewport"):Connect(refresh)
	gui = g
	content = frame
	uiScale = scale
	refresh()
	return frame
end

function Root.content(): Frame
	return content or build()
end

function Root.gui(): ScreenGui
	Root.content()
	return gui :: ScreenGui
end

-- Current UI scale (design px -> screen px).
function Root.scale(): number
	Root.content()
	return if uiScale then uiScale.Scale else 1
end

-- Content size in design px.
function Root.size(): Vector2
	Root.content()
	return designSize
end

-- Narrow screens (portrait phones) stack the top row into two rows.
function Root.isNarrow(): boolean
	return Root.size().X < U.NarrowWidth
end

-- Short screens (landscape phones) hide secondary chips while the station panel is open.
function Root.isShort(): boolean
	return Root.size().Y < U.ShortHeight
end

-- Converts an absolute screen point (AbsolutePosition space) into content-local design px.
function Root.toLocal(abs: Vector2): Vector2
	local c = Root.content()
	local s = Root.scale()
	return (abs - c.AbsolutePosition) / s
end

-- Call fn now and on every resize.
function Root.onResize(fn: (Vector2) -> ())
	fn(Root.size())
	Root.Resized:Connect(fn)
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

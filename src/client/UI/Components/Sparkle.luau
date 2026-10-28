--!strict
-- Sparkle twinkle: a handful of four-point glints that pop in over a target and fade out with a
-- quarter turn. Used for the shop purchase moment. Owner: UI agent.
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

local Sparkle = {}

local C = Theme.C
local U = Theme.UI
local rng = Random.new()

local ARM_RATIO = 0.22 -- arm thickness / glint size
local STAGGER = 0.05
local SPIN_DEGREES = 90
local MIN_SCALE = 0.6

local function glint(layer: Frame, at: Vector2, size: number, color: Color3): Frame
	local host = Util.frame(layer, {
		Name = "Sparkle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(at.X, at.Y),
		Size = UDim2.fromOffset(size, size),
		Rotation = rng:NextNumber(0, 45),
	})
	local arm = math.max(2, math.floor(size * ARM_RATIO))
	for _, vertical in { true, false } do
		local bar = Util.solid(host, color, 0, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if vertical then UDim2.new(0, arm, 1, 0) else UDim2.new(1, 0, 0, arm),
		})
		Util.pill(bar)
	end
	local core = Util.solid(host, C.Highlight, 0, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(arm + 2, arm + 2),
		ZIndex = 2,
	})
	Util.pill(core)
	return host
end

-- Twinkles over a GuiObject (positions in its absolute rect, drawn on a top layer).
function Sparkle.burst(target: GuiObject, count: number?)
	local layer = Root.layer("Sparkle", U.ZBanner + 2)
	local topLeft = Root.toLocal(target.AbsolutePosition)
	local size = target.AbsoluteSize / Root.scale()
	local colors = { C.Highlight, C.GoldLight, C.Primary }
	for i = 1, count or U.SparkleCount do
		local at = topLeft + Vector2.new(rng:NextNumber(0, size.X), rng:NextNumber(0, size.Y))
		local px = U.SparkleSize * rng:NextNumber(MIN_SCALE, 1)
		local g = glint(layer, at, px, colors[(i - 1) % #colors + 1])
		local scale = Tween.scaleOf(g)
		scale.Scale = 0
		task.delay((i - 1) * STAGGER, function()
			if not g.Parent then
				return
			end
			local grow = Tween.play(scale, { Scale = 1 }, Theme.Motion.Sparkle)
			grow.Completed:Once(function()
				Tween.play(g, { Rotation = g.Rotation + SPIN_DEGREES }, Theme.Motion.SparkleOut)
				local shrink = Tween.play(scale, { Scale = 0 }, Theme.Motion.SparkleOut)
				shrink.Completed:Once(function()
					g:Destroy()
				end)
			end)
		end)
	end
end

return Sparkle

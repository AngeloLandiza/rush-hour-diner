--!strict
-- Confetti burst: small palette-colored chips that pop outward, then tumble down and fade.
-- Owner: UI agent.
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

local Confetti = {}

local P = Theme.Colors
local COLORS = { P.Mustard, P.Ketchup, P.Mint, P.NeonPink, P.White, P.PinkGlow }
local rng = Random.new()

local BURST_SECONDS = 0.35
local FALL_SECONDS = 1.1
local FALL_DISTANCE = 180
local SPREAD = 150

-- origin is a content-local design-px point.
function Confetti.burst(origin: Vector2, count: number?)
	local layer = Root.layer("Confetti", Theme.UI.ZBanner + 1)
	for _ = 1, count or Theme.UI.ConfettiCount do
		local w = rng:NextInteger(6, 10)
		local chip = Util.frame(layer, {
			BackgroundTransparency = 0,
			BackgroundColor3 = COLORS[rng:NextInteger(1, #COLORS)],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Size = UDim2.fromOffset(w, w * rng:NextNumber(1.4, 2)),
			Rotation = rng:NextNumber(0, 360),
		})
		Util.corner(chip, 2)
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(0.3, 1) * SPREAD
		local mid = origin + Vector2.new(math.cos(angle) * dist, math.sin(angle) * dist * 0.7 - SPREAD * 0.35)
		Tween.to(
			chip,
			{ Position = UDim2.fromOffset(mid.X, mid.Y), Rotation = chip.Rotation + rng:NextNumber(-180, 180) },
			BURST_SECONDS,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		task.delay(BURST_SECONDS, function()
			if not chip.Parent then
				return
			end
			local drift = rng:NextNumber(-40, 40)
			local fall = Tween.to(chip, {
				Position = UDim2.fromOffset(mid.X + drift, mid.Y + FALL_DISTANCE),
				Rotation = chip.Rotation + rng:NextNumber(-360, 360),
				BackgroundTransparency = 1,
			}, FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			fall.Completed:Once(function()
				chip:Destroy()
			end)
		end)
	end
end

return Confetti

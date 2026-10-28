--!strict
-- Animated diagonal candy stripes laid over a fill (cooking bars, the Rush Hour bar). Square tiles
-- each carry a 45° stepped-transparency UIGradient with period 0.5, so neighbours line up seamlessly;
-- the strip slides one tile per period. No rotated frames (those would escape ClipsDescendants).
-- Owner: UI agent.
local Theme = require(script.Parent.Parent.Theme)
local Ticker = require(script.Parent.Parent.Ticker)
local Util = require(script.Parent.Parent.Util)

export type Stripes = {
	instance: Frame,
	SetEnabled: (self: Stripes, on: boolean) -> (),
	Destroy: (self: Stripes) -> (),
}

local Stripes = {}

local STRIPE_T = 0.72 -- stripe transparency (white over the fill)
local EDGE = 0.001

local function pattern(): NumberSequence
	-- Stripe on [0, 0.25) and [0.5, 0.75): period 0.5 along the gradient axis.
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, STRIPE_T),
		NumberSequenceKeypoint.new(0.25 - EDGE, STRIPE_T),
		NumberSequenceKeypoint.new(0.25, 1),
		NumberSequenceKeypoint.new(0.5 - EDGE, 1),
		NumberSequenceKeypoint.new(0.5, STRIPE_T),
		NumberSequenceKeypoint.new(0.75 - EDGE, STRIPE_T),
		NumberSequenceKeypoint.new(0.75, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- parent should clip (ClipsDescendants) and be height px tall; maxWidth = widest the parent gets.
function Stripes.new(parent: GuiObject, height: number, maxWidth: number, zIndex: number?): Stripes
	local tiles = math.ceil(maxWidth / height) + 2
	local strip = Util.frame(parent, {
		Name = "Stripes",
		Size = UDim2.fromOffset(tiles * height, height),
		ZIndex = zIndex or 5,
	})
	local seq = pattern()
	for i = 0, tiles - 1 do
		local tile = Util.frame(strip, {
			BackgroundTransparency = 0,
			BackgroundColor3 = Theme.C.Highlight,
			Position = UDim2.fromOffset(i * height, 0),
			Size = UDim2.fromOffset(height, height),
			ZIndex = zIndex or 5,
		})
		Util.new("UIGradient", { Rotation = 45, Transparency = seq }, tile)
	end
	local enabled = true
	local period = Theme.UI.StripePeriodSeconds
	local remove = Ticker.add(function(now)
		if not enabled then
			return
		end
		local f = (now % period) / period
		strip.Position = UDim2.fromOffset(-height + f * height, 0)
	end)
	local self: Stripes = {
		instance = strip,
		SetEnabled = function(_, on: boolean)
			enabled = on
			strip.Visible = on
		end,
		Destroy = function(_)
			remove()
			strip:Destroy()
		end,
	}
	return self
end

return Stripes

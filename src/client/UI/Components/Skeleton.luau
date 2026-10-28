--!strict
-- Loading placeholder for a text label: shows "--:--" (or any placeholder) with a soft shimmer band
-- sweeping across the glyphs until the real value arrives, then pops the value in. Owner: UI agent.
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Skeleton = {
	-- Ends the loading state. text (optional) replaces the placeholder; the label pops in.
	Reveal: (self: Skeleton, text: string?) -> (),
	IsLoading: (self: Skeleton) -> boolean,
}

local Skeleton = {}

local S = Theme.Skeleton
local SHIMMER: TweenInfo = Theme.Motion.Shimmer

local function band(): NumberSequence
	local mid = 0.5
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, S.DimTransparency),
		NumberSequenceKeypoint.new(mid - S.BandWidth, S.DimTransparency),
		NumberSequenceKeypoint.new(mid, S.BandTransparency),
		NumberSequenceKeypoint.new(mid + S.BandWidth, S.DimTransparency),
		NumberSequenceKeypoint.new(1, S.DimTransparency),
	})
end

function Skeleton.text(label: TextLabel, placeholder: string?): Skeleton
	label.Text = placeholder or S.Clock
	local gradient = Util.new("UIGradient", {
		Name = "Shimmer",
		Transparency = band(),
		Offset = Vector2.new(-1, 0),
	}, label) :: UIGradient
	local sweep = TweenService:Create(
		gradient,
		TweenInfo.new(SHIMMER.Time, SHIMMER.EasingStyle, SHIMMER.EasingDirection, -1),
		{ Offset = Vector2.new(1, 0) }
	)
	sweep:Play()
	-- Ghost the glyph outline too, so the placeholder reads as "not yet" rather than a value.
	local stroke = label:FindFirstChildOfClass("UIStroke")
	local strokeTransparency = if stroke then stroke.Transparency else 0
	if stroke then
		stroke.Transparency = S.DimTransparency
	end
	local loading = true

	local self: Skeleton = {
		Reveal = function(_, text: string?)
			if not loading then
				if text then
					label.Text = text
				end
				return
			end
			loading = false
			sweep:Cancel()
			gradient:Destroy()
			if stroke then
				stroke.Transparency = strokeTransparency
			end
			if text then
				label.Text = text
			end
			Tween.popIn(label)
		end,
		IsLoading = function(_)
			return loading
		end,
	}
	return self
end

return Skeleton

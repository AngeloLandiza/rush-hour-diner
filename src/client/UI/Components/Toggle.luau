--!strict
-- On/off switch: pill track (mint when on, sunken when off) with a raised knob that slides with a
-- Back overshoot. The whole control is a 44px+ touch target. Owner: UI agent.
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Toggle = {
	instance: TextButton,
	Set: (self: Toggle, on: boolean) -> (),
}

local Toggle = {}

local C = Theme.C
local U = Theme.UI
local KNOB_INSET = 3

function Toggle.new(parent: Instance, onChanged: () -> ()): Toggle
	local hit = Util.new("TextButton", {
		Name = "Toggle",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Theme.Space.MD, 0.5, 0),
		Size = UDim2.fromOffset(U.ToggleWidth + Theme.Space.SM, Theme.MinTouchTarget),
	}, parent) :: TextButton
	local track = Util.solid(hit, C.Sunken, 0, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(U.ToggleWidth, U.ToggleHeight),
	})
	Util.pill(track)
	local edge = Util.stroke(track, C.SunkenDeep, Theme.Stroke.Thin)
	local knobSize = U.ToggleHeight - KNOB_INSET * 2
	local knob = Util.solid(track, C.Raised, 0, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB_INSET, 0.5, 0),
		Size = UDim2.fromOffset(knobSize, knobSize),
		ZIndex = 3,
	})
	Util.pill(knob)
	Util.bevel(knob)
	Util.stroke(knob, C.NeutralEdge, Theme.Stroke.Thin)
	local shadow = Util.solid(track, C.Shadow, 0, {
		BackgroundTransparency = Theme.Depth.ShadowTransparency,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KNOB_INSET, 0.5, 2),
		Size = UDim2.fromOffset(knobSize, knobSize),
		ZIndex = 2,
	})
	Util.pill(shadow)

	local self: Toggle = {
		instance = hit,
		Set = function(_, on: boolean)
			local x = if on then U.ToggleWidth - KNOB_INSET - knobSize else KNOB_INSET
			Tween.play(knob, { Position = UDim2.new(0, x, 0.5, 0) }, Theme.Motion.Release)
			Tween.play(shadow, { Position = UDim2.new(0, x, 0.5, 2) }, Theme.Motion.Release)
			Tween.play(track, { BackgroundColor3 = if on then C.Success else C.Sunken }, Theme.Motion.Fade)
			edge.Color = if on then C.SuccessEdge else C.SunkenDeep
		end,
	}
	hit.Activated:Connect(onChanged)
	return self
end

return Toggle

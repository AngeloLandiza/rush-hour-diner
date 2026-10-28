--!strict
-- Bouncy tween helpers. Back/Elastic easing for pop-ins and presses. Owner: agent D.
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Tween = {}

local SCALE_NAME = "BounceScale"

-- Play a tween and return it.
function Tween.to(
	inst: Instance,
	props: { [string]: any },
	seconds: number,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- The UIScale used for pop/press effects on a GuiObject (created on demand).
function Tween.scaleOf(inst: Instance): UIScale
	local existing = inst:FindFirstChild(SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local s = Instance.new("UIScale")
	s.Name = SCALE_NAME
	s.Parent = inst
	return s
end

-- Pop in from small with a Back overshoot.
function Tween.popIn(inst: Instance, delay: number?)
	local s = Tween.scaleOf(inst)
	s.Scale = Theme.UI.PopFromScale
	if delay and delay > 0 then
		task.delay(delay, function()
			Tween.to(s, { Scale = 1 }, Theme.UI.PopInSeconds, Enum.EasingStyle.Back)
		end)
	else
		Tween.to(s, { Scale = 1 }, Theme.UI.PopInSeconds, Enum.EasingStyle.Back)
	end
end

-- Shrink on press.
function Tween.press(inst: Instance)
	Tween.to(Tween.scaleOf(inst), { Scale = Theme.UI.PressScale }, Theme.UI.PressSeconds, Enum.EasingStyle.Quad)
end

-- Spring back on release.
function Tween.release(inst: Instance)
	Tween.to(Tween.scaleOf(inst), { Scale = 1 }, Theme.UI.ReleaseSeconds, Enum.EasingStyle.Elastic)
end

-- Quick celebratory bounce (grow past 1 then settle).
function Tween.bounce(inst: Instance)
	local s = Tween.scaleOf(inst)
	s.Scale = Theme.UI.BounceScale
	Tween.to(s, { Scale = 1 }, Theme.UI.BounceSeconds, Enum.EasingStyle.Elastic)
end

-- Tween a number and call onStep for each value. Returns a cancel function.
function Tween.number(from: number, to: number, seconds: number, onStep: (number) -> ()): () -> ()
	local value = Instance.new("NumberValue")
	value.Value = from
	local conn = value.Changed:Connect(onStep)
	local tween = TweenService:Create(
		value,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = to }
	)
	tween.Completed:Once(function()
		conn:Disconnect()
		value:Destroy()
	end)
	tween:Play()
	return function()
		tween:Cancel()
		conn:Disconnect()
		value:Destroy()
	end
end

-- Endless gentle pulse of a GuiObject's scale. Returns a stop function.
function Tween.pulse(inst: Instance, amount: number): () -> ()
	local s = Tween.scaleOf(inst)
	local tween = TweenService:Create(
		s,
		TweenInfo.new(Theme.UI.PulseSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + amount }
	)
	tween:Play()
	return function()
		tween:Cancel()
		s.Scale = 1
	end
end

return Tween

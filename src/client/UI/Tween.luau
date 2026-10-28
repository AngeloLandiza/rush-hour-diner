--!strict
-- Motion helpers built on the Theme motion specs (press, release, hover, pop, bounce, pulse, shake).
-- Owner: UI agent.
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Tween = {}

local SCALE_NAME = "MotionScale"
local M = Theme.Motion
local MS = Theme.MotionScale

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

-- Play a tween with a named Theme motion spec.
function Tween.play(inst: Instance, props: { [string]: any }, motion: TweenInfo): Tween
	local tween = TweenService:Create(inst, motion, props)
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
	s.Scale = MS.PopFrom
	if delay and delay > 0 then
		task.delay(delay, function()
			Tween.play(s, { Scale = 1 }, M.PopIn)
		end)
	else
		Tween.play(s, { Scale = 1 }, M.PopIn)
	end
end

-- Shrink out quickly, then call done.
function Tween.popOut(inst: Instance, done: (() -> ())?)
	local t = Tween.play(Tween.scaleOf(inst), { Scale = 0 }, M.PopOut)
	if done then
		t.Completed:Once(function()
			done()
		end)
	end
end

function Tween.press(inst: Instance)
	Tween.play(Tween.scaleOf(inst), { Scale = MS.Press }, M.Press)
end

function Tween.release(inst: Instance)
	Tween.play(Tween.scaleOf(inst), { Scale = 1 }, M.Release)
end

function Tween.hover(inst: Instance, on: boolean)
	Tween.play(Tween.scaleOf(inst), { Scale = if on then MS.Hover else 1 }, M.Hover)
end

-- Quick celebratory bounce (grow past 1 then settle).
function Tween.bounce(inst: Instance, amount: number?)
	local s = Tween.scaleOf(inst)
	s.Scale = amount or MS.Bounce
	Tween.play(s, { Scale = 1 }, M.Bounce)
end

-- Horizontal "no" shake via Rotation (works inside layouts).
function Tween.shake(inst: GuiObject)
	local base = 0
	local steps = { 9, -8, 6, -4, 2, 0 }
	task.spawn(function()
		for _, deg in steps do
			if not inst.Parent then
				return
			end
			Tween.to(inst, { Rotation = base + deg }, 0.04, Enum.EasingStyle.Sine)
			task.wait(0.04)
		end
	end)
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
	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		conn:Disconnect()
		value:Destroy()
	end
	tween.Completed:Once(function()
		onStep(to)
		cleanup()
	end)
	tween:Play()
	return function()
		tween:Cancel()
		cleanup()
	end
end

-- Endless gentle pulse of a GuiObject's scale. Returns a stop function.
function Tween.pulse(inst: Instance, amount: number?): () -> ()
	local s = Tween.scaleOf(inst)
	local tween = TweenService:Create(
		s,
		TweenInfo.new(Theme.MotionSeconds.Pulse.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1 + (amount or MS.Pulse) }
	)
	tween:Play()
	return function()
		tween:Cancel()
		s.Scale = 1
	end
end

-- Endless linear rotation (rays, shimmer gradients). Returns a stop function.
function Tween.spin(inst: Instance, seconds: number): () -> ()
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{ Rotation = 360 }
	)
	tween:Play()
	return function()
		tween:Cancel()
	end
end

return Tween

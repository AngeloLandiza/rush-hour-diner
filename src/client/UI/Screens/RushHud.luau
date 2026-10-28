--!strict
-- Rush Hour HUD widget. Idle: dark glass pill with a clock and "RUSH HOUR IN m:ss" (turns pink and
-- pulses in the last minute). Active: a neon bar with a draining pink-to-gold fill, moving stripes,
-- a bobbing flame, a "2x PAY" tag, a pulsing glow, plus neon screen-edge glow and a start stamp.
-- Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Card = require(script.Parent.Parent.Components.Card)
local Countdown = require(script.Parent.Parent.Components.Countdown)
local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Icons = require(script.Parent.Parent.Icons)
local Root = require(script.Parent.Parent.Root)
local Schedule = require(ReplicatedStorage.Shared.Logic.Schedule)
local Skeleton = require(script.Parent.Parent.Components.Skeleton)
local Stamp = require(script.Parent.Parent.Components.Stamp)
local State = require(script.Parent.Parent.Parent.State)
local Stripes = require(script.Parent.Parent.Components.Stripes)
local Theme = require(script.Parent.Parent.Theme)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

export type RushHud = {
	instance: Frame,
	Step: (self: RushHud, now: number) -> (),
	Height: (self: RushHud) -> number,
	SetWidth: (self: RushHud, maxWidth: number) -> (),
}

local RushHud = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local GLOW_PAD = 6
local TAG_W = 66
local FLAME = 46
local FLAME_BOB_DEG = 8
local FLAME_BOB_SPEED = 6
local GLOW_SPEED = 5
local EDGE_PULSE = 0.15

local function edgeGlow(): Frame
	local layer = Root.layer("RushEdge", U.ZWorld)
	local host = Util.frame(layer, { Name = "RushEdgeGlow", Size = UDim2.fromScale(1, 1), Visible = false })
	local fade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	local sides = {
		{ pos = UDim2.fromScale(0, 0), size = UDim2.new(1, 0, 0, U.EdgeGlowSize), rot = 90 },
		{ pos = UDim2.new(0, 0, 1, -U.EdgeGlowSize), size = UDim2.new(1, 0, 0, U.EdgeGlowSize), rot = -90 },
		{ pos = UDim2.fromScale(0, 0), size = UDim2.new(0, U.EdgeGlowSize, 1, 0), rot = 0 },
		{ pos = UDim2.new(1, -U.EdgeGlowSize, 0, 0), size = UDim2.new(0, U.EdgeGlowSize, 1, 0), rot = 180 },
	}
	for _, s in sides do
		local f = Util.frame(host, {
			BackgroundTransparency = U.EdgeGlowTransparency,
			BackgroundColor3 = C.RushHot,
			Position = s.pos,
			Size = s.size,
		})
		Util.new("UIGradient", { Transparency = fade, Rotation = s.rot }, f)
	end
	return host
end

function RushHud.new(parent: Instance): RushHud
	local root = Util.frame(parent, {
		Name = "RushHud",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(U.RushPillWidth, U.RushPillHeight),
	})

	-- Idle pill
	local pill = Card.new({ parent = root, variant = "glass", radius = math.huge, name = "Pill" })
	Icons.build("Clock", pill.face, U.RushPillHeight - 10, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		ZIndex = 3,
	})
	local textX = U.RushPillHeight
	local caption = Util.display(pill.face, "RUSH HOUR IN", {
		Position = UDim2.fromOffset(textX, 3),
		Size = UDim2.new(1, -(textX + Space.MD), 0, 14),
		TextSize = Theme.Type.Micro,
		TextColor3 = C.TextOnGlassMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local value = Util.display(pill.face, "", {
		Position = UDim2.fromOffset(textX, 15),
		Size = UDim2.new(1, -(textX + Space.MD), 0, 24),
		TextSize = Theme.Type.Title + 2,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, C.Outline)
	local idleCountdown = Countdown.new(value, Util.mmss)
	-- "--:--" shimmer until the snapshot brings the real Rush Hour state.
	local valueSkeleton = Skeleton.text(value, Theme.Skeleton.Clock)

	-- Active bar
	local bar = Util.frame(root, { Name = "Bar", Size = UDim2.fromScale(1, 1), Visible = false })
	local glow = Util.solid(bar, C.RushHot, 0, {
		BackgroundTransparency = 0.5,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, GLOW_PAD * 2, 1, GLOW_PAD * 2),
		ZIndex = 0,
	})
	Util.pill(glow)
	local barCard =
		Card.new({ parent = bar, variant = "accent", color = C.RushDeep, edge = C.Outline, radius = math.huge })
	if barCard.stroke then
		barCard.stroke.Thickness = Theme.Stroke.Base
	end
	local barFace = barCard.face
	local fillClip = Util.frame(barFace, { Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 3 })
	Util.pill(fillClip)
	local fill =
		Util.solid(fillClip, C.RushHot, 0, { Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 3 })
	Util.pill(fill)
	Util.new("UIGradient", { Color = ColorSequence.new(C.RushHot, C.RushWarm) }, fill)
	Stripes.new(fill, U.RushBarHeight, U.RushBarWidth, 4)
	local gloss = Util.frame(fill, {
		BackgroundTransparency = Theme.Depth.HighlightTransparency,
		BackgroundColor3 = C.Highlight,
		Position = UDim2.fromOffset(Space.LG, 3),
		Size = UDim2.new(1, -Space.LG * 2, 0.34, 0),
		ZIndex = 5,
	})
	Util.pill(gloss)

	local flame = Icons.build("Flame", bar, FLAME, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, FLAME / 2 - 6, 0.5, -4),
		ZIndex = 10,
	})
	local barTitle = Util.display(barFace, "RUSH HOUR!", {
		Position = UDim2.fromOffset(FLAME, 4),
		Size = UDim2.new(1, -(FLAME + TAG_W + Space.SM * 2 + 52), 0, 26),
		TextSize = Theme.Type.Title + 2,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	}, C.Outline)
	Util.fit(barTitle, Theme.Type.Title + 2)
	local byLine = Util.label(barFace, "", {
		Position = UDim2.fromOffset(FLAME, 28),
		Size = UDim2.new(1, -(FLAME + TAG_W + Space.SM * 2 + 52), 0, 14),
		TextSize = Theme.Type.Micro,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 8,
	})
	Util.fit(byLine, Theme.Type.Micro)
	Util.textStroke(byLine, C.Outline, Theme.Stroke.Hair)
	local timer = Util.display(barFace, "", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(TAG_W + Space.SM), 0.5, 0),
		Size = UDim2.fromOffset(56, 30),
		TextSize = Theme.Type.Title + 4,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 8,
	}, C.Outline)
	local tag = Card.new({
		parent = barFace,
		variant = "accent",
		color = C.Primary,
		edge = C.Outline,
		radius = math.huge,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -5, 0.5, 0),
		size = UDim2.fromOffset(TAG_W - 6, 30),
		shadow = false,
		zIndex = 9,
	})
	tag.instance.Rotation = -6
	Util.display(tag.face, `{Economy.RushHour.PayMultiplier}× PAY`, {
		TextSize = Theme.Type.Small,
		TextColor3 = C.Text,
		ZIndex = 10,
	})

	local edges = edgeGlow()
	local wasActive: boolean? = nil
	local soon = false
	local stopPulse: (() -> ())? = nil
	local maxWidth = U.RushBarWidth

	local function setActive(active: boolean, rh: Types.RushHourState?)
		if active and stopPulse then
			stopPulse()
			stopPulse = nil
		end
		if active then
			soon = false
			caption.Text = "RUSH HOUR IN"
			caption.TextColor3 = C.TextOnGlassMuted
			pill.face.BackgroundColor3 = C.Glass
		end
		pill.instance.Visible = not active
		bar.Visible = active
		edges.Visible = active
		local w = if active then math.min(U.RushBarWidth, maxWidth) else U.RushPillWidth
		local h = if active then U.RushBarHeight else U.RushPillHeight
		Tween.play(root, { Size = UDim2.fromOffset(w, h) }, Theme.Motion.Release)
		Tween.popIn(if active then bar else pill.instance)
		if active and wasActive == false then
			Stamp.show("RUSH HOUR!", {
				color = C.RushHot,
				sub = `{Economy.RushHour.PayMultiplier}× PAY · {Timings.RushHour.SpawnMultiplier}× CUSTOMERS`,
			})
		end
		byLine.Text = if rh and rh.triggeredByName then `Started by {rh.triggeredByName}` else "Every coin pays double!"
		wasActive = active
	end

	local self: RushHud = {
		instance = root,
		Height = function(_)
			return if bar.Visible then U.RushBarHeight else U.RushPillHeight
		end,
		SetWidth = function(_, w: number)
			maxWidth = w
			if bar.Visible then
				root.Size = UDim2.fromOffset(math.min(U.RushBarWidth, maxWidth), U.RushBarHeight)
			end
		end,
		Step = function(_, now: number)
			if not State.Ready then
				return
			end
			if valueSkeleton:IsLoading() then
				valueSkeleton:Reveal()
			end
			local rh = State.rushHour
			local active = rh ~= nil and rh.active and rh.endsAt ~= nil and now < rh.endsAt
			if active ~= wasActive then
				setActive(active, rh)
			end
			if active and rh and rh.endsAt then
				local total = (rh.endsAt - (rh.startedAt or (rh.endsAt - Timings.RushHour.DurationSeconds)))
				local left = rh.endsAt - now
				fill.Size = UDim2.fromScale(if total > 0 then Util.clamp01(left / total) else 1, 1)
				local t = Util.mmss(left)
				if timer.Text ~= t then
					timer.Text = t
				end
				flame.Rotation = math.sin(now * FLAME_BOB_SPEED) * FLAME_BOB_DEG
				local wave = (math.sin(now * GLOW_SPEED) + 1) / 2
				glow.BackgroundTransparency = 0.35 + wave * 0.45
				for _, e in edges:GetChildren() do
					if e:IsA("Frame") then
						e.BackgroundTransparency = U.EdgeGlowTransparency + wave * EDGE_PULSE
					end
				end
				return
			end
			local target = if rh and rh.nextAt > now then rh.nextAt else Schedule.nextRushHourAt(now)
			idleCountdown:SetTarget(target)
			idleCountdown:Step(now)
			local isSoon = target - now <= U.RushSoonSeconds
			if isSoon ~= soon then
				soon = isSoon
				caption.Text = if isSoon then "RUSH HOUR SOON!" else "RUSH HOUR IN"
				caption.TextColor3 = if isSoon then C.AccentLight else C.TextOnGlassMuted
				Tween.play(
					pill.face,
					{ BackgroundColor3 = if isSoon then C.AccentDeep else C.Glass },
					Theme.Motion.Fade
				)
				if isSoon and not stopPulse then
					stopPulse = Tween.pulse(pill.instance)
				elseif not isSoon and stopPulse then
					stopPulse()
					stopPulse = nil
				end
			end
		end,
	}
	State.Changed.RushHour:Connect(function(rh)
		if wasActive and rh.active then
			byLine.Text = if rh.triggeredByName then `Started by {rh.triggeredByName}` else "Every coin pays double!"
		end
	end)
	return self
end

return RushHud

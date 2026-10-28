--!strict
-- Server-wide legendary banner: spinning gold rays behind a pink-to-gold ribbon with folded tails,
-- a "LEGENDARY" crown kicker, a shine sweep and a confetti burst. Slams in, holds, pops out.
-- Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Card = require(script.Parent.Parent.Components.Card)
local Confetti = require(script.Parent.Parent.Components.Confetti)
local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Icons = require(script.Parent.Parent.Icons)
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local LegendaryBanner = {}

local C = Theme.C
local U = Theme.UI

local RAY_COUNT = 10
local RAY_SIZE = 300
local RIBBON_MAX = 560
local TAIL = 26
local KICKER_W = 168
local KICKER_H = 32
local SHINE_W = 60
local SHINE_SECONDS = 0.9

local current: Frame? = nil

local function headline(a: Types.LegendaryAnnouncement): (string, string)
	if a.servedByName then
		local sub = if a.tip then `+{Util.coins(a.tip)} tip!` else "Legendary served!"
		return `{a.servedByName} served {a.displayName}!`, sub
	end
	local def = Customers.Legendary[a.legendaryId]
	if def then
		return (string.gsub(def.announcement, "{owner}", a.ownerName)), "Go serve them for a giant tip!"
	end
	return `{a.displayName} arrived at {a.ownerName}'s diner!`, "Go serve them for a giant tip!"
end

local function rays(parent: Instance): () -> ()
	local host = Util.frame(parent, {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(RAY_SIZE, RAY_SIZE),
		ZIndex = 1,
	})
	for i = 1, RAY_COUNT do
		local ray = Util.frame(host, {
			BackgroundTransparency = 0.55,
			BackgroundColor3 = C.RushWarm,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 34, 1, 0),
			Rotation = (i - 1) * (180 / RAY_COUNT),
			ZIndex = 1,
		})
		Util.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
		}, ray)
	end
	return Tween.spin(host, U.BannerRaySeconds)
end

function LegendaryBanner.show(a: Types.LegendaryAnnouncement)
	if current then
		current:Destroy()
		current = nil
	end
	local layer = Root.layer("Banner", U.ZBanner)
	local root = Util.frame(layer, {
		Name = "LegendaryBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, U.BannerYScale),
		Size = UDim2.new(1, -U.Margin * 2, 0, U.BannerHeight),
	})
	Util.maxSize(root, RIBBON_MAX)
	current = root
	local stopRays = rays(root)

	-- Folded ribbon tails behind the ends.
	for _, side in { 0, 1 } do
		local tail = Util.solid(root, C.AccentDeep, Theme.Radius.SM, {
			AnchorPoint = Vector2.new(side, 0.5),
			Position = UDim2.new(side, if side == 0 then -TAIL / 2 else TAIL / 2, 0.5, TAIL / 2),
			Size = UDim2.new(0, TAIL * 2, 0.62, 0),
			ZIndex = 2,
		})
		Util.stroke(tail, C.Outline, Theme.Stroke.Base)
	end

	local ribbon = Card.new({
		parent = root,
		variant = "accent",
		color = C.Accent,
		edge = C.Outline,
		radius = Theme.Radius.XL,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
		size = UDim2.fromScale(1, 0.78),
		zIndex = 3,
	})
	if ribbon.stroke then
		ribbon.stroke.Thickness = Theme.Stroke.Bold
	end
	local face = ribbon.face
	face.ClipsDescendants = true
	for _, child in face:GetChildren() do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	Util.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.Accent),
			ColorSequenceKeypoint.new(0.5, C.RushWarm),
			ColorSequenceKeypoint.new(1, C.Accent),
		}),
	}, face)

	local shine = Util.frame(face, {
		BackgroundTransparency = 0.55,
		BackgroundColor3 = C.Highlight,
		Position = UDim2.fromOffset(-SHINE_W, 0),
		Size = UDim2.new(0, SHINE_W, 1, 0),
		ZIndex = 4,
	})
	Util.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shine)

	local main, sub = headline(a)
	local title = Util.display(face, main, {
		Position = UDim2.new(0, Theme.Space.LG, 0.12, 0),
		Size = UDim2.new(1, -Theme.Space.LG * 2, 0.5, 0),
		TextSize = Theme.Type.Heading,
		TextColor3 = C.TextInverse,
		ZIndex = 5,
	}, C.Outline)
	Util.fit(title, Theme.Type.Heading)
	local subLabel = Util.display(face, sub, {
		Position = UDim2.new(0, Theme.Space.LG, 0.6, 0),
		Size = UDim2.new(1, -Theme.Space.LG * 2, 0.3, 0),
		TextSize = Theme.Type.Title,
		TextColor3 = if a.tip then C.GoldLight else C.TextInverse,
		ZIndex = 5,
	}, C.Outline)
	Util.fit(subLabel, Theme.Type.Title)

	local kicker = Card.new({
		parent = root,
		variant = "accent",
		color = C.Primary,
		edge = C.Outline,
		radius = math.huge,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.11),
		size = UDim2.fromOffset(KICKER_W, KICKER_H),
		zIndex = 6,
	})
	local kickRow = Util.frame(kicker.face, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
	Util.list(
		kickRow,
		Enum.FillDirection.Horizontal,
		Theme.Space.XS,
		Enum.HorizontalAlignment.Center,
		Enum.VerticalAlignment.Center
	)
	Icons.build("Crown", kickRow, KICKER_H - 6, { LayoutOrder = 1, ZIndex = 6 })
	Util.display(kickRow, "LEGENDARY", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = Theme.Type.Title - 2,
		TextColor3 = C.Text,
		LayoutOrder = 2,
		ZIndex = 6,
	})
	kicker.instance.Rotation = -4

	-- Entrance
	local scale = Tween.scaleOf(root)
	scale.Scale = 0
	Tween.play(scale, { Scale = 1 }, Theme.Motion.BannerIn)
	task.delay(Theme.MotionSeconds.BannerIn.seconds * 0.5, function()
		if root.Parent then
			local center = Root.toLocal(root.AbsolutePosition + root.AbsoluteSize / 2)
			Confetti.burst(center)
			Tween.bounce(kicker.instance, 1.3)
			Tween.to(shine, { Position = UDim2.new(1, SHINE_W, 0, 0) }, SHINE_SECONDS, Enum.EasingStyle.Quad)
		end
	end)

	task.delay(U.BannerSeconds, function()
		if not root.Parent then
			return
		end
		local out = Tween.play(scale, { Scale = 0 }, Theme.Motion.BannerOut)
		out.Completed:Once(function()
			stopRays()
			root:Destroy()
			if current == root then
				current = nil
			end
		end)
	end)
end

return LegendaryBanner

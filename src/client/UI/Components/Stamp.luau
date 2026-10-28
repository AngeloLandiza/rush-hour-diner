--!strict
-- Celebration stamp: big tilted Fredoka word with a heavy outline that slams in (scale overshoot),
-- holds, then swells and fades. Used for "RUSH HOUR!", "PERFECT!", "UPGRADED!". Owner: UI agent.
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Options = {
	sub: string?,
	color: Color3?,
	textSize: number?,
	position: UDim2?, -- content-local; default screen center-ish
	parent: GuiObject?,
	seconds: number?,
	tilt: number?,
}

local Stamp = {}

local C = Theme.C
local SLAM_FROM = 2.2
local EXIT_SCALE = 1.35
local HEIGHT_FACTOR = 1.3

function Stamp.show(text: string, opts: Options?)
	local o: Options = opts or {}
	local parent: GuiObject = o.parent or Root.layer("Stamps", Theme.UI.ZBanner)
	local size = o.textSize or Theme.Type.Hero
	local root = Util.frame(parent, {
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = o.position or UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(1, 0, 0, size * HEIGHT_FACTOR + (if o.sub then Theme.Type.Title + 6 else 0)),
		Rotation = o.tilt or -6,
		ZIndex = 20,
	})
	local title = Util.display(root, text, {
		Size = UDim2.new(1, 0, 0, size * HEIGHT_FACTOR),
		TextSize = size,
		TextColor3 = o.color or C.Primary,
		ZIndex = 21,
	})
	Util.textStroke(title, C.Outline, Theme.Stroke.Bold + 1)
	Util.gradient(title, C.Highlight, Theme.shade(C.Highlight, 0.15))
	local subLabel: TextLabel? = nil
	if o.sub then
		local s = Util.display(root, o.sub, {
			Position = UDim2.fromOffset(0, size * HEIGHT_FACTOR - 4),
			Size = UDim2.new(1, 0, 0, Theme.Type.Title + 6),
			TextSize = Theme.Type.Title,
			TextColor3 = C.TextInverse,
			ZIndex = 21,
		}, C.Outline)
		subLabel = s
	end

	local scale = Tween.scaleOf(root)
	scale.Scale = SLAM_FROM
	title.TextTransparency = 1
	Tween.play(title, { TextTransparency = 0 }, Theme.Motion.Press)
	Tween.to(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(o.seconds or Theme.UI.StampSeconds, function()
		if not root.Parent then
			return
		end
		Tween.play(scale, { Scale = EXIT_SCALE }, Theme.Motion.Fade)
		Tween.play(title, { TextTransparency = 1 }, Theme.Motion.Fade)
		for _, d in root:GetDescendants() do
			if d:IsA("UIStroke") then
				Tween.play(d, { Transparency = 1 }, Theme.Motion.Fade)
			end
		end
		local sl = subLabel
		if sl then
			Tween.play(sl, { TextTransparency = 1 }, Theme.Motion.Fade)
		end
		task.delay(Theme.MotionSeconds.Fade.seconds, function()
			root:Destroy()
		end)
	end)
end

return Stamp

--!strict
-- Notification badge: ketchup bubble with a white ring at a GuiObject's top-right corner. Shows a
-- count ("3", "9+") or "!" and pops when the value changes; gently pulses while visible. Owner: UI agent.
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Badge = {
	instance: Frame,
	Set: (self: Badge, value: (number | string | boolean)?) -> (),
}

local Badge = {}

local C = Theme.C
local MAX_COUNT = 9

function Badge.new(parent: GuiObject, color: Color3?): Badge
	local size = Theme.UI.BadgeSize
	local root = Util.frame(parent, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(size, size),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		BackgroundColor3 = color or C.Danger,
		ZIndex = 20,
		Visible = false,
	})
	Util.pill(root)
	Util.stroke(root, C.TextInverse, Theme.Stroke.Thin)
	Util.padding(root, 0, Theme.Space.XS + 1, 0, Theme.Space.XS + 1)
	Util.new("UISizeConstraint", { MinSize = Vector2.new(size, size) }, root)
	local label = Util.display(root, "", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = Theme.Type.Caption + 1,
		TextColor3 = C.TextInverse,
		ZIndex = 21,
	}, C.Outline)

	local current: string? = nil
	local stopPulse: (() -> ())? = nil

	local self: Badge = {
		instance = root,
		Set = function(_, value: (number | string | boolean)?)
			local text: string? = nil
			if typeof(value) == "number" then
				if value > 0 then
					text = if value > MAX_COUNT then `{MAX_COUNT}+` else tostring(value)
				end
			elseif typeof(value) == "string" then
				text = value
			elseif value == true then
				text = "!"
			end
			if text == current then
				return
			end
			current = text
			root.Visible = text ~= nil
			if text then
				label.Text = text
				if stopPulse then
					stopPulse()
					stopPulse = nil
				end
				Tween.bounce(root, 1.5)
				task.delay(Theme.MotionSeconds.Bounce.seconds, function()
					if current and not stopPulse then
						stopPulse = Tween.pulse(root, 0.12)
					end
				end)
			elseif stopPulse then
				stopPulse()
				stopPulse = nil
			end
		end,
	}
	return self
end

return Badge

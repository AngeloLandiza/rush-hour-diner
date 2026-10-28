--!strict
-- Animated fill bar driven by a server time range. Owner: agent D.
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

export type ProgressBar = {
	instance: Frame,
	Fill: Frame,
	SetFraction: (self: ProgressBar, f: number) -> (),
	SetColor: (self: ProgressBar, c: Color3) -> (),
	SetRange: (self: ProgressBar, startAt: number?, endAt: number?, reverse: boolean?) -> (),
	Step: (self: ProgressBar, now: number) -> (),
	_start: number?,
	_end: number?,
	_reverse: boolean,
}

local ProgressBar = {}

function ProgressBar.new(parent: Instance?, size: UDim2, color: Color3): ProgressBar
	local track = Util.card(parent, Theme.Colors.Cream, { Size = size, ClipsDescendants = true })
	local fill = Util.frame(track, {
		Name = "Fill",
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Size = UDim2.fromScale(0, 1),
	})
	Util.corner(fill, Theme.UI.SmallCorner)
	local self: ProgressBar
	self = {
		instance = track,
		Fill = fill,
		_start = nil,
		_end = nil,
		_reverse = false,
		SetFraction = function(this: ProgressBar, f: number)
			this.Fill.Size = UDim2.fromScale(Util.clamp01(f), 1)
		end,
		SetColor = function(this: ProgressBar, c: Color3)
			this.Fill.BackgroundColor3 = c
		end,
		SetRange = function(this: ProgressBar, startAt: number?, endAt: number?, reverse: boolean?)
			this._start = startAt
			this._end = endAt
			this._reverse = reverse == true
		end,
		Step = function(this: ProgressBar, now: number)
			local s, e = this._start, this._end
			if not s or not e or e <= s then
				return
			end
			local f = Util.clamp01((now - s) / (e - s))
			this:SetFraction(if this._reverse then 1 - f else f)
		end,
	}
	return self
end

return ProgressBar

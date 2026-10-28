--!strict
-- Pill progress bar: sunken track, beveled fill with a glossy top band, optional moving stripes and a
-- centered caption. Can be driven by a server time range (SetRange + Step). Owner: UI agent.
local Stripes = require(script.Parent.Stripes)
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

export type ProgressBar = {
	instance: Frame,
	Fill: Frame,
	Caption: TextLabel,
	SetFraction: (self: ProgressBar, f: number) -> (),
	SetColor: (self: ProgressBar, c: Color3) -> (),
	SetRange: (self: ProgressBar, startAt: number?, endAt: number?, reverse: boolean?) -> (),
	SetStripes: (self: ProgressBar, on: boolean) -> (),
	SetCaption: (self: ProgressBar, text: string) -> (),
	Step: (self: ProgressBar, now: number) -> (),
	_start: number?,
	_end: number?,
	_reverse: boolean,
}

local ProgressBar = {}

local C = Theme.C

-- height in px (needed for stripes); maxWidth = widest the bar gets.
function ProgressBar.new(parent: Instance?, size: UDim2, color: Color3, height: number, maxWidth: number): ProgressBar
	local track = Util.solid(parent, C.Sunken, 0, { Name = "ProgressBar", Size = size, ClipsDescendants = true })
	Util.pill(track)
	Util.stroke(track, C.SunkenDeep, Theme.Stroke.Thin)
	-- Inner top shadow sells the inset.
	Util.frame(track, {
		BackgroundTransparency = 0.85,
		BackgroundColor3 = C.Shadow,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 2,
	})

	local fill = Util.solid(track, color, 0, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		ClipsDescendants = true,
		ZIndex = 3,
	})
	Util.pill(fill)
	Util.bevel(fill)
	local gloss = Util.frame(fill, {
		BackgroundTransparency = Theme.Depth.HighlightTransparency,
		BackgroundColor3 = C.Highlight,
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0.36, 0),
		ZIndex = 6,
	})
	Util.pill(gloss)
	local stripes = Stripes.new(fill, height, maxWidth, 4)
	stripes:SetEnabled(false)

	local caption = Util.display(track, "", {
		TextSize = Theme.Type.Small,
		TextColor3 = C.TextInverse,
		ZIndex = 8,
	}, C.Outline)

	local self: ProgressBar
	self = {
		instance = track,
		Fill = fill,
		Caption = caption,
		_start = nil,
		_end = nil,
		_reverse = false,
		SetFraction = function(this: ProgressBar, f: number)
			local v = Util.clamp01(f)
			this.Fill.Size = UDim2.fromScale(v, 1)
			this.Fill.Visible = v > 0
		end,
		SetColor = function(this: ProgressBar, c: Color3)
			this.Fill.BackgroundColor3 = c
		end,
		SetRange = function(this: ProgressBar, startAt: number?, endAt: number?, reverse: boolean?)
			this._start = startAt
			this._end = endAt
			this._reverse = reverse == true
		end,
		SetStripes = function(_, on: boolean)
			stripes:SetEnabled(on)
		end,
		SetCaption = function(_, text: string)
			caption.Text = text
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

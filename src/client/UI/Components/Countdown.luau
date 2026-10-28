--!strict
-- Text label that counts down to a server timestamp. Owner: agent D.
export type Countdown = {
	Label: TextLabel,
	SetTarget: (self: Countdown, target: number?) -> (),
	Step: (self: Countdown, now: number) -> (),
	_target: number?,
	_format: (seconds: number) -> string,
}

local Countdown = {}

-- format maps remaining seconds to the full label text.
function Countdown.new(label: TextLabel, format: (number) -> string): Countdown
	return {
		Label = label,
		_target = nil,
		_format = format,
		SetTarget = function(self: Countdown, target: number?)
			self._target = target
		end,
		Step = function(self: Countdown, now: number)
			local t = self._target
			if t then
				self.Label.Text = self._format(math.max(0, t - now))
			end
		end,
	}
end

return Countdown

--!strict
-- Text label that counts down to a server timestamp. Optional onUrgent fires once when the remaining
-- time crosses urgentSeconds (for pulses / color shifts). Owner: UI agent.
export type Countdown = {
	Label: TextLabel,
	SetTarget: (self: Countdown, target: number?) -> (),
	Step: (self: Countdown, now: number) -> (),
	Remaining: (self: Countdown, now: number) -> number?,
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
		Remaining = function(self: Countdown, now: number): number?
			local t = self._target
			return if t then math.max(0, t - now) else nil
		end,
		Step = function(self: Countdown, now: number)
			local t = self._target
			if t then
				local text = self._format(math.max(0, t - now))
				if self.Label.Text ~= text then
					self.Label.Text = text
				end
			end
		end,
	}
end

return Countdown

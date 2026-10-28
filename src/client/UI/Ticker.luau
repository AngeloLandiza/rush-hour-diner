--!strict
-- One shared per-frame loop for animated UI (progress bars, countdowns). Owner: agent D.
local RunService = game:GetService("RunService")

local Ticker = {}

local nextId = 0
local callbacks: { [number]: (now: number, dt: number) -> () } = {}
local connection: RBXScriptConnection? = nil

local function ensure()
	if connection then
		return
	end
	connection = RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for _, fn in callbacks do
			fn(now, dt)
		end
	end)
end

-- Register a per-frame callback; returns a function that removes it.
function Ticker.add(fn: (now: number, dt: number) -> ()): () -> ()
	ensure()
	nextId += 1
	local id = nextId
	callbacks[id] = fn
	return function()
		callbacks[id] = nil
	end
end

return Ticker

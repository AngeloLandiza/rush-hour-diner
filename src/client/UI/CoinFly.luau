--!strict
-- Coin fly-to-counter: coins burst out from a source point, then arc into the HUD coin icon, each one
-- punching the counter on arrival. The HUD registers the target; FX/notify code launches flights.
-- Owner: UI agent.
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Tween = require(script.Parent.Tween)

local CoinFly = {}

local U = Theme.UI
local M = Theme.Motion
local rng = Random.new()

local target: GuiObject? = nil
local onArrive: (() -> ())? = nil
local arrivalAt = 0 -- os.clock() when the first coin of the latest flight lands

local LOG_BASE = 2
local SHRINK = 0.55

-- The HUD coin icon (and what to do as each coin lands).
function CoinFly.setTarget(gui: GuiObject, arrive: () -> ())
	target = gui
	onArrive = arrive
end

-- Seconds until the first coin of the most recent flight lands (0 if none in flight).
function CoinFly.untilArrival(): number
	return math.max(0, arrivalAt - os.clock())
end

local function coinCount(amount: number): number
	local n = math.floor(math.log(math.max(amount, 1), LOG_BASE)) + 1
	return math.clamp(n, U.FlyMinCoins, U.FlyMaxCoins)
end

-- from = content-local design px.
function CoinFly.fromLocal(from: Vector2, amount: number)
	local t = target
	if not t or not t.Parent then
		return
	end
	local layer = Root.layer("Fly", U.ZFly)
	local dest = Root.toLocal(t.AbsolutePosition + t.AbsoluteSize / 2)
	local n = coinCount(amount)
	local burst = M.CoinBurst
	local travel = M.CoinTravel
	arrivalAt = os.clock() + burst.Time + travel.Time
	for i = 1, n do
		local coin = Icons.build("Coin", layer, U.FlyCoinSize, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(from.X, from.Y),
			ZIndex = 1,
		})
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.4, 1) * U.FlyBurstRadius
		local mid = from + Vector2.new(math.cos(angle) * r, math.sin(angle) * r)
		local delay = (i - 1) * U.FlyStagger
		task.delay(delay, function()
			Tween.popIn(coin)
			local out = Tween.play(coin, { Position = UDim2.fromOffset(mid.X, mid.Y) }, burst)
			out.Completed:Once(function()
				Tween.play(Tween.scaleOf(coin), { Scale = SHRINK }, travel)
				local fly = Tween.play(coin, { Position = UDim2.fromOffset(dest.X, dest.Y) }, travel)
				fly.Completed:Once(function()
					coin:Destroy()
					local arrive = onArrive
					if arrive then
						arrive()
					end
				end)
			end)
		end)
	end
end

-- from = absolute screen point (AbsolutePosition space).
function CoinFly.fromScreen(from: Vector2, amount: number)
	CoinFly.fromLocal(Root.toLocal(from), amount)
end

-- from = world position (projected through the current camera).
function CoinFly.fromWorld(pos: Vector3, amount: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local screen, onScreen = camera:WorldToScreenPoint(pos)
	if not onScreen then
		local size = Root.size()
		CoinFly.fromLocal(Vector2.new(size.X / 2, size.Y / 2), amount)
		return
	end
	-- WorldToScreenPoint accounts for the GUI inset, matching AbsolutePosition space.
	CoinFly.fromScreen(Vector2.new(screen.X, screen.Y), amount)
end

return CoinFly

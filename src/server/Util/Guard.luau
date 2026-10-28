--!strict
-- Server-side remote validation helpers. Owner: orchestrator. Every client→server handler goes
-- through Guard.onEvent / Guard.onInvoke, which enforce the per-remote rate limit
-- (Config/Timings.RateLimits), require a plain-table payload (or nil), and isolate handler errors.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)

local Guard = {}

type Bucket = { tokens: number, updatedAt: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

-- Token bucket: allows `rate` calls/second with a burst of max(1, rate×2).
function Guard.allow(player: Player, remoteName: string): boolean
	local rate = Timings.RateLimits[remoteName]
	assert(rate, `No rate limit configured for '{remoteName}' in Config/Timings.RateLimits`)
	local burst = math.max(1, rate * 2)
	local now = os.clock()
	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local bucket = perPlayer[remoteName]
	if not bucket then
		bucket = { tokens = burst, updatedAt = now }
		perPlayer[remoteName] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updatedAt) * rate)
	bucket.updatedAt = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function Guard.isNumber(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v >= min and v <= max
end

function Guard.isInt(v: any, min: number, max: number): boolean
	return Guard.isNumber(v, min, max) and v % 1 == 0
end

function Guard.isString(v: any, maxLen: number): boolean
	return type(v) == "string" and #v <= maxLen and utf8.len(v) ~= nil
end

function Guard.isBool(v: any): boolean
	return type(v) == "boolean"
end

-- True if v is a key of `set` (e.g. Guard.isOneOf(id, Config.Upgrades.Defs)).
function Guard.isOneOf(v: any, set: { [any]: any }): boolean
	return type(v) == "string" and set[v] ~= nil
end

-- A plain table with only string keys and no metatable, or nil.
function Guard.isPayload(v: any): boolean
	if v == nil then
		return true
	end
	if type(v) ~= "table" or getmetatable(v) ~= nil then
		return false
	end
	for k in v do
		if type(k) ~= "string" then
			return false
		end
	end
	return true
end

-- True if the player's character root is within `range` studs of position.
function Guard.isNear(player: Player, position: Vector3, range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - position).Magnitude <= range
end

-- Connect a client→server RemoteEvent with rate limiting, payload shape check and error isolation.
-- The handler still validates every field and ownership itself.
function Guard.onEvent(name: string, handler: (player: Player, payload: any) -> ())
	Net.event(name).OnServerEvent:Connect(function(player: Player, payload: any, ...: any)
		-- Rate limit first so oversized/spammed payloads are dropped before being walked.
		if not Guard.allow(player, name) or select("#", ...) > 0 or not Guard.isPayload(payload) then
			return
		end
		local ok, err = pcall(function()
			handler(player, payload)
		end)
		if not ok then
			warn(`[Guard] {name} handler error for {player.UserId}: {err}`)
		end
	end)
end

-- Bind a RemoteFunction. Returns nil to the client when rate limited, malformed or on error.
function Guard.onInvoke(name: string, handler: (player: Player, payload: any) -> any)
	Net.func(name).OnServerInvoke = function(player: Player, payload: any, ...: any): any
		-- Rate limit first so oversized/spammed payloads are dropped before being walked.
		if not Guard.allow(player, name) or select("#", ...) > 0 or not Guard.isPayload(payload) then
			return nil
		end
		local ok, result = pcall(handler, player, payload)
		if not ok then
			warn(`[Guard] {name} invoke error for {player.UserId}: {result}`)
			return nil
		end
		return result
	end
end

return Guard

--!strict
-- Hourly Rush Hour scheduler (+ purchased "Rush Hour Now"). Owner: agent C.
-- Fires Events.RushHourStarted/Ended and broadcasts RushHourState.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Schedule = require(ReplicatedStorage.Shared.Logic.Schedule)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local RushHourService = {}

local state: Types.RushHourState = { active = false, nextAt = Schedule.nextRushHourAt(os.time()) }
-- Scheduled windows that began before this time are ignored (a purchased rush already covered them).
local lastEndedAt = 0

local function broadcast()
	Net.event("RushHourState"):FireAllClients(RushHourService.GetState())
end

local function startRush(startedAt: number, endsAt: number, triggeredByName: string?)
	state = {
		active = true,
		startedAt = startedAt,
		endsAt = endsAt,
		nextAt = Schedule.nextRushHourAt(startedAt),
		triggeredByName = triggeredByName,
	}
	Events.RushHourStarted:Fire(RushHourService.GetState())
	broadcast()
end

local function endRush(now: number)
	lastEndedAt = now
	state = { active = false, nextAt = Schedule.nextRushHourAt(now) }
	Events.RushHourEnded:Fire(RushHourService.GetState())
	broadcast()
end

local function poll()
	local now = os.time()
	if state.active then
		local endsAt = state.endsAt or now
		if now >= endsAt then
			endRush(now)
		end
		return
	end
	local sched = Schedule.rushHourState(now)
	state.nextAt = sched.nextAt
	if sched.active and (sched.startedAt or now) > lastEndedAt then
		startRush(sched.startedAt or now, sched.endsAt or (now + Timings.RushHour.DurationSeconds), nil)
	end
end

function RushHourService.Init()
	if RunService:IsStudio() then
		-- Studio command bar: workspace:SetAttribute("DebugRushNow", true)
		workspace:GetAttributeChangedSignal("DebugRushNow"):Connect(function()
			if workspace:GetAttribute("DebugRushNow") == true then
				RushHourService.TriggerNow(nil)
				workspace:SetAttribute("DebugRushNow", false)
			end
		end)
	end
end

function RushHourService.Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				poll()
			end)
			if not ok then
				warn(`[RushHourService] poll failed: {err}`)
			end
			task.wait(Timings.RushHour.PollSeconds)
		end
	end)
end

function RushHourService.GetState(): Types.RushHourState
	return table.clone(state)
end

function RushHourService.IsActive(): boolean
	return state.active
end

-- Starts a Rush Hour now (purchased). If one is already active, extends it and still returns true.
function RushHourService.TriggerNow(buyer: Player?): boolean
	local now = os.time()
	local name = if buyer then buyer.DisplayName else nil
	if state.active then
		state.endsAt = (state.endsAt or now) + Timings.RushHour.DurationSeconds
		state.triggeredByName = name or state.triggeredByName
		broadcast()
		return true
	end
	startRush(now, now + Timings.RushHour.DurationSeconds, name)
	return true
end

-- True only inside the free, scheduled hourly window. Odds-affecting bonuses (the legendary multiplier) key
-- off this, never off a purchased "Rush Hour Now", so no Robux purchase changes random outcomes.
function RushHourService.IsScheduledRush(): boolean
	return state.active and Schedule.rushHourState(os.time()).active
end

-- Spawn-rate multiplier right now (1, or Timings.RushHour.SpawnMultiplier while active).
function RushHourService.GetSpawnMultiplier(): number
	return if state.active then Timings.RushHour.SpawnMultiplier else 1
end

return RushHourService

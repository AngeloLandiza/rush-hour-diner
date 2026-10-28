--!strict
-- PURE station cook state machine. No Roblox services. Owner: agent B. Signatures are a contract.
-- StationService (agent C) owns the timers and calls these to decide transitions; it never trusts
-- client timing — only "an action arrived at server time now".
--
-- Phases: Idle --Start--> Cooking --(cookSeconds)--> NeedsFlip --Flip--> Finishing --(finishSeconds)-->
--         Ready --Collect--> Idle.  NeedsFlip timeout or Ready timeout -> Burnt --Clear--> Idle.
--
-- Rules:
--  * Start works only from Idle. cookSeconds/finishSeconds in the schedule already include the
--    station speed upgrade (schedule() divides by Upgrades.stationSpeedMultiplier).
--  * NeedsFlip lasts flipWindowSeconds. Flip within perfectSeconds of the window opening = Perfect,
--    later in the window = Good, no flip before the window closes = Burnt.
--  * Ready uncollected for burnSeconds = Burnt (flipQuality becomes "Burnt").
--  * Collect works only from Ready (returns flipQuality, state -> Idle). Clear works only from Burnt.
--  * advance() chains several elapsed transitions: each new phase starts at the previous phaseEndsAt,
--    not at now. Inputs are never mutated. Invalid actions return false and an unchanged clone.
local Types = require("../Contracts/Types")
local Dishes = require("../Config/Dishes")
local Upgrades = require("./Upgrades")

local Cooking = {}

-- Timings for one cook of dishId with the plot owner's upgrades.
function Cooking.schedule(dishId: Types.DishId, ownerUpgrades: { [Types.UpgradeId]: number }): Types.CookSchedule
	local dish = Dishes.Defs[dishId]
	local speed = Upgrades.stationSpeedMultiplier(ownerUpgrades, dish.stationId)
	return {
		cookSeconds = dish.cookSeconds / speed,
		flipWindowSeconds = dish.flipWindowSeconds,
		perfectSeconds = dish.perfectSeconds,
		finishSeconds = dish.finishSeconds / speed,
		burnSeconds = dish.burnSeconds,
	}
end

local function enter(state: Types.StationState, phase: Types.StationPhase, startedAt: number, duration: number?)
	state.phase = phase
	state.phaseStartedAt = startedAt
	state.phaseEndsAt = if duration then startedAt + duration else nil
end

-- Apply time-based transitions (Cooking→NeedsFlip, NeedsFlip→Burnt, Finishing→Ready, Ready→Burnt).
-- Returns a new state table (never mutates the input).
function Cooking.advance(state: Types.StationState, now: number, sched: Types.CookSchedule): Types.StationState
	local s = table.clone(state)
	while true do
		local endsAt = s.phaseEndsAt
		if endsAt == nil or now < endsAt then
			break
		end
		if s.phase == "Cooking" then
			enter(s, "NeedsFlip", endsAt, sched.flipWindowSeconds)
		elseif s.phase == "Finishing" then
			enter(s, "Ready", endsAt, sched.burnSeconds)
		elseif s.phase == "NeedsFlip" or s.phase == "Ready" then
			enter(s, "Burnt", endsAt, nil)
			s.flipQuality = "Burnt"
		else
			break
		end
	end
	return s
end

-- Apply a player action at server time now. Returns ok, the new state, and — for a successful
-- Collect — the quality of the dish handed to the player. Calls advance() first.
function Cooking.applyAction(
	state: Types.StationState,
	action: Types.CookAction,
	now: number,
	sched: Types.CookSchedule,
	actorUserId: number
): (boolean, Types.StationState, Types.CookQuality?)
	local s = Cooking.advance(state, now, sched)
	if action == "Start" and s.phase == "Idle" then
		enter(s, "Cooking", now, sched.cookSeconds)
		s.cookerUserId = actorUserId
		s.flipQuality = nil
		return true, s, nil
	elseif action == "Flip" and s.phase == "NeedsFlip" then
		s.flipQuality = if now - s.phaseStartedAt <= sched.perfectSeconds then "Perfect" else "Good"
		enter(s, "Finishing", now, sched.finishSeconds)
		return true, s, nil
	elseif action == "Collect" and s.phase == "Ready" then
		local quality: Types.CookQuality? = s.flipQuality
		enter(s, "Idle", now, nil)
		s.cookerUserId = nil
		s.flipQuality = nil
		return true, s, quality
	elseif action == "Clear" and s.phase == "Burnt" then
		enter(s, "Idle", now, nil)
		s.cookerUserId = nil
		s.flipQuality = nil
		return true, s, nil
	end
	return false, table.clone(state), nil
end

return Cooking

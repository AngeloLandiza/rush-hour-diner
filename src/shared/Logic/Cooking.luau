--!strict
-- PURE station cook state machine. No Roblox services. Owner: agent B. Signatures are a contract.
-- StationService (agent C) owns the timers and calls these to decide transitions; it never trusts
-- client timing — only "an action arrived at server time now".
--
-- Phases: Idle --Start--> Cooking --(cookSeconds)--> NeedsFlip --Flip--> Finishing --(finishSeconds)-->
--         Ready --Collect--> Idle.  NeedsFlip timeout or Ready timeout -> Burnt --Clear--> Idle.
local Types = require("../Contracts/Types")

local Cooking = {}

-- Timings for one cook of dishId with the plot owner's upgrades.
function Cooking.schedule(dishId: Types.DishId, ownerUpgrades: { [Types.UpgradeId]: number }): Types.CookSchedule
	return { cookSeconds = 3, flipWindowSeconds = 2.5, perfectSeconds = 0.8, finishSeconds = 2, burnSeconds = 8 }
end

-- Apply time-based transitions (Cooking→NeedsFlip, NeedsFlip→Burnt, Finishing→Ready, Ready→Burnt).
-- Returns a new state table (never mutates the input).
function Cooking.advance(state: Types.StationState, now: number, sched: Types.CookSchedule): Types.StationState
	return table.clone(state)
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
	return false, table.clone(state), nil
end

return Cooking

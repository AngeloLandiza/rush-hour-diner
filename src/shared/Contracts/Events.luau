--!strict
-- ⚠ CONTRACT — owned by the orchestrator. Agents request changes in their report; never edit directly.
-- Server-internal signals. Services talk to each other through these (or the public functions in
-- docs/ARCHITECTURE.md). Server-only: never fire or connect from the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require("./Types")

type Signal<T...> = Signal.Signal<T...>

local Events = {
	-- DataService
	PlayerDataLoaded = Signal.new() :: Signal<Player, Types.PlayerData>, -- profile ready, before first DataSync
	PlayerDataReleasing = Signal.new() :: Signal<Player>, -- about to end session (PlayerRemoving / shutdown)
	CoinsChanged = Signal.new() :: Signal<Player, number, number, string>, -- player, newBalance, delta, reason
	UpgradePurchased = Signal.new() :: Signal<Player, Types.UpgradeId, number>, -- player, id, newLevel
	TutorialCompleted = Signal.new() :: Signal<Player>,

	-- PurchaseService
	PassOwnershipChanged = Signal.new() :: Signal<Player, Types.PassKey, boolean>,
	ProductGranted = Signal.new() :: Signal<Player, Types.ProductKey, string>, -- player, key, purchaseId
	BoostsChanged = Signal.new() :: Signal<Player>,

	-- PlotService
	PlotClaimed = Signal.new() :: Signal<number, Player>, -- plotId, owner
	PlotReleased = Signal.new() :: Signal<number>, -- plotId (owner left)
	CrewChanged = Signal.new() :: Signal<number, { Player }>, -- plotId, crew (excluding owner)
	PlotLayoutChanged = Signal.new() :: Signal<number>, -- plotId: seats/decor/station slots changed

	-- StationService
	DishCooked = Signal.new() :: Signal<Player, number, Types.DishId, Types.CookQuality>, -- cook, plotId, dish, quality
	StationBurnt = Signal.new() :: Signal<number, number>, -- plotId, slot

	-- CustomerService
	CustomerSpawned = Signal.new() :: Signal<Types.Customer>,
	CustomerLeft = Signal.new() :: Signal<Types.Customer, Types.LeaveReason>,
	LegendaryArrived = Signal.new() :: Signal<Types.Customer>,
	OrderServed = Signal.new() :: Signal<Types.ServeResult>,

	-- RushHourService
	RushHourStarted = Signal.new() :: Signal<Types.RushHourState>,
	RushHourEnded = Signal.new() :: Signal<Types.RushHourState>,
}

return Events

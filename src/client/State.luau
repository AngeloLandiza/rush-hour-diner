--!strict
-- Client state store. Fetches GetSnapshot once, then applies server->client events and
-- exposes change signals to controllers. Owner: agent D.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require(ReplicatedStorage.Shared.Contracts.Remotes)
local Signal = require(script.Parent.Signal)
local Theme = require(script.Parent.UI.Theme)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

type Signal<T> = Signal.Signal<T>

local State = {
	Ready = false,
	data = nil :: Types.PlayerDataView?,
	plots = {} :: { Types.PlotInfo },
	myPlotId = nil :: number?,
	stations = {} :: { [string]: Types.StationState },
	customers = {} :: { [number]: Types.CustomerView },
	rushHour = nil :: Types.RushHourState?,
	leaderboard = { lifetime = {}, rushHour = {} } :: Types.LeaderboardSnapshot,
	held = nil :: Types.HeldItem?,
	combo = 0,

	Changed = {
		Snapshot = Signal.new() :: Signal<boolean>,
		Data = Signal.new() :: Signal<Types.PlayerDataView>,
		Plots = Signal.new() :: Signal<{ Types.PlotInfo }>,
		Station = Signal.new() :: Signal<Types.StationState>,
		Held = Signal.new() :: Signal<Types.HeldItem?>,
		Customer = Signal.new() :: Signal<Types.CustomerView>,
		CustomerRemoved = Signal.new() :: Signal<Remotes.CustomerRemovedPayload>,
		RushHour = Signal.new() :: Signal<Types.RushHourState>,
		Leaderboard = Signal.new() :: Signal<Types.LeaderboardSnapshot>,
		PurchaseGranted = Signal.new() :: Signal<Remotes.PurchaseGrantedPayload>,
		OrderServed = Signal.new() :: Signal<Remotes.OrderServedPayload>,
		Combo = Signal.new() :: Signal<number>,
	},
}

local readyEvent = Instance.new("BindableEvent")
-- PlotsChanged that lands while GetSnapshot is in flight is at least as new as the snapshot's copy.
local plotsFromEvent = false
local localPlayer = Players.LocalPlayer

-- Server time (unix seconds).
function State.now(): number
	return workspace:GetServerTimeNow()
end

function State.stationKey(plotId: number, slot: number): string
	return `{plotId}:{slot}`
end

function State.getStation(plotId: number, slot: number): Types.StationState?
	return State.stations[State.stationKey(plotId, slot)]
end

-- True if the local player is the owner of the plot they work on.
function State.isOwner(): boolean
	local id = State.myPlotId
	if not id then
		return false
	end
	for _, plot in State.plots do
		if plot.plotId == id then
			return plot.ownerUserId == localPlayer.UserId
		end
	end
	return false
end

function State.waitReady()
	if not State.Ready then
		readyEvent.Event:Wait()
	end
end

local function recomputePlot()
	-- The server-set attribute is the plot the player actually works on (owned or crew).
	local attr = localPlayer:GetAttribute(WorldSchema.Attributes.PlayerPlotId)
	if typeof(attr) == "number" then
		State.myPlotId = attr
		return
	end
	local owned: number? = nil
	for _, plot in State.plots do
		if table.find(plot.crewUserIds, localPlayer.UserId) then
			State.myPlotId = plot.plotId
			return
		end
		if plot.ownerUserId == localPlayer.UserId then
			owned = plot.plotId
		end
	end
	State.myPlotId = owned or State.myPlotId
end

local function applyPlots(plots: { Types.PlotInfo })
	if not State.Ready then
		plotsFromEvent = true
	end
	State.plots = plots
	recomputePlot()
	State.Changed.Plots:Fire(plots)
end

local function applySnapshot(snap: Remotes.Snapshot)
	if snap.data then
		State.data = snap.data
	end
	if not plotsFromEvent then
		State.plots = snap.plots
	end
	State.myPlotId = snap.myPlotId
	recomputePlot()
	State.stations = {}
	for _, s in snap.stations do
		State.stations[State.stationKey(s.plotId, s.slot)] = s
	end
	State.customers = {}
	for _, c in snap.customers do
		State.customers[c.id] = c
	end
	State.rushHour = snap.rushHour
	State.leaderboard = snap.leaderboard
	State.Ready = true
	readyEvent:Fire()
	State.Changed.Snapshot:Fire(true)
end

function State.Init()
	localPlayer:GetAttributeChangedSignal(WorldSchema.Attributes.PlayerPlotId):Connect(function()
		recomputePlot()
		State.Changed.Plots:Fire(State.plots)
	end)
	local ev = Net.event
	ev("DataSync").OnClientEvent:Connect(function(view: Types.PlayerDataView)
		State.data = view
		State.Changed.Data:Fire(view)
	end)
	ev("PlotsChanged").OnClientEvent:Connect(applyPlots)
	ev("StationUpdate").OnClientEvent:Connect(function(s: Types.StationState)
		State.stations[State.stationKey(s.plotId, s.slot)] = s
		State.Changed.Station:Fire(s)
	end)
	ev("HeldItemChanged").OnClientEvent:Connect(function(p: Remotes.HeldItemPayload)
		State.held = p.item
		State.Changed.Held:Fire(p.item)
	end)
	ev("CustomerUpdate").OnClientEvent:Connect(function(c: Types.CustomerView)
		State.customers[c.id] = c
		State.Changed.Customer:Fire(c)
	end)
	ev("CustomerRemoved").OnClientEvent:Connect(function(p: Remotes.CustomerRemovedPayload)
		State.customers[p.id] = nil
		State.Changed.CustomerRemoved:Fire(p)
	end)
	ev("RushHourState").OnClientEvent:Connect(function(r: Types.RushHourState)
		State.rushHour = r
		State.Changed.RushHour:Fire(r)
	end)
	ev("LeaderboardUpdate").OnClientEvent:Connect(function(l: Types.LeaderboardSnapshot)
		State.leaderboard = l
		State.Changed.Leaderboard:Fire(l)
	end)
	ev("PurchaseGranted").OnClientEvent:Connect(function(p: Remotes.PurchaseGrantedPayload)
		State.Changed.PurchaseGranted:Fire(p)
	end)
	ev("OrderServed").OnClientEvent:Connect(function(p: Remotes.OrderServedPayload)
		if p.servedByUserId == localPlayer.UserId and not p.byBot then
			State.combo = p.combo
			State.Changed.Combo:Fire(p.combo)
		end
		State.Changed.OrderServed:Fire(p)
	end)
end

function State.Start()
	local invoke = Net.func("GetSnapshot")
	while not State.Ready do
		local ok, snap = pcall(function()
			return invoke:InvokeServer()
		end)
		if ok and typeof(snap) == "table" then
			applySnapshot(snap :: Remotes.Snapshot)
		else
			task.wait(Theme.UI.SnapshotRetrySeconds)
		end
	end
end

return State

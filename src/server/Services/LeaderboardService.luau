--!strict
-- Global lifetime-coins OrderedDataStore + per-server best Rush Hour. Owner: agent A.
-- Broadcasts LeaderboardUpdate. Maintains leaderstats (Coins).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local DataService = require(script.Parent.DataService)

local STATS_FOLDER = "leaderstats"
local COINS_STAT = "Coins"
local FALLBACK_NAME = "Player"

local LeaderboardService = {}

type Tally = { name: string, value: number }

local lifetimeList: { Types.LeaderboardEntry } = {}
local rushBest: { [number]: Tally } = {} -- this server's best single rush per user
local rushTally: { [number]: Tally } = {} -- current rush
local rushActive = false
local lastWritten: { [number]: number } = {}
local nameCache: { [number]: string } = {}
local orderedStore: OrderedDataStore? = nil

local function getStore(): OrderedDataStore?
	if orderedStore then
		return orderedStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Timings.Data.LeaderboardStoreName)
	end)
	if ok then
		orderedStore = result
	end
	return orderedStore
end

local function topList(source: { [number]: Tally }): { Types.LeaderboardEntry }
	local list: { Types.LeaderboardEntry } = {}
	for userId, t in source do
		table.insert(list, { userId = userId, name = t.name, value = t.value })
	end
	table.sort(list, function(a, b)
		return a.value > b.value
	end)
	while #list > Timings.Data.LeaderboardSize do
		table.remove(list)
	end
	return list
end

function LeaderboardService.GetSnapshot(): Types.LeaderboardSnapshot
	return { lifetime = lifetimeList, rushHour = topList(rushBest) }
end

local function broadcast()
	Net.event("LeaderboardUpdate"):FireAllClients(LeaderboardService.GetSnapshot())
end

local function nameFor(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.Name
		return player.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return FALLBACK_NAME
end

-- Writes only when the value changed, to stay within DataStore budgets.
local function writeLifetime(player: Player)
	local data = DataService.GetData(player)
	local store = getStore()
	if not data or not store then
		return
	end
	local value = math.floor(data.lifetimeCoins)
	if lastWritten[player.UserId] == value then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), value)
	end)
	if ok then
		lastWritten[player.UserId] = value
	else
		warn(`[LeaderboardService] write failed: {err}`)
	end
end

local function readTop()
	local store = getStore()
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, Timings.Data.LeaderboardSize):GetCurrentPage()
	end)
	if not ok then
		warn(`[LeaderboardService] read failed: {page}`)
		return
	end
	local list: { Types.LeaderboardEntry } = {}
	for _, entry in page do
		local userId = tonumber(entry.key)
		if userId and type(entry.value) == "number" then
			table.insert(list, { userId = userId, name = nameFor(userId), value = entry.value })
		end
	end
	lifetimeList = list
end

local function refresh()
	for _, player in Players:GetPlayers() do
		writeLifetime(player)
	end
	readTop()
	broadcast()
end

local function setupStats(player: Player)
	local folder = player:FindFirstChild(STATS_FOLDER)
	if not folder then
		local created = Instance.new("Folder")
		created.Name = STATS_FOLDER
		created.Parent = player
		folder = created
	end
	if folder and not folder:FindFirstChild(COINS_STAT) then
		local coins = Instance.new("IntValue")
		coins.Name = COINS_STAT
		coins.Parent = folder
	end
end

local function setCoins(player: Player, balance: number)
	local folder = player:FindFirstChild(STATS_FOLDER)
	local coins = if folder then folder:FindFirstChild(COINS_STAT) else nil
	if coins and coins:IsA("IntValue") then
		coins.Value = math.floor(balance)
	end
end

local function onRushEnded()
	rushActive = false
	for userId, tally in rushTally do
		if tally.value > 0 then
			local best = rushBest[userId]
			if not best or tally.value > best.value then
				rushBest[userId] = { name = tally.name, value = tally.value }
			end
			local player = Players:GetPlayerByUserId(userId)
			if player then
				DataService.Update(player, function(d)
					d.bestRushHour = math.max(d.bestRushHour, tally.value)
					d.stats.rushHoursPlayed += 1
				end)
			end
		end
	end
	rushTally = {}
	broadcast()
end

function LeaderboardService.Init()
	Players.PlayerAdded:Connect(setupStats)
	Events.PlayerDataLoaded:Connect(function(player, data)
		setupStats(player)
		setCoins(player, data.coins)
	end)
	Events.CoinsChanged:Connect(function(player, balance)
		setCoins(player, balance)
	end)
	Events.PlayerDataReleasing:Connect(function(player)
		task.spawn(writeLifetime, player)
	end)
	Events.RushHourStarted:Connect(function()
		rushActive = true
		rushTally = {}
	end)
	Events.RushHourEnded:Connect(onRushEnded)
	Events.OrderServed:Connect(function(result)
		if not rushActive then
			return
		end
		local userId = result.player.UserId
		local tally = rushTally[userId]
		if not tally then
			tally = { name = result.player.Name, value = 0 }
			rushTally[userId] = tally
		end
		tally.value += result.payout.total
	end)
	Players.PlayerRemoving:Connect(function(player)
		nameCache[player.UserId] = player.Name
	end)
end

function LeaderboardService.Start()
	for _, player in Players:GetPlayers() do
		setupStats(player)
		local data = DataService.GetData(player)
		if data then
			setCoins(player, data.coins)
		end
	end
	while true do
		refresh()
		task.wait(Timings.Data.LeaderboardRefreshSeconds)
	end
end

return LeaderboardService

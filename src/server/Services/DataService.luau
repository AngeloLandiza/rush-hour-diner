--!strict
-- Player profiles (ProfileStore), coins, upgrades, streak, restock, boosts, receipts. Owner: agent A.
-- Handles remotes: BuyUpgrade, ClaimStreak, CollectRestock, CompleteTutorial, SetSetting. Sends DataSync.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local Guard = require(script.Parent.Parent.Util.Guard)
local LogicOffline = require(ReplicatedStorage.Shared.Logic.Offline)
local LogicStreak = require(ReplicatedStorage.Shared.Logic.Streak)
local LogicUpgrades = require(ReplicatedStorage.Shared.Logic.Upgrades)
local Net = require(ReplicatedStorage.Shared.Net)
local ProfileStore = require(ServerStorage.Vendor.ProfileStore)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UpgradeConfig = require(ReplicatedStorage.Shared.Config.Upgrades)
local AnalyticsService = require(script.Parent.AnalyticsService)

-- Service-local plumbing constants (not gameplay tuning).
local CURRENT_SCHEMA = Timings.Data.SchemaVersion
local WAIT_POLL_SECONDS = 0.1
local DEFAULT_WAIT_SECONDS = Timings.Data.DataWaitTimeoutSeconds
local SAVE_TIMEOUT_SECONDS = Timings.Data.SaveConfirmTimeoutSeconds
local KICK_MESSAGE = "Your data session ended. Please rejoin."
local LOAD_FAIL_MESSAGE = "Could not load your data. Please rejoin."

local PASS_KEYS: { any } = { "TipsX2", "AutoChef", "ExtraStation", "VIPBooth" }

local DataService = {}

local function newTemplate(): Types.PlayerData
	return {
		schemaVersion = CURRENT_SCHEMA,
		coins = Economy.StartingCoins,
		lifetimeCoins = Economy.StartingCoins,
		upgrades = {},
		streak = { day = 0, lastClaimDay = 0 },
		lastRestock = 0,
		lastOnline = 0,
		bestRushHour = 0,
		receipts = {},
		boosts = {},
		tutorialDone = false,
		stats = { dishesServed = 0, legendaryServed = 0, rushHoursPlayed = 0 },
		settings = { music = true, sfx = true },
	}
end

-- Migration steps: migrations[v] upgrades data from schema v to v + 1. Add v1 -> v2 here later.
local migrations: { [number]: (data: any) -> () } = {}

local function migrate(data: Types.PlayerData)
	local version = data.schemaVersion
	while version < CURRENT_SCHEMA do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
		data.schemaVersion = version
	end
end

local store = ProfileStore.New(Timings.Data.ProfileStoreName, newTemplate())

local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local loadFailed: { [Player]: boolean } = {}
local passCache: { [Player]: { [string]: boolean } } = {}
local unconfirmedReceipts: { [Player]: { [string]: boolean } } = {}
local syncQueue: { [Player]: boolean } = {}
local syncScheduled = false

local function toast(player: Player, text: string, kind: Types.ToastKind)
	Net.event("Toast"):FireClient(player, { text = text, kind = kind })
end

local function awarded(player: Player, amount: number, reason: string)
	Net.event("CoinsAwarded"):FireClient(player, { amount = amount, reason = reason })
end

local function validAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount ~= math.huge
end

function DataService.GetData(player: Player): Types.PlayerData?
	local profile = profiles[player]
	if profile then
		return profile.Data
	end
	return nil
end

function DataService.WaitForData(player: Player, timeoutSeconds: number?): Types.PlayerData?
	local deadline = os.clock() + (timeoutSeconds or DEFAULT_WAIT_SECONDS)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.GetData(player)
		if data then
			return data
		end
		if loadFailed[player] then
			return nil
		end
		task.wait(WAIT_POLL_SECONDS)
	end
	return DataService.GetData(player)
end

function DataService.GetView(player: Player): Types.PlayerDataView?
	local data = DataService.GetData(player)
	if not data then
		return nil
	end
	local now = os.time()
	local passes: { [Types.PassKey]: boolean } = {}
	local cache = passCache[player] or {}
	for _i = 1, #PASS_KEYS do
		local key = PASS_KEYS[_i]
		passes[key] = cache[key] == true
	end
	return {
		coins = data.coins,
		lifetimeCoins = data.lifetimeCoins,
		upgrades = table.clone(data.upgrades),
		streak = table.clone(data.streak),
		streakClaimable = LogicStreak.canClaim(data.streak, now),
		lastRestock = data.lastRestock,
		restockPending = LogicOffline.pending(data.lastRestock, now, data.upgrades),
		bestRushHour = data.bestRushHour,
		boosts = table.clone(data.boosts),
		passes = passes,
		tutorialDone = data.tutorialDone,
		settings = table.clone(data.settings),
	}
end

function DataService.PushSync(player: Player)
	syncQueue[player] = true
	if syncScheduled then
		return
	end
	syncScheduled = true
	task.defer(function()
		syncScheduled = false
		local queued = syncQueue
		syncQueue = {}
		for p in queued do
			local view = DataService.GetView(p)
			if view and p.Parent == Players then
				Net.event("DataSync"):FireClient(p, view)
			end
		end
	end)
end

function DataService.Update(player: Player, mutator: (data: Types.PlayerData) -> ())
	local data = DataService.GetData(player)
	if not data then
		return
	end
	mutator(data)
	DataService.PushSync(player)
end

function DataService.AddCoins(player: Player, amount: number, reason: string): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	if not validAmount(amount) then
		warn(`[DataService] rejected AddCoins({tostring(amount)}, {reason})`)
		return data.coins
	end
	if amount == 0 then
		return data.coins
	end
	data.coins += amount
	data.lifetimeCoins += amount
	AnalyticsService.LogEconomy(player, "Source", amount, data.coins, reason)
	Events.CoinsChanged:Fire(player, data.coins, amount, reason)
	DataService.PushSync(player)
	return data.coins
end

function DataService.SpendCoins(player: Player, amount: number, reason: string): boolean
	local data = DataService.GetData(player)
	if not data then
		return false
	end
	if not validAmount(amount) or data.coins < amount then
		return false
	end
	if amount == 0 then
		return true
	end
	data.coins -= amount
	AnalyticsService.LogEconomy(player, "Sink", amount, data.coins, reason)
	Events.CoinsChanged:Fire(player, data.coins, -amount, reason)
	DataService.PushSync(player)
	return true
end

function DataService.AddBoost(player: Player, boost: Types.BoostKey, seconds: number)
	if not validAmount(seconds) or seconds == 0 then
		return
	end
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local now = os.time()
	data.boosts[boost] = math.max(data.boosts[boost] or 0, now) + seconds
	Events.BoostsChanged:Fire(player)
	DataService.PushSync(player)
end

function DataService.CollectRestock(player: Player, full: boolean): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	local now = os.time()
	local amount = if full
		then LogicOffline.fullRestock(data.upgrades)
		else LogicOffline.pending(data.lastRestock, now, data.upgrades)
	if amount <= 0 and not full then
		return 0
	end
	data.lastRestock = now
	if amount > 0 then
		DataService.AddCoins(player, amount, "Restock")
	else
		DataService.PushSync(player)
	end
	return amount
end

function DataService.HasReceipt(player: Player, purchaseId: string): boolean
	local data = DataService.GetData(player)
	return data ~= nil and data.receipts[purchaseId] ~= nil
end

function DataService.RecordReceipt(player: Player, purchaseId: string)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	data.receipts[purchaseId] = os.time()
	local pending = unconfirmedReceipts[player]
	if not pending then
		pending = {}
		unconfirmedReceipts[player] = pending
	end
	pending[purchaseId] = true
	-- Cap the list, dropping the oldest (never the one just recorded).
	local count = 0
	for _ in data.receipts do
		count += 1
	end
	while count > Timings.Data.MaxStoredReceipts do
		local oldestId: string? = nil
		local oldestTime = math.huge
		for id, t in data.receipts do
			if id ~= purchaseId and t < oldestTime then
				oldestId, oldestTime = id, t
			end
		end
		if not oldestId then
			break
		end
		data.receipts[oldestId] = nil
		pending[oldestId] = nil
		count -= 1
	end
end

-- Save and wait for ProfileStore's OnAfterSave. A save already in flight may predate our latest
-- mutation, so we verify LastSavedData contains every unconfirmed receipt and save again if not.
function DataService.SaveAndConfirm(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	local deadline = os.clock() + SAVE_TIMEOUT_SECONDS
	while os.clock() < deadline do
		if profiles[player] ~= profile or not profile:IsActive() then
			return false
		end
		local done = false
		local conn = profile.OnAfterSave:Connect(function()
			done = true
		end)
		profile:Save()
		while not done and os.clock() < deadline and profiles[player] == profile do
			task.wait(WAIT_POLL_SECONDS)
		end
		conn:Disconnect()
		if profiles[player] ~= profile then
			return false
		end
		if done then
			local saved = profile.LastSavedData
			local allSaved = true
			local pending = unconfirmedReceipts[player]
			if pending then
				for id in pending do
					if saved.receipts[id] == nil and profile.Data.receipts[id] ~= nil then
						allSaved = false
						break
					end
				end
			end
			if allSaved then
				unconfirmedReceipts[player] = nil
				return true
			end
		end
	end
	return false
end

-- ── Session lifecycle ───────────────────────────────────────────────────────

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Events.PlayerDataReleasing:Fire(player)
	profile.Data.lastOnline = os.time()
	profiles[player] = nil
	profile:EndSession()
end

local function loadPlayer(player: Player)
	loading[player] = true
	local key = `Player_{player.UserId}`
	local function cancelled(): boolean
		return player.Parent ~= Players
	end
	local profile: any = store:StartSessionAsync(key, { Cancel = cancelled })
	if profile == nil and not cancelled() then
		-- Session lock was not released in time: take it over.
		profile = store:StartSessionAsync(key, { Steal = true, Cancel = cancelled })
	end
	if profile == nil then
		loading[player] = nil
		loadFailed[player] = true
		if not cancelled() then
			player:Kick(LOAD_FAIL_MESSAGE)
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)
	if cancelled() then
		loading[player] = nil
		profile:EndSession()
		return
	end
	profile.OnSave:Connect(function()
		profile.Data.lastOnline = os.time()
	end)
	profile.OnSessionEnd:Connect(function()
		-- Session ended by someone else (e.g. stolen by another server).
		if profiles[player] == profile then
			Events.PlayerDataReleasing:Fire(player)
			profiles[player] = nil
			if player.Parent == Players then
				player:Kick(KICK_MESSAGE)
			end
		end
	end)
	if profile.Data.lastRestock == 0 then
		profile.Data.lastRestock = os.time()
	end
	profiles[player] = profile
	loading[player] = nil
	Events.PlayerDataLoaded:Fire(player, profile.Data)
	DataService.PushSync(player)
end

local function onPlayerAdded(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	task.spawn(loadPlayer, player)
end

local function onPlayerRemoving(player: Player)
	releaseProfile(player)
	loading[player] = nil
	loadFailed[player] = nil
	passCache[player] = nil
	unconfirmedReceipts[player] = nil
	syncQueue[player] = nil
end

-- ── Remote handlers ─────────────────────────────────────────────────────────

local function handleBuyUpgrade(player: Player, payload: any)
	if type(payload) ~= "table" or not Guard.isOneOf(payload.upgradeId, UpgradeConfig.Defs) then
		return
	end
	local id: string = payload.upgradeId
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local ok, reason = LogicUpgrades.canBuy(data.upgrades, data.coins, id)
	if not ok then
		local text = if reason == "TooPoor"
			then "Not enough coins."
			elseif reason == "Maxed" then "Already maxed out."
			else "Can't buy that."
		toast(player, text, "Warning")
		return
	end
	local cost = LogicUpgrades.nextCost(data.upgrades, id)
	if not cost or not DataService.SpendCoins(player, cost, "Upgrade") then
		toast(player, "Not enough coins.", "Warning")
		return
	end
	local newLevel = LogicUpgrades.getLevel(data.upgrades, id) + 1
	DataService.Update(player, function(d)
		d.upgrades[id] = newLevel
	end)
	AnalyticsService.LogEvent(player, "UpgradePurchased", newLevel)
	Events.UpgradePurchased:Fire(player, id, newLevel)
end

local function handleClaimStreak(player: Player, _payload: any)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local now = os.time()
	if not LogicStreak.canClaim(data.streak, now) then
		toast(player, "Already claimed today. Come back tomorrow!", "Info")
		return
	end
	local newStreak, reward = LogicStreak.claim(data.streak, now)
	if reward <= 0 then
		return
	end
	DataService.Update(player, function(d)
		d.streak = newStreak
	end)
	DataService.AddCoins(player, reward, "Streak")
	awarded(player, reward, "Streak")
end

local function handleCollectRestock(player: Player, _payload: any)
	local granted = DataService.CollectRestock(player, false)
	if granted > 0 then
		awarded(player, granted, "Restock")
	end
end

local function handleCompleteTutorial(player: Player, _payload: any)
	local data = DataService.GetData(player)
	if not data or data.tutorialDone then
		return
	end
	DataService.Update(player, function(d)
		d.tutorialDone = true
	end)
	Events.TutorialCompleted:Fire(player)
end

local function handleSetSetting(player: Player, payload: any)
	if type(payload) ~= "table" or not Guard.isBool(payload.value) then
		return
	end
	local key = payload.key
	if key ~= "music" and key ~= "sfx" then
		return
	end
	local value: boolean = payload.value
	DataService.Update(player, function(d)
		if key == "music" then
			d.settings.music = value
		else
			d.settings.sfx = value
		end
	end)
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	Events.PassOwnershipChanged:Connect(function(player, pass, owned)
		local cache = passCache[player]
		if not cache then
			cache = {}
			passCache[player] = cache
		end
		cache[pass] = owned
		DataService.PushSync(player)
	end)

	Events.OrderServed:Connect(function(result)
		DataService.Update(result.player, function(d)
			d.stats.dishesServed += 1
			if result.kind == "Legendary" then
				d.stats.legendaryServed += 1
			end
		end)
	end)

	Guard.onEvent("BuyUpgrade", handleBuyUpgrade)
	Guard.onEvent("ClaimStreak", handleClaimStreak)
	Guard.onEvent("CollectRestock", handleCollectRestock)
	Guard.onEvent("CompleteTutorial", handleCompleteTutorial)
	Guard.onEvent("SetSetting", handleSetSetting)
end

function DataService.Start()
	-- Players already in the server before Init connected (Studio / late boot).
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return DataService

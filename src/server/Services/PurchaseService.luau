--!strict
-- Game passes, developer products (idempotent ProcessReceipt), rewarded video ads. Owner: agent A.
-- Handles remote: RequestRewardedAd. Placeholder ids (0) are never prompted or granted.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local LogicEconomy = require(ReplicatedStorage.Shared.Logic.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local RushHourService = require(script.Parent.RushHourService)

-- Service-local plumbing constants (not gameplay tuning).
local OWNERSHIP_RETRIES = Timings.Data.OwnershipRetryAttempts
local OWNERSHIP_RETRY_SECONDS = Timings.Data.OwnershipRetryDelaySeconds
local RECEIPT_DATA_WAIT_SECONDS = Timings.Data.ReceiptDataWaitSeconds
local DEBUG_ATTRIBUTE = "DebugAllPasses"

local PASS_KEYS: { any } = { "TipsX2", "AutoChef", "ExtraStation", "VIPBooth" }
local PRODUCT_KEYS: { any } = {
	"InstantRestock",
	"RushHourNow",
	"TipPotion",
	"CoinsSmall",
	"CoinsMedium",
	"CoinsLarge",
	"AdTipBoost",
}
local AD_PRODUCT: any = "AdTipBoost"

local PurchaseService = {}

local ownership: { [Player]: { [string]: boolean } } = {}
local passByGamePassId: { [number]: any } = {}
local productById: { [number]: any } = {}
local inFlight: { [string]: boolean } = {}
local adCooldownUntil: { [Player]: number } = {}

local function toast(player: Player, text: string, kind: Types.ToastKind)
	Net.event("Toast"):FireClient(player, { text = text, kind = kind })
end

local function debugAll(): boolean
	return RunService:IsStudio() and workspace:GetAttribute(DEBUG_ATTRIBUTE) == true
end

function PurchaseService.OwnsPass(player: Player, pass: Types.PassKey): boolean
	if debugAll() then
		return true
	end
	local def = Products.Passes[pass]
	if not def or def.id == 0 then
		return false
	end
	local cache = ownership[player]
	return cache ~= nil and cache[pass] == true
end

function PurchaseService.GetPasses(player: Player): { [Types.PassKey]: boolean }
	local result: { [Types.PassKey]: boolean } = {}
	for _i = 1, #PASS_KEYS do
		local key = PASS_KEYS[_i]
		result[key] = PurchaseService.OwnsPass(player, key)
	end
	return result
end

function PurchaseService.GetTipBoostPct(player: Player): number
	local data = DataService.GetData(player)
	if not data then
		return 0
	end
	return LogicEconomy.tipBoostPct(data.boosts, os.time())
end

local function setOwned(player: Player, pass: any, owned: boolean)
	if player.Parent ~= Players then
		return false
	end
	local cache = ownership[player]
	if not cache then
		cache = {}
		ownership[player] = cache
	end
	local changed = cache[pass] ~= owned
	cache[pass] = owned
	if pass == "VIPBooth" then
		player:SetAttribute(WorldSchema.Attributes.VIPBooth, PurchaseService.OwnsPass(player, "VIPBooth"))
	end
	if changed then
		Events.PassOwnershipChanged:Fire(player, pass, owned)
	end
	return changed
end

-- pcall'd with retry. Returns nil if the query kept failing.
local function queryOwnership(player: Player, gamePassId: number): boolean?
	for attempt = 1, OWNERSHIP_RETRIES do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
		end)
		if ok then
			return result == true
		end
		if attempt < OWNERSHIP_RETRIES then
			task.wait(OWNERSHIP_RETRY_SECONDS)
		end
	end
	return nil
end

local function loadPasses(player: Player)
	for _i = 1, #PASS_KEYS do
		local key = PASS_KEYS[_i]
		local def = Products.Passes[key]
		if player.Parent ~= Players then
			return
		end
		if def.id ~= 0 then
			local owned = queryOwnership(player, def.id)
			if owned ~= nil then
				setOwned(player, key, owned)
			end
		end
	end
	if debugAll() then
		for _i = 1, #PASS_KEYS do
			local key = PASS_KEYS[_i]
			if Products.Passes[key].id ~= 0 then
				Events.PassOwnershipChanged:Fire(player, key, true)
			end
		end
	end
end

local function onPassPurchaseFinished(player: Player, gamePassId: number, wasPurchased: boolean)
	local key = passByGamePassId[gamePassId]
	if not key then
		return
	end
	local owned = queryOwnership(player, gamePassId)
	if wasPurchased then
		owned = true -- Roblox's ownership cache can lag right after a purchase
	end
	if owned == nil then
		return
	end
	local changed = setOwned(player, key, owned)
	if owned and (changed or wasPurchased) then
		Net.event("PurchaseGranted"):FireClient(player, { key = key, kind = "Pass" })
		AnalyticsService.LogEvent(player, `PassPurchased_{key}`)
	end
end

-- ── Developer products ──────────────────────────────────────────────────────

-- Applies the product's effect. Errors propagate to the caller (-> NotProcessedYet).
local function grantProduct(player: Player, key: any, def: Types.ProductDef)
	if def.coins then
		DataService.AddCoins(player, def.coins, `Product_{key}`)
		Net.event("CoinsAwarded"):FireClient(player, { amount = def.coins, reason = key })
	end
	if def.boost and def.boostSeconds then
		-- DataService.AddBoost fires Events.BoostsChanged.
		DataService.AddBoost(player, def.boost, def.boostSeconds)
	end
	if key == "InstantRestock" then
		local granted = DataService.CollectRestock(player, true)
		if granted > 0 then
			Net.event("CoinsAwarded"):FireClient(player, { amount = granted, reason = key })
		end
	elseif key == "RushHourNow" then
		if not RushHourService.TriggerNow(player) then
			warn(`[PurchaseService] RushHourNow trigger refused for {player.UserId}`)
		end
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted

	local key = productById[info.ProductId]
	if not key then
		return notYet
	end
	local def = Products.Products[key]
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not def or not player then
		return notYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if inFlight[purchaseId] then
		return notYet
	end
	inFlight[purchaseId] = true
	local decision = notYet
	local errMessage = ""
	local ok = xpcall(function()
		if not DataService.WaitForData(player, RECEIPT_DATA_WAIT_SECONDS) then
			return
		end
		if DataService.HasReceipt(player, purchaseId) then
			-- Already granted in memory; only acknowledge once it is durably saved.
			if DataService.SaveAndConfirm(player) then
				decision = granted
			end
			return
		end
		grantProduct(player, key, def)
		DataService.RecordReceipt(player, purchaseId)
		if DataService.SaveAndConfirm(player) then
			decision = granted
			Net.event("PurchaseGranted"):FireClient(player, { key = key, kind = "Product" })
			Events.ProductGranted:Fire(player, key, purchaseId)
			AnalyticsService.LogEvent(player, `ProductGranted_{key}`)
		end
	end, function(e)
		errMessage = tostring(e)
	end)
	inFlight[purchaseId] = nil
	if not ok then
		warn(`[PurchaseService] ProcessReceipt error for {purchaseId}: {errMessage}`)
		return notYet
	end
	return decision
end

-- ── Rewarded video ──────────────────────────────────────────────────────────

local function handleRewardedAd(player: Player, _payload: any)
	local now = os.clock()
	if (adCooldownUntil[player] or 0) > now then
		toast(player, "Please wait before watching another ad.", "Info")
		return
	end
	adCooldownUntil[player] = now + Timings.Ads.CooldownSeconds
	if not DataService.GetData(player) then
		return
	end
	local def = Products.Products[AD_PRODUCT]
	if def.id == 0 then
		toast(player, "Ads aren't available right now.", "Info")
		return
	end
	-- AdService API (create.roblox.com/docs/reference/engine/classes/AdService):
	-- GetAdAvailabilityNowAsync(Enum.AdFormat) -> { AdAvailabilityResult }, CreateAdRewardFromDevProductId,
	-- ShowRewardedVideoAdAsync(player, reward). Accessed dynamically so API drift cannot break the build.
	local service = AdService :: any
	local availOk, availability = pcall(function()
		return service:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	if
		not availOk
		or availability == nil
		or availability.AdAvailabilityResult ~= Enum.AdAvailabilityResult.IsAvailable
	then
		toast(player, "No ad available right now. Try again soon!", "Info")
		return
	end
	local rewardOk, reward = pcall(function()
		return service:CreateAdRewardFromDevProductId(def.id)
	end)
	if not rewardOk or reward == nil then
		toast(player, "Ads aren't available right now.", "Info")
		return
	end
	local showOk, result = pcall(function()
		return service:ShowRewardedVideoAdAsync(player, reward)
	end)
	if not showOk then
		warn(`[PurchaseService] ShowRewardedVideoAdAsync failed: {result}`)
		toast(player, "Couldn't show the ad. Try again later.", "Warning")
		return
	end
	AnalyticsService.LogEvent(player, "RewardedAdRequested")
	-- The reward itself arrives through MarketplaceService.ProcessReceipt.
end

-- ── Boot ────────────────────────────────────────────────────────────────────

function PurchaseService.Init()
	for _i = 1, #PASS_KEYS do
		local key = PASS_KEYS[_i]
		local def = Products.Passes[key]
		if def.id ~= 0 then
			passByGamePassId[def.id] = key
		end
	end
	for _i = 1, #PRODUCT_KEYS do
		local key = PRODUCT_KEYS[_i]
		local def = Products.Products[key]
		if def.id ~= 0 then
			productById[def.id] = key
		end
	end

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchaseFinished)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		ownership[player] = nil
		adCooldownUntil[player] = nil
	end)
	Guard.onEvent("RequestRewardedAd", handleRewardedAd)
end

function PurchaseService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(loadPasses, player)
	end
end

return PurchaseService

--!strict
-- Player profiles (ProfileStore), coins, upgrades, streak, restock, boosts, receipts. Owner: agent A.
-- Handles remotes: BuyUpgrade, ClaimStreak, CollectRestock, CompleteTutorial, SetSetting. Sends DataSync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local DataService = {}

function DataService.Init() end

function DataService.Start() end

-- Loaded profile data, or nil while loading / after release. Treat as read-only; mutate via the API below.
function DataService.GetData(player: Player): Types.PlayerData?
	return nil
end

-- Yields until the profile loads (or timeout / player leaves). Returns nil on failure.
function DataService.WaitForData(player: Player, timeoutSeconds: number?): Types.PlayerData?
	return nil
end

function DataService.GetView(player: Player): Types.PlayerDataView?
	return nil
end

-- Adds coins (and lifetimeCoins when amount > 0). Returns the new balance. Fires Events.CoinsChanged.
function DataService.AddCoins(player: Player, amount: number, reason: string): number
	return 0
end

-- Deducts coins if the balance allows. Returns true on success.
function DataService.SpendCoins(player: Player, amount: number, reason: string): boolean
	return false
end

-- Generic mutation for fields without a dedicated function (stats, bestRushHour...). Sends DataSync.
function DataService.Update(player: Player, mutator: (data: Types.PlayerData) -> ()) end

-- Sets/extends a timed boost: expiry = max(current, now) + seconds. Fires Events.BoostsChanged.
function DataService.AddBoost(player: Player, boost: Types.BoostKey, seconds: number) end

-- Grants offline/restock earnings. full = true pays a full capped restock (Instant Restock).
-- Resets lastRestock. Returns coins granted.
function DataService.CollectRestock(player: Player, full: boolean): number
	return 0
end

-- Receipt idempotency (used by PurchaseService.ProcessReceipt).
function DataService.HasReceipt(player: Player, purchaseId: string): boolean
	return false
end

function DataService.RecordReceipt(player: Player, purchaseId: string) end

-- Forces a save and yields until it is confirmed. Returns false if the save failed or the session ended.
function DataService.SaveAndConfirm(player: Player): boolean
	return false
end

-- Queue a DataSync for this player (debounced to once per frame).
function DataService.PushSync(player: Player) end

return DataService

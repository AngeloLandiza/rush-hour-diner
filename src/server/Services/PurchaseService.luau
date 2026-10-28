--!strict
-- Game passes, developer products (idempotent ProcessReceipt), rewarded video ads. Owner: agent A.
-- Handles remote: RequestRewardedAd. Placeholder ids (0) are never prompted or granted.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local PurchaseService = {}

function PurchaseService.Init() end

function PurchaseService.Start() end

-- Cached pass ownership (refreshed on join and on PromptGamePassPurchaseFinished).
function PurchaseService.OwnsPass(player: Player, pass: Types.PassKey): boolean
	return false
end

-- All passes for the DataSync view.
function PurchaseService.GetPasses(player: Player): { [Types.PassKey]: boolean }
	return {}
end

-- Sum of active timed tip boosts for the player (Logic/Economy.tipBoostPct).
function PurchaseService.GetTipBoostPct(player: Player): number
	return 0
end

return PurchaseService

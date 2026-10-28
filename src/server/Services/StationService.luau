--!strict
-- Server-authoritative cook state machine per plot slot, held items, Auto-Chef AFK income. Owner: agent C.
-- Handles remote: CookAction. Sends StationUpdate, HeldItemChanged.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local StationService = {}

function StationService.Init() end

function StationService.Start() end

function StationService.GetHeldItem(player: Player): Types.HeldItem?
	return nil
end

-- Removes and returns the player's held item (used when serving).
function StationService.TakeHeldItem(player: Player): Types.HeldItem?
	return nil
end

function StationService.GetStations(plotId: number): { Types.StationState }
	return {}
end

function StationService.GetAllStates(): { Types.StationState }
	return {}
end

-- For the auto-server bot: removes a Ready dish of dishId from the plot's stations, returns its quality.
function StationService.TakeReadyDish(plotId: number, dishId: Types.DishId): Types.CookQuality?
	return nil
end

return StationService

--!strict
-- Station, food and bot props from primitives (Palette colors only). Owner: agent E.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local PropBuilder = {}

function PropBuilder.Init() end

function PropBuilder.Start() end

-- A station model with an "Interact" part and "FX" attachment (see WorldSchema).
function PropBuilder.MakeStation(stationId: Types.StationId): Model
	local model = Instance.new("Model")
	model.Name = "Station"
	return model
end

-- A small plated dish model (welded to a character's hand when held).
function PropBuilder.MakeDish(dishId: Types.DishId): Model
	local model = Instance.new("Model")
	model.Name = "Dish"
	return model
end

-- The auto-server robot (Humanoid-free model with a PrimaryPart).
function PropBuilder.MakeAutoServerBot(): Model
	local model = Instance.new("Model")
	model.Name = "AutoServer"
	return model
end

return PropBuilder

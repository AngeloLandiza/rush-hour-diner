--!strict
-- Dish icons (thin wrapper over UI/Icons; dish ids are icon names). Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local DishIcon = {}

local DEFAULT_PX = 44

-- A square dish icon. px drives outline weight; size overrides the root Size (default: fill parent).
function DishIcon.create(dishId: Types.DishId, parent: Instance?, size: UDim2?, px: number?): Frame
	return Icons.build(dishId, parent, px or DEFAULT_PX, { Size = size or UDim2.fromScale(1, 1), Name = "DishIcon" })
end

return DishIcon

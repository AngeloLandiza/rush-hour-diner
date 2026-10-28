--!strict
-- Dish icons built from primitives (no emoji, no assets). Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Util)

local DishIcon = {}

local C = Theme.Colors

local function part(parent: Instance, color: Color3, pos: UDim2, size: UDim2, radius: number): Frame
	local f = Util.frame(parent, {
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Position = pos,
		Size = size,
	})
	Util.new("UICorner", { CornerRadius = UDim.new(radius, 0) }, f)
	Util.stroke(f, C.Ink, Theme.UI.ThinStroke)
	return f
end

-- A square icon filling its parent-sized frame.
function DishIcon.create(dishId: Types.DishId, parent: Instance?, size: UDim2?): Frame
	local root = Util.frame(parent, { Name = "DishIcon", Size = size or UDim2.fromScale(1, 1) })
	Util.new("UIAspectRatioConstraint", { AspectRatio = 1 }, root)
	if dishId == "Burger" then
		part(root, C.Mustard, UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.8, 0.32), 0.5)
		part(root, C.Ketchup, UDim2.fromScale(0.06, 0.42), UDim2.fromScale(0.88, 0.14), 0.5)
		part(root, C.Ink, UDim2.fromScale(0.1, 0.54), UDim2.fromScale(0.8, 0.16), 0.5)
		part(root, C.Mustard, UDim2.fromScale(0.1, 0.7), UDim2.fromScale(0.8, 0.2), 0.5)
	elseif dishId == "Fries" then
		for i = 0, 3 do
			local y = 0.08 + (i % 2) * 0.06
			part(root, C.Mustard, UDim2.fromScale(0.16 + i * 0.17, y), UDim2.fromScale(0.14, 0.5), 0.3)
		end
		part(root, C.Ketchup, UDim2.fromScale(0.12, 0.45), UDim2.fromScale(0.76, 0.45), 0.2)
	elseif dishId == "Pizza" then
		part(root, C.Mustard, UDim2.fromScale(0.05, 0.05), UDim2.fromScale(0.9, 0.9), 0.5)
		part(root, C.Ketchup, UDim2.fromScale(0.3, 0.25), UDim2.fromScale(0.2, 0.2), 0.5)
		part(root, C.Ketchup, UDim2.fromScale(0.55, 0.45), UDim2.fromScale(0.2, 0.2), 0.5)
		part(root, C.Mint, UDim2.fromScale(0.3, 0.6), UDim2.fromScale(0.14, 0.14), 0.5)
	else -- Drink
		part(root, C.Mint, UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.5, 0.68), 0.2)
		part(root, C.NeonPink, UDim2.fromScale(0.55, 0.02), UDim2.fromScale(0.1, 0.4), 0.3)
		part(root, C.White, UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.5, 0.14), 0.3)
	end
	return root
end

return DishIcon

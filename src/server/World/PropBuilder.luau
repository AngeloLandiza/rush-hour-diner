--!strict
-- Station, food and bot props from primitives (Palette colors only). Owner: agent E.
-- Stations are built facing +Z (the player side) around a pivot at floor level.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Layout = require("./Layout")
local Build = require("./Build")
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local C = Palette.Color
local NEON = Enum.Material.Neon

local PropBuilder = {}

local CAB_W, CAB_H, CAB_D = 8, 3.2, 5.5
local CAB_Y = 0.3 -- cabinet bottom (on top of the plinth)
local TOP_Y = CAB_Y + CAB_H

local function cf(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Shared base: plinth (PrimaryPart), cabinet, front trim stripe and the Interact part with the FX attachment.
local function baseStation(model: Model, cabinetColor: Color3, trimColor: Color3, fxHeight: number)
	local plinth = Build.Part(model, "Plinth", Vector3.new(CAB_W + 0.6, CAB_Y, CAB_D + 0.4), cf(0, CAB_Y / 2, 0), C.Ink)
	model.PrimaryPart = plinth
	Build.Part(model, "Cabinet", Vector3.new(CAB_W, CAB_H, CAB_D), cf(0, CAB_Y + CAB_H / 2, 0), cabinetColor)
	Build.Part(model, "Trim", Vector3.new(CAB_W + 0.2, 0.7, CAB_D + 0.2), cf(0, CAB_Y + CAB_H - 0.35, 0), trimColor)
	local interactY = 0.6
	local interact = Build.Marker(
		model,
		WorldSchema.Parts.Interact,
		Vector3.new(6, 1, 3),
		cf(0, interactY, CAB_D / 2 + Layout.InteractOffsetZ - CAB_D / 2)
	)
	local fx = Instance.new("Attachment")
	fx.Name = WorldSchema.Parts.FXAttachment
	-- Attachment position is relative to Interact: up to the cooking surface and back over the station.
	fx.Position = Vector3.new(0, fxHeight - interactY, -Layout.InteractOffsetZ)
	fx.Parent = interact
end

local function knobs(model: Model, color: Color3, count: number)
	for i = 1, count do
		local x = (i - (count + 1) / 2) * 1.6
		Build.Ball(model, "Knob", Vector3.new(0.8, 0.8, 0.8), cf(x, CAB_Y + 1.4, CAB_D / 2 + 0.2), color)
	end
end

local function makeGrill(model: Model)
	baseStation(model, C.Cream, C.Ketchup, TOP_Y + 0.8)
	Build.Part(model, "Plate", Vector3.new(7.2, 0.5, 4.6), cf(0, TOP_Y + 0.25, 0.2), C.Ink)
	for i = 1, 4 do
		Build.Part(
			model,
			"GrillLine",
			Vector3.new(0.3, 0.12, 4.2),
			cf((i - 2.5) * 1.5, TOP_Y + 0.55, 0.2),
			C.Ketchup,
			NEON
		)
	end
	Build.Part(model, "Backsplash", Vector3.new(CAB_W, 2.6, 0.6), cf(0, TOP_Y + 1.3, -CAB_D / 2 + 0.3), C.Ketchup)
	knobs(model, C.Mustard, 3)
end

local function makeFryer(model: Model)
	baseStation(model, C.Cream, C.Mustard, TOP_Y + 1)
	Build.Part(model, "VatRim", Vector3.new(6.4, 0.6, 4.2), cf(0, TOP_Y + 0.3, 0.2), C.Ink)
	Build.Part(model, "Oil", Vector3.new(5.6, 0.2, 3.4), cf(0, TOP_Y + 0.65, 0.2), C.Mustard, NEON)
	Build.Part(model, "Basket", Vector3.new(3.2, 1.1, 2.4), cf(-0.8, TOP_Y + 1.1, 0.2), C.InkSoft)
	Build.Cylinder(
		model,
		"BasketHandle",
		0.35,
		3.6,
		cf(-0.8, TOP_Y + 1.5, 2.4) * CFrame.Angles(math.pi / 2 - 0.3, 0, 0),
		C.Ketchup
	)
	Build.Cylinder(model, "Vent", 1.2, 2.2, cf(2.6, TOP_Y + 1.1, -1.8), C.Ink)
	knobs(model, C.Ketchup, 2)
end

local function makeOven(model: Model)
	baseStation(model, C.Cream, C.Mint, TOP_Y + 3)
	Build.Ball(model, "Dome", Vector3.new(5.4, 5.4, 5.4), cf(0, TOP_Y, 0), C.Ketchup)
	Build.Cylinder(model, "Mouth", 2.8, 0.3, cf(0, TOP_Y + 0.9, 2.55) * CFrame.Angles(math.pi / 2, 0, 0), C.Ink)
	Build.Cylinder(
		model,
		"Glow",
		2.2,
		0.3,
		cf(0, TOP_Y + 0.9, 2.62) * CFrame.Angles(math.pi / 2, 0, 0),
		C.Mustard,
		NEON
	)
	Build.Cylinder(model, "Chimney", 1.1, 1.8, cf(0, TOP_Y + 3.1, -0.6), C.Ink)
	knobs(model, C.Mint, 2)
end

local function makeSoda(model: Model)
	baseStation(model, C.Cream, C.NeonPink, TOP_Y + 1)
	Build.Part(model, "Tower", Vector3.new(6, 3.2, 3.2), cf(0, TOP_Y + 1.6, -0.9), C.Mint)
	Build.Part(model, "Head", Vector3.new(6.4, 1.2, 4), cf(0, TOP_Y + 3.2, -0.5), C.MintDeep)
	local colors = { C.Ketchup, C.Mustard, C.NeonPink }
	for i, color in colors do
		Build.Cylinder(model, "Nozzle", 0.7, 1.1, cf((i - 2) * 1.8, TOP_Y + 2.1, 1.3), color)
	end
	Build.Part(model, "Tray", Vector3.new(5.4, 0.2, 2), cf(0, TOP_Y + 0.1, 1.5), C.Ink)
	Build.Ball(model, "Cherry", Vector3.new(1, 1, 1), cf(0, TOP_Y + 4.1, -0.5), C.NeonPink, NEON)
end

local STATION_MAKERS: { [Types.StationId]: (Model) -> () } = {
	Grill = makeGrill,
	Fryer = makeFryer,
	Oven = makeOven,
	Soda = makeSoda,
}

-- Dishes are built at the origin around a PrimaryPart, then rigged (unanchored, massless, welded).
local function makeBurger(model: Model)
	local plate = Build.Cylinder(model, "Plate", 3, 0.15, cf(0, 0.075, 0), C.Cream)
	model.PrimaryPart = plate
	Build.Cylinder(model, "BunBottom", 2, 0.4, cf(0, 0.35, 0), C.Mustard)
	Build.Cylinder(model, "Patty", 2.1, 0.35, cf(0, 0.72, 0), C.Ink)
	Build.Part(model, "Cheese", Vector3.new(2.1, 0.1, 2.1), cf(0, 0.95, 0), C.Mustard, NEON)
	Build.Cylinder(model, "Lettuce", 2.2, 0.15, cf(0, 1.08, 0), C.Mint)
	Build.Cylinder(model, "Tomato", 1.9, 0.18, cf(0, 1.25, 0), C.Ketchup)
	Build.Ball(model, "BunTop", Vector3.new(2.1, 1.1, 2.1), cf(0, 1.6, 0), C.Mustard)
end

local function makeFries(model: Model)
	local carton = Build.Part(model, "Carton", Vector3.new(1.8, 1.4, 1.1), cf(0, 0.7, 0), C.Ketchup)
	model.PrimaryPart = carton
	Build.Part(model, "CartonBand", Vector3.new(1.85, 0.4, 1.15), cf(0, 0.6, 0), C.Mustard)
	for i = 1, 5 do
		local x = (i - 3) * 0.32
		Build.Part(
			model,
			"Fry",
			Vector3.new(0.22, 1.1, 0.22),
			cf(x, 1.7, 0) * CFrame.Angles(0, 0, (i - 3) * 0.12),
			C.Mustard
		)
	end
end

local function makePizza(model: Model)
	local crust = Build.Cylinder(model, "Crust", 3.2, 0.25, cf(0, 0.125, 0), C.Cream)
	model.PrimaryPart = crust
	Build.Cylinder(model, "Sauce", 2.8, 0.3, cf(0, 0.2, 0), C.Ketchup)
	Build.Cylinder(model, "Cheese", 2.5, 0.34, cf(0, 0.22, 0), C.Mustard)
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		Build.Cylinder(model, "Pepperoni", 0.55, 0.38, cf(math.cos(a) * 0.8, 0.24, math.sin(a) * 0.8), C.Ketchup)
	end
	Build.Cylinder(model, "Basil", 0.45, 0.4, cf(0, 0.26, 0), C.Mint)
end

local function makeDrink(model: Model)
	local cup = Build.Cylinder(model, "Cup", 1.3, 1.8, cf(0, 0.9, 0), C.Cream)
	model.PrimaryPart = cup
	Build.Cylinder(model, "Stripe", 1.34, 0.5, cf(0, 0.9, 0), C.Ketchup)
	Build.Cylinder(model, "Lid", 1.4, 0.18, cf(0, 1.85, 0), C.Ink)
	Build.Cylinder(model, "Straw", 0.18, 1.6, cf(0.2, 2.4, 0) * CFrame.Angles(0, 0, -0.2), C.NeonPink)
end

local DISH_MAKERS: { [Types.DishId]: (Model) -> () } = {
	Burger = makeBurger,
	Fries = makeFries,
	Pizza = makePizza,
	Drink = makeDrink,
}

function PropBuilder.Init() end

function PropBuilder.Start() end

-- A station model with an "Interact" part and "FX" attachment (under Interact), pivot at the floor.
function PropBuilder.MakeStation(stationId: Types.StationId): Model
	local model = Instance.new("Model")
	model.Name = "Station"
	local maker = STATION_MAKERS[stationId]
	assert(maker, "unknown station " .. tostring(stationId))
	maker(model)
	model:SetAttribute(WorldSchema.Attributes.StationId, stationId)
	return model
end

-- A small plated dish: unanchored, massless, non-colliding, welded to its PrimaryPart.
function PropBuilder.MakeDish(dishId: Types.DishId): Model
	local model = Instance.new("Model")
	model.Name = "Dish"
	local maker = DISH_MAKERS[dishId]
	assert(maker, "unknown dish " .. tostring(dishId))
	maker(model)
	model:SetAttribute("DishId", dishId)
	Build.Rig(model, false)
	return model
end

-- The auto-server robot (Humanoid-free). Front faces -Z; the anchored body is the PrimaryPart.
function PropBuilder.MakeAutoServerBot(): Model
	local model = Instance.new("Model")
	model.Name = "AutoServer"
	local body = Build.Ball(model, "Body", Vector3.new(3.4, 3.4, 3.4), cf(0, 2.6, 0), C.Mint)
	model.PrimaryPart = body
	Build.Part(model, "Face", Vector3.new(2.2, 1.2, 0.3), cf(0, 3.1, -1.55), C.Ink)
	Build.Ball(model, "EyeL", Vector3.new(0.5, 0.5, 0.2), cf(-0.5, 3.15, -1.72), C.NeonPink, NEON)
	Build.Ball(model, "EyeR", Vector3.new(0.5, 0.5, 0.2), cf(0.5, 3.15, -1.72), C.NeonPink, NEON)
	Build.Cylinder(model, "Antenna", 0.2, 1, cf(0, 4.7, 0), C.Ink)
	Build.Ball(model, "AntennaTip", Vector3.new(0.6, 0.6, 0.6), cf(0, 5.3, 0), C.Mustard, NEON)
	Build.Ball(model, "ArmL", Vector3.new(0.7, 0.7, 1.4), cf(-1.8, 2.3, -0.6), C.MintDeep)
	Build.Ball(model, "ArmR", Vector3.new(0.7, 0.7, 1.4), cf(1.8, 2.3, -0.6), C.MintDeep)
	Build.Cylinder(model, "Tray", 3, 0.2, cf(0, 2.2, -2.2), C.Cream)
	Build.Cylinder(model, "TrayRim", 3.3, 0.12, cf(0, 2.1, -2.2), C.Mustard)
	Build.Ball(model, "Wheel", Vector3.new(1.4, 1.4, 1.4), cf(0, 0.7, 0), C.Ink)
	Build.Rig(model, true)
	return model
end

return PropBuilder

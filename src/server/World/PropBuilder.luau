--!strict
-- Station, food and bot props (Palette colors only). Owner: agent E.
-- Stations are built facing +Z (the player side) around a pivot at floor level: stainless cabinets with
-- a colored fascia, chunky hero tops and small details (knobs, handles, tools). Dishes and the bot can
-- use generated hero meshes from Config/Art (loaded in Start, cached); primitives are the fallback.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Config.Art)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local Build = require("./Build")
local Layout = require("./Layout")

local C = Palette.Color
local NEON = Enum.Material.Neon

local PropBuilder = {}

-- Names StationVisuals looks up inside a station / slot model.
PropBuilder.Visual = {
	Folder = "Visuals", -- Folder holding the hidden food parts
	Cue = "Worktop", -- the worktop rim turns neon for NeedsFlip / Burnt
	FX = "VisFX", -- Attachment (on the worktop) at the food: cook / burn / ding emitters
	Light = "StatusLight", -- PointLight on the worktop: cue, ready glow, burnt warning
}

local VA = Art.Attributes

local CAB_W, CAB_H, CAB_D = 8, 3.2, 5.5
local CAB_Y = 0.3 -- cabinet bottom (on top of the plinth)
local TOP_Y = CAB_Y + CAB_H
local WORK_Y = TOP_Y + 0.3 -- top of the worktop slab
local FRONT_Z = CAB_D / 2

local function cf(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- ── Generated mesh cache ─────────────────────────────────────────────────────

local meshCache: { [string]: MeshPart } = {}

local function loadMesh(key: string, spec: Art.MeshSpec)
	if spec.meshId == 0 then
		return
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(`rbxassetid://{spec.meshId}`))
	end)
	if not ok or typeof(result) ~= "Instance" or not result:IsA("MeshPart") then
		warn(`[PropBuilder] mesh {key} ({spec.meshId}) failed to load, using primitives: {result}`)
		return
	end
	local mesh = result :: MeshPart
	if spec.textureId ~= 0 then
		mesh.TextureContent = Content.fromUri(`rbxassetid://{spec.textureId}`)
	end
	local size = spec.size
	if size then
		mesh.Size = Vector3.new(size[1], size[2], size[3])
	end
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.Material = Enum.Material.SmoothPlastic
	meshCache[key] = mesh
end

-- A fresh clone of a loaded hero mesh, or nil (not configured, not loaded yet, or failed).
local function heroMesh(key: string, parent: Instance, name: string, at: CFrame): MeshPart?
	local template = meshCache[key]
	if not template then
		return nil
	end
	local mesh = template:Clone()
	mesh.Name = name
	mesh.CFrame = at
	mesh.Parent = parent
	return mesh
end

-- ── Stations ─────────────────────────────────────────────────────────────────

-- Shared base: plinth (PrimaryPart), stainless cabinet with two doors, worktop, colored fascia with
-- knobs, and the Interact part with the FX attachment. Returns the worktop.
local function baseStation(model: Model, fascia: Color3, knobCount: number, fxHeight: number): Part
	local plinth =
		Build.Part(model, "Plinth", Vector3.new(CAB_W - 0.4, CAB_Y, CAB_D - 0.4), cf(0, CAB_Y / 2, 0), C.Charcoal)
	model.PrimaryPart = plinth
	plinth.PivotOffset = CFrame.new(0, -CAB_Y / 2, 0) -- pivot at floor level
	Build.Part(model, "Cabinet", Vector3.new(CAB_W, CAB_H, CAB_D), cf(0, CAB_Y + CAB_H / 2, 0), C.Steel)
	local worktop = Build.Part(
		model,
		PropBuilder.Visual.Cue,
		Vector3.new(CAB_W + 0.3, 0.3, CAB_D + 0.3),
		cf(0, TOP_Y + 0.15, 0),
		C.Chrome
	)
	Build.Part(model, "Fascia", Vector3.new(CAB_W + 0.1, 0.9, 0.2), cf(0, TOP_Y - 0.5, FRONT_Z + 0.05), fascia)
	local doorW, doorH = CAB_W / 2 - 0.5, CAB_H - 1.6
	for _, side in { -1, 1 } do
		local x = side * (CAB_W / 4)
		Build.Part(
			model,
			"Door",
			Vector3.new(doorW, doorH, 0.12),
			cf(x, CAB_Y + 0.35 + doorH / 2, FRONT_Z + 0.06),
			C.Chrome
		)
	end
	-- One long handle bar across both doors
	Build.Rod(model, "Handle", 0.2, CAB_W - 1.5, cf(0, CAB_Y + 0.35 + doorH - 0.35, FRONT_Z + 0.25), C.SteelDark)
	for i = 1, knobCount do
		local x = (i - (knobCount + 1) / 2) * 1.5
		Build.Disc(model, "Knob", 0.55, 0.3, cf(x, TOP_Y - 0.5, FRONT_Z + 0.25), C.Charcoal)
	end

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
	return worktop
end

-- ── Cook-state food (hidden until StationVisuals shows it) ───────────────────

type FoodOpts = { afterFlip: boolean?, liquid: boolean?, shown: number?, burnt: Color3? }

-- Visuals folder plus the status light and the food-level FX attachment on the worktop.
local function visuals(model: Model, worktop: BasePart, foodAt: Vector3): Folder
	local folder = Instance.new("Folder")
	folder.Name = PropBuilder.Visual.Folder
	folder.Parent = model
	local fx = Instance.new("Attachment")
	fx.Name = PropBuilder.Visual.FX
	fx.Position = foodAt - worktop.Position -- the station is still unrotated at the origin here
	fx.Parent = worktop
	local light = Instance.new("PointLight")
	light.Name = PropBuilder.Visual.Light
	light.Enabled = false
	light.Shadows = false
	light.Parent = worktop
	return folder
end

-- Marks a part as station food: hidden, non-colliding, with its raw / cooked / burnt colors.
local function food(part: BasePart, raw: Color3, cooked: Color3, opts: FoodOpts?): BasePart
	local o: FoodOpts = opts or {}
	Build.Soft(part)
	part.Color = raw
	part.Transparency = 1
	part:SetAttribute(VA.Managed, true)
	part:SetAttribute(VA.RawColor, raw)
	part:SetAttribute(VA.CookedColor, cooked)
	part:SetAttribute(VA.BurntColor, o.burnt or C.Char)
	part:SetAttribute(VA.ShownTransparency, o.shown or 0)
	if o.afterFlip then
		part:SetAttribute(VA.AfterFlip, true)
	end
	if o.liquid then
		part:SetAttribute(VA.Liquid, true)
	end
	return part
end

-- Flat-top griddle: dark plate with steel splash guards, a spatula and a heat lamp. The griddle starts
-- clean; StationVisuals shows the patty (and the cheese after the flip).
local function makeGrill(model: Model)
	local worktop = baseStation(model, C.Ketchup, 3, WORK_Y + 0.6)
	local plateY = WORK_Y + 0.3 -- griddle surface
	Build.Part(model, "Griddle", Vector3.new(7.2, 0.3, 4.4), cf(0, WORK_Y + 0.15, 0.3), C.Charcoal)
	Build.Part(model, "Trough", Vector3.new(7.2, 0.25, 0.4), cf(0, WORK_Y + 0.12, FRONT_Z - 0.1), C.SteelDark)
	Build.Part(model, "Splash", Vector3.new(CAB_W, 1.8, 0.3), cf(0, WORK_Y + 0.9, -FRONT_Z + 0.15), C.Steel)
	for _, side in { -1, 1 } do
		-- Sloped side guards: high at the back, low at the front.
		Build.Wedge(
			model,
			"Guard",
			Vector3.new(0.3, 1.5, 4.6),
			cf(side * (CAB_W / 2 - 0.15), WORK_Y + 0.75, -0.2),
			C.Steel
		)
	end
	local folder = visuals(model, worktop, Vector3.new(0, plateY + 0.4, 0.4))
	food(
		Build.Cylinder(folder, "FoodPatty", 2.2, 0.42, cf(0, plateY + 0.21, 0.4), C.PattyRaw),
		C.PattyRaw,
		C.PattyCooked
	)
	food(
		Build.Part(
			folder,
			"FoodCheese",
			Vector3.new(1.7, 0.1, 1.7),
			cf(0, plateY + 0.47, 0.4) * CFrame.Angles(0, math.pi / 4, 0),
			C.Mustard
		),
		C.Mustard,
		C.MustardDeep,
		{ afterFlip = true }
	)
	-- Spatula resting on the right guard
	Build.Part(model, "SpatulaBlade", Vector3.new(1, 0.08, 0.9), cf(2.6, WORK_Y + 0.35, 1.4), C.Chrome)
	Build.Part(model, "SpatulaHandle", Vector3.new(0.25, 0.2, 1.6), cf(2.6, WORK_Y + 0.4, 2.5), C.WoodDark)
	-- Heat lamp bar on two posts (warm glow, always on)
	for _, side in { -1, 1 } do
		Build.Cylinder(model, "LampPost", 0.25, 2.2, cf(side * 3.6, WORK_Y + 1.8 + 1.1, -FRONT_Z + 0.2), C.SteelDark)
	end
	Build.Part(model, "LampHood", Vector3.new(7.6, 0.5, 1.2), cf(0, WORK_Y + 4.1, -FRONT_Z + 0.6), C.Steel)
	Build.Part(model, "LampGlow", Vector3.new(7, 0.1, 0.7), cf(0, WORK_Y + 3.82, -FRONT_Z + 0.6), C.Ember, NEON)
end

-- Twin fryer: oil vats in a steel rim, one basket dunked and one lifted (empty, draining), control panel
-- with a screen. StationVisuals shows the fries in the dunked basket.
local function makeFryer(model: Model)
	local worktop = baseStation(model, C.Mustard, 2, WORK_Y + 0.8)
	Build.Part(model, "VatRim", Vector3.new(7.2, 0.5, 4.4), cf(0, WORK_Y + 0.25, 0.3), C.SteelDark)
	for _, x in { -1.75, 1.75 } do
		Build.Part(model, "Oil", Vector3.new(3, 0.1, 3.6), cf(x, WORK_Y + 0.52, 0.3), C.MustardDeep)
	end
	-- Basket left: dunked (just its rim and handle show). Basket right: lifted and draining.
	Build.Part(model, "BasketDunked", Vector3.new(2.6, 0.3, 3), cf(-1.75, WORK_Y + 0.65, 0.3), C.Charcoal)
	Build.Part(model, "BasketLifted", Vector3.new(2.6, 1.1, 3), cf(1.75, WORK_Y + 1.6, -0.2), C.SteelDark)
	-- Two crossed piles read as a heap of fries poking out of the oil.
	local folder = visuals(model, worktop, Vector3.new(-1.75, WORK_Y + 1.1, 0.3))
	food(
		Build.Part(folder, "FoodFries", Vector3.new(2.2, 0.42, 2.6), cf(-1.75, WORK_Y + 0.86, 0.3), C.FriesRaw),
		C.FriesRaw,
		C.FriesGold
	)
	food(
		Build.Part(
			folder,
			"FoodFriesTop",
			Vector3.new(1.5, 0.34, 2),
			cf(-1.75, WORK_Y + 1.1, 0.25) * CFrame.Angles(0, 0.55, 0),
			C.FriesRaw
		),
		C.FriesRaw,
		C.FriesGold
	)
	for i, x in { -1.75, 1.75 } do
		local lift = if i == 2 then 1.1 else 0.2
		Build.Part(
			model,
			"BasketHandle",
			Vector3.new(0.3, 0.3, 2.4),
			cf(x, WORK_Y + 0.7 + lift, 2.6) * CFrame.Angles(0.35, 0, 0),
			C.Charcoal
		)
		Build.Part(
			model,
			"Grip",
			Vector3.new(0.4, 0.4, 0.9),
			cf(x, WORK_Y + 0.42 + lift, 3.55) * CFrame.Angles(0.35, 0, 0),
			C.Ketchup
		)
	end
	Build.Part(model, "Panel", Vector3.new(7.2, 1.8, 0.7), cf(0, WORK_Y + 0.9, -FRONT_Z + 0.35), C.Steel)
	local screen =
		Build.Part(model, "Screen", Vector3.new(1.8, 0.7, 0.1), cf(-2, WORK_Y + 1.2, -FRONT_Z + 0.72), C.Mint, NEON)
	screen.CastShadow = false
	Build.Disc(model, "Dial", 0.5, 0.2, cf(1.6, WORK_Y + 1.2, -FRONT_Z + 0.75), C.Charcoal)
	Build.Disc(model, "Dial", 0.5, 0.2, cf(2.6, WORK_Y + 1.2, -FRONT_Z + 0.75), C.Ketchup)
end

-- Wood-fired pizza oven: terracotta dome with a stone arch mouth, embers, a chimney, logs and a peel.
-- StationVisuals shows a pizza on the stone landing in front of the mouth.
local function makeOven(model: Model)
	local worktop = baseStation(model, C.Terracotta, 2, WORK_Y + 3.2)
	local domeY = WORK_Y + 0.2
	Build.Cylinder(model, "Collar", 6.4, 0.6, cf(0, WORK_Y + 0.3, -0.1), C.TerracottaDeep)
	Build.Ball(model, "Dome", Vector3.new(6, 6, 6), cf(0, domeY, -0.1), C.Terracotta)
	local mouthY, mouthZ = WORK_Y + 1.25, 2.55
	Build.Disc(model, "Arch", 3.4, 0.5, cf(0, mouthY, mouthZ), C.Linen)
	Build.Part(model, "ArchBase", Vector3.new(3.4, 1, 0.5), cf(0, WORK_Y + 0.5 + 0.1, mouthZ), C.Linen)
	Build.Disc(model, "Mouth", 2.5, 0.2, cf(0, mouthY, mouthZ + 0.2), C.Charcoal)
	Build.Part(model, "MouthBase", Vector3.new(2.5, 0.9, 0.2), cf(0, WORK_Y + 0.75, mouthZ + 0.2), C.Charcoal)
	local ember =
		Build.Part(model, "Embers", Vector3.new(1.8, 0.35, 0.1), cf(0, WORK_Y + 0.55, mouthZ + 0.32), C.Ember, NEON)
	ember.CastShadow = false
	local glow = Build.Light(ember, C.Ember, 8, 1.2)
	glow.Shadows = false
	-- Stone landing in front of the mouth, overhanging the worktop a little: the pizza rests here.
	local landingZ = mouthZ + 0.75
	Build.Part(model, "Hearth", Vector3.new(4, 0.3, 1.9), cf(0, WORK_Y + 0.15, landingZ), C.CreamShade)
	local folder = visuals(model, worktop, Vector3.new(0, WORK_Y + 0.6, landingZ))
	food(Build.Cylinder(folder, "FoodCrust", 2.1, 0.2, cf(0, WORK_Y + 0.4, landingZ), C.DoughRaw), C.DoughRaw, C.Bun)
	food(
		Build.Cylinder(folder, "FoodSauce", 1.75, 0.08, cf(0, WORK_Y + 0.53, landingZ), C.Ketchup),
		C.Ketchup,
		C.PizzaBaked
	)
	Build.Cylinder(model, "Chimney", 1, 2, cf(0, domeY + 3.6, -1.2), C.SteelDark)
	Build.Cylinder(model, "ChimneyCap", 1.5, 0.35, cf(0, domeY + 4.7, -1.2), C.Charcoal)
	-- Logs stacked on the right of the worktop
	for i, p in { Vector3.new(3.35, 0.3, 0.6), Vector3.new(3.35, 0.3, -0.6), Vector3.new(3.35, 0.85, 0) } do
		Build.Disc(model, "Log", 0.6, 2.6, cf(p.X, WORK_Y + p.Y, p.Z - 0.4), if i == 3 then C.Wood else C.WoodDark)
	end
	-- Pizza peel leaning on the left
	Build.Part(
		model,
		"PeelHandle",
		Vector3.new(0.25, 3.2, 0.25),
		cf(-3.5, WORK_Y + 1.6, 1) * CFrame.Angles(0.15, 0, 0.12),
		C.Wood
	)
	Build.Cylinder(model, "PeelBlade", 1.5, 0.12, cf(-3.35, WORK_Y + 0.15, 1.6), C.WoodLight)
end

-- Soda fountain: tall steel tower under a rounded mint lightbox, three taps with colored levers,
-- a drip tray grille, a cup stack and a cherry on top.
-- StationVisuals shows a clear cup under the middle nozzle that fills with soda.
local function makeSoda(model: Model)
	local worktop = baseStation(model, C.Mint, 0, WORK_Y + 1.2)
	Build.Part(model, "Tower", Vector3.new(6.4, 3.4, 2.2), cf(0, WORK_Y + 1.7, -1.3), C.Steel)
	Build.Pill(model, "Header", Vector3.new(7.2, 1.6, 2.6), cf(0, WORK_Y + 4.2, -1.2), C.Mint)
	local plate = Build.Part(model, "HeaderPlate", Vector3.new(5, 1.1, 0.1), cf(0, WORK_Y + 4.2, 0.12), C.MintDeep)
	Build.Text(plate, "SODA", C.Cream, Enum.NormalId.Back)
	Build.Part(model, "TapBar", Vector3.new(6, 0.6, 1.4), cf(0, WORK_Y + 2.6, -0.1), C.Chrome)
	for i, color in { C.Ketchup, C.Mustard, C.NeonPink } do
		local x = (i - 2) * 1.9
		Build.Cylinder(model, "Nozzle", 0.45, 0.6, cf(x, WORK_Y + 2.05, 0.3), C.SteelDark)
		Build.Part(
			model,
			"Lever",
			Vector3.new(0.5, 1, 0.35),
			cf(x, WORK_Y + 3.3, 0.35) * CFrame.Angles(-0.25, 0, 0),
			color
		)
	end
	Build.Part(model, "DripTray", Vector3.new(6, 0.25, 1.8), cf(0, WORK_Y + 0.12, 0.9), C.SteelDark)
	for i = 1, 4 do
		Build.Part(
			model,
			"Grille",
			Vector3.new(5.6, 0.06, 0.12),
			cf(0, WORK_Y + 0.27, 0.9 + (i - 2.5) * 0.4),
			C.Charcoal
		)
	end
	local trayTop = WORK_Y + 0.27
	local cupH, liquidH = 1.3, 1.1
	local folder = visuals(model, worktop, Vector3.new(0, trayTop + cupH, 0.35))
	food(
		Build.Cylinder(folder, "FoodCup", 1.15, cupH, cf(0, trayTop + cupH / 2, 0.35), C.MintPale, Build.Glass),
		C.MintPale,
		C.MintPale,
		{ shown = 0.45, burnt = C.MintPale }
	)
	food(
		Build.Cylinder(folder, "FoodLiquid", 0.95, liquidH, cf(0, trayTop + 0.08 + liquidH / 2, 0.35), C.SodaLiquid),
		C.SodaLiquid,
		C.SodaLiquid,
		{ liquid = true, burnt = C.SodaFlat }
	)
	-- Cup stack on the right edge
	Build.Cylinder(model, "Cups", 0.9, 1.6, cf(3.4, WORK_Y + 0.8, 1.6), C.CreamLight)
	Build.Cylinder(model, "CupBand", 0.95, 0.35, cf(3.4, WORK_Y + 1.2, 1.6), C.Ketchup)
	Build.Ball(model, "Cherry", Vector3.new(1.1, 1.1, 1.1), cf(0, WORK_Y + 5.5, -1.2), C.Ketchup)
	Build.Part(
		model,
		"Stem",
		Vector3.new(0.12, 0.9, 0.12),
		cf(0.2, WORK_Y + 6.3, -1.2) * CFrame.Angles(0, 0, -0.4),
		C.LeafDark
	)
end

local STATION_MAKERS: { [Types.StationId]: (Model) -> () } = {
	Grill = makeGrill,
	Fryer = makeFryer,
	Oven = makeOven,
	Soda = makeSoda,
}

-- ── Dishes ───────────────────────────────────────────────────────────────────
-- Built at the origin around a PrimaryPart, then rigged (unanchored, massless, welded).

local function plate(model: Model, diameter: number): Part
	local p = Build.Cylinder(model, "Plate", diameter, 0.15, cf(0, 0.075, 0), C.CreamLight)
	Build.Cylinder(model, "PlateRim", diameter + 0.2, 0.08, cf(0, 0.12, 0), C.MintPale)
	model.PrimaryPart = p
	return p
end

local function makeBurger(model: Model)
	plate(model, 3)
	if heroMesh("Burger", model, "Burger", cf(0, 1.1, 0)) then
		return
	end
	Build.Cylinder(model, "BunBottom", 2.1, 0.45, cf(0, 0.38, 0), C.Bun)
	Build.Cylinder(model, "Patty", 2.25, 0.42, cf(0, 0.8, 0), C.Patty)
	Build.Part(
		model,
		"Cheese",
		Vector3.new(1.9, 0.1, 1.9),
		cf(0, 1.05, 0) * CFrame.Angles(0, math.pi / 4, 0),
		C.Mustard
	)
	Build.Cylinder(model, "Lettuce", 2.35, 0.14, cf(0, 1.16, 0), C.Lettuce)
	Build.Cylinder(model, "Tomato", 2, 0.16, cf(0, 1.3, 0), C.Ketchup)
	Build.Ball(model, "BunTop", Vector3.new(2.2, 1.2, 2.2), cf(0, 1.55, 0), C.Bun)
	for i = 1, 5 do
		local a = i * 2 * math.pi / 5
		Build.Ball(
			model,
			"Seed",
			Vector3.new(0.18, 0.12, 0.25),
			cf(math.cos(a) * 0.55, 2.08, math.sin(a) * 0.55),
			C.CreamLight
		)
	end
end

local function makeFries(model: Model)
	if heroMesh("Fries", model, "Fries", cf(0, 1.2, 0)) then
		local base = Build.Marker(model, "Root", Vector3.new(1, 0.2, 1), cf(0, 0.1, 0))
		model.PrimaryPart = base
		return
	end
	local carton = Build.Part(model, "Carton", Vector3.new(1.7, 1.3, 1.05), cf(0, 0.65, 0), C.Ketchup)
	model.PrimaryPart = carton
	Build.Part(model, "CartonBand", Vector3.new(1.75, 0.3, 1.1), cf(0, 0.95, 0), C.CreamLight)
	for _, side in { -1, 1 } do
		Build.Wedge(
			model,
			"Flap",
			Vector3.new(1.7, 0.5, 0.1),
			cf(0, 1.55, side * 0.5) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0),
			C.Ketchup
		)
	end
	for i = 1, 7 do
		local x = (i - 4) * 0.22
		local z = if i % 2 == 0 then 0.18 else -0.18
		Build.Part(
			model,
			"Fry",
			Vector3.new(0.2, 1.2, 0.2),
			cf(x, 1.6 + (i % 3) * 0.1, z) * CFrame.Angles(z * 0.4, 0, (i - 4) * 0.1),
			if i % 2 == 0 then C.Mustard else C.MustardPale
		)
	end
end

local function makePizza(model: Model)
	local board = Build.Cylinder(model, "Board", 3.5, 0.2, cf(0, 0.1, 0), C.WoodLight)
	model.PrimaryPart = board
	Build.Part(model, "BoardHandle", Vector3.new(0.8, 0.2, 1), cf(0, 0.1, 2.1), C.WoodLight)
	if heroMesh("Pizza", model, "Pizza", cf(0, 0.45, 0)) then
		return
	end
	Build.Cylinder(model, "Crust", 3.1, 0.28, cf(0, 0.34, 0), C.Bun)
	Build.Cylinder(model, "Cheese", 2.65, 0.3, cf(0, 0.38, 0), C.MustardPale)
	for i = 1, 5 do
		local a = i * 2 * math.pi / 5 + 0.3
		Build.Cylinder(model, "Pepperoni", 0.55, 0.34, cf(math.cos(a) * 0.8, 0.4, math.sin(a) * 0.8), C.KetchupDeep)
	end
	for i = 1, 3 do
		local a = i * 2 * math.pi / 3 + 1
		Build.Ball(
			model,
			"Basil",
			Vector3.new(0.35, 0.12, 0.25),
			cf(math.cos(a) * 0.35, 0.55, math.sin(a) * 0.35),
			C.Leaf
		)
	end
end

local function makeDrink(model: Model)
	if heroMesh("Drink", model, "Drink", cf(0, 1.3, 0)) then
		local base = Build.Marker(model, "Root", Vector3.new(1, 0.2, 1), cf(0, 0.1, 0))
		model.PrimaryPart = base
		return
	end
	local cup = Build.Cylinder(model, "Cup", 1.3, 1.9, cf(0, 0.95, 0), C.CreamLight)
	model.PrimaryPart = cup
	Build.Cylinder(model, "Stripe", 1.34, 0.45, cf(0, 1.05, 0), C.Ketchup)
	Build.Cylinder(model, "Band", 1.34, 0.12, cf(0, 0.6, 0), C.Mustard)
	Build.Ball(model, "Lid", Vector3.new(1.4, 0.45, 1.4), cf(0, 1.92, 0), C.Chrome)
	Build.Cylinder(model, "Straw", 0.18, 1.4, cf(0.15, 2.6, 0) * CFrame.Angles(0, 0, -0.18), C.NeonPink)
	Build.Cylinder(model, "StrawTip", 0.18, 0.5, cf(0.5, 3.35, 0) * CFrame.Angles(0, 0, -1.2), C.NeonPink)
end

local DISH_MAKERS: { [Types.DishId]: (Model) -> () } = {
	Burger = makeBurger,
	Fries = makeFries,
	Pizza = makePizza,
	Drink = makeDrink,
}

-- ── Lifecycle ────────────────────────────────────────────────────────────────

function PropBuilder.Init() end

-- Loads the generated hero meshes (yields). Until a mesh is ready its prop uses primitives.
function PropBuilder.Start()
	for key, spec in Art.Meshes.Dishes do
		task.spawn(loadMesh, key, spec)
	end
	local bot = Art.Meshes.AutoServer
	if bot then
		task.spawn(loadMesh, "AutoServer", bot)
	end
end

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
	-- Pivot upright at the dish's base center (the PrimaryPart may be a rotated cylinder), so the dish
	-- sits level wherever it is pivoted (hand weld, counter).
	local root = model.PrimaryPart
	if root then
		root.PivotOffset = root.CFrame:Inverse()
	end
	model:SetAttribute("DishId", dishId)
	Build.Rig(model, false)
	return model
end

-- The auto-server robot (Humanoid-free): an egg-shaped waiter with a screen face, bow tie and tray.
-- Front faces -Z; the anchored body is the PrimaryPart.
function PropBuilder.MakeAutoServerBot(): Model
	local model = Instance.new("Model")
	model.Name = "AutoServer"
	local body = Build.Ball(model, "Body", Vector3.new(3, 3.2, 3), cf(0, 2.6, 0), C.Mint)
	model.PrimaryPart = body
	local mesh = heroMesh("AutoServer", model, "BotMesh", cf(0, 2.5, 0))
	if mesh then
		body.Transparency = 1
	else
		Build.Ball(model, "Belly", Vector3.new(2.2, 2.2, 1), cf(0, 2.3, -1.05), C.CreamLight)
		Build.Ball(model, "Head", Vector3.new(2.6, 2.2, 2.4), cf(0, 4.6, 0), C.CreamLight)
		Build.Part(model, "Screen", Vector3.new(1.9, 1.1, 0.3), cf(0, 4.65, -1.05), C.Charcoal)
		for _, x in { -0.45, 0.45 } do
			local eye = Build.Ball(model, "Eye", Vector3.new(0.35, 0.5, 0.2), cf(x, 4.75, -1.22), C.Mint, NEON)
			eye.CastShadow = false
		end
		Build.Part(model, "Smile", Vector3.new(0.6, 0.1, 0.2), cf(0, 4.35, -1.22), C.Mint, NEON)
		Build.Cylinder(model, "Antenna", 0.15, 0.8, cf(0, 6, 0), C.SteelDark)
		Build.Ball(model, "AntennaTip", Vector3.new(0.5, 0.5, 0.5), cf(0, 6.45, 0), C.Mustard, NEON)
		for _, side in { -1, 1 } do
			Build.Wedge(
				model,
				"Bow",
				Vector3.new(0.2, 0.5, 0.5),
				cf(side * 0.3, 3.75, -1.25) * CFrame.Angles(0, side * math.pi / 2, 0),
				C.Ketchup
			)
			Build.Ball(
				model,
				"Arm",
				Vector3.new(0.7, 0.7, 1.6),
				cf(side * 1.6, 2.6, -0.7) * CFrame.Angles(0.4, 0, 0),
				C.MintDeep
			)
		end
		Build.Ball(model, "Knot", Vector3.new(0.3, 0.3, 0.3), cf(0, 3.75, -1.3), C.KetchupDeep)
		Build.Cylinder(model, "Skirt", 2.2, 0.5, cf(0, 1.05, 0), C.Ink)
		Build.Ball(model, "Wheel", Vector3.new(1.2, 1.2, 1.2), cf(0, 0.6, 0), C.Charcoal)
	end
	Build.Cylinder(model, "Tray", 2.8, 0.15, cf(0, 2.9, -2.1), C.Chrome)
	Build.Cylinder(model, "TrayRim", 3, 0.1, cf(0, 2.82, -2.1), C.SteelDark)
	Build.Rig(model, true)
	return model
end

return PropBuilder

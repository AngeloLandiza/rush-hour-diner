--!strict
-- Cook-state visuals on the station props. Owner: agent E.
-- StationService sets WorldSchema.Attributes.StationPhase / StationQuality on every Slot_<k> model; this
-- module turns that into readable food on the prop: an empty station when Idle, raw food while Cooking, a
-- bouncing dish and a pulsing neon worktop rim at NeedsFlip, a color tween toward cooked (or a filling
-- cup) while Finishing, a golden glow with ding sparkles when Ready, and char, fire, smoke and a red
-- warning light when Burnt. Food parts are pre-built (hidden) by PropBuilder; nothing is created per
-- phase change except tweens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Art = require(ReplicatedStorage.Shared.Config.Art)
local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local Presets = require(ReplicatedStorage.Shared.VFX.Presets)
local MapBuilder = require("./MapBuilder")
local PropBuilder = require("./PropBuilder")

local C = Palette.Color
local A = WorldSchema.Attributes
local VA = Art.Attributes
local V = Art.StationVisuals
local NEON = Enum.Material.Neon
local SMOOTH = Enum.Material.SmoothPlastic

local StationVisuals = {}

type Food = {
	part: BasePart,
	raw: Color3,
	cooked: Color3,
	burnt: Color3,
	shown: number,
	afterFlip: boolean,
	liquid: boolean,
	baseCF: CFrame,
	baseSize: Vector3,
}

type Station = {
	slot: Model,
	stationId: Types.StationId,
	dish: Dishes.DishDef,
	plinth: BasePart?,
	cue: BasePart?,
	cueColor: Color3,
	cueMaterial: Enum.Material,
	light: PointLight?,
	emitters: { [string]: ParticleEmitter },
	foods: { Food },
	tweens: { Tween },
	phase: Types.StationPhase,
}

-- Emitters per station while cooking and when burnt (the soda fountain never catches fire).
local COOK_FX: { [Types.StationId]: { string } } = {
	Grill = { "Steam", "Sizzle" },
	Fryer = { "Steam", "Sizzle" },
	Oven = { "Steam" },
	Soda = {},
}
local BURN_FX: { [Types.StationId]: { string } } = {
	Grill = { "Fire", "Smoke" },
	Fryer = { "Fire", "Smoke" },
	Oven = { "Fire", "Smoke" },
	Soda = { "Smoke" },
}

local function fxFor(map: { [Types.StationId]: { string } }, id: Types.StationId): { string }
	return map[id] or {}
end

local VALID_PHASES: { [string]: boolean } = {
	Idle = true,
	Cooking = true,
	NeedsFlip = true,
	Finishing = true,
	Ready = true,
	Burnt = true,
}

local stations: { Station } = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function tween(st: Station, inst: Instance, info: TweenInfo, goal: { [string]: any })
	local t = TweenService:Create(inst, info, goal)
	table.insert(st.tweens, t)
	t:Play()
end

local function once(seconds: number): TweenInfo
	return TweenInfo.new(math.max(seconds, 0), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function loop(seconds: number, style: Enum.EasingStyle): TweenInfo
	return TweenInfo.new(seconds, style, Enum.EasingDirection.Out, -1, true)
end

-- Liquid level: the part is an upright Cylinder (its local X axis points up); keep the bottom fixed.
local function liquidGoal(food: Food, fraction: number): (Vector3, CFrame)
	local full = food.baseSize
	local h = math.max(full.X * fraction, 0.01)
	return Vector3.new(h, full.Y, full.Z), food.baseCF * CFrame.new(-(full.X - h) / 2, 0, 0)
end

local function setEmitters(st: Station, on: { string }, rateScale: number?)
	local wanted: { [string]: boolean } = {}
	for _, name in on do
		wanted[name] = true
	end
	for name, emitter in st.emitters do
		emitter.Enabled = wanted[name] == true
	end
	local ding = st.emitters.Ding
	if ding then
		ding.Rate = Presets.DefaultRate("Ding") * (rateScale or 1)
	end
end

local function setLight(st: Station, color: Color3?, spec: { range: number, brightness: number }?, brightness: number?)
	local light = st.light
	if not light then
		return
	end
	if not color or not spec then
		light.Enabled = false
		return
	end
	light.Color = color
	light.Range = spec.range
	light.Brightness = brightness or spec.brightness
	light.Enabled = true
end

-- The worktop rim as a neon cue (nil restores the stainless worktop).
local function setCue(st: Station, color: Color3?)
	local cue = st.cue
	if not cue then
		return
	end
	if color then
		cue.Material = NEON
		cue.Color = color
		tween(st, cue, loop(V.CuePulseSeconds, Enum.EasingStyle.Sine), { Color = C.CreamLight:Lerp(color, 0.35) })
	else
		cue.Material = st.cueMaterial
		cue.Color = st.cueColor
	end
end

local function isShown(st: Station): boolean
	local plinth = st.plinth
	return plinth == nil or plinth.Transparency < 1
end

-- ── Phases ───────────────────────────────────────────────────────────────────

local function apply(st: Station)
	for _, t in st.tweens do
		t:Cancel()
	end
	table.clear(st.tweens)

	local phase: Types.StationPhase = if isShown(st) then st.phase else "Idle"
	local quality = st.slot:GetAttribute(A.StationQuality)
	local flipped = phase == "Finishing" or phase == "Ready" or phase == "Burnt"

	-- Reset every food part to its resting pose, then show the ones this phase needs.
	for _, food in st.foods do
		local part = food.part
		part.CFrame = food.baseCF
		part.Size = food.baseSize
		local visible = phase ~= "Idle" and (flipped or not (food.afterFlip or food.liquid))
		part.Transparency = if visible then food.shown else 1
		if phase == "Burnt" then
			tween(st, part, once(V.BurnSeconds), { Color = food.burnt })
		elseif phase == "Ready" then
			part.Color = food.cooked
		elseif phase == "Finishing" then
			part.Color = food.raw:Lerp(food.cooked, V.FlipCookFraction)
			tween(st, part, once(st.dish.finishSeconds), { Color = food.cooked })
		elseif phase == "NeedsFlip" then
			part.Color = food.raw:Lerp(food.cooked, V.FlipCookFraction)
		else
			part.Color = food.raw
			if phase == "Cooking" then
				local partial = food.raw:Lerp(food.cooked, V.FlipCookFraction)
				tween(st, part, once(st.dish.cookSeconds), { Color = partial })
			end
		end
		if food.liquid and visible and phase == "Finishing" then
			local startSize, startCF = liquidGoal(food, V.LiquidStartFraction)
			part.Size = startSize
			part.CFrame = startCF
			local fullSize, fullCF = liquidGoal(food, 1)
			tween(st, part, once(st.dish.finishSeconds), { Size = fullSize, CFrame = fullCF })
		elseif visible and phase == "NeedsFlip" then
			local up = food.baseCF + Vector3.new(0, V.FlipBounceHeight, 0)
			tween(st, part, loop(V.FlipBounceSeconds, Enum.EasingStyle.Quad), { CFrame = up })
		elseif visible and phase == "Ready" then
			local up = food.baseCF + Vector3.new(0, V.ReadyBobHeight, 0)
			tween(st, part, loop(V.ReadyBobSeconds, Enum.EasingStyle.Sine), { CFrame = up })
		end
	end

	-- Station-level cues: worktop neon, status light, emitters.
	local cook = fxFor(COOK_FX, st.stationId)
	if phase == "Cooking" or phase == "Finishing" then
		setCue(st, nil)
		setLight(st, nil, nil)
		setEmitters(st, cook)
	elseif phase == "NeedsFlip" then
		setCue(st, C.Mustard)
		setLight(st, C.Mustard, V.CueLight)
		setEmitters(st, cook)
	elseif phase == "Ready" then
		local perfect = quality == "Perfect"
		setCue(st, nil)
		setLight(
			st,
			C.Mustard,
			V.ReadyLight,
			if perfect then V.ReadyLight.perfectBrightness else V.ReadyLight.brightness
		)
		setEmitters(st, { "Ding" }, if perfect then V.PerfectDingRateScale else 1)
		local fx = st.cue and st.cue:FindFirstChild(PropBuilder.Visual.FX)
		if fx then
			Presets.Burst("Ding", fx)
		end
	elseif phase == "Burnt" then
		setCue(st, C.Ketchup)
		setLight(st, C.Ketchup, V.WarnLight)
		setEmitters(st, fxFor(BURN_FX, st.stationId))
	else
		setCue(st, nil)
		setLight(st, nil, nil)
		setEmitters(st, {})
	end
end

local function readPhase(slot: Model): Types.StationPhase
	local value = slot:GetAttribute(A.StationPhase)
	if type(value) == "string" and VALID_PHASES[value] then
		return value :: any
	end
	return "Idle"
end

-- ── Setup ────────────────────────────────────────────────────────────────────

local function collectFoods(folder: Instance): { Food }
	local foods: { Food } = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(VA.Managed) == true then
			local raw = d:GetAttribute(VA.RawColor)
			local cooked = d:GetAttribute(VA.CookedColor)
			local burnt = d:GetAttribute(VA.BurntColor)
			local shown = d:GetAttribute(VA.ShownTransparency)
			table.insert(foods, {
				part = d,
				raw = if typeof(raw) == "Color3" then raw else d.Color,
				cooked = if typeof(cooked) == "Color3" then cooked else d.Color,
				burnt = if typeof(burnt) == "Color3" then burnt else C.Char,
				shown = if type(shown) == "number" then shown else 0,
				afterFlip = d:GetAttribute(VA.AfterFlip) == true,
				liquid = d:GetAttribute(VA.Liquid) == true,
				baseCF = d.CFrame,
				baseSize = d.Size,
			})
		end
	end
	return foods
end

local function setupSlot(slot: Model)
	local stationId = slot:GetAttribute(A.StationId)
	if type(stationId) ~= "string" then
		return
	end
	local def = Stations.Defs[stationId :: Types.StationId]
	local dish = def and Dishes.Defs[def.dishId]
	if not dish then
		return
	end
	local folder = slot:FindFirstChild(PropBuilder.Visual.Folder)
	local cueInst = slot:FindFirstChild(PropBuilder.Visual.Cue)
	local cue = if cueInst and cueInst:IsA("BasePart") then cueInst else nil
	local lightInst = cue and cue:FindFirstChild(PropBuilder.Visual.Light)
	local fx = cue and cue:FindFirstChild(PropBuilder.Visual.FX)
	local st: Station = {
		slot = slot,
		stationId = stationId :: Types.StationId,
		dish = dish,
		plinth = slot.PrimaryPart,
		cue = cue,
		cueColor = if cue then cue.Color else C.Chrome,
		cueMaterial = if cue then cue.Material else SMOOTH,
		light = if lightInst and lightInst:IsA("PointLight") then lightInst else nil,
		emitters = {},
		foods = if folder then collectFoods(folder) else {},
		tweens = {},
		phase = readPhase(slot),
	}
	if fx then
		local function create(name: string)
			if not st.emitters[name] then
				local emitter = Presets.Create(name :: any, fx) -- names come from the typed FX tables above
				emitter.Name = "Vis" .. name
				st.emitters[name] = emitter
			end
		end
		create("Ding")
		for _, name in fxFor(COOK_FX, st.stationId) do
			create(name)
		end
		for _, name in fxFor(BURN_FX, st.stationId) do
			create(name)
		end
	end
	table.insert(stations, st)

	slot:GetAttributeChangedSignal(A.StationPhase):Connect(function()
		local phase: Types.StationPhase = readPhase(slot)
		if phase ~= st.phase then
			st.phase = phase
			apply(st)
		end
	end)
	slot:GetAttributeChangedSignal(A.StationQuality):Connect(function()
		if st.phase == "Ready" then
			apply(st)
		end
	end)
	-- MapBuilder hides locked slots (slot 5) by making their parts transparent: follow the plinth.
	local plinth = st.plinth
	if plinth then
		local wasShown = isShown(st)
		plinth:GetPropertyChangedSignal("Transparency"):Connect(function()
			local shown = isShown(st)
			if shown ~= wasShown then
				wasShown = shown
				apply(st)
			end
		end)
	end
	apply(st)
end

function StationVisuals.Init()
	for plotId = 1, Timings.Plots.Count do
		local model = MapBuilder.GetPlotModel(plotId)
		local folder = model and model:FindFirstChild(WorldSchema.Parts.Stations)
		if folder then
			for _, slot in folder:GetChildren() do
				if slot:IsA("Model") then
					setupSlot(slot)
				end
			end
		end
	end
end

function StationVisuals.Start() end

return StationVisuals

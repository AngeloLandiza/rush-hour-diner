--!strict
-- ParticleEmitter presets: steam, sizzle, fire, smoke, ding, coin burst, tip explosion. Owner: agent E.
-- Used by the server (station FX) and the client FXController (coin burst / tip explosion).
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Palette = require("../Config/Palette")

local C = Palette.Color

local Presets = {}

export type PresetName =
	"Steam"
	| "Sizzle"
	| "Fire"
	| "Smoke"
	| "Ding"
	| "CoinBurst"
	| "TipExplosion"
	| "LegendarySparkle"

local TEX_SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"

-- Seconds the server keeps an emitter enabled to fake a burst (Emit() does not replicate from the server).
local SERVER_BURST_WINDOW = 0.15
local CLEANUP_PADDING = 0.5
local MAX_SCALE = 6

type Def = {
	texture: string,
	color: ColorSequence,
	size: { number }, -- start, end
	transparency: { number }, -- start, end
	lifetime: { number }, -- min, max
	speed: { number }, -- min, max
	spread: number,
	rate: number, -- continuous rate when enabled
	burst: number, -- particles emitted by Burst at scale 1
	acceleration: Vector3,
	lightEmission: number,
	drag: number,
	rotSpeed: { number },
}

local DEFS: { [PresetName]: Def } = {
	Steam = {
		texture = TEX_SMOKE,
		color = ColorSequence.new(C.White, C.Cream),
		size = { 1, 3.2 },
		transparency = { 0.5, 1 },
		lifetime = { 1.2, 2 },
		speed = { 3, 5 },
		spread = 18,
		rate = 8,
		burst = 8,
		acceleration = Vector3.new(0, 2, 0),
		lightEmission = 0.1,
		drag = 1,
		rotSpeed = { -40, 40 },
	},
	Sizzle = {
		texture = TEX_SPARKLES,
		color = ColorSequence.new(C.Mustard, C.Cream),
		size = { 0.35, 0 },
		transparency = { 0, 0.6 },
		lifetime = { 0.4, 0.8 },
		speed = { 4, 9 },
		spread = 40,
		rate = 22,
		burst = 10,
		acceleration = Vector3.new(0, -14, 0),
		lightEmission = 0.8,
		drag = 0,
		rotSpeed = { -180, 180 },
	},
	Fire = {
		texture = TEX_FIRE,
		color = ColorSequence.new(C.Mustard, C.Ketchup),
		size = { 1.4, 0 },
		transparency = { 0.1, 1 },
		lifetime = { 0.5, 0.9 },
		speed = { 2, 4 },
		spread = 12,
		rate = 24,
		burst = 14,
		acceleration = Vector3.new(0, 4, 0),
		lightEmission = 1,
		drag = 1,
		rotSpeed = { -90, 90 },
	},
	-- Thick dark smoke rising off burnt food.
	Smoke = {
		texture = TEX_SMOKE,
		color = ColorSequence.new(C.Smoke, C.Charcoal),
		size = { 1.2, 4 },
		transparency = { 0.25, 1 },
		lifetime = { 1.6, 2.6 },
		speed = { 2, 4 },
		spread = 15,
		rate = 10,
		burst = 10,
		acceleration = Vector3.new(0, 3, 0),
		lightEmission = 0,
		drag = 0.8,
		rotSpeed = { -30, 30 },
	},
	-- Gentle golden "ding" sparkles floating up off finished food.
	Ding = {
		texture = TEX_SPARKLES,
		color = ColorSequence.new(C.Mustard, C.CreamLight),
		size = { 0.5, 0 },
		transparency = { 0, 0.4 },
		lifetime = { 0.8, 1.3 },
		speed = { 1.5, 3 },
		spread = 35,
		rate = 7,
		burst = 16,
		acceleration = Vector3.new(0, 1, 0),
		lightEmission = 1,
		drag = 0.6,
		rotSpeed = { -120, 120 },
	},
	CoinBurst = {
		texture = TEX_SPARKLES,
		color = ColorSequence.new(C.Mustard, C.Cream),
		size = { 0.9, 0.2 },
		transparency = { 0, 0.8 },
		lifetime = { 0.6, 1 },
		speed = { 14, 24 },
		spread = 360,
		rate = 0,
		burst = 14,
		acceleration = Vector3.new(0, -40, 0),
		lightEmission = 0.9,
		drag = 1,
		rotSpeed = { -360, 360 },
	},
	TipExplosion = {
		texture = TEX_SPARKLES,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.Mustard),
			ColorSequenceKeypoint.new(0.5, C.NeonPink),
			ColorSequenceKeypoint.new(1, C.Mint),
		}),
		size = { 1.2, 0 },
		transparency = { 0, 0.7 },
		lifetime = { 0.8, 1.4 },
		speed = { 18, 38 },
		spread = 360,
		rate = 0,
		burst = 36,
		acceleration = Vector3.new(0, -28, 0),
		lightEmission = 1,
		drag = 1.5,
		rotSpeed = { -300, 300 },
	},
	LegendarySparkle = {
		texture = TEX_SPARKLES,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.NeonPink),
			ColorSequenceKeypoint.new(0.5, C.Mustard),
			ColorSequenceKeypoint.new(1, C.Cream),
		}),
		size = { 0.7, 0 },
		transparency = { 0, 0.5 },
		lifetime = { 1.2, 2 },
		speed = { 2, 6 },
		spread = 180,
		rate = 26,
		burst = 20,
		acceleration = Vector3.new(0, 1.5, 0),
		lightEmission = 1,
		drag = 0.5,
		rotSpeed = { -120, 120 },
	},
}

local function configure(emitter: ParticleEmitter, def: Def, scale: number)
	emitter.Texture = def.texture
	emitter.Color = def.color
	emitter.Size = NumberSequence.new(def.size[1] * scale, def.size[2] * scale)
	emitter.Transparency = NumberSequence.new(def.transparency[1], def.transparency[2])
	emitter.Lifetime = NumberRange.new(def.lifetime[1], def.lifetime[2])
	emitter.Speed = NumberRange.new(def.speed[1] * scale, def.speed[2] * scale)
	emitter.SpreadAngle = Vector2.new(def.spread, def.spread)
	emitter.Rate = def.rate
	emitter.Acceleration = def.acceleration
	emitter.LightEmission = def.lightEmission
	emitter.Drag = def.drag
	emitter.RotSpeed = NumberRange.new(def.rotSpeed[1], def.rotSpeed[2])
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.EmissionDirection = Enum.NormalId.Top
end

-- Create a configured emitter (Enabled = false) parented to `parent`.
function Presets.Create(name: PresetName, parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	configure(emitter, DEFS[name], 1)
	emitter.Parent = parent
	return emitter
end

-- The continuous emission rate a Create()d emitter of this preset uses when enabled.
function Presets.DefaultRate(name: PresetName): number
	return DEFS[name].rate
end

-- One-shot burst. scale (default 1) multiplies count, size and speed: a bigger tip is a bigger explosion.
-- The temporary emitter cleans itself up.
function Presets.Burst(name: PresetName, parent: Instance, scale: number?)
	local s = math.clamp(scale or 1, 0.1, MAX_SCALE)
	local def = DEFS[name]
	local count = math.max(1, math.round(def.burst * s))

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name .. "Burst"
	emitter.Enabled = false
	configure(emitter, def, s)
	emitter.Parent = parent

	if RunService:IsServer() then
		-- Server-side Emit() does not reach clients, but Enabled does: run the emitter briefly.
		emitter.Rate = count / SERVER_BURST_WINDOW
		emitter.Enabled = true
		task.delay(SERVER_BURST_WINDOW, function()
			emitter.Enabled = false
		end)
	else
		emitter:Emit(count)
	end
	Debris:AddItem(emitter, def.lifetime[2] + SERVER_BURST_WINDOW + CLEANUP_PADDING)
end

return Presets

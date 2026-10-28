--!strict
-- Future lighting, Atmosphere, ColorCorrection, Bloom; Day preset and the Rush Hour tween. Owner: agent E.
-- Listens to Events.RushHourStarted/Ended. Also lights the Art.Tags.RushNeon accents (signs, bulbs,
-- under-counter glow): Neon + light on in Rush, plain plastic with lights off by day.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Art = require(ReplicatedStorage.Shared.Config.Art)
local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local LightingConfig = require(ReplicatedStorage.Shared.Config.Lighting)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local LightingDirector = {}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect
local bloom: BloomEffect
local running: { Tween } = {}
local neonPreset: { Lit: boolean, LightScale: number } = { Lit = false, LightScale = 0 }

local function color(key: string): Color3
	local c = Palette.Color[key]
	assert(c, "unknown palette color " .. key)
	return c
end

local function getOrCreate<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing :: any
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst :: any
end

local function tweenOrSet(target: Instance, props: { [string]: any }, info: TweenInfo, instant: boolean)
	if instant then
		for k, v in props do
			(target :: any)[k] = v
		end
		return
	end
	local tween = TweenService:Create(target, info, props)
	table.insert(running, tween)
	tween:Play()
end

-- Apply the current neon state to one tagged part (and its lights).
local function applyNeon(inst: Instance, info: TweenInfo?)
	if not inst:IsA("BasePart") then
		return
	end
	inst.Material = if neonPreset.Lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local lit = inst:GetAttribute(Art.Attributes.LitBrightness)
	local target = (if type(lit) == "number" then lit else 1) * neonPreset.LightScale
	for _, child in inst:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = true
			if info then
				local tween = TweenService:Create(child, info, { Brightness = target })
				table.insert(running, tween)
				tween:Play()
			else
				child.Brightness = target
			end
		end
	end
end

function LightingDirector.Init()
	-- Only one Atmosphere can be active; drop leftovers (e.g. from a Studio template) so ours wins.
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") and child.Name ~= "DinerAtmosphere" then
			child:Destroy()
		end
	end
	atmosphere = getOrCreate("Atmosphere", "DinerAtmosphere")
	colorCorrection = getOrCreate("ColorCorrectionEffect", "DinerColorCorrection")
	bloom = getOrCreate("BloomEffect", "DinerBloom")
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = LightingConfig.GeographicLatitude
	CollectionService:GetInstanceAddedSignal(Art.Tags.RushNeon):Connect(function(inst)
		applyNeon(inst, nil)
	end)
	LightingDirector.Apply("Day", true)
	Events.RushHourStarted:Connect(function()
		LightingDirector.Apply("Rush")
	end)
	Events.RushHourEnded:Connect(function()
		LightingDirector.Apply("Day")
	end)
end

function LightingDirector.Start() end

-- Tween to a Config/Lighting preset ("Day" | "Rush"). instant = true snaps.
function LightingDirector.Apply(presetName: string, instant: boolean?)
	local preset = LightingConfig.Presets[presetName]
	if not preset then
		warn("LightingDirector: unknown preset " .. presetName)
		return
	end
	for _, tween in running do
		tween:Cancel()
	end
	table.clear(running)

	local snap = instant == true
	local info = TweenInfo.new(LightingConfig.TweenSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tweenOrSet(Lighting, {
		ClockTime = preset.ClockTime,
		Brightness = preset.Brightness,
		Ambient = color(preset.Ambient),
		OutdoorAmbient = color(preset.OutdoorAmbient),
		ExposureCompensation = preset.ExposureCompensation,
		EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
		ShadowSoftness = preset.ShadowSoftness,
	}, info, snap)
	tweenOrSet(atmosphere, {
		Density = preset.Atmosphere.Density,
		Haze = preset.Atmosphere.Haze,
		Glare = preset.Atmosphere.Glare,
		Color = color(preset.Atmosphere.Color),
		Decay = color(preset.Atmosphere.Decay),
	}, info, snap)
	tweenOrSet(colorCorrection, {
		Brightness = preset.ColorCorrection.Brightness,
		Contrast = preset.ColorCorrection.Contrast,
		Saturation = preset.ColorCorrection.Saturation,
		TintColor = color(preset.ColorCorrection.TintColor),
	}, info, snap)
	tweenOrSet(bloom, {
		Intensity = preset.Bloom.Intensity,
		Size = preset.Bloom.Size,
		Threshold = preset.Bloom.Threshold,
	}, info, snap)
	neonPreset = preset.Neon
	for _, inst in CollectionService:GetTagged(Art.Tags.RushNeon) do
		applyNeon(inst, if snap then nil else info)
	end
end

return LightingDirector

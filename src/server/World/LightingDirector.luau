--!strict
-- Future lighting, Atmosphere, ColorCorrection, Bloom; Day preset and the Rush Hour tween. Owner: agent E.
-- Listens to Events.RushHourStarted/Ended.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local LightingConfig = require(ReplicatedStorage.Shared.Config.Lighting)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local LightingDirector = {}

local atmosphere: Atmosphere
local colorCorrection: ColorCorrectionEffect
local bloom: BloomEffect
local running: { Tween } = {}

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

function LightingDirector.Init()
	atmosphere = getOrCreate("Atmosphere", "DinerAtmosphere")
	colorCorrection = getOrCreate("ColorCorrectionEffect", "DinerColorCorrection")
	bloom = getOrCreate("BloomEffect", "DinerBloom")
	Lighting.GlobalShadows = true
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
end

return LightingDirector

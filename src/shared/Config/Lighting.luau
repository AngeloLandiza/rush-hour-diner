--!strict
-- Lighting presets. Owner: agent E. Colors are Palette keys; LightingDirector converts them.
export type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: string,
	OutdoorAmbient: string,
	ExposureCompensation: number,
	Atmosphere: { Density: number, Haze: number, Glare: number, Color: string, Decay: string },
	ColorCorrection: { Brightness: number, Contrast: number, Saturation: number, TintColor: string },
	Bloom: { Intensity: number, Size: number, Threshold: number },
}

local Lighting = {
	TweenSeconds = 2.5,
	Presets = {
		Day = {
			ClockTime = 14,
			Brightness = 3,
			Ambient = "Cream",
			OutdoorAmbient = "Cream",
			ExposureCompensation = 0,
			Atmosphere = { Density = 0.3, Haze = 1, Glare = 0.2, Color = "Cream", Decay = "Mustard" },
			ColorCorrection = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.2, TintColor = "White" },
			Bloom = { Intensity = 0.4, Size = 24, Threshold = 1.5 },
		},
		Rush = {
			ClockTime = 19.5,
			Brightness = 2,
			Ambient = "NeonPink",
			OutdoorAmbient = "Ink",
			ExposureCompensation = 0.2,
			Atmosphere = { Density = 0.4, Haze = 2, Glare = 0.5, Color = "NeonPink", Decay = "Ink" },
			ColorCorrection = { Brightness = 0.05, Contrast = 0.3, Saturation = 0.6, TintColor = "White" },
			Bloom = { Intensity = 1, Size = 32, Threshold = 1 },
		},
	} :: { [string]: Preset },
}

return Lighting

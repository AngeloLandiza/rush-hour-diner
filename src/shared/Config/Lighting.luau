--!strict
-- Lighting presets. Owner: agent E. Colors are Palette keys; LightingDirector converts them.
-- Day: warm, soft afternoon sun with long-ish shadows. Rush: neon dusk; pink lives in the Atmosphere only.
export type Preset = {
	ClockTime: number,
	Brightness: number,
	Ambient: string,
	OutdoorAmbient: string,
	ExposureCompensation: number,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	ShadowSoftness: number,
	Atmosphere: { Density: number, Haze: number, Glare: number, Color: string, Decay: string },
	ColorCorrection: { Brightness: number, Contrast: number, Saturation: number, TintColor: string },
	Bloom: { Intensity: number, Size: number, Threshold: number },
	-- Accents tagged Art.Tags.RushNeon: Lit = Neon material (else SmoothPlastic), LightScale scales their lights.
	Neon: { Lit: boolean, LightScale: number },
}

local Lighting = {
	TweenSeconds = 2.5,
	GeographicLatitude = 30,
	Presets = {
		Day = {
			ClockTime = 15.3,
			Brightness = 2.6,
			Ambient = "DayAmbient",
			OutdoorAmbient = "DayOutdoor",
			ExposureCompensation = 0.1,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.35,
			ShadowSoftness = 0.25,
			Atmosphere = { Density = 0.22, Haze = 0.5, Glare = 0.1, Color = "SkyHaze", Decay = "SkyBlue" },
			ColorCorrection = { Brightness = 0, Contrast = 0.06, Saturation = 0.04, TintColor = "WarmTint" },
			Bloom = { Intensity = 0.3, Size = 22, Threshold = 1.9 },
			Neon = { Lit = false, LightScale = 0 },
		},
		Rush = {
			ClockTime = 19.8,
			Brightness = 3,
			Ambient = "Ink",
			OutdoorAmbient = "DuskViolet",
			ExposureCompensation = 0.35,
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.6,
			ShadowSoftness = 0.3,
			Atmosphere = { Density = 0.32, Haze = 1.6, Glare = 0.4, Color = "NeonPink", Decay = "NightInk" },
			ColorCorrection = { Brightness = 0.02, Contrast = 0.12, Saturation = 0.15, TintColor = "PinkGlow" },
			Bloom = { Intensity = 0.55, Size = 26, Threshold = 1.4 },
			Neon = { Lit = true, LightScale = 0.45 },
		},
	} :: { [string]: Preset },
}

return Lighting

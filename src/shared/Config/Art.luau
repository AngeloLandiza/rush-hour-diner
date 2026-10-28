--!strict
-- World art config: CollectionService tags, attribute names and generated hero mesh ids. Owner: agent E.
-- Mesh ids are Roblox asset ids (numbers) produced by Studio's own generation tools. 0 = not generated:
-- PropBuilder then uses the primitive-built prop. Never put Creator Store / Toolbox assets here.
export type MeshSpec = {
	meshId: number, -- MeshPart asset id
	textureId: number, -- 0 = no texture (keep the MeshPart color)
	size: { number }?, -- target size in studs {x, y, z} (nil = native size)
}

local Art = {
	Tags = {
		-- Neon accents that light up during Rush Hour (LightingDirector toggles them).
		RushNeon = "RushNeon",
	},
	Attributes = {
		-- On RushNeon parts: the light's brightness at full Rush (lights are children of the part).
		LitBrightness = "LitBrightness",
		-- On station food parts (PropBuilder builds them hidden; World/StationVisuals drives them).
		-- MapBuilder's slot show/hide skips Managed parts: StationVisuals owns their visibility.
		Managed = "VisManaged",
		RawColor = "VisRaw", -- Color3 while raw (Cooking)
		CookedColor = "VisCooked", -- Color3 when done (Ready)
		BurntColor = "VisBurnt", -- Color3 when Burnt
		ShownTransparency = "VisShown", -- Transparency while shown (glass cup < 1)
		AfterFlip = "VisAfterFlip", -- true: appears only after the flip (cheese)
		Liquid = "VisLiquid", -- true: fills (height tween) during Finishing
	},
	-- World/StationVisuals timings and looks (seconds, studs, light units).
	StationVisuals = {
		FlipCookFraction = 0.35, -- how far raw → cooked the food gets before the flip
		FlipBounceHeight = 0.45,
		FlipBounceSeconds = 0.22,
		CuePulseSeconds = 0.3, -- worktop neon pulse while NeedsFlip / Burnt
		ReadyBobHeight = 0.18,
		ReadyBobSeconds = 0.9,
		BurnSeconds = 0.6, -- color tween to char
		LiquidStartFraction = 0.08,
		CueLight = { range = 9, brightness = 1.6 },
		ReadyLight = { range = 9, brightness = 2, perfectBrightness = 3.2 },
		WarnLight = { range = 7, brightness = 1.5 }, -- a red glow on this station only
		PerfectDingRateScale = 2,
	},
	-- Generated hero meshes (station, dish and bot props). Keys match Types.StationId / Types.DishId.
	-- Generated with Studio's generate_mesh (textured MeshParts published to the place owner's inventory).
	Meshes = {
		Stations = {} :: { [string]: MeshSpec },
		Dishes = {
			Burger = { meshId = 77006481648183, textureId = 138328360184664, size = { 2.4, 1.94, 2.4 } },
			Fries = { meshId = 108047426108695, textureId = 77125399013537, size = { 1.8, 2.33, 1.16 } },
			Pizza = { meshId = 86392333835592, textureId = 130239030854367, size = { 3.2, 0.51, 3.2 } },
			Drink = { meshId = 92423574798934, textureId = 119214228211114, size = { 1.4, 2.56, 1.37 } },
		} :: { [string]: MeshSpec },
		AutoServer = { meshId = 71726394278691, textureId = 117040127936581, size = { 4.2, 5, 3.4 } } :: MeshSpec?,
	},
	-- Seconds PropBuilder waits for one mesh load before falling back to primitives.
	MeshLoadTimeout = 10,
}

return Art

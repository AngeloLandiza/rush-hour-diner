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

--!strict
-- Customer kinds, legendary customers and code-built looks. Data only. Owner: agent B (numbers).
-- The WeeklyMeme legendary is driven entirely by this table: edit it for each weekly content drop.
-- Colors are Palette keys (Config/Palette), never raw values.
local Types = require("../Contracts/Types")

export type KindDef = {
	kind: Types.CustomerKind,
	displayName: string,
	spawnWeight: number, -- relative weight among non-legendary spawns
	payMultiplier: number,
	patienceMultiplier: number,
}

export type LegendaryDef = {
	id: Types.LegendaryId,
	displayName: string,
	announcement: string, -- "{owner}" is replaced with the plot owner's name
	payMultiplier: number,
	tipBonus: number, -- extra tip fraction added on top of the normal tip
	patienceMultiplier: number,
	scale: number, -- character scale (Giant Chef is big)
	bodyColor: string, -- Palette key
	accentColor: string, -- Palette key
	favoriteDish: Types.DishId?, -- always orders this if set
	costume: string?, -- key of Customers.Looks.Costumes (the code-built signature look)
	enabled: boolean,
}

-- ── Appearance (code-built looks, no catalog assets) ────────────────────────
-- Colors are Palette keys or one of the per-customer tokens "$skin", "$shirt", "$pants", "$shoes",
-- "$accent" (the outfit's accent) and "$hair". Geometry is in studs at character scale 1; the model is
-- scaled afterwards, so legendary looks grow with the character.
export type PartShape = "Block" | "Ball" | "Cylinder" | "Ellipsoid" -- Cylinder axis is the part's X
export type PartSpec = {
	attach: string, -- R15 body part the piece is welded to ("Head", "UpperTorso", "RightHand", ...)
	shape: PartShape,
	size: { number }, -- {x, y, z}; Ball sizes must be uniform
	anchor: { number }?, -- point on the host's box, as a fraction of its half-size per axis (-Z is the front)
	offset: { number }?, -- studs from the anchor, in the host's space
	rotation: { number }?, -- degrees about X, Y, Z
	color: string,
	neon: boolean?,
	reflectance: number?,
	transparency: number?,
}
export type BodyColorSpec = {
	skin: string,
	shirt: string,
	pants: string,
	shoes: string,
	longSleeves: boolean,
}
export type AccessorySlot = "Hat" | "Face" | "Hair"
export type AccessoryDef = { id: string, slot: AccessorySlot, parts: { PartSpec } }
export type OutfitCombo = { shirt: string, pants: string, shoes: string, accent: string }
export type CostumeDef = {
	bodyColors: BodyColorSpec,
	glow: string, -- Palette key of the legendary's PointLight
	parts: { PartSpec },
}
export type EmitterSpec = {
	texture: string,
	colors: { string }, -- Palette keys, evenly spaced along the particle lifetime
	size: { number }, -- start, end
	transparency: { number }, -- start, end
	lifetime: { number }, -- min, max
	speed: { number }, -- min, max
	spread: number,
	rate: number,
	lightEmission: number,
	acceleration: { number },
}

local ACCESSORIES: { AccessoryDef } = {
	{
		id = "BaseballCap",
		slot = "Hat",
		parts = {
			{
				attach = "Head",
				shape = "Ellipsoid",
				size = { 1.3, 0.8, 1.3 },
				anchor = { 0, 1, 0 },
				offset = { 0, -0.12, 0 },
				color = "$accent",
			},
			{
				attach = "Head",
				shape = "Block",
				size = { 0.9, 0.07, 0.55 },
				anchor = { 0, 1, -1 },
				offset = { 0, -0.2, -0.2 },
				color = "$accent",
			},
		},
	},
	{
		id = "Beanie",
		slot = "Hat",
		parts = {
			{
				attach = "Head",
				shape = "Ellipsoid",
				size = { 1.32, 1, 1.32 },
				anchor = { 0, 1, 0 },
				offset = { 0, -0.15, 0 },
				color = "$accent",
			},
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.25, 1.36, 1.36 },
				anchor = { 0, 1, 0 },
				offset = { 0, -0.3, 0 },
				rotation = { 0, 0, 90 },
				color = "$shirt",
			},
			{
				attach = "Head",
				shape = "Ball",
				size = { 0.36, 0.36, 0.36 },
				anchor = { 0, 1, 0 },
				offset = { 0, 0.4, 0 },
				color = "$shirt",
			},
		},
	},
	{
		id = "BucketHat",
		slot = "Hat",
		parts = {
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.5, 1.3, 1.3 },
				anchor = { 0, 1, 0 },
				offset = { 0, 0, 0 },
				rotation = { 0, 0, 90 },
				color = "$accent",
			},
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.07, 1.9, 1.9 },
				anchor = { 0, 1, 0 },
				offset = { 0, -0.22, 0 },
				rotation = { 0, 0, 90 },
				color = "$accent",
			},
		},
	},
	{
		id = "Headphones",
		slot = "Hat",
		parts = {
			{
				attach = "Head",
				shape = "Block",
				size = { 1.42, 0.14, 0.24 },
				anchor = { 0, 1, 0 },
				offset = { 0, 0.06, 0 },
				color = "Charcoal",
			},
			{
				attach = "Head",
				shape = "Block",
				size = { 0.1, 0.5, 0.18 },
				anchor = { 1, 0, 0 },
				offset = { 0.06, 0.42, 0 },
				color = "Charcoal",
			},
			{
				attach = "Head",
				shape = "Block",
				size = { 0.1, 0.5, 0.18 },
				anchor = { -1, 0, 0 },
				offset = { -0.06, 0.42, 0 },
				color = "Charcoal",
			},
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.22, 0.62, 0.62 },
				anchor = { 1, 0, 0 },
				offset = { 0.1, 0.08, 0 },
				color = "$accent",
			},
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.22, 0.62, 0.62 },
				anchor = { -1, 0, 0 },
				offset = { -0.1, 0.08, 0 },
				color = "$accent",
			},
		},
	},
	{
		id = "RoundGlasses",
		slot = "Face",
		parts = {
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.06, 0.42, 0.42 },
				anchor = { 0, 0, -1 },
				offset = { 0.24, 0.12, -0.03 },
				rotation = { 0, 90, 0 },
				color = "Ink",
				transparency = 0.35,
			},
			{
				attach = "Head",
				shape = "Cylinder",
				size = { 0.06, 0.42, 0.42 },
				anchor = { 0, 0, -1 },
				offset = { -0.24, 0.12, -0.03 },
				rotation = { 0, 90, 0 },
				color = "Ink",
				transparency = 0.35,
			},
			{
				attach = "Head",
				shape = "Block",
				size = { 0.1, 0.05, 0.05 },
				anchor = { 0, 0, -1 },
				offset = { 0, 0.15, -0.03 },
				color = "Charcoal",
			},
		},
	},
	{
		id = "Bow",
		slot = "Hair",
		parts = {
			{
				attach = "Head",
				shape = "Ellipsoid",
				size = { 0.45, 0.34, 0.18 },
				anchor = { 0.5, 1, 0 },
				offset = { 0.22, 0.05, 0 },
				rotation = { 0, 0, -15 },
				color = "$accent",
			},
			{
				attach = "Head",
				shape = "Ellipsoid",
				size = { 0.45, 0.34, 0.18 },
				anchor = { 0.5, 1, 0 },
				offset = { -0.22, 0.05, 0 },
				rotation = { 0, 0, 15 },
				color = "$accent",
			},
			{
				attach = "Head",
				shape = "Ball",
				size = { 0.2, 0.2, 0.2 },
				anchor = { 0.5, 1, 0 },
				offset = { 0, 0.05, 0 },
				color = "$shirt",
			},
		},
	},
	{
		id = "HairPuff",
		slot = "Hair",
		parts = {
			{
				attach = "Head",
				shape = "Ball",
				size = { 1.15, 1.15, 1.15 },
				anchor = { 0, 1, 0.3 },
				offset = { 0, 0.05, 0.05 },
				color = "$hair",
			},
		},
	},
	{
		id = "HairBun",
		slot = "Hair",
		parts = {
			{
				attach = "Head",
				shape = "Ellipsoid",
				size = { 1.28, 0.7, 1.3 },
				anchor = { 0, 1, 0 },
				offset = { 0, -0.12, 0.04 },
				color = "$hair",
			},
			{
				attach = "Head",
				shape = "Ball",
				size = { 0.6, 0.6, 0.6 },
				anchor = { 0, 1, 0.7 },
				offset = { 0, 0.05, 0.1 },
				color = "$hair",
			},
		},
	},
}

-- Curated shirt / pants / shoes / accent combos (Palette keys).
local OUTFITS: { OutfitCombo } = {
	{ shirt = "Ketchup", pants = "Ink", shoes = "White", accent = "Mustard" },
	{ shirt = "Mint", pants = "InkSoft", shoes = "Cream", accent = "Ketchup" },
	{ shirt = "Mustard", pants = "Slate", shoes = "Charcoal", accent = "Ink" },
	{ shirt = "KetchupSoft", pants = "Ink", shoes = "White", accent = "Mint" },
	{ shirt = "InkSoft", pants = "Sand", shoes = "WoodDark", accent = "Mustard" },
	{ shirt = "MintDeep", pants = "Charcoal", shoes = "White", accent = "NeonPink" },
	{ shirt = "MustardPale", pants = "MintDeep", shoes = "Ink", accent = "Ketchup" },
	{ shirt = "Cream", pants = "KetchupDeep", shoes = "Charcoal", accent = "Ink" },
	{ shirt = "Leaf", pants = "Asphalt", shoes = "Cream", accent = "Mustard" },
	{ shirt = "SkyBlue", pants = "Ink", shoes = "White", accent = "Ketchup" },
	{ shirt = "KetchupPale", pants = "SteelDark", shoes = "KetchupDeep", accent = "Mint" },
	{ shirt = "Terracotta", pants = "Ink", shoes = "Cream", accent = "MintPale" },
	{ shirt = "DuskViolet", pants = "Charcoal", shoes = "Mustard", accent = "Mustard" },
	{ shirt = "MintPale", pants = "Slate", shoes = "Ink", accent = "NeonPink" },
	{ shirt = "White", pants = "WoodDark", shoes = "Charcoal", accent = "Ketchup" },
	{ shirt = "PinkGlow", pants = "InkSoft", shoes = "White", accent = "Ketchup" },
}

export type LooksDef = {
	MaxExtraParts: number,
	AccessoryChance: number,
	ShortSleeveChance: number,
	SkinTones: { string },
	HairColors: { string },
	Outfits: { OutfitCombo },
	Accessories: { AccessoryDef },
	FaceTexture: string,
	VIP: { blocksSlot: AccessorySlot, parts: { PartSpec } },
	Hungry: { parts: { PartSpec }, rumbleAttach: string, rumble: EmitterSpec },
	Legendary: {
		auraAttach: string,
		auraRate: number,
		lightAttach: string,
		lightBrightness: number,
		lightRange: number,
	},
	Costumes: { [string]: CostumeDef },
}

local LOOKS: LooksDef = {
	-- Max parts a look may add to the rig (accessory + kind cue, or a legendary costume).
	MaxExtraParts = 12,
	-- Chance a non-legendary customer gets one random accessory from Accessories.
	AccessoryChance = 0.7,
	ShortSleeveChance = 0.5,
	-- Light to deep.
	SkinTones = { "SkinPorcelain", "SkinLight", "SkinTan", "SkinMedium", "SkinBrown", "SkinDeep" },
	HairColors = { "Charcoal", "WoodDark", "Patty", "MustardDeep", "TerracottaDeep", "Ink", "KetchupDeep" },
	Outfits = OUTFITS,
	Accessories = ACCESSORIES,
	-- Default face for the code-built rig (built-in engine content).
	FaceTexture = "rbxasset://textures/face.png",

	-- VIPs: gold sunglasses plus a gold sash. Occupies the Face slot (no other glasses).
	VIP = {
		blocksSlot = "Face",
		parts = {
			{
				attach = "Head",
				shape = "Block",
				size = { 0.42, 0.26, 0.06 },
				anchor = { 0, 0, -1 },
				offset = { 0.24, 0.12, -0.03 },
				color = "MustardDeep",
				reflectance = 0.5,
			},
			{
				attach = "Head",
				shape = "Block",
				size = { 0.42, 0.26, 0.06 },
				anchor = { 0, 0, -1 },
				offset = { -0.24, 0.12, -0.03 },
				color = "MustardDeep",
				reflectance = 0.5,
			},
			{
				attach = "Head",
				shape = "Block",
				size = { 0.14, 0.06, 0.05 },
				anchor = { 0, 0, -1 },
				offset = { 0, 0.16, -0.03 },
				color = "Mustard",
				reflectance = 0.3,
			},
			{
				attach = "UpperTorso",
				shape = "Block",
				size = { 0.32, 2.3, 1.12 },
				rotation = { 0, 0, 40 },
				color = "Mustard",
				reflectance = 0.2,
			},
		},
	},

	-- Hungry customers: a drool drop and a rumbling-tummy twinkle.
	Hungry = {
		parts = {
			{
				attach = "Head",
				shape = "Ellipsoid",
				size = { 0.12, 0.2, 0.12 },
				anchor = { 0, 0, -1 },
				offset = { 0.18, -0.32, -0.02 },
				color = "MintPale",
				transparency = 0.2,
			},
		},
		rumbleAttach = "LowerTorso",
		rumble = {
			texture = "rbxasset://textures/particles/sparkles_main.dds",
			colors = { "Mustard", "Ketchup" },
			size = { 0.35, 0 },
			transparency = { 0, 0.4 },
			lifetime = { 0.4, 0.8 },
			speed = { 1.5, 3 },
			spread = 50,
			rate = 5,
			lightEmission = 0.3,
			acceleration = { 0, 2, 0 },
		},
	},

	-- Every legendary: a subtle LegendarySparkle aura plus a PointLight in its costume glow color.
	Legendary = {
		auraAttach = "UpperTorso",
		auraRate = 8, -- particles/s (the preset's own rate is for one-shot bursts)
		lightAttach = "UpperTorso",
		lightBrightness = 1.5,
		lightRange = 10, -- studs at scale 1
	},

	Costumes = {
		GiantChef = {
			bodyColors = { skin = "Peach", shirt = "White", pants = "Slate", shoes = "Charcoal", longSleeves = true },
			glow = "Mustard",
			parts = {
				-- Tall puffy chef hat
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.35, 1.32, 1.32 },
					anchor = { 0, 1, 0 },
					offset = { 0, 0.02, 0 },
					rotation = { 0, 0, 90 },
					color = "White",
				},
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 1.1, 1.4, 1.4 },
					anchor = { 0, 1, 0 },
					offset = { 0, 0.7, 0 },
					rotation = { 0, 0, 90 },
					color = "White",
				},
				{
					attach = "Head",
					shape = "Ball",
					size = { 1.8, 1.8, 1.8 },
					anchor = { 0, 1, 0 },
					offset = { 0, 1.5, 0 },
					color = "White",
				},
				{
					attach = "Head",
					shape = "Ball",
					size = { 1.3, 1.3, 1.3 },
					anchor = { 0, 1, 0 },
					offset = { -0.5, 1.3, 0.2 },
					color = "CreamLight",
				},
				-- Cream double-breasted apron with ketchup buttons
				{
					attach = "UpperTorso",
					shape = "Block",
					size = { 1.7, 2, 0.1 },
					anchor = { 0, 0, -1 },
					offset = { 0, -0.3, -0.05 },
					color = "Cream",
				},
				{
					attach = "UpperTorso",
					shape = "Ball",
					size = { 0.22, 0.22, 0.22 },
					anchor = { 0, 0, -1 },
					offset = { 0.35, 0.35, -0.12 },
					color = "Ketchup",
				},
				{
					attach = "UpperTorso",
					shape = "Ball",
					size = { 0.22, 0.22, 0.22 },
					anchor = { 0, 0, -1 },
					offset = { -0.35, 0.35, -0.12 },
					color = "Ketchup",
				},
				{
					attach = "UpperTorso",
					shape = "Ball",
					size = { 0.22, 0.22, 0.22 },
					anchor = { 0, 0, -1 },
					offset = { 0.35, -0.15, -0.12 },
					color = "Ketchup",
				},
				{
					attach = "UpperTorso",
					shape = "Ball",
					size = { 0.22, 0.22, 0.22 },
					anchor = { 0, 0, -1 },
					offset = { -0.35, -0.15, -0.12 },
					color = "Ketchup",
				},
				-- Mustache
				{
					attach = "Head",
					shape = "Ellipsoid",
					size = { 0.85, 0.2, 0.25 },
					anchor = { 0, 0, -1 },
					offset = { 0, -0.18, -0.05 },
					color = "WoodDark",
				},
				-- Rolling pin in hand
				{
					attach = "RightHand",
					shape = "Cylinder",
					size = { 2, 0.32, 0.32 },
					anchor = { 0, -1, 0 },
					offset = { 0, 0, -0.2 },
					rotation = { 0, 90, 0 },
					color = "Wood",
				},
			},
		},
		SpaceAlien = {
			bodyColors = { skin = "Mint", shirt = "MintDeep", pants = "MintDeep", shoes = "Ink", longSleeves = false },
			glow = "NeonPink",
			parts = {
				-- Dark glossy wraparound visor
				{
					attach = "Head",
					shape = "Ellipsoid",
					size = { 1.3, 0.42, 0.7 },
					anchor = { 0, 0, -1 },
					offset = { 0, 0.1, 0.2 },
					color = "NightInk",
					reflectance = 0.5,
				},
				-- Antennae with glowing tips
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.9, 0.09, 0.09 },
					anchor = { 0, 1, 0 },
					offset = { 0.44, 0.38, 0 },
					rotation = { 0, 0, 65 },
					color = "MintDeep",
				},
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.9, 0.09, 0.09 },
					anchor = { 0, 1, 0 },
					offset = { -0.44, 0.38, 0 },
					rotation = { 0, 0, 115 },
					color = "MintDeep",
				},
				{
					attach = "Head",
					shape = "Ball",
					size = { 0.32, 0.32, 0.32 },
					anchor = { 0, 1, 0 },
					offset = { 0.63, 0.8, 0 },
					color = "NeonPink",
					neon = true,
				},
				{
					attach = "Head",
					shape = "Ball",
					size = { 0.32, 0.32, 0.32 },
					anchor = { 0, 1, 0 },
					offset = { -0.63, 0.8, 0 },
					color = "NeonPink",
					neon = true,
				},
				-- Floating UFO halo: a neon ring with a little glass dome
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.08, 1.8, 1.8 },
					anchor = { 0, 1, 0 },
					offset = { 0, 1.3, 0 },
					rotation = { 0, 0, 90 },
					color = "NeonPink",
					neon = true,
				},
				{
					attach = "Head",
					shape = "Ellipsoid",
					size = { 0.9, 0.45, 0.9 },
					anchor = { 0, 1, 0 },
					offset = { 0, 1.42, 0 },
					color = "MintPale",
					transparency = 0.2,
				},
				-- Glowing chest core
				{
					attach = "UpperTorso",
					shape = "Ball",
					size = { 0.4, 0.4, 0.4 },
					anchor = { 0, 0, -1 },
					offset = { 0, 0.25, -0.05 },
					color = "NeonPink",
					neon = true,
				},
			},
		},
		SirSandwich = {
			bodyColors = {
				skin = "Peach",
				shirt = "MustardPale",
				pants = "Ink",
				shoes = "Charcoal",
				longSleeves = true,
			},
			glow = "Mustard",
			parts = {
				-- Bread slices front and back, each with a domed crust top
				{
					attach = "UpperTorso",
					shape = "Block",
					size = { 2.1, 2.2, 0.3 },
					anchor = { 0, 0, -1 },
					offset = { 0, -0.35, -0.2 },
					color = "BunLight",
				},
				{
					attach = "UpperTorso",
					shape = "Ellipsoid",
					size = { 2.1, 0.6, 0.3 },
					anchor = { 0, 0, -1 },
					offset = { 0, 0.75, -0.2 },
					color = "Bun",
				},
				{
					attach = "UpperTorso",
					shape = "Block",
					size = { 2.1, 2.2, 0.3 },
					anchor = { 0, 0, 1 },
					offset = { 0, -0.35, 0.2 },
					color = "BunLight",
				},
				{
					attach = "UpperTorso",
					shape = "Ellipsoid",
					size = { 2.1, 0.6, 0.3 },
					anchor = { 0, 0, 1 },
					offset = { 0, 0.75, 0.2 },
					color = "Bun",
				},
				-- Lettuce trim peeking out between body and bread
				{
					attach = "UpperTorso",
					shape = "Block",
					size = { 2.3, 2.4, 0.12 },
					anchor = { 0, 0, -1 },
					offset = { 0, -0.35, -0.04 },
					color = "Lettuce",
				},
				{
					attach = "UpperTorso",
					shape = "Block",
					size = { 2.3, 2.4, 0.12 },
					anchor = { 0, 0, 1 },
					offset = { 0, -0.35, 0.04 },
					color = "Lettuce",
				},
				-- Cheese-slice cape (a square slice hung as a diamond)
				{
					attach = "UpperTorso",
					shape = "Block",
					size = { 2.4, 2.4, 0.08 },
					anchor = { 0, 0, 1 },
					offset = { 0, -0.4, 0.42 },
					rotation = { 0, 0, 45 },
					color = "Mustard",
				},
				-- Gentleman's top hat
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.08, 1.5, 1.5 },
					anchor = { 0, 1, 0 },
					offset = { 0, 0.04, 0 },
					rotation = { 0, 0, 90 },
					color = "Ink",
				},
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.9, 1.05, 1.05 },
					anchor = { 0, 1, 0 },
					offset = { 0, 0.5, 0 },
					rotation = { 0, 0, 90 },
					color = "Ink",
				},
				-- Little gold monocle and chain
				{
					attach = "Head",
					shape = "Cylinder",
					size = { 0.06, 0.45, 0.45 },
					anchor = { 0, 0, -1 },
					offset = { 0.25, 0.1, -0.04 },
					rotation = { 0, 90, 0 },
					color = "Mustard",
					reflectance = 0.3,
					transparency = 0.25,
				},
				{
					attach = "Head",
					shape = "Block",
					size = { 0.04, 0.6, 0.04 },
					anchor = { 0, 0, -1 },
					offset = { 0.42, -0.2, -0.04 },
					rotation = { 0, 0, 15 },
					color = "Mustard",
				},
			},
		},
	},
}

local Customers = {
	Kinds = {
		Regular = {
			kind = "Regular",
			displayName = "Customer",
			spawnWeight = 80,
			payMultiplier = 1,
			patienceMultiplier = 1,
		},
		Hungry = {
			kind = "Hungry",
			displayName = "Hungry Customer",
			spawnWeight = 15,
			payMultiplier = 1.5,
			patienceMultiplier = 0.6,
		},
		VIP = { kind = "VIP", displayName = "VIP", spawnWeight = 5, payMultiplier = 3, patienceMultiplier = 1 },
	} :: { [string]: KindDef },

	-- Chance per spawn that the customer is legendary (Rush Hour multiplies it by RushLegendaryMultiplier).
	LegendaryChance = 0.005,
	RushLegendaryMultiplier = 3,

	Legendary = {
		GiantChef = {
			id = "GiantChef",
			displayName = "The Giant Chef",
			announcement = "THE GIANT CHEF has arrived at {owner}'s diner!",
			payMultiplier = 10,
			tipBonus = 2,
			patienceMultiplier = 1.5,
			scale = 2.2,
			bodyColor = "Cream",
			accentColor = "Ketchup",
			favoriteDish = "Burger",
			costume = "GiantChef",
			enabled = true,
		},
		SpaceAlien = {
			id = "SpaceAlien",
			displayName = "Space Alien",
			announcement = "A SPACE ALIEN landed at {owner}'s diner!",
			payMultiplier = 12,
			tipBonus = 2.5,
			patienceMultiplier = 1.5,
			scale = 1.1,
			bodyColor = "Mint",
			accentColor = "NeonPink",
			favoriteDish = "Drink",
			costume = "SpaceAlien",
			enabled = true,
		},
		WeeklyMeme = {
			id = "WeeklyMeme",
			displayName = "Sir Sandwich",
			announcement = "SIR SANDWICH demands a table at {owner}'s diner!",
			payMultiplier = 15,
			tipBonus = 3,
			patienceMultiplier = 1.5,
			scale = 1.3,
			bodyColor = "Mustard",
			accentColor = "Ink",
			favoriteDish = nil,
			costume = "SirSandwich", -- swap for this week's costume in Looks.Costumes
			enabled = true,
		},
	} :: { [Types.LegendaryId]: LegendaryDef },

	Looks = LOOKS,
}

return Customers

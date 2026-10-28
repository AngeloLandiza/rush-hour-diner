--!strict
-- The ONLY source of colors in the game. Owner: agent E. Use Palette.Color.<Name> (Color3) or Palette.Hex.
--
-- Usage rule (world art): cream and the warm neutrals cover most surfaces (walls, floors, cabinets);
-- the six brand colors are ACCENTS only (awning stripes, trim bands, cushions, signs, knobs).
-- Neon is reserved for signage, bulbs and glow strips. Metals and wood ground the props.
local Hex: { [string]: string } = {
	-- The six spec colors
	Cream = "FFF4E0",
	Ketchup = "E63946",
	Mustard = "FFB703",
	Mint = "2EC4B6",
	Ink = "1D3557",
	NeonPink = "FF5DA2",
	White = "FFFFFF",
	-- Tints derived from the six brand colors (shading and secondary surfaces only).
	CreamShade = "EAD7B5", -- cream, darkened
	CreamLight = "FFFAF0", -- cream, lightened (countertops, plates)
	InkSoft = "34527F", -- ink, lightened
	KetchupDeep = "B22A36", -- ketchup, darkened
	KetchupSoft = "F2737D", -- ketchup, lightened
	KetchupPale = "F9C9C7", -- ketchup, very light (panels)
	MintDeep = "1E968B", -- mint, darkened
	MintPale = "BDEDE6", -- mint, lightened (glass, tiles)
	MustardDeep = "D98F00", -- mustard, darkened
	MustardPale = "FFE3A0", -- mustard, lightened
	NightInk = "14213D", -- ink, darkened for night ambient
	PinkGlow = "FFE3F0", -- near-white neon pink, for subtle tints
	DuskViolet = "5A3A7A", -- rush hour outdoor ambient
	-- Warm neutrals (dominant surfaces)
	Linen = "F3E6CF", -- walls, secondary cream
	Sand = "E2CFAE", -- patio, sidewalk joints
	Concrete = "D9D1C3", -- sidewalks
	ConcreteDark = "BEB4A3", -- curbs, seams
	Asphalt = "4A4E5C", -- street
	AsphaltDark = "3B3E4A", -- street edges
	Slate = "56627E", -- muted ink (checker tiles)
	-- Wood
	Wood = "C98B5A", -- warm oak
	WoodLight = "E0AE7E", -- planks, crates
	WoodDark = "8E5A3B", -- frames, trunks
	-- Metals
	Steel = "C7CED6", -- stainless cabinets
	SteelDark = "7F8A98", -- panels, rims
	Chrome = "EEF2F6", -- trims, handles
	Charcoal = "2E3140", -- griddles, vats, knobs
	-- Nature
	Grass = "86C17A",
	GrassDark = "6AA864",
	Leaf = "4FA35E",
	LeafDark = "37804A",
	Terracotta = "D2774E", -- pots, oven dome
	TerracottaDeep = "A9583A",
	-- Food
	Bun = "E9A54B",
	BunLight = "F6C77A",
	Patty = "6B3A2A",
	Lettuce = "7BC950",
	Ember = "FF8A2B",
	-- Atmosphere and lighting
	DayAmbient = "7A6E6A", -- warm grey indoor fill
	DayOutdoor = "A49A93", -- warm sky fill
	SkyHaze = "F7E9D7", -- day atmosphere
	SkyBlue = "9FD3EE", -- day atmosphere decay (horizon)
	Peach = "F3B78F", -- day atmosphere decay
	WarmTint = "FFF7EC", -- day color correction
	Lamp = "FFD9A0", -- warm bulb light
}

local Color: { [string]: Color3 } = {}
for name, hex in Hex do
	Color[name] = Color3.fromHex(hex)
end

return {
	Hex = Hex,
	Color = Color,
}

--!strict
-- The ONLY source of colors in the game. Owner: agent E. Use Palette.Color.<Name> (Color3) or Palette.Hex.
local Hex: { [string]: string } = {
	Cream = "FFF4E0",
	Ketchup = "E63946",
	Mustard = "FFB703",
	Mint = "2EC4B6",
	Ink = "1D3557",
	NeonPink = "FF5DA2",
	White = "FFFFFF",
	-- Tints derived from the six brand colors (shading and secondary surfaces only).
	CreamShade = "EAD7B5", -- cream, darkened
	InkSoft = "34527F", -- ink, lightened
	KetchupDeep = "B22A36", -- ketchup, darkened
	MintDeep = "1E968B", -- mint, darkened
	MustardDeep = "D98F00", -- mustard, darkened
	NightInk = "14213D", -- ink, darkened for night ambient
	PinkGlow = "FFE3F0", -- near-white neon pink, for subtle tints
}

local Color: { [string]: Color3 } = {}
for name, hex in Hex do
	Color[name] = Color3.fromHex(hex)
end

return {
	Hex = Hex,
	Color = Color,
}

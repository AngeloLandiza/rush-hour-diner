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
}

local Color: { [string]: Color3 } = {}
for name, hex in Hex do
	Color[name] = Color3.fromHex(hex)
end

return {
	Hex = Hex,
	Color = Color,
}

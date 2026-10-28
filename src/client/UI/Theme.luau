--!strict
-- UI theme: fonts, sizes, Palette-derived colors, tween presets. Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local Theme = {
	Font = Enum.Font.FredokaOne,
	MinTouchTarget = 44, -- px, mobile-first
	Colors = Palette.Color,
}

return Theme

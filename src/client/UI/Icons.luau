--!strict
-- Vector-style "sticker" icons composed from Frames: each icon is a list of shapes drawn in three passes
-- (soft drop shadow, dark outline silhouette, color fills), so outlines never cut through the art.
-- Config/UI.Images can swap any hero icon for an uploaded image; the code icon is the fallback.
-- Names: Icons.names(). Composites: "Burger+Bolt" draws a small Bolt badge on a Burger. Owner: UI agent.
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Icons = {}

local P = Theme.Colors
local C = Theme.C

type Shape = {
	color: Color3,
	cx: number,
	cy: number,
	w: number,
	h: number,
	r: number,
	rot: number,
	o: boolean, -- part of the outlined silhouette
	t: number, -- transparency
	ring: number?, -- stroke-only ring, thickness as a fraction of the icon size
	edge: boolean?, -- thin inner outline (separates overlapping parts)
}

-- Outlined silhouette shape.
local function S(color: Color3, cx: number, cy: number, w: number, h: number, r: number?, rot: number?): Shape
	return { color = color, cx = cx, cy = cy, w = w, h = h, r = r or 0, rot = rot or 0, o = true, t = 0 }
end

-- Detail shape (drawn on top, no outline).
local function D(
	color: Color3,
	cx: number,
	cy: number,
	w: number,
	h: number,
	r: number?,
	rot: number?,
	t: number?
): Shape
	return { color = color, cx = cx, cy = cy, w = w, h = h, r = r or 0, rot = rot or 0, o = false, t = t or 0 }
end

-- Stroke-only ring (handles, shackles).
local function R(color: Color3, cx: number, cy: number, w: number, h: number, thickness: number): Shape
	return { color = color, cx = cx, cy = cy, w = w, h = h, r = 0.5, rot = 0, o = true, t = 0, ring = thickness }
end

local function edged(s: Shape): Shape
	s.edge = true
	return s
end

local SHINE_T = 0.4
local PATTY = P.KetchupDeep:Lerp(P.Ink, 0.5)
local GOLD_LIGHT = C.GoldLight
local WOOD_DARK = Theme.shade(P.MustardDeep, 0.25)

local function circleGlyph(fill: Color3): { Shape }
	return { S(fill, 0.5, 0.5, 0.9, 0.9, 0.5) }
end

local SPECS: { [string]: () -> { Shape } } = {
	Coin = function()
		return {
			S(P.Mustard, 0.5, 0.5, 0.88, 0.88, 0.5),
			D(P.MustardDeep, 0.5, 0.5, 0.66, 0.66, 0.5),
			D(GOLD_LIGHT, 0.5, 0.5, 0.56, 0.56, 0.5),
			D(P.MustardDeep, 0.5, 0.5, 0.14, 0.34, 0.5),
			D(P.White, 0.32, 0.3, 0.2, 0.1, 0.5, -40, 0.35),
		}
	end,
	Shop = function()
		return {
			R(P.KetchupDeep, 0.5, 0.3, 0.42, 0.42, 0.09),
			S(P.Ketchup, 0.5, 0.62, 0.8, 0.62, 0.2),
			D(P.KetchupDeep, 0.5, 0.39, 0.66, 0.1, 0.5),
			D(P.Cream, 0.5, 0.66, 0.8, 0.12, 0),
			D(P.Mustard, 0.5, 0.66, 0.16, 0.16, 0.15, 45),
			D(P.White, 0.24, 0.52, 0.07, 0.16, 0.5, 0, SHINE_T),
		}
	end,
	Trophy = function()
		return {
			R(P.MustardDeep, 0.22, 0.36, 0.24, 0.26, 0.07),
			R(P.MustardDeep, 0.78, 0.36, 0.24, 0.26, 0.07),
			S(P.MustardDeep, 0.5, 0.68, 0.14, 0.2, 0),
			S(P.InkSoft, 0.5, 0.85, 0.56, 0.14, 0.35),
			S(P.Mustard, 0.5, 0.38, 0.56, 0.5, 0.45),
			S(P.Mustard, 0.5, 0.2, 0.64, 0.12, 0.3),
			D(P.Cream, 0.5, 0.4, 0.16, 0.16, 0.1, 45),
			D(P.White, 0.36, 0.34, 0.06, 0.16, 0.5, 0, SHINE_T),
		}
	end,
	Crew = function()
		return {
			S(P.MintDeep, 0.67, 0.32, 0.27, 0.27, 0.5),
			S(P.MintDeep, 0.67, 0.74, 0.42, 0.42, 0.45),
			edged(S(P.Mint, 0.38, 0.36, 0.31, 0.31, 0.5)),
			edged(S(P.Mint, 0.38, 0.8, 0.52, 0.44, 0.45)),
			D(P.White, 0.32, 0.3, 0.08, 0.08, 0.5, 0, 0.3),
		}
	end,
	Gear = function()
		return {
			S(P.InkSoft, 0.5, 0.5, 0.2, 0.94, 0.25, 0),
			S(P.InkSoft, 0.5, 0.5, 0.2, 0.94, 0.25, 45),
			S(P.InkSoft, 0.5, 0.5, 0.2, 0.94, 0.25, 90),
			S(P.InkSoft, 0.5, 0.5, 0.2, 0.94, 0.25, 135),
			S(P.InkSoft, 0.5, 0.5, 0.66, 0.66, 0.5),
			D(P.White, 0.5, 0.5, 0.28, 0.28, 0.5),
		}
	end,
	Clock = function()
		return {
			S(P.Ketchup, 0.24, 0.16, 0.22, 0.14, 0.5, -35),
			S(P.Ketchup, 0.76, 0.16, 0.22, 0.14, 0.5, 35),
			S(P.Ketchup, 0.5, 0.53, 0.86, 0.86, 0.5),
			D(P.White, 0.5, 0.53, 0.66, 0.66, 0.5),
			D(P.Ink, 0.5, 0.41, 0.09, 0.26, 0.5),
			D(P.Ink, 0.61, 0.53, 0.24, 0.09, 0.5),
			D(P.Ketchup, 0.5, 0.53, 0.12, 0.12, 0.5),
		}
	end,
	Flame = function()
		return {
			S(P.Ketchup, 0.5, 0.64, 0.7, 0.7, 0.5),
			S(P.Ketchup, 0.5, 0.42, 0.5, 0.5, 0.14, 45),
			D(P.Mustard, 0.5, 0.72, 0.42, 0.42, 0.5),
			D(P.Mustard, 0.5, 0.58, 0.3, 0.3, 0.12, 45),
			D(P.Cream, 0.5, 0.78, 0.18, 0.18, 0.5),
		}
	end,
	Calendar = function()
		return {
			S(P.White, 0.5, 0.56, 0.82, 0.74, 0.16),
			S(P.Ketchup, 0.5, 0.31, 0.82, 0.26, 0.3),
			D(P.Ketchup, 0.5, 0.4, 0.82, 0.08, 0),
			S(P.InkSoft, 0.33, 0.18, 0.09, 0.2, 0.5),
			S(P.InkSoft, 0.67, 0.18, 0.09, 0.2, 0.5),
			D(P.CreamShade, 0.3, 0.6, 0.14, 0.12, 0.3),
			D(P.CreamShade, 0.5, 0.6, 0.14, 0.12, 0.3),
			D(P.CreamShade, 0.7, 0.6, 0.14, 0.12, 0.3),
			D(P.CreamShade, 0.3, 0.78, 0.14, 0.12, 0.3),
			D(P.CreamShade, 0.5, 0.78, 0.14, 0.12, 0.3),
			D(P.Mustard, 0.7, 0.78, 0.14, 0.12, 0.3),
		}
	end,
	Crate = function()
		return {
			S(P.MustardDeep, 0.5, 0.6, 0.84, 0.64, 0.12),
			D(P.Mustard, 0.5, 0.47, 0.72, 0.12, 0.3),
			D(P.Mustard, 0.5, 0.74, 0.72, 0.12, 0.3),
			D(WOOD_DARK, 0.5, 0.6, 0.08, 0.6, 0.3, 52),
			S(P.Mustard, 0.5, 0.27, 0.94, 0.16, 0.3),
			D(P.White, 0.22, 0.25, 0.14, 0.05, 0.5, 0, SHINE_T),
		}
	end,
	Burger = function()
		return {
			S(P.Mustard, 0.5, 0.36, 0.86, 0.44, 0.5),
			S(P.Mint, 0.5, 0.55, 0.94, 0.12, 0.5),
			S(P.Ketchup, 0.5, 0.62, 0.88, 0.1, 0.5),
			S(PATTY, 0.5, 0.7, 0.88, 0.14, 0.5),
			S(P.Mustard, 0.5, 0.83, 0.82, 0.14, 0.45),
			D(P.Cream, 0.36, 0.25, 0.07, 0.04, 0.5, -25),
			D(P.Cream, 0.52, 0.21, 0.07, 0.04, 0.5),
			D(P.Cream, 0.66, 0.27, 0.07, 0.04, 0.5, 25),
			D(P.White, 0.27, 0.36, 0.1, 0.06, 0.5, -30, SHINE_T),
		}
	end,
	Fries = function()
		return {
			S(P.Mustard, 0.3, 0.36, 0.12, 0.5, 0.3, -14),
			S(P.Mustard, 0.42, 0.29, 0.12, 0.5, 0.3, -5),
			S(P.Mustard, 0.56, 0.28, 0.12, 0.5, 0.3, 5),
			S(P.Mustard, 0.68, 0.35, 0.12, 0.5, 0.3, 14),
			S(P.Mustard, 0.49, 0.38, 0.12, 0.44, 0.3, 0),
			S(P.Ketchup, 0.5, 0.71, 0.72, 0.52, 0.16),
			D(P.KetchupDeep, 0.5, 0.5, 0.72, 0.07, 0.3),
			D(P.White, 0.5, 0.73, 0.2, 0.2, 0.15, 45),
			D(P.White, 0.24, 0.66, 0.06, 0.18, 0.5, 0, SHINE_T),
		}
	end,
	Pizza = function()
		return {
			S(P.Mustard, 0.5, 0.5, 0.9, 0.9, 0.5),
			D(GOLD_LIGHT, 0.5, 0.5, 0.72, 0.72, 0.5),
			D(P.MustardDeep, 0.5, 0.5, 0.03, 0.72, 0, 45),
			D(P.MustardDeep, 0.5, 0.5, 0.03, 0.72, 0, -45),
			D(P.Ketchup, 0.36, 0.36, 0.18, 0.18, 0.5),
			D(P.Ketchup, 0.65, 0.4, 0.16, 0.16, 0.5),
			D(P.Ketchup, 0.42, 0.66, 0.16, 0.16, 0.5),
			D(P.Ketchup, 0.66, 0.64, 0.14, 0.14, 0.5),
			D(P.Mint, 0.52, 0.52, 0.09, 0.09, 0.5),
			D(P.Mint, 0.28, 0.54, 0.08, 0.08, 0.5),
		}
	end,
	Drink = function()
		return {
			S(P.NeonPink, 0.6, 0.17, 0.08, 0.32, 0.5, 18),
			S(P.Ketchup, 0.5, 0.62, 0.6, 0.66, 0.14),
			D(P.White, 0.5, 0.6, 0.6, 0.16, 0),
			D(P.Mustard, 0.5, 0.6, 0.1, 0.1, 0.2, 45),
			S(P.Cream, 0.5, 0.3, 0.72, 0.12, 0.5),
			D(P.White, 0.3, 0.76, 0.06, 0.14, 0.5, 0, SHINE_T),
		}
	end,
	Bolt = function()
		return {
			S(P.Mustard, 0.42, 0.33, 0.22, 0.48, 0.12, 22),
			S(P.Mustard, 0.58, 0.67, 0.22, 0.48, 0.12, 22),
			S(P.Mustard, 0.5, 0.5, 0.48, 0.15, 0.1, -20),
		}
	end,
	Star = function()
		return {
			S(P.Mustard, 0.5, 0.52, 0.62, 0.62, 0.12),
			S(P.Mustard, 0.5, 0.52, 0.62, 0.62, 0.12, 45),
			D(P.White, 0.42, 0.42, 0.12, 0.12, 0.5, 0, SHINE_T),
		}
	end,
	Crown = function()
		return {
			S(P.Mustard, 0.22, 0.42, 0.2, 0.2, 0.15, 45),
			S(P.Mustard, 0.5, 0.33, 0.24, 0.24, 0.15, 45),
			S(P.Mustard, 0.78, 0.42, 0.2, 0.2, 0.15, 45),
			S(P.Mustard, 0.5, 0.6, 0.76, 0.32, 0.1),
			S(P.MustardDeep, 0.5, 0.78, 0.8, 0.14, 0.3),
			D(P.Ketchup, 0.5, 0.6, 0.14, 0.14, 0.5),
			D(P.Mint, 0.28, 0.62, 0.1, 0.1, 0.5),
			D(P.Mint, 0.72, 0.62, 0.1, 0.1, 0.5),
		}
	end,
	ChefHat = function()
		return {
			S(P.White, 0.3, 0.4, 0.38, 0.38, 0.5),
			S(P.White, 0.7, 0.4, 0.38, 0.38, 0.5),
			S(P.White, 0.5, 0.3, 0.46, 0.46, 0.5),
			S(P.White, 0.5, 0.7, 0.56, 0.3, 0.12),
			D(P.CreamShade, 0.5, 0.78, 0.56, 0.08, 0),
		}
	end,
	Potion = function()
		return {
			S(P.White, 0.5, 0.3, 0.26, 0.26, 0.2),
			S(P.MustardDeep, 0.5, 0.15, 0.32, 0.12, 0.3),
			S(P.NeonPink, 0.5, 0.64, 0.66, 0.66, 0.5),
			D(P.PinkGlow, 0.42, 0.62, 0.12, 0.12, 0.5),
			D(P.PinkGlow, 0.6, 0.74, 0.08, 0.08, 0.5),
			D(P.White, 0.32, 0.56, 0.08, 0.2, 0.5, 0, 0.35),
		}
	end,
	Robot = function()
		return {
			S(P.InkSoft, 0.5, 0.17, 0.06, 0.18, 0),
			S(P.Ketchup, 0.5, 0.09, 0.15, 0.15, 0.5),
			S(P.CreamShade, 0.1, 0.55, 0.1, 0.24, 0.3),
			S(P.CreamShade, 0.9, 0.55, 0.1, 0.24, 0.3),
			S(P.White, 0.5, 0.55, 0.78, 0.6, 0.28),
			D(P.InkSoft, 0.5, 0.5, 0.6, 0.28, 0.45),
			D(P.Mint, 0.38, 0.5, 0.12, 0.12, 0.5),
			D(P.Mint, 0.62, 0.5, 0.12, 0.12, 0.5),
			D(P.CreamShade, 0.5, 0.74, 0.26, 0.06, 0.5),
		}
	end,
	Stool = function()
		return {
			S(P.InkSoft, 0.5, 0.64, 0.12, 0.44, 0.2),
			S(P.InkSoft, 0.5, 0.88, 0.52, 0.1, 0.5),
			S(P.Ketchup, 0.5, 0.34, 0.82, 0.24, 0.5),
			D(P.White, 0.32, 0.3, 0.14, 0.06, 0.5, 0, SHINE_T),
		}
	end,
	Music = function()
		return {
			S(P.NeonPink, 0.56, 0.46, 0.08, 0.54, 0.4),
			S(P.NeonPink, 0.69, 0.24, 0.26, 0.12, 0.5, 30),
			S(P.NeonPink, 0.42, 0.74, 0.34, 0.26, 0.5, -20),
			D(P.White, 0.36, 0.71, 0.08, 0.05, 0.5, -20, SHINE_T),
		}
	end,
	Speaker = function()
		return {
			S(P.InkSoft, 0.28, 0.5, 0.2, 0.32, 0.15),
			S(P.InkSoft, 0.44, 0.5, 0.26, 0.62, 0.3),
			S(P.Mint, 0.72, 0.5, 0.07, 0.3, 0.5),
			S(P.Mint, 0.86, 0.5, 0.07, 0.52, 0.5),
		}
	end,
	Check = function()
		return {
			S(P.Mint, 0.32, 0.58, 0.16, 0.4, 0.5, -45),
			S(P.Mint, 0.62, 0.48, 0.16, 0.66, 0.5, 40),
		}
	end,
	CheckWhite = function()
		return {
			S(P.White, 0.32, 0.58, 0.16, 0.4, 0.5, -45),
			S(P.White, 0.62, 0.48, 0.16, 0.66, 0.5, 40),
		}
	end,
	Close = function()
		return {
			S(P.White, 0.5, 0.5, 0.18, 0.84, 0.5, 45),
			S(P.White, 0.5, 0.5, 0.18, 0.84, 0.5, -45),
		}
	end,
	CloseInk = function()
		return {
			D(P.Ink, 0.5, 0.5, 0.14, 0.8, 0.5, 45),
			D(P.Ink, 0.5, 0.5, 0.14, 0.8, 0.5, -45),
		}
	end,
	Plus = function()
		return {
			S(P.White, 0.5, 0.5, 0.2, 0.8, 0.5),
			S(P.White, 0.5, 0.5, 0.8, 0.2, 0.5),
		}
	end,
	Lock = function()
		return {
			R(P.InkSoft, 0.5, 0.36, 0.44, 0.5, 0.1),
			S(P.Mustard, 0.5, 0.66, 0.74, 0.5, 0.16),
			D(P.Ink, 0.5, 0.62, 0.12, 0.12, 0.5),
			D(P.Ink, 0.5, 0.72, 0.06, 0.14, 0.3),
		}
	end,
	Info = function()
		local s = circleGlyph(P.InkSoft)
		table.insert(s, D(P.White, 0.5, 0.29, 0.14, 0.14, 0.5))
		table.insert(s, D(P.White, 0.5, 0.62, 0.13, 0.36, 0.5))
		return s
	end,
	Warning = function()
		local s = circleGlyph(P.Mustard)
		table.insert(s, D(P.Ink, 0.5, 0.42, 0.13, 0.38, 0.5))
		table.insert(s, D(P.Ink, 0.5, 0.75, 0.14, 0.14, 0.5))
		return s
	end,
	Error = function()
		local s = circleGlyph(P.Ketchup)
		table.insert(s, D(P.White, 0.5, 0.5, 0.13, 0.52, 0.5, 45))
		table.insert(s, D(P.White, 0.5, 0.5, 0.13, 0.52, 0.5, -45))
		return s
	end,
	Success = function()
		local s = circleGlyph(P.Mint)
		table.insert(s, D(P.White, 0.38, 0.57, 0.12, 0.28, 0.5, -45))
		table.insert(s, D(P.White, 0.57, 0.5, 0.12, 0.46, 0.5, 40))
		return s
	end,
	Chevron = function()
		return {
			S(P.NeonPink, 0.36, 0.42, 0.18, 0.6, 0.5, -40),
			S(P.NeonPink, 0.64, 0.42, 0.18, 0.6, 0.5, 40),
		}
	end,
	Ad = function()
		return {
			S(P.InkSoft, 0.36, 0.17, 0.06, 0.2, 0.5, -30),
			S(P.InkSoft, 0.64, 0.17, 0.06, 0.2, 0.5, 30),
			S(P.InkSoft, 0.5, 0.56, 0.86, 0.64, 0.2),
			D(P.White, 0.42, 0.56, 0.3, 0.3, 0.1, 45),
			D(P.InkSoft, 0.31, 0.56, 0.22, 0.46, 0),
		}
	end,
	Cart = function()
		return {
			S(P.InkSoft, 0.2, 0.3, 0.2, 0.08, 0.5),
			S(P.Mint, 0.54, 0.46, 0.62, 0.36, 0.2),
			S(P.InkSoft, 0.38, 0.8, 0.14, 0.14, 0.5),
			S(P.InkSoft, 0.7, 0.8, 0.14, 0.14, 0.5),
		}
	end,
}

-- Multi-icon composites: { name, cx, cy, size } in the same 0..1 space.
local COMPOSITES: { [string]: { { name: string, cx: number, cy: number, size: number } } } = {
	Coins2 = {
		{ name = "Coin", cx = 0.36, cy = 0.6, size = 0.66 },
		{ name = "Coin", cx = 0.64, cy = 0.42, size = 0.66 },
	},
	Coins3 = {
		{ name = "Coin", cx = 0.3, cy = 0.64, size = 0.6 },
		{ name = "Coin", cx = 0.7, cy = 0.64, size = 0.6 },
		{ name = "Coin", cx = 0.5, cy = 0.36, size = 0.64 },
	},
}

local BADGE_SIZE = 0.5

function Icons.names(): { string }
	local out = {}
	for name in SPECS do
		table.insert(out, name)
	end
	for name in COMPOSITES do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

local function strokeFor(px: number): number
	return math.max(1.5, math.floor(px * 0.075 * 2 + 0.5) / 2)
end

local function place(parent: Instance, s: Shape, grow: number, dy: number, z: number): Frame
	local f = Util.frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(s.cx, 0, s.cy, dy),
		Size = UDim2.new(s.w, grow * 2, s.h, grow * 2),
		Rotation = s.rot,
		ZIndex = z,
	})
	if s.r > 0 then
		Util.new("UICorner", { CornerRadius = UDim.new(s.r, 0) }, f)
	end
	return f
end

local function drawShape(
	parent: Instance,
	s: Shape,
	px: number,
	color: Color3,
	extra: number,
	dy: number,
	z: number,
	t: number
): Frame
	if s.ring then
		local f = place(parent, s, 0, dy, z)
		Util.new("UIStroke", {
			Color = color,
			Thickness = s.ring * px + extra * 2,
			Transparency = t,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Center,
		}, f)
		return f
	end
	local f = place(parent, s, extra, dy, z)
	f.BackgroundTransparency = t
	f.BackgroundColor3 = color
	return f
end

local function drawSpec(root: Frame, shapes: { Shape }, px: number, shadow: boolean)
	local stroke = strokeFor(px)
	local z = 1
	if shadow then
		for _, s in shapes do
			if s.o then
				drawShape(root, s, px, C.Shadow, stroke, stroke, z, 0.6)
			end
		end
	end
	z += 1
	for _, s in shapes do
		if s.o then
			drawShape(root, s, px, C.Outline, stroke, 0, z, 0)
		end
	end
	for i, s in shapes do
		local f = drawShape(root, s, px, s.color, 0, 0, z + i, s.t)
		if s.edge then
			Util.stroke(f, C.Outline, math.max(1, stroke * 0.6))
		end
	end
end

local function imageFor(name: string): number?
	local id = Theme.Images[name]
	if id and id ~= 0 then
		return id
	end
	return nil
end

local build: (name: string, parent: Instance?, px: number, props: { [string]: any }?) -> Frame

-- Build an icon. px is the rendered size in design px (drives outline weight); props override the
-- root Frame (e.g. Size = UDim2.fromScale(1, 1), Position, AnchorPoint, ZIndex).
build = function(name: string, parent: Instance?, px: number, props: { [string]: any }?): Frame
	local root = Util.frame(nil, { Name = "Icon_" .. name, Size = UDim2.fromOffset(px, px) })
	if props then
		for k, v in props do
			(root :: any)[k] = v
		end
	end
	Util.aspect(root, 1)

	local plus = string.find(name, "+", 1, true)
	if plus then
		local base = string.sub(name, 1, plus - 1)
		local badge = string.sub(name, plus + 1)
		build(base, root, px, { Size = UDim2.fromScale(1, 1) })
		build(badge, root, px * BADGE_SIZE, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1.08, 1.06),
			Size = UDim2.fromScale(BADGE_SIZE, BADGE_SIZE),
			ZIndex = 50,
		})
	elseif imageFor(name) then
		Util.new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = `rbxassetid://{imageFor(name)}`,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
		}, root)
	elseif COMPOSITES[name] then
		for i, part in COMPOSITES[name] do
			build(part.name, root, px * part.size, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(part.cx, part.cy),
				Size = UDim2.fromScale(part.size, part.size),
				ZIndex = i,
			})
		end
	else
		local spec = SPECS[name] or SPECS.Info
		drawSpec(root, spec(), px, px >= 28)
	end
	root.Parent = parent
	return root
end

Icons.build = build

return Icons

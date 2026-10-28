--!strict
-- Diner shells per decor tier, built in plot-local space (+Z = street) into the plot's Shell folder.
-- The footprint grows with the tier:
--   0  food stand at the back of an open lot: plank deck, slatted wall and awning over the kitchen, a
--      paved terrace with picnic tables in front, a garden arch at the Door.
--   1  enclosed diner (x ±31): walls with windows, a glass facade with the entrance, checker dining
--      room with booths, pendant lamps, a marquee on the facade.
--   2  big neon diner (x ±40): wider room with a jukebox and a pie case, a striped covered patio out
--      to z 18 with bistro tables and string lights, neon trim, a marquee, a blade sign and the
--      rooftop burger.
-- Never touches stations, seats or the named plot parts. Diners are open-topped so the kitchen stays
-- readable from the gameplay camera. Art rules: warm neutral walls and floors, the plot accent only
-- on awnings, stripes, trim and cushions; Neon only on signs and bulbs (tagged RushNeon).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Build = require("./Build")
local Layout = require("./Layout")
local Yard = require("./Yard")

local C = Palette.Color
local F = Layout.FloorY
local ZB = Layout.WallBackZ
local ZF = Layout.WallFrontZ
local ZD = Layout.DiningZ0
local DOOR_HALF = Layout.DoorSize.X / 2
local DOOR_H = Layout.DoorSize.Y

local Shells = {}

type Ctx = { shell: Folder, plotCF: CFrame, accent: Color3, pale: Color3, wx: number }

-- The light tint of each plot accent (lower facade panels).
local PALE: { [string]: Color3 } = {
	[C.Ketchup:ToHex()] = C.KetchupPale,
	[C.Mint:ToHex()] = C.MintPale,
	[C.Mustard:ToHex()] = C.MustardPale,
}

local function at(ctx: Ctx, x: number, y: number, z: number): CFrame
	return ctx.plotCF * CFrame.new(x, y, z)
end

local function box(
	ctx: Ctx,
	name: string,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	mat: Enum.Material?
): Part
	return Build.Part(ctx.shell, name, size, at(ctx, x, y, z), color, mat)
end

local function softBox(
	ctx: Ctx,
	name: string,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	mat: Enum.Material?
): Part
	local p = box(ctx, name, size, x, y, z, color, mat)
	Build.Soft(p)
	return p
end

local function glass(ctx: Ctx, size: Vector3, x: number, y: number, z: number): Part
	local g = box(ctx, "Window", size, x, y, z, C.MintPale, Build.Glass)
	g.Transparency = 0.55
	g.CastShadow = false
	return g
end

-- ── Building blocks ──────────────────────────────────────────────────────────

-- Striped awning with a scalloped valance. It hangs off a wall at z = zWall (top edge at yTop) and
-- slopes down toward +Z by `drop` over `depth`. Stripes alternate the plot accent and cream.
local function awning(
	ctx: Ctx,
	cx: number,
	width: number,
	stripes: number,
	depth: number,
	drop: number,
	yTop: number,
	zWall: number,
	pergola: boolean?
)
	local stripeW = width / stripes
	local slope = math.atan2(drop, depth)
	local len = math.sqrt(depth * depth + drop * drop)
	local valanceH = 0.9
	local yEdge = yTop - drop
	local zEdge = zWall + depth
	local scallopH = 1.5 -- each scallop is a half-ellipse hanging scallopH / 2 below the valance
	for i = 1, stripes do
		local x = cx + (i - (stripes + 1) / 2) * stripeW
		local color = if i % 2 == 0 then C.Cream else ctx.accent
		if pergola and i % 2 == 0 then
			-- Open bay between two canvas sails: a pair of cream rafters
			for _, side in { -1, 1 } do
				Build.Soft(
					Build.Part(
						ctx.shell,
						"Rafter",
						Vector3.new(0.5, 0.5, len),
						at(ctx, x + side * (stripeW / 2 - 0.4), yTop - drop / 2 - 0.1, zWall + depth / 2)
							* CFrame.Angles(slope, 0, 0),
						C.CreamLight
					)
				)
			end
			continue
		end
		Build.Soft(
			Build.Part(
				ctx.shell,
				"AwningStripe",
				Vector3.new(stripeW, 0.3, len),
				at(ctx, x, yTop - drop / 2, zWall + depth / 2) * CFrame.Angles(slope, 0, 0),
				color
			)
		)
		softBox(ctx, "AwningValance", Vector3.new(stripeW, valanceH, 0.2), x, yEdge - valanceH / 2 + 0.1, zEdge, color)
		Build.Soft(
			Build.Ellipse(
				ctx.shell,
				"AwningScallop",
				stripeW,
				scallopH,
				0.16,
				at(ctx, x, yEdge - valanceH + 0.1, zEdge - 0.01),
				color
			)
		)
	end
end

-- A floor slab with a painted pattern (one part): checker tiles, or planks when `rowsOnly`.
local function paintedFloor(
	ctx: Ctx,
	name: string,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	base: Color3,
	other: Color3,
	tile: number,
	rowsOnly: boolean?,
	lift: number?
): Part
	local w, d = x1 - x0, z1 - z0
	local y = F + 0.05 + (lift or 0)
	local floor = box(ctx, name, Vector3.new(w, 0.1, d), (x0 + x1) / 2, y, (z0 + z1) / 2, base)
	local cols = if rowsOnly then 1 else math.max(1, math.round(w / tile))
	Build.Checker(
		floor,
		Enum.NormalId.Top,
		cols,
		math.max(1, math.round(d / tile)),
		other,
		nil,
		nil,
		nil,
		Build.FloorPPS
	)
	return floor
end

local function pottedPlant(ctx: Ctx, x: number, z: number, scale: number)
	Build.Cylinder(ctx.shell, "Pot", 1.6 * scale, 1.4 * scale, at(ctx, x, F + 0.7 * scale, z), C.Terracotta)
	Build.Ball(ctx.shell, "Leaves", Vector3.new(2.2, 2, 2.2) * scale, at(ctx, x, F + 2.1 * scale, z), C.Leaf)
	Build.Ball(
		ctx.shell,
		"Leaves",
		Vector3.new(1.4, 1.4, 1.4) * scale,
		at(ctx, x + 0.4 * scale, F + 3 * scale, z - 0.2 * scale),
		C.LeafDark
	)
end

-- Wooden planter box with a hedge and two flowers.
local function planter(ctx: Ctx, x: number, z: number, w: number)
	box(ctx, "Planter", Vector3.new(w, 1.3, 1.6), x, F + 0.65, z, C.Wood)
	box(ctx, "PlanterRim", Vector3.new(w + 0.3, 0.2, 1.9), x, F + 1.35, z, C.WoodDark)
	Build.Dome(ctx.shell, "Hedge", Vector3.new(w - 0.2, 1.6, 1.4), at(ctx, x, F + 1.9, z), C.Leaf)
	for i, color in { C.Ketchup, C.Mustard } do
		Build.Ball(
			ctx.shell,
			"Flower",
			Vector3.new(0.6, 0.6, 0.6),
			at(ctx, x + (i - 1.5) * w * 0.5, F + 2.55, z + 0.3),
			color
		)
	end
end

-- Menu board on the back wall (inside, facing +Z).
local function menuBoard(ctx: Ctx, x: number, y: number, w: number)
	box(ctx, "MenuFrame", Vector3.new(w + 0.6, 3.6, 0.3), x, y, ZB + 0.65, C.WoodDark)
	local board = box(ctx, "MenuBoard", Vector3.new(w, 3, 0.2), x, y, ZB + 0.85, C.Charcoal)
	Build.Text(board, "BURGERS · FRIES · PIZZA · SODA", C.Cream)
end

local function wallClock(ctx: Ctx, x: number, y: number)
	Build.Disc(ctx.shell, "ClockRim", 2.6, 0.25, at(ctx, x, y, ZB + 0.62), C.Ketchup)
	Build.Disc(ctx.shell, "ClockFace", 2.1, 0.12, at(ctx, x, y, ZB + 0.78), C.CreamLight)
	box(ctx, "ClockHand", Vector3.new(0.12, 0.8, 0.05), x, y + 0.35, ZB + 0.86, C.Charcoal)
	box(ctx, "ClockHand", Vector3.new(0.6, 0.12, 0.05), x + 0.25, y, ZB + 0.86, C.Charcoal)
end

-- A row of RushNeon bulbs from p0 to p1 sagging by `sag` in the middle. Every `lightEvery`th bulb lights.
-- Bulbs inside `avoid` (x/y rectangle) are skipped so they never cover signage lettering.
local function stringLights(
	ctx: Ctx,
	p0: Vector3,
	p1: Vector3,
	count: number,
	sag: number,
	lightEvery: number,
	avoid: { x0: number, x1: number, y0: number, y1: number }?
)
	local colors = { C.Mustard, C.NeonPink, C.Mint }
	for i = 1, count do
		local t = (i - 0.5) / count
		local p = p0:Lerp(p1, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local color = colors[(i - 1) % #colors + 1]
		if avoid and p.X >= avoid.x0 and p.X <= avoid.x1 and p.Y >= avoid.y0 and p.Y <= avoid.y1 then
			continue
		end
		local bulb =
			Build.Ball(ctx.shell, "Bulb", Vector3.new(0.6, 0.75, 0.6), at(ctx, p.X, p.Y, p.Z), color, Build.Neon)
		Build.Soft(bulb)
		Build.RushNeon(bulb, if i % lightEvery == 0 then 14 else nil, 1.2)
	end
	-- The wire: two straight halves meeting at the sag point read as a catenary from gameplay distance.
	local mid = p0:Lerp(p1, 0.5) - Vector3.new(0, sag, 0)
	for _, seg in { { p0, mid }, { mid, p1 } } do
		local a, b = seg[1], seg[2]
		local wire = Build.Part(
			ctx.shell,
			"Wire",
			Vector3.new(0.08, 0.08, (b - a).Magnitude),
			ctx.plotCF * CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.3, 0), b + Vector3.new(0, 0.3, 0)),
			C.Charcoal
		)
		Build.Soft(wire)
		wire.CastShadow = false
	end
end

-- Hanging pendant lamps along a soft ceiling beam (warm, always on).
local function pendants(ctx: Ctx, beamY: number, z: number, width: number, xs: { number }, range: number)
	softBox(ctx, "Beam", Vector3.new(width, 0.5, 0.6), 0, beamY, z, C.WoodDark)
	for _, x in xs do
		local cordLen = 1.8
		local cord =
			Build.Cylinder(ctx.shell, "Cord", 0.12, cordLen, at(ctx, x, beamY - 0.4 - cordLen / 2, z), C.Charcoal)
		Build.Soft(cord)
		local shadeY = beamY - 0.4 - cordLen - 0.3
		local shade = Build.Cylinder(ctx.shell, "Shade", 1.4, 0.6, at(ctx, x, shadeY, z), ctx.accent)
		Build.Soft(shade)
		local bulb = Build.Ball(
			ctx.shell,
			"LampBulb",
			Vector3.new(0.9, 0.9, 0.9),
			at(ctx, x, shadeY - 0.45, z),
			C.Lamp,
			Build.Neon
		)
		Build.Soft(bulb)
		bulb.CastShadow = false
		Build.Light(bulb, C.Lamp, range, 0.6)
	end
end

-- ── Walls ────────────────────────────────────────────────────────────────────

-- Back wall with a backsplash and an accent trim, and side walls that are solid along the kitchen and
-- glazed along the dining room (wainscot, a window band, an upper panel).
local function shellWalls(ctx: Ctx, height: number)
	local wx = ctx.wx
	local width = wx * 2 + 1
	box(ctx, "BackWall", Vector3.new(width, height, 1), 0, F + height / 2, ZB, C.Linen)
	softBox(ctx, "WallCap", Vector3.new(width + 0.6, 0.5, 1.6), 0, F + height + 0.25, ZB, C.CreamLight)
	box(ctx, "Backsplash", Vector3.new(width - 2, 3.4, 0.15), 0, F + 5.4, ZB + 0.55, C.MintPale)
	box(ctx, "BacksplashTrim", Vector3.new(width - 2, 0.3, 0.3), 0, F + 7.2, ZB + 0.6, ctx.accent)
	local kitchenLen = ZD - ZB
	local kitchenZ = (ZB + ZD) / 2
	local diningLen = ZF - ZD
	local diningZ = (ZD + ZF) / 2
	local lowerTop = F + 3.4
	local winTop = F + 8.6
	for _, side in { -1, 1 } do
		local x = side * wx
		box(ctx, "SideWall", Vector3.new(1, height, kitchenLen), x, F + height / 2, kitchenZ, C.Linen)
		box(ctx, "SideLower", Vector3.new(1, lowerTop - F, diningLen), x, (F + lowerTop) / 2, diningZ, C.Linen)
		glass(ctx, Vector3.new(0.3, winTop - lowerTop, diningLen - 1), x, (lowerTop + winTop) / 2, diningZ)
		box(
			ctx,
			"SideUpper",
			Vector3.new(1, F + height - winTop, diningLen),
			x,
			(winTop + F + height) / 2,
			diningZ,
			C.Linen
		)
		box(ctx, "SideSill", Vector3.new(1.5, 0.3, diningLen), x, lowerTop + 0.15, diningZ, C.Chrome)
		for m = 1, 3 do
			box(
				ctx,
				"Mullion",
				Vector3.new(0.6, winTop - lowerTop, 0.35),
				x,
				(lowerTop + winTop) / 2,
				ZD + m * diningLen / 4,
				C.Chrome
			)
		end
		softBox(ctx, "WallCap", Vector3.new(1.6, 0.5, ZF - ZB), x, F + height + 0.25, (ZB + ZF) / 2, C.CreamLight)
		-- Outside: wainscot and an accent stripe the full length of the building
		box(ctx, "SideWainscot", Vector3.new(0.2, 3, ZF - ZB), x + side * 0.6, F + 1.5, (ZB + ZF) / 2, C.CreamShade)
		box(ctx, "SideStripe", Vector3.new(0.25, 0.4, ZF - ZB), x + side * 0.62, F + 3.2, (ZB + ZF) / 2, ctx.accent)
	end
end

-- Street facade at z = ZF: kick plate, tinted lower panel, accent stripe, big framed windows, pilasters,
-- a framed doorway with an OPEN sign, a cornice, and a shallow canopy roof behind it. `awnings` adds the
-- striped window awnings (tier 1; tier 2's covered patio replaces them).
local function facade(ctx: Ctx, height: number, awningStripes: number, awnings: boolean)
	local wx = ctx.wx
	local sideW = wx - DOOR_HALF
	local lowerTop = F + 3.4
	local winTop = F + 8.6
	for _, side in { -1, 1 } do
		local cx = side * (DOOR_HALF + sideW / 2)
		box(ctx, "Kick", Vector3.new(sideW, 0.8, 1.3), cx, F + 0.4, ZF, C.ConcreteDark)
		box(ctx, "FrontLower", Vector3.new(sideW, lowerTop - F - 0.8, 1), cx, (lowerTop + F + 0.8) / 2, ZF, ctx.pale)
		box(ctx, "FrontStripe", Vector3.new(sideW, 0.45, 1.15), cx, lowerTop - 0.2, ZF, ctx.accent)
		box(ctx, "Sill", Vector3.new(sideW - 1, 0.3, 1.6), cx, lowerTop + 0.15, ZF + 0.1, C.Chrome)
		glass(ctx, Vector3.new(sideW - 1, winTop - lowerTop - 0.3, 0.3), cx, (lowerTop + winTop) / 2 + 0.15, ZF)
		local panes = 4
		for m = 1, panes - 1 do
			box(
				ctx,
				"Mullion",
				Vector3.new(0.35, winTop - lowerTop, 0.6),
				side * DOOR_HALF + side * m * sideW / panes,
				(lowerTop + winTop) / 2,
				ZF,
				C.Chrome
			)
		end
		box(ctx, "FrontUpper", Vector3.new(sideW, F + height - winTop, 1), cx, (winTop + F + height) / 2, ZF, C.Linen)
		-- Pilasters at the outer corner and beside the door
		for _, px in { side * (wx + 0.1), side * (DOOR_HALF + 0.5) } do
			box(ctx, "Pilaster", Vector3.new(1.4, height, 1.6), px, F + height / 2, ZF + 0.1, C.CreamLight)
		end
		if awnings then
			awning(ctx, cx, sideW - 2, awningStripes, 3.2, 1.4, winTop + 1.6, ZF + 0.6)
		end
	end
	-- Doorway
	box(
		ctx,
		"Lintel",
		Vector3.new(DOOR_HALF * 2, height - DOOR_H, 1),
		0,
		F + DOOR_H + (height - DOOR_H) / 2,
		ZF,
		C.Linen
	)
	box(ctx, "DoorHead", Vector3.new(DOOR_HALF * 2 + 0.6, 0.5, 1.5), 0, F + DOOR_H + 0.25, ZF + 0.1, C.Chrome)
	local open = box(ctx, "OpenSign", Vector3.new(4.2, 1.4, 0.2), 0, F + DOOR_H + 1.5, ZF + 0.6, C.NeonPink, Build.Neon)
	Build.RushNeon(open, 8, 1)
	Build.Text(open, "OPEN", C.CreamLight)
	-- Welcome mat inside the entrance
	local mat = box(ctx, "DoorMat", Vector3.new(5, 0.06, 2.6), 0, F + 0.13, ZF - 2, ctx.accent)
	mat.CanCollide = false
	-- Cornice and canopy roof (soft so it never blocks the camera)
	softBox(ctx, "Cornice", Vector3.new(wx * 2 + 2.4, 0.7, 2.4), 0, F + height + 0.35, ZF + 0.4, C.CreamLight)
	softBox(ctx, "CorniceStripe", Vector3.new(wx * 2 + 2.5, 0.3, 2.5), 0, F + height - 0.15, ZF + 0.4, ctx.accent)
	softBox(ctx, "Canopy", Vector3.new(wx * 2, 0.5, 5), 0, F + height - 0.1, ZF - 2.5, C.CreamShade)
end

-- The big rooftop marquee sign: an ink pill board with cream lettering, a neon outline and bulbs.
local function marquee(ctx: Ctx, y: number, w: number, h: number, text: string, bulbs: number)
	local z = ZF + 0.6
	Build.Pill(
		ctx.shell,
		"MarqueeFrame",
		Vector3.new(w + 0.7, h + 0.7, 0.6),
		at(ctx, 0, y, z - 0.2),
		ctx.accent,
		nil,
		true
	)
	local board = Build.Pill(ctx.shell, "Marquee", Vector3.new(w, h, 0.8), at(ctx, 0, y, z), C.Ink, nil, true)
	Build.Text(board, text, C.CreamLight)
	local tube = softBox(
		ctx,
		"MarqueeNeon",
		Vector3.new(w - h, 0.18, 0.18),
		0,
		y - h / 2 + 0.35,
		z + 0.45,
		C.NeonPink,
		Build.Neon
	)
	Build.RushNeon(tube, 16, 2)
	for i = 1, bulbs do
		local x = (i - (bulbs + 1) / 2) * ((w - h) / (bulbs - 1))
		local b = Build.Ball(
			ctx.shell,
			"MarqueeBulb",
			Vector3.new(0.5, 0.5, 0.5),
			at(ctx, x, y + h / 2 + 0.1, z + 0.3),
			C.Mustard,
			Build.Neon
		)
		Build.Soft(b)
		Build.RushNeon(b)
	end
	-- Legs down to the cornice
	for _, side in { -1, 1 } do
		softBox(ctx, "MarqueeLeg", Vector3.new(0.6, 2, 0.6), side * (w / 2 - 3), y - h / 2 - 0.8, z - 0.4, C.Charcoal)
	end
end

-- Kitchen and dining floors plus the interior dressing shared by tiers 1 and 2.
local function interior(ctx: Ctx, height: number)
	local inner = ctx.wx - 0.5
	paintedFloor(ctx, "KitchenFloor", -inner, inner, ZB + 0.5, ZD, C.CreamLight, C.MintPale, 2.6)
	paintedFloor(ctx, "Floor", -inner, inner, ZD, ZF - 0.5, C.CreamLight, C.Slate, 3.4)
	-- A cream runner rug down the customer aisle, door to counter
	local rug = box(ctx, "AisleRug", Vector3.new(6, 0.04, ZF - ZD - 4), 0, F + 0.12, (ZD + ZF) / 2 - 1, C.Cream)
	rug.CanCollide = false
	box(ctx, "RugBorder", Vector3.new(6.6, 0.03, ZF - ZD - 3.4), 0, F + 0.11, (ZD + ZF) / 2 - 1, ctx.accent).CanCollide =
		false
	menuBoard(ctx, -4.75, F + 8.6, 16)
	wallClock(ctx, 14, F + 8.6)
	pendants(ctx, F + height - 1.2, Layout.CounterZ, ctx.wx * 2 - 1, { -15, -5, 5, 15 }, 14)
	pottedPlant(ctx, -(ctx.wx - 2), ZF - 2.5, 1.1)
	pottedPlant(ctx, ctx.wx - 2, ZF - 2.5, 1.1)
	pottedPlant(ctx, ctx.wx - 2, ZD + 1.5, 0.9)
end

-- ── Tiers ────────────────────────────────────────────────────────────────────

-- Tier 0: open-air food stand at the back of the lot. Plank deck under the kitchen and stools, a
-- slatted back wall with the menu, a scalloped awning over the kitchen, bunting, a paved terrace with
-- the picnic tables (built by Dining) and a garden arch at the Door.
local function tierStand(ctx: Ctx)
	local wx = ctx.wx
	paintedFloor(ctx, "Deck", -(wx - 1), wx - 1, ZB + 0.5, Layout.StandFrontZ, C.Wood, C.WoodLight, 1.4, true)
	box(ctx, "DeckEdge", Vector3.new(wx * 2 - 1.6, 0.35, 0.5), 0, F + 0.17, Layout.StandFrontZ, C.WoodDark)
	-- Terrace: pale paving with a cream border in front of the stand, where the patio tables stand
	local tz0, tz1 = Layout.StandFrontZ, ZF - 1
	box(ctx, "TerraceBorder", Vector3.new(wx * 2 - 1, 0.08, tz1 - tz0 + 1), 0, F + 0.04, (tz0 + tz1) / 2, C.CreamLight)
	box(ctx, "Terrace", Vector3.new(wx * 2 - 3, 0.1, tz1 - tz0 - 1), 0, F + 0.05, (tz0 + tz1) / 2, C.Sand)
	-- Slatted back wall (one part, painted slats)
	local wallH = 9.5
	local wall = box(ctx, "SlatWall", Vector3.new(wx * 2 - 2, wallH, 0.6), 0, F + wallH / 2, ZB + 0.3, C.Wood)
	Build.Checker(wall, Enum.NormalId.Back, 1, 5, C.WoodLight)
	menuBoard(ctx, 0, F + 8.2, 18)
	-- Corner posts holding the awning
	local awningDepth = 9.3
	for _, x in { -(wx - 1), wx - 1 } do
		box(ctx, "Post", Vector3.new(0.9, 12.5, 0.9), x, F + 6.25, ZB + 0.3, C.WoodDark)
		box(ctx, "Post", Vector3.new(0.9, 10.6, 0.9), x, F + 5.3, ZB + awningDepth + 0.6, C.WoodDark)
		Build.Ball(ctx.shell, "PostCap", Vector3.new(1.3, 1.3, 1.3), at(ctx, x, F + 12.7, ZB + 0.3), ctx.accent)
	end
	awning(ctx, 0, wx * 2 - 1, 12, awningDepth, 1.6, F + 12.4, ZB + 0.6)
	-- String lights along the awning edge, under the scallops; keep them off the menu board
	local edgeY = F + 12.4 - 1.6 - 0.9 - 0.95
	local boardAvoid = { x0 = -10, x1 = 10, y0 = F + 8.2 - 2.8, y1 = F + 8.2 + 2.8 }
	local edgeZ = ZB + awningDepth + 0.6
	stringLights(ctx, Vector3.new(-(wx - 1), edgeY, edgeZ), Vector3.new(wx - 1, edgeY, edgeZ), 14, 0.5, 4, boardAvoid)
	-- Bunting from the front posts out to the terrace lamp poles
	for _, side in { -1, 1 } do
		local px = side * (wx - 1.5)
		box(ctx, "LightPole", Vector3.new(0.6, 8.5, 0.6), px, F + 4.25, ZF - 1.5, C.WoodDark)
		stringLights(ctx, Vector3.new(side * (wx - 1), F + 10, edgeZ), Vector3.new(px, F + 8.3, ZF - 1.5), 8, 0.9, 4)
	end
	-- Produce crates and potted plants at the deck corners
	for i, x in { -(wx - 4.5), wx - 4.5 } do
		box(ctx, "Crate", Vector3.new(2.4, 1.6, 2), x, F + 0.8, Layout.StandFrontZ - 2, C.WoodLight)
		box(ctx, "CrateSlat", Vector3.new(2.5, 0.25, 2.1), x, F + 1.1, Layout.StandFrontZ - 2, C.Wood)
		for k = 1, 3 do
			local color = if i == 1 then C.Ketchup else C.Lettuce
			Build.Ball(
				ctx.shell,
				"Produce",
				Vector3.new(0.8, 0.8, 0.8),
				at(ctx, x + (k - 2) * 0.7, F + 1.85, Layout.StandFrontZ - 2 + (k % 2) * 0.4),
				color
			)
		end
	end
	-- Garden arch over the Door: two posts, a beam with a WELCOME board and leafy tops
	local ah = Layout.Yard.ArchHalf
	for _, side in { -1, 1 } do
		box(ctx, "ArchPost", Vector3.new(0.6, 7.6, 0.6), side * ah, F + 3.8, ZF, C.CreamLight)
		Build.Dome(ctx.shell, "ArchVine", Vector3.new(2, 1.8, 1.6), at(ctx, side * (ah - 0.6), F + 7.8, ZF), C.Leaf)
	end
	softBox(ctx, "ArchBeam", Vector3.new(ah * 2 + 1.2, 0.6, 1.1), 0, F + 7.6, ZF, C.CreamLight)
	local welcome = softBox(ctx, "ArchBoard", Vector3.new(5.6, 1.3, 0.25), 0, F + 8.6, ZF + 0.2, ctx.accent)
	Build.Text(welcome, "WELCOME", C.CreamLight)
end

-- Tier 1: an enclosed diner. Checker dining room, glazed side walls, facade with awnings, a marquee.
local function tierDiner(ctx: Ctx)
	local height = 11
	shellWalls(ctx, height - 1)
	facade(ctx, height, 5, true)
	interior(ctx, height)
	marquee(ctx, F + height + 2.6, 26, 3, "RUSH HOUR DINER", 9)
end

-- Rooftop burger statue on the canopy: the tier 2 landmark.
local function burgerStatue(ctx: Ctx, x: number, y: number, z: number)
	local parts: { BasePart } = {
		Build.Cylinder(ctx.shell, "StatueBase", 4, 0.8, at(ctx, x, y + 0.4, z), C.Charcoal),
		Build.Cylinder(ctx.shell, "StatueBunBottom", 5.6, 1.2, at(ctx, x, y + 1.4, z), C.Bun),
		Build.Cylinder(ctx.shell, "StatuePatty", 6, 1, at(ctx, x, y + 2.5, z), C.Patty),
		Build.Part(
			ctx.shell,
			"StatueCheese",
			Vector3.new(5.2, 0.25, 5.2),
			at(ctx, x, y + 3.1, z) * CFrame.Angles(0, math.pi / 4, 0),
			C.Mustard
		),
		Build.Cylinder(ctx.shell, "StatueLettuce", 6.2, 0.35, at(ctx, x, y + 3.35, z), C.Lettuce),
		Build.Dome(ctx.shell, "StatueBunTop", Vector3.new(6, 3.8, 6), at(ctx, x, y + 4.1, z), C.Bun),
	}
	Build.SoftAll(parts)
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		local seed = Build.Ball(
			ctx.shell,
			"StatueSeed",
			Vector3.new(0.5, 0.35, 0.8),
			at(ctx, x + math.cos(a) * 1.6, y + 5.75, z + math.sin(a) * 1.6),
			C.CreamLight
		)
		Build.Soft(seed)
	end
end

-- Jukebox against the left wall, facing +X into the room (6 parts).
local function jukebox(ctx: Ctx, x: number, z: number)
	local base = ctx.plotCF * CFrame.new(x, F, z) * CFrame.Angles(0, math.pi / 2, 0)
	Build.Part(ctx.shell, "Jukebox", Vector3.new(3, 3.6, 2), base * CFrame.new(0, 1.8, 0), C.WoodDark)
	Build.Disc(ctx.shell, "JukeboxTop", 3, 2, base * CFrame.new(0, 3.6, 0), C.WoodDark)
	local arch = Build.Disc(ctx.shell, "JukeboxArch", 2.4, 0.2, base * CFrame.new(0, 3.6, 1.05), C.NeonPink, Build.Neon)
	Build.RushNeon(arch, 10, 1.5)
	Build.Disc(ctx.shell, "JukeboxWindow", 1.8, 0.2, base * CFrame.new(0, 3.6, 1.1), C.MustardPale)
	Build.Part(ctx.shell, "JukeboxGrille", Vector3.new(2.2, 1.4, 0.15), base * CFrame.new(0, 1.3, 1.05), C.Chrome)
end

-- Glass pie case on a cream cabinet against the right wall, facing -X (7 parts).
local function pieCase(ctx: Ctx, x: number, z: number)
	box(ctx, "PieCabinet", Vector3.new(2.6, 3.2, 6), x, F + 1.6, z, C.CreamLight)
	box(ctx, "PieBand", Vector3.new(2.7, 0.5, 6.1), x, F + 2.6, z, ctx.accent)
	local case = box(ctx, "PieGlass", Vector3.new(2.4, 1.8, 5.8), x, F + 4.1, z, C.MintPale, Build.Glass)
	case.Transparency = 0.5
	for i, color in { C.Ketchup, C.Bun, C.MustardPale } do
		Build.Cylinder(ctx.shell, "Pie", 1.5, 0.45, at(ctx, x, F + 3.5, z + (i - 2) * 1.8), color)
	end
	box(ctx, "PieLid", Vector3.new(2.6, 0.25, 6), x, F + 5.1, z, C.Chrome)
end

-- Bistro set: round table with two chairs facing each other along X (7 parts, decor only).
local function bistroSet(ctx: Ctx, x: number, z: number)
	Build.Cylinder(ctx.shell, "BistroTop", 3, 0.25, at(ctx, x, F + 3, z), C.CreamLight)
	Build.Cylinder(ctx.shell, "BistroLeg", 0.4, 2.9, at(ctx, x, F + 1.45, z), C.Chrome)
	Build.Cylinder(ctx.shell, "BistroVase", 0.5, 0.8, at(ctx, x, F + 3.5, z), ctx.accent)
	for _, side in { -1, 1 } do
		local cx = x + side * 2.3
		Build.Cylinder(ctx.shell, "BistroChair", 1.6, 0.4, at(ctx, cx, F + 1.9, z), ctx.accent)
		Build.Cylinder(ctx.shell, "BistroChairLeg", 0.3, 1.7, at(ctx, cx, F + 0.85, z), C.Chrome)
	end
end

-- Striped canvas roof over the patio from the facade out to PatioZ1, with a scalloped valance.
local function patioCover(ctx: Ctx, yWall: number, yEdge: number)
	local wx = ctx.wx
	local z1 = Layout.PatioZ1
	local depth = z1 - ZF
	awning(ctx, 0, wx * 2 + 1, 11, depth, yWall - yEdge, yWall, ZF + 0.4, true)
	-- Front posts and beam (posts leave the aisle at x = 0 clear)
	for _, x in { -(wx - 0.6), -22, -6, 6, 22, wx - 0.6 } do
		box(ctx, "PatioPost", Vector3.new(0.8, yEdge - F - 1, 0.8), x, F + (yEdge - F - 1) / 2, z1 - 0.6, C.CreamLight)
	end
	softBox(ctx, "PatioBeam", Vector3.new(wx * 2 + 0.6, 0.6, 0.9), 0, yEdge - 1.2, z1 - 0.6, C.WoodDark)
end

-- Tier 2: the big neon diner with a covered patio.
local function tierBig(ctx: Ctx)
	local height = 12.5
	shellWalls(ctx, height - 1.5)
	facade(ctx, height, 4, false)
	interior(ctx, height)
	marquee(ctx, F + height + 3.2, 30, 3.6, "RUSH HOUR DINER", 11)
	local eat = box(ctx, "EatSign", Vector3.new(5, 1.8, 0.2), 22, F + 8.8, ZB + 0.7, C.NeonPink, Build.Neon)
	Build.RushNeon(eat, 12, 1.5)
	Build.Text(eat, "EAT", C.CreamLight)
	-- Pendants over the tables
	pendants(ctx, F + height - 1.5, -9.5, ctx.wx * 2 - 1, { -15, 15, 25.2 }, 12)
	jukebox(ctx, -(ctx.wx - 1.6), -17)
	pieCase(ctx, ctx.wx - 1.9, -16)
	pottedPlant(ctx, -(ctx.wx - 2), ZD + 1.5, 0.9)
	-- Neon trim along the cornice and up the outer pilasters
	local wx = ctx.wx
	local trim = softBox(
		ctx,
		"NeonTrim",
		Vector3.new(wx * 2 + 2.6, 0.22, 0.22),
		0,
		F + height - 0.45,
		ZF + 1.7,
		C.Mint,
		Build.Neon
	)
	Build.RushNeon(trim)
	for _, side in { -1, 1 } do
		local v = softBox(
			ctx,
			"NeonTrim",
			Vector3.new(0.22, height - 1, 0.22),
			side * (wx + 0.1),
			F + (height - 1) / 2,
			ZF + 0.95,
			C.Mint,
			Build.Neon
		)
		Build.RushNeon(v)
	end
	-- Vertical DINER blade sign on the right corner of the roofline
	local bx, bz = wx - 3, ZF - 1
	local blade = Build.Part(ctx.shell, "BladeSign", Vector3.new(1, 9, 3), at(ctx, bx, F + height + 4.5, bz), C.Ink)
	Build.Soft(blade)
	local bladeNeon =
		softBox(ctx, "BladeNeon", Vector3.new(1.2, 9.4, 0.25), bx, F + height + 4.5, bz + 1.55, C.NeonPink, Build.Neon)
	Build.RushNeon(bladeNeon, 14, 1.6)
	Build.Text(blade, "D\nI\nN\nE\nR", C.CreamLight, Enum.NormalId.Left)
	Build.Text(blade, "D\nI\nN\nE\nR", C.CreamLight, Enum.NormalId.Right)
	burgerStatue(ctx, -(wx - 8), F + height + 0.2, ZF - 2.5)
	-- Covered patio: tiled floor, striped canvas, bistro tables, planters and string lights
	paintedFloor(ctx, "PatioFloor", -wx, wx, ZF + 0.5, Layout.PatioZ1, C.CreamShade, C.Terracotta, 4, false, 0.02)
	patioCover(ctx, F + height - 1.5, F + 10)
	for _, x in { -30, -14, 14, 30 } do
		bistroSet(ctx, x, 10.5)
	end
	for _, side in { -1, 1 } do
		planter(ctx, side * 14, Layout.PatioZ1 - 0.6, 12)
		planter(ctx, side * 31, Layout.PatioZ1 - 0.6, 14)
		stringLights(
			ctx,
			Vector3.new(side * 7, F + 9.2, ZF + 1),
			Vector3.new(side * (wx - 1), F + 8.6, Layout.PatioZ1 - 1),
			7,
			0.8,
			3
		)
	end
end

function Shells.Build(shell: Folder, plotCF: CFrame, accent: Color3, tier: number)
	local ctx: Ctx = {
		shell = shell,
		plotCF = plotCF,
		accent = accent,
		pale = PALE[accent:ToHex()] or C.Linen,
		wx = if tier >= 2 then Layout.WallXBig else Layout.WallX,
	}
	if tier <= 0 then
		tierStand(ctx)
	elseif tier == 1 then
		tierDiner(ctx)
	else
		tierBig(ctx)
	end
	Yard.Build(shell, plotCF, accent, tier)
end

return Shells

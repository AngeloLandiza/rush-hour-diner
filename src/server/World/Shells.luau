--!strict
-- Diner shells per decor tier (0 food stand, 1 small diner, 2 big neon diner). Built in plot-local space
-- (+Z = street) and placed with the plot CFrame. Never touches stations, seats or the named plot parts.
--
-- Art rules: warm neutral walls and floors, the plot accent only on awnings, stripes and trim; Neon only
-- on signs and bulbs (tagged RushNeon so they light up in Rush Hour). Diners are open-topped so the
-- kitchen stays readable from the gameplay camera; a front canopy and parapet give the street facade
-- a believable roofline.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Build = require("./Build")
local Layout = require("./Layout")
local Yard = require("./Yard")

local C = Palette.Color
local F = Layout.FloorY
local WX = Layout.WallX
local ZB = Layout.WallBackZ
local ZF = Layout.WallFrontZ
local DEPTH = ZF - ZB -- interior depth
local MIDZ = (ZB + ZF) / 2
local DOOR_HALF = Layout.DoorSize.X / 2
local DOOR_H = Layout.DoorSize.Y

local Shells = {}

type Ctx = { shell: Folder, plotCF: CFrame, accent: Color3, pale: Color3 }

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
	zWall: number
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

-- Wood plank floor inside x ∈ [-w/2, w/2], z ∈ [z0, z1].
local function plankFloor(ctx: Ctx, w: number, z0: number, z1: number, planks: number)
	local pd = (z1 - z0) / planks
	for i = 1, planks do
		local color = if i % 2 == 0 then C.Wood else C.WoodLight
		box(ctx, "Plank", Vector3.new(w, 0.12, pd - 0.08), 0, F + 0.06, z0 + (i - 0.5) * pd, color)
	end
end

-- Classic diner checkerboard: a cream floor with slate tiles on every other cell. The tiles are painted
-- on with a SurfaceGui (one part instead of 26), which keeps the max-decor part budget for the yard.
local function checkerFloor(ctx: Ctx)
	local w, d = WX * 2 - 1, DEPTH - 1
	local floor = box(ctx, "Floor", Vector3.new(w, 0.1, d), 0, F + 0.05, MIDZ, C.CreamLight)
	local tile = 5.8
	Build.Checker(floor, Enum.NormalId.Top, math.round(w / tile), math.round(d / tile), C.Slate)
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

-- Wooden planter box with a hedge and two flowers (street side of the facade).
local function planter(ctx: Ctx, x: number, z: number, w: number)
	box(ctx, "Planter", Vector3.new(w, 1.3, 1.6), x, F + 0.65, z, C.Wood)
	box(ctx, "PlanterRim", Vector3.new(w + 0.3, 0.2, 1.9), x, F + 1.35, z, C.WoodDark)
	Build.Ball(ctx.shell, "Hedge", Vector3.new(w - 0.2, 1.6, 1.4), at(ctx, x, F + 1.9, z), C.Leaf)
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
		Build.RushNeon(bulb, if i % lightEvery == 0 then 12 else nil, 1.2)
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

-- Hanging pendant lamps along a ceiling beam over the counter (warm, always on).
local function pendants(ctx: Ctx, beamY: number, z: number, xs: { number })
	softBox(ctx, "Beam", Vector3.new(WX * 2 - 1, 0.5, 0.6), 0, beamY, z, C.WoodDark)
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
		Build.Light(bulb, C.Lamp, 16, 0.9)
	end
end

-- ── Walls ────────────────────────────────────────────────────────────────────

-- Back and side walls, with an accent pinstripe and a cap. Interior faces get a mint-pale backsplash.
local function shellWalls(ctx: Ctx, height: number)
	local sideLen = DEPTH
	box(ctx, "BackWall", Vector3.new(WX * 2 + 1, height, 1), 0, F + height / 2, ZB, C.Linen)
	softBox(ctx, "WallCap", Vector3.new(WX * 2 + 1.6, 0.5, 1.6), 0, F + height + 0.25, ZB, C.CreamLight)
	box(ctx, "Backsplash", Vector3.new(WX * 2 - 1, 3.4, 0.15), 0, F + 5.4, ZB + 0.55, C.MintPale)
	box(ctx, "BacksplashTrim", Vector3.new(WX * 2 - 1, 0.3, 0.3), 0, F + 7.2, ZB + 0.6, ctx.accent)
	for _, side in { -1, 1 } do
		local x = side * WX
		box(ctx, "SideWall", Vector3.new(1, height, sideLen), x, F + height / 2, MIDZ, C.Linen)
		softBox(ctx, "WallCap", Vector3.new(1.6, 0.5, sideLen), x, F + height + 0.25, MIDZ, C.CreamLight)
		-- Outside: wainscot + accent stripe
		box(ctx, "SideWainscot", Vector3.new(0.2, 3.5, sideLen), x + side * 0.6, F + 1.75, MIDZ, C.CreamShade)
		box(ctx, "SideStripe", Vector3.new(0.25, 0.4, sideLen), x + side * 0.62, F + 3.7, MIDZ, ctx.accent)
	end
end

-- Street facade at z = ZF: kick plate, wainscot, accent stripe, big framed windows with awnings,
-- pilasters, a framed doorway with an OPEN sign, a cornice, and a shallow canopy roof behind it.
local function facade(ctx: Ctx, height: number, awningStripes: number)
	local sideW = WX - DOOR_HALF
	local lowerTop = F + 3.4
	local winTop = F + 8.6
	for _, side in { -1, 1 } do
		local cx = side * (DOOR_HALF + sideW / 2)
		box(ctx, "Kick", Vector3.new(sideW, 0.8, 1.3), cx, F + 0.4, ZF, C.ConcreteDark)
		box(ctx, "FrontLower", Vector3.new(sideW, lowerTop - F - 0.8, 1), cx, (lowerTop + F + 0.8) / 2, ZF, ctx.pale)
		box(ctx, "FrontStripe", Vector3.new(sideW, 0.45, 1.15), cx, lowerTop - 0.2, ZF, ctx.accent)
		box(ctx, "Sill", Vector3.new(sideW - 1, 0.3, 1.6), cx, lowerTop + 0.15, ZF + 0.1, C.Chrome)
		local glass = box(
			ctx,
			"Window",
			Vector3.new(sideW - 1, winTop - lowerTop - 0.3, 0.3),
			cx,
			(lowerTop + winTop) / 2 + 0.15,
			ZF,
			C.MintPale,
			Build.Glass
		)
		glass.Transparency = 0.55
		glass.CastShadow = false
		for _, m in { -1, 1 } do
			box(
				ctx,
				"Mullion",
				Vector3.new(0.35, winTop - lowerTop, 0.6),
				cx + m * sideW / 6,
				(lowerTop + winTop) / 2,
				ZF,
				C.Chrome
			)
		end
		box(ctx, "FrontUpper", Vector3.new(sideW, F + height - winTop, 1), cx, (winTop + F + height) / 2, ZF, C.Linen)
		-- Pilasters at the outer corner and beside the door
		for _, px in { side * (WX + 0.1), side * (DOOR_HALF + 0.5) } do
			box(ctx, "Pilaster", Vector3.new(1.4, height, 1.6), px, F + height / 2, ZF + 0.1, C.CreamLight)
		end
		awning(ctx, cx, sideW - 2, awningStripes, 3.2, 1.4, winTop + 1.6, ZF + 0.6)
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
	-- Cornice and canopy roof (soft so it never blocks the camera)
	softBox(ctx, "Cornice", Vector3.new(WX * 2 + 2.4, 0.7, 2.4), 0, F + height + 0.35, ZF + 0.4, C.CreamLight)
	softBox(ctx, "CorniceStripe", Vector3.new(WX * 2 + 2.5, 0.3, 2.5), 0, F + height - 0.15, ZF + 0.4, ctx.accent)
	softBox(ctx, "Canopy", Vector3.new(WX * 2, 0.5, 5), 0, F + height - 0.1, ZF - 2.5, C.CreamShade)
	-- Planters either side of the door
	for _, side in { -1, 1 } do
		planter(ctx, side * 7.5, ZF + 1.8, 4.5)
	end
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
	Build.RushNeon(tube, 14, 2)
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

-- ── Tiers ────────────────────────────────────────────────────────────────────

-- Tier 0: open-air food stand. Plank deck, slatted back wall with the menu, a scalloped striped awning
-- over the kitchen, bunting and a few props.
local function tierStand(ctx: Ctx)
	plankFloor(ctx, WX * 2 - 2, ZB + 0.5, -1, 7)
	-- Slatted back wall
	local wallH = 9.5
	for i = 1, 5 do
		local h = wallH / 5
		box(
			ctx,
			"Slat",
			Vector3.new(WX * 2 - 2, h - 0.15, 0.6),
			0,
			F + (i - 0.5) * h,
			ZB + 0.3,
			if i % 2 == 0 then C.WoodLight else C.Wood
		)
	end
	menuBoard(ctx, 0, F + 8.2, 18)
	-- Corner posts holding the awning
	for _, x in { -(WX - 1), WX - 1 } do
		box(ctx, "Post", Vector3.new(0.9, 12.5, 0.9), x, F + 6.25, ZB + 0.3, C.WoodDark)
		box(ctx, "Post", Vector3.new(0.9, 10.6, 0.9), x, F + 5.3, -15.2, C.WoodDark)
		Build.Ball(ctx.shell, "PostCap", Vector3.new(1.3, 1.3, 1.3), at(ctx, x, F + 12.7, ZB + 0.3), ctx.accent)
	end
	awning(ctx, 0, WX * 2 - 1, 12, 9.3, 1.6, F + 12.4, ZB + 0.6)
	-- String lights along the awning edge, under the scallops
	local edgeY = F + 12.4 - 1.6 - 0.9 - 0.95
	-- Menu board is 18 wide, 3.6 tall (frame) centred at F + 8.2: keep bulbs off it, with 1 stud margin.
	local boardAvoid = { x0 = -10, x1 = 10, y0 = F + 8.2 - 2.8, y1 = F + 8.2 + 2.8 }
	stringLights(ctx, Vector3.new(-(WX - 1), edgeY, -14.4), Vector3.new(WX - 1, edgeY, -14.4), 14, 0.5, 4, boardAvoid)
	-- Props: produce crates and potted plants (the yard adds the menu A-frame)
	for i, x in { -26.5, 26.5 } do
		box(ctx, "Crate", Vector3.new(2.4, 1.6, 2), x, F + 0.8, -3, C.WoodLight)
		box(ctx, "CrateSlat", Vector3.new(2.5, 0.25, 2.1), x, F + 1.1, -3, C.Wood)
		for k = 1, 3 do
			local color = if i == 1 then C.Ketchup else C.Lettuce
			Build.Ball(
				ctx.shell,
				"Produce",
				Vector3.new(0.8, 0.8, 0.8),
				at(ctx, x + (k - 2) * 0.7, F + 1.85, -3 + (k % 2) * 0.4),
				color
			)
		end
		pottedPlant(ctx, x, 3, 1)
	end
end

-- Tier 1: a small diner. Plank floor, cream walls, facade with windows and awnings, a marquee,
-- pendant lamps, menu board and plants.
local function tierDiner(ctx: Ctx)
	local height = 11
	plankFloor(ctx, WX * 2 - 1, ZB + 0.5, ZF - 0.5, 9)
	shellWalls(ctx, height - 1)
	facade(ctx, height, 5)
	marquee(ctx, F + height + 2.6, 24, 3, "RUSH HOUR DINER", 9)
	menuBoard(ctx, 0, F + 8.6, 16)
	wallClock(ctx, 17, F + 8.6)
	pendants(ctx, F + height - 1.2, -9, { -16, -5.5, 5.5, 16 })
	pottedPlant(ctx, -27, 3.5, 1.1)
	pottedPlant(ctx, 27, 3.5, 1.1)
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
		Build.Ball(ctx.shell, "StatueBunTop", Vector3.new(6, 3.8, 6), at(ctx, x, y + 4.1, z), C.Bun),
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

local function jukebox(ctx: Ctx, x: number, z: number)
	local base = ctx.plotCF * CFrame.new(x, F, z) * CFrame.Angles(0, math.pi / 2, 0) -- faces +X (into the room)
	Build.Part(ctx.shell, "Jukebox", Vector3.new(3, 3.6, 2), base * CFrame.new(0, 1.8, 0), C.WoodDark)
	Build.Disc(ctx.shell, "JukeboxTop", 3, 2, base * CFrame.new(0, 3.6, 0), C.WoodDark)
	local arch = Build.Disc(ctx.shell, "JukeboxArch", 2.4, 0.2, base * CFrame.new(0, 3.6, 1.05), C.NeonPink, Build.Neon)
	Build.RushNeon(arch, 10, 1.5)
	Build.Disc(ctx.shell, "JukeboxWindow", 1.8, 0.2, base * CFrame.new(0, 3.6, 1.1), C.MustardPale)
	Build.Part(ctx.shell, "JukeboxGrille", Vector3.new(2.2, 1.4, 0.15), base * CFrame.new(0, 1.3, 1.05), C.Chrome)
end

-- Tier 2: the big neon diner. Checker floor, taller facade, big marquee with neon, string lights over
-- the patio, a jukebox, pendant lamps, a neon EAT sign and the rooftop burger.
local function tierBig(ctx: Ctx)
	local height = 12.5
	checkerFloor(ctx)
	shellWalls(ctx, height - 1.5)
	facade(ctx, height, 4)
	marquee(ctx, F + height + 3.2, 28, 3.6, "RUSH HOUR DINER", 9)
	menuBoard(ctx, -4, F + 8.8, 16)
	wallClock(ctx, 14, F + 8.8)
	local eat = box(ctx, "EatSign", Vector3.new(5, 1.8, 0.2), 22, F + 8.8, ZB + 0.7, C.NeonPink, Build.Neon)
	Build.RushNeon(eat, 12, 1.5)
	Build.Text(eat, "EAT", C.CreamLight)
	pendants(ctx, F + height - 2, -9, { -16, -5.5, 5.5, 16 })
	-- Neon trim along the cornice and up the outer pilasters
	local trim = softBox(
		ctx,
		"NeonTrim",
		Vector3.new(WX * 2 + 2.6, 0.22, 0.22),
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
			side * (WX + 0.1),
			F + (height - 1) / 2,
			ZF + 0.95,
			C.Mint,
			Build.Neon
		)
		Build.RushNeon(v)
	end
	-- String lights from the facade out to two patio poles
	local poleZ = Layout.PlotSize.Z / 2 - 1.5
	for _, side in { -1, 1 } do
		local px = side * (WX - 1.5)
		box(ctx, "LightPole", Vector3.new(0.6, 9.5, 0.6), px, F + 4.75, poleZ, C.WoodDark)
		stringLights(ctx, Vector3.new(px, F + height - 1.2, ZF + 1.5), Vector3.new(px, F + 9.3, poleZ), 5, 0.9, 3)
	end
	stringLights(ctx, Vector3.new(-(WX - 1.5), F + 10.6, ZF + 4), Vector3.new(WX - 1.5, F + 10.6, ZF + 4), 11, 1.2, 4)
	jukebox(ctx, -(WX - 1.6), 1)
	pottedPlant(ctx, 27, 3.5, 1.1)
	burgerStatue(ctx, -21.5, F + height + 0.2, ZF - 2.5)
end

function Shells.Build(shell: Folder, plotCF: CFrame, accent: Color3, tier: number)
	local ctx: Ctx = { shell = shell, plotCF = plotCF, accent = accent, pale = PALE[accent:ToHex()] or C.Linen }
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

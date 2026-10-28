--!strict
-- The lot around the diner. Permanent parts (built once by MapBuilder): the brick path from the street
-- to the Door, the lot hedges and the lot trees. Per decor tier (into the Shell folder): garden lamp posts,
-- a chalkboard A-frame, queue rope stanchions, parasol tables and flower beds on the lawn (tiers 0-1)
-- and a delivery scooter (tier 2). Built in plot-local space (+Z = street). Every prop stays off the
-- customer walk (CustomerSpawn → Door runs down the path at x = 0) and under 10 parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Build = require("./Build")
local Layout = require("./Layout")

local C = Palette.Color
local F = Layout.FloorY
local Y = Layout.Yard
local PATH_W = Layout.DoorSize.X + 2

local Yard = {}

-- Brick path from z0 to z1 (plot local) on a cream border, with a cream/ink checker runner painted down
-- the middle (3 parts).
function Yard.Path(parent: Instance, plotCF: CFrame, z0: number, z1: number)
	local len = z1 - z0
	local z = (z0 + z1) / 2
	Build.Part(parent, "Path", Vector3.new(PATH_W, 0.08, len), plotCF * CFrame.new(0, F + 0.04, z), C.CreamLight)
	local brickW = PATH_W - 2 * Y.PathBorder
	local brick = Build.Part(
		parent,
		"PathBrick",
		Vector3.new(brickW, 0.1, len),
		plotCF * CFrame.new(0, F + 0.05, z),
		C.Terracotta,
		Build.BrickMat
	)
	local half = Y.RunnerWidth / 2 / brickW
	local rows = math.max(1, math.round(len / Y.RunnerCell))
	Build.Checker(brick, Enum.NormalId.Top, 2, rows, C.Cream, C.Ink, 0.5 - half, 0.5 + half)
end

-- Round-canopy tree (4 parts).
function Yard.Tree(parent: Instance, base: CFrame, scale: number)
	Build.Cylinder(parent, "Trunk", 1.1 * scale, 5 * scale, base * CFrame.new(0, 2.5 * scale, 0), C.WoodDark)
	Build.Ball(parent, "Canopy", Vector3.new(7, 6, 7) * scale, base * CFrame.new(0, 6.5 * scale, 0), C.Leaf)
	Build.Ball(
		parent,
		"Canopy",
		Vector3.new(4.6, 4.2, 4.6) * scale,
		base * CFrame.new(1.6 * scale, 8.4 * scale, 0.8 * scale),
		C.Leaf
	)
	Build.Ball(
		parent,
		"Canopy",
		Vector3.new(4, 3.6, 4) * scale,
		base * CFrame.new(-1.8 * scale, 7.8 * scale, -1 * scale),
		C.LeafDark
	)
end

-- Permanent lot dressing: hedges on the back and sides, a street-edge hedge with a gap for the path, the
-- path itself and the lot trees.
function Yard.Lot(model: Model, cf: CFrame)
	local hx, hz = Layout.PlotSize.X / 2, Layout.PlotSize.Z / 2
	local function hedge(x: number, z: number, w: number, d: number)
		Build.Part(model, "HedgeBox", Vector3.new(w, 0.9, d), cf * CFrame.new(x, F + 0.45, z), C.Wood)
		Build.Part(model, "Hedge", Vector3.new(w - 0.3, 1.3, d - 0.3), cf * CFrame.new(x, F + 1.45, z), C.Leaf)
	end
	local edgeW = hx - PATH_W / 2 - 1
	for _, side in { -1, 1 } do
		hedge(side * (PATH_W / 2 + edgeW / 2 + 0.5), hz - 1, edgeW, 1.6)
		hedge(side * (hx - 1), 0, 1.6, Layout.PlotSize.Z - 4)
	end
	hedge(0, -(hz - 1), Layout.PlotSize.X - 2, 1.6)
	Yard.Path(model, cf, Layout.WallFrontZ, hz)
	for _, t in Y.LotTrees do
		Yard.Tree(model, cf * CFrame.new(t[1], F, t[2]), t[3])
	end
end

-- Round bistro table under a parasol, with two stools (6 parts).
local function tableSet(parent: Instance, base: CFrame, canopy: Color3)
	Build.Cylinder(parent, "PatioTable", 3.2, 0.22, base * CFrame.new(0, 2.7, 0), C.CreamLight)
	Build.Cylinder(parent, "PatioTableLeg", 0.5, 2.6, base * CFrame.new(0, 1.3, 0), C.Chrome)
	Build.Soft(Build.Cylinder(parent, "ParasolPole", 0.18, 3.6, base * CFrame.new(0, 4.6, 0), C.Chrome))
	local shade = Build.Dome(parent, "Parasol", Vector3.new(6.2, 1.6, 6.2), base * CFrame.new(0, 6.1, 0), canopy)
	Build.Soft(shade)
	for _, side in { -1, 1 } do
		Build.Cylinder(parent, "PatioStool", 1.4, 1.7, base * CFrame.new(side * 2.3, 0.85, 0), C.Wood)
	end
end

-- Two chrome stanchions with a velvet rope between them, along z (3 parts).
local function queueRope(parent: Instance, plotCF: CFrame, x: number)
	local z0, z1 = Y.RopeZ[1], Y.RopeZ[2]
	for _, z in { z0, z1 } do
		Build.Cylinder(parent, "Stanchion", 0.4, 3, plotCF * CFrame.new(x, F + 1.5, z), C.Chrome)
	end
	local rope = Build.Rod(
		parent,
		"QueueRope",
		0.3,
		z1 - z0,
		plotCF * CFrame.new(x, F + 2.6, (z0 + z1) / 2) * CFrame.Angles(0, math.pi / 2, 0),
		C.KetchupDeep
	)
	Build.Soft(rope)
end

-- Short garden lamp post with a warm globe (3 parts, always lit like the street lamps).
local function lampPost(parent: Instance, plotCF: CFrame, x: number, z: number)
	local base = plotCF * CFrame.new(x, F, z)
	Build.Cylinder(parent, "YardLampPole", 0.35, 5, base * CFrame.new(0, 2.5, 0), C.Ink)
	local globe = Build.Ball(
		parent,
		"YardLampGlobe",
		Vector3.new(1.2, 1.4, 1.2),
		base * CFrame.new(0, 5.6, 0),
		C.Lamp,
		Build.Neon
	)
	globe.CastShadow = false
	Build.Light(globe, C.Lamp, 14, 0.8)
	Build.Cylinder(parent, "YardLampCap", 0.8, 0.25, base * CFrame.new(0, 6.4, 0), C.Ink)
end

-- Chalkboard A-frame facing the street (+Z of `base`) (3 parts).
local function aFrame(parent: Instance, base: CFrame, text: string)
	for _, side in { -1, 1 } do
		Build.Wedge(
			parent,
			"AFrame",
			Vector3.new(2.8, 3.4, 1),
			base * CFrame.new(0, 1.7, side * 0.5) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			C.WoodDark
		)
	end
	local board = Build.Part(
		parent,
		"AFrameBoard",
		Vector3.new(2.3, 2, 0.1),
		base * CFrame.new(0, 1.7, 0.56) * CFrame.Angles(-0.29, 0, 0),
		C.Charcoal
	)
	Build.Text(board, text, C.Cream)
end

-- Low flower bed: a wooden border with a row of shrubs and flowers (5 parts).
local function flowerBed(parent: Instance, plotCF: CFrame, x: number, z: number)
	local base = plotCF * CFrame.new(x, F, z)
	Build.Part(parent, "BedBorder", Vector3.new(3, 0.6, 10), base * CFrame.new(0, 0.3, 0), C.WoodDark)
	Build.Part(parent, "BedSoil", Vector3.new(2.6, 0.62, 9.6), base * CFrame.new(0, 0.32, 0), C.Patty)
	Build.Dome(parent, "BedShrub", Vector3.new(2.4, 1.8, 4), base * CFrame.new(0, 1.2, -2.6), C.Leaf)
	Build.Dome(parent, "BedShrub", Vector3.new(2.4, 1.6, 3.6), base * CFrame.new(0, 1.1, 2.6), C.LeafDark)
	Build.Dome(parent, "BedFlowers", Vector3.new(2, 1.2, 2), base * CFrame.new(0, 1.1, 0), C.KetchupSoft)
end

-- Parked delivery scooter, side-on to the street (8 parts).
local function scooter(parent: Instance, base: CFrame)
	Build.Part(parent, "ScooterDeck", Vector3.new(3.4, 0.45, 1.1), base * CFrame.new(0, 1, 0), C.Mint)
	Build.Part(parent, "ScooterBody", Vector3.new(1.8, 0.8, 1), base * CFrame.new(-0.5, 1.6, 0), C.Mint)
	Build.Part(parent, "ScooterSeat", Vector3.new(1.1, 0.3, 0.9), base * CFrame.new(0.1, 2.15, 0), C.Ink)
	for _, x in { -1.4, 1.4 } do
		Build.Disc(parent, "ScooterWheel", 1.2, 0.45, base * CFrame.new(x, 0.6, 0), C.Charcoal)
	end
	Build.Part(
		parent,
		"ScooterColumn",
		Vector3.new(0.35, 2.2, 0.6),
		base * CFrame.new(1.45, 2.1, 0) * CFrame.Angles(0, 0, -0.25),
		C.Mint
	)
	Build.Rod(
		parent,
		"ScooterBars",
		0.2,
		1.8,
		base * CFrame.new(1.75, 3.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		C.Chrome
	)
	local box = Build.Part(parent, "ScooterBox", Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(-1, 2.65, 0), C.Ketchup)
	Build.Text(box, "EATS", C.CreamLight)
end

-- Per-tier yard props: parasol tables and flower beds on the lawn, lamps, rope and menu; tier 2 adds
-- the delivery scooter.
function Yard.Build(shell: Folder, plotCF: CFrame, accent: Color3, tier: number)
	for _, side in { -1, 1 } do
		queueRope(shell, plotCF, side * Y.RopeX)
		for _, z in Y.LampZ do
			lampPost(shell, plotCF, side * Y.LampX, z)
		end
		-- Tier 2's patio covers the lawn tables' spot, so they move out toward the street
		local tableZ = if tier >= 2 then Y.TableZBig else Y.TableZ
		tableSet(shell, plotCF * CFrame.new(side * Y.TableX, F, tableZ), accent)
		flowerBed(shell, plotCF, side * Y.FlowerBedX, Y.FlowerBedZ)
	end
	aFrame(shell, plotCF * CFrame.new(Y.MenuPos.X, F, Y.MenuPos.Z) * CFrame.Angles(0, 0.35, 0), "MENU")
	if tier >= 2 then
		scooter(shell, plotCF * CFrame.new(Y.ScooterPos.X, F, Y.ScooterPos.Z))
	end
end

return Yard

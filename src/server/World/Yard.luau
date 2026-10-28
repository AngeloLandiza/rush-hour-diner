--!strict
-- Front yard of a plot: a brick path with a checker runner, umbrella tables, lamp posts, a chalkboard
-- A-frame, queue rope stanchions by the entrance, planters (tier 0) and a delivery scooter (tier 2).
-- Built in plot-local space (+Z = street) into the Shell folder, so it is rebuilt with the decor tier.
-- Every prop stays off the customer walk (see Layout.Yard) and under 10 parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Build = require("./Build")
local Layout = require("./Layout")

local C = Palette.Color
local F = Layout.FloorY
local Y = Layout.Yard
local PATH_W = Layout.DoorSize.X + 2

local Yard = {}

-- Brick path from z0 to z1 (plot local) with a cream/ink checker runner painted down the middle.
-- border = true adds the cream border slab underneath (the permanent street-to-door path).
function Yard.Path(parent: Instance, plotCF: CFrame, z0: number, z1: number, border: boolean)
	local len = z1 - z0
	local z = (z0 + z1) / 2
	if border then
		Build.Part(parent, "Path", Vector3.new(PATH_W, 0.08, len), plotCF * CFrame.new(0, F + 0.04, z), C.CreamLight)
	end
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

-- Round bistro table under a parasol, with two stools (6 parts).
local function tableSet(parent: Instance, base: CFrame, canopy: Color3)
	Build.Cylinder(parent, "PatioTable", 3.2, 0.22, base * CFrame.new(0, 2.7, 0), C.CreamLight)
	Build.Cylinder(parent, "PatioTableLeg", 0.5, 2.6, base * CFrame.new(0, 1.3, 0), C.Chrome)
	Build.Soft(Build.Cylinder(parent, "ParasolPole", 0.18, 3.6, base * CFrame.new(0, 4.6, 0), C.Chrome))
	local shade = Build.Ball(parent, "Parasol", Vector3.new(6.2, 1.5, 6.2), base * CFrame.new(0, 6.1, 0), canopy)
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

-- Terracotta pot with a round shrub and one flower (3 parts).
local function planter(parent: Instance, plotCF: CFrame, x: number, z: number, flower: Color3)
	local base = plotCF * CFrame.new(x, F, z)
	Build.Cylinder(parent, "YardPot", 2.2, 1.8, base * CFrame.new(0, 0.9, 0), C.Terracotta)
	Build.Ball(parent, "YardShrub", Vector3.new(2.6, 2.3, 2.6), base * CFrame.new(0, 2.5, 0), C.Leaf)
	Build.Ball(parent, "YardFlower", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0.5, 3.5, 0.4), flower)
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

-- Tier 0 gets corner planters and the path stub up to the stand; tiers 1-2 already have facade
-- planters. Tier 2 adds the delivery scooter.
function Yard.Build(shell: Folder, plotCF: CFrame, accent: Color3, tier: number)
	if tier <= 0 then
		Yard.Path(shell, plotCF, Y.StandPathZ0, Layout.WallFrontZ, false)
	end
	for _, side in { -1, 1 } do
		tableSet(shell, plotCF * CFrame.new(side * Y.TableX, F, Y.TableZ), accent)
		queueRope(shell, plotCF, side * Y.RopeX)
		lampPost(shell, plotCF, side * Y.LampX, Y.LampZ)
		if tier <= 0 then
			planter(shell, plotCF, side * Y.PlanterX, Y.PlanterZ, if side < 0 then C.Ketchup else C.Mustard)
		end
	end
	aFrame(shell, plotCF * CFrame.new(Y.MenuPos.X, F, Y.MenuPos.Z) * CFrame.Angles(0, 0.35, 0), "MENU")
	if tier >= 2 then
		scooter(shell, plotCF * CFrame.new(Y.ScooterPos.X, F, Y.ScooterPos.Z))
	end
end

return Yard

--!strict
-- Diner shells per decor tier (0 stand, 1 small diner, 2 big chaotic diner). Built in plot-local space
-- and placed with the plot CFrame. Never touches stations, seats or the named plot parts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Layout = require("./Layout")
local Build = require("./Build")

local C = Palette.Color
local NEON = Enum.Material.Neon
local F = Layout.FloorY
local WX = Layout.WallX
local ZB = Layout.WallBackZ
local ZF = Layout.WallFrontZ
local DEPTH = ZF - ZB -- interior depth

local Shells = {}

type Ctx = { shell: Folder, plotCF: CFrame, accent: Color3 }

local function box(ctx: Ctx, name: string, size: Vector3, x: number, y: number, z: number, color: Color3): Part
	return Build.Part(ctx.shell, name, size, ctx.plotCF * CFrame.new(x, y, z), color)
end

local function softBox(ctx: Ctx, name: string, size: Vector3, x: number, y: number, z: number, color: Color3): Part
	local p = box(ctx, name, size, x, y, z, color)
	Build.Soft(p)
	return p
end

local function label(part: BasePart, text: string, textColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Back -- the +Z (street) face in plot space
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = textColor
	t.Parent = gui
	gui.Parent = part
end

local function awningStripes(ctx: Ctx, count: number, width: number, depth: number, y: number, z: number)
	local stripeW = width / count
	for i = 1, count do
		local x = (i - (count + 1) / 2) * stripeW
		local color = if i % 2 == 0 then C.Cream else ctx.accent
		local p = Build.Part(
			ctx.shell,
			"AwningStripe",
			Vector3.new(stripeW, 0.4, depth),
			ctx.plotCF * CFrame.new(x, y, z) * CFrame.Angles(0.14, 0, 0),
			color
		)
		Build.Soft(p)
		local v = Build.Part(
			ctx.shell,
			"AwningValance",
			Vector3.new(stripeW, 1.2, 0.3),
			ctx.plotCF * CFrame.new(x, y - 0.8, z + depth / 2 - 0.1),
			color
		)
		Build.Soft(v)
	end
end

local function tierStand(ctx: Ctx)
	for _, x in { -26, 26 } do
		for _, z in { -6, -23 } do
			Build.Cylinder(ctx.shell, "Post", 0.8, 9, ctx.plotCF * CFrame.new(x, F + 4.5, z), C.Ink)
		end
	end
	box(ctx, "BackPanel", Vector3.new(52, 8, 0.6), 0, F + 4, ZB + 0.5, C.Mint)
	awningStripes(ctx, 8, 56, 18, F + 9.4, -14.5)
end

local function frontWall(ctx: Ctx, height: number)
	local doorHalf = Layout.DoorSize.X / 2
	local sideW = WX - doorHalf
	local lowerH, winH = 3.5, height - 6
	for _, side in { -1, 1 } do
		local cx = side * (doorHalf + sideW / 2)
		box(ctx, "FrontLower", Vector3.new(sideW, lowerH, 1), cx, F + lowerH / 2, ZF, C.Cream)
		local win = box(ctx, "Window", Vector3.new(sideW - 3, winH, 0.4), cx, F + lowerH + winH / 2, ZF, C.Mint)
		win.Transparency = 0.35
		win.CanCollide = false
		box(ctx, "FrontUpper", Vector3.new(sideW, height - lowerH - winH, 1), cx, F + height - 1.25, ZF, C.Cream)
	end
	local lintelH = height - Layout.DoorSize.Y
	box(ctx, "Lintel", Vector3.new(doorHalf * 2, lintelH, 1), 0, F + height - lintelH / 2, ZF, C.Cream)
	for _, side in { -1, 1 } do
		box(
			ctx,
			"DoorFrame",
			Vector3.new(0.8, Layout.DoorSize.Y, 1.2),
			side * doorHalf,
			F + Layout.DoorSize.Y / 2,
			ZF,
			ctx.accent
		)
	end
end

local function shellWalls(ctx: Ctx, height: number)
	box(ctx, "BackWall", Vector3.new(WX * 2, height, 1), 0, F + height / 2, ZB, C.Cream)
	local sideLen = DEPTH - 1
	for _, side in { -1, 1 } do
		box(ctx, "SideWall", Vector3.new(1, height, sideLen), side * WX, F + height / 2, (ZB + ZF) / 2, C.Cream)
	end
	frontWall(ctx, height)
	-- Floor
	box(ctx, "Floor", Vector3.new(WX * 2 - 1, 0.1, sideLen), 0, F + 0.05, (ZB + ZF) / 2, C.CreamShade)
end

local function roof(ctx: Ctx, height: number)
	softBox(ctx, "RoofSlab", Vector3.new(WX * 2 + 2, 1, DEPTH + 3), 0, F + height + 0.5, (ZB + ZF) / 2 + 1, ctx.accent)
	softBox(ctx, "RoofLip", Vector3.new(WX * 2 + 2.4, 0.6, 0.8), 0, F + height + 0.2, ZF + 1.8, C.Cream)
	local chimney = Build.Cylinder(ctx.shell, "Chimney", 2, 4, ctx.plotCF * CFrame.new(-18, F + height + 3, -18), C.Ink)
	Build.Soft(chimney)
end

local function tierDiner(ctx: Ctx)
	local height = 11
	shellWalls(ctx, height)
	roof(ctx, height)
	-- Little striped awning over the door
	awningStripes(ctx, 4, 10, 4, F + Layout.DoorSize.Y + 1.2, ZF + 2.6)
	for _, side in { -1, 1 } do
		Build.Ball(
			ctx.shell,
			"Planter",
			Vector3.new(2.4, 2.4, 2.4),
			ctx.plotCF * CFrame.new(side * 8, F + 1.2, ZF + 3),
			C.Mint
		)
	end
end

local function checkerFloor(ctx: Ctx)
	local tile = 7.2
	local cols, rows = 8, 4
	local x0 = -(cols - 1) * tile / 2
	local z0 = ZB + 2.5 + tile / 2
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			if (r + c) % 2 == 0 then
				box(ctx, "Tile", Vector3.new(tile, 0.06, tile), x0 + c * tile, F + 0.13, z0 + r * tile, C.Ketchup)
			end
		end
	end
end

local function tierBig(ctx: Ctx)
	local height = 13
	shellWalls(ctx, height)
	checkerFloor(ctx)
	roof(ctx, height)
	awningStripes(ctx, 6, 14, 4, F + Layout.DoorSize.Y + 1.5, ZF + 2.8)

	-- Neon sign on the facade
	local roofTop = F + height + 1
	local sign = softBox(ctx, "NeonSign", Vector3.new(22, 6, 0.8), 0, roofTop + 3.5, ZF + 0.2, C.NeonPink)
	sign.Material = NEON
	label(sign, "DINER", C.Cream)
	for _, side in { -1, 1 } do
		box(ctx, "SignLeg", Vector3.new(0.8, 4, 0.8), side * 8, roofTop + 1.5, ZF + 0.2, C.Ink)
	end
	-- Neon trim around the roof edge
	local front =
		softBox(ctx, "NeonTrimFront", Vector3.new(WX * 2 + 2, 0.4, 0.4), 0, F + height - 0.4, ZF + 2.2, C.Mint)
	front.Material = NEON
	for _, side in { -1, 1 } do
		local s = softBox(
			ctx,
			"NeonTrimSide",
			Vector3.new(0.4, 0.4, DEPTH + 3),
			side * (WX + 1.2),
			F + height - 0.4,
			(ZB + ZF) / 2 + 1,
			C.Mint
		)
		s.Material = NEON
	end
	-- String lights and balloons: chaos
	for i = 1, 8 do
		local color = if i % 2 == 0 then C.Mustard else C.NeonPink
		local b = Build.Ball(
			ctx.shell,
			"Bulb",
			Vector3.new(0.9, 0.9, 0.9),
			ctx.plotCF * CFrame.new((i - 4.5) * 7, F + height - 1.8 - math.sin(i * 1.7) * 0.4, ZF + 2.4),
			color,
			NEON
		)
		Build.Soft(b)
	end
	for i, x in { -26, -22, 22, 26 } do
		local color = if i % 2 == 0 then C.Ketchup else C.Mustard
		local b = Build.Ball(
			ctx.shell,
			"Balloon",
			Vector3.new(2.6, 3.2, 2.6),
			ctx.plotCF * CFrame.new(x, F + 9 + (i % 2) * 2, ZF + 4),
			color
		)
		Build.Soft(b)
	end
	-- Rooftop burger statue
	local bx, by, bz = 20, roofTop + 1, -14
	for _, part in
		{
			Build.Ball(
				ctx.shell,
				"StatueBunBottom",
				Vector3.new(6, 2.4, 6),
				ctx.plotCF * CFrame.new(bx, by + 1, bz),
				C.Mustard
			),
			Build.Cylinder(ctx.shell, "StatuePatty", 6.4, 1.2, ctx.plotCF * CFrame.new(bx, by + 2.4, bz), C.Ink),
			Build.Cylinder(ctx.shell, "StatueTomato", 6, 0.6, ctx.plotCF * CFrame.new(bx, by + 3.2, bz), C.Ketchup),
			Build.Ball(
				ctx.shell,
				"StatueBunTop",
				Vector3.new(6.4, 3.6, 6.4),
				ctx.plotCF * CFrame.new(bx, by + 4.2, bz),
				C.Mustard
			),
		}
	do
		Build.Soft(part)
	end
end

function Shells.Build(shell: Folder, plotCF: CFrame, accent: Color3, tier: number)
	local ctx: Ctx = { shell = shell, plotCF = plotCF, accent = accent }
	if tier <= 0 then
		tierStand(ctx)
	elseif tier == 1 then
		tierDiner(ctx)
	else
		tierBig(ctx)
	end
end

return Shells

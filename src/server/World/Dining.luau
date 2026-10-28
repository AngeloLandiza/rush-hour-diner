--!strict
-- Seats and tables (WorldSchema Seats/Seat_<k>): counter stools, two booths and a high-top. Owner: agent E.
-- Rebuilt by MapBuilder.ApplyDecor so the furniture matches the decor tier (tier 0: wooden picnic
-- benches and parasols on the lawn; tiers 1-2: upholstered booths and chrome stools), always at the same
-- positions. Each Seat_<k> part is the cushion the customer sits on, with a "Sit" attachment (at the
-- cushion top, facing the table/counter) and an "Approach" attachment (floor level, on the clear aisle).
-- A table and its booth frame are children of the table's FIRST seat, so MapBuilder.SetSeatCount
-- shows a table together with its first seat; later seats add their cushion and place setting.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local Build = require("./Build")
local Layout = require("./Layout")

local C = Palette.Color
local P = WorldSchema.Parts
local A = WorldSchema.Attributes
local F = Layout.FloorY
local S = Layout.Seating

local Dining = {}

type Ctx = { folder: Folder, plotCF: CFrame, plotId: number, accent: Color3, tier: number }

local function at(ctx: Ctx, x: number, y: number, z: number): CFrame
	return ctx.plotCF * CFrame.new(x, y, z)
end

-- Names the cushion as Seat_<k> and adds the contract attributes and attachments.
-- `face` is the plot-local horizontal direction the seated customer looks toward.
local function finishSeat(ctx: Ctx, seat: BasePart, k: number, top: Vector3, face: Vector3, approach: Vector3)
	seat.Name = WorldSchema.SeatPrefix .. k
	seat:SetAttribute(A.SeatIndex, k)
	seat:SetAttribute(A.PlotId, ctx.plotId)
	local sit = Instance.new("Attachment")
	sit.Name = P.SitAttachment
	sit.Parent = seat
	sit.WorldCFrame = ctx.plotCF * CFrame.lookAt(top, top + face)
	local appr = Instance.new("Attachment")
	appr.Name = P.SeatApproach
	appr.Parent = seat
	appr.WorldCFrame = ctx.plotCF * CFrame.new(approach)
	seat.Parent = ctx.folder
end

-- Round stool: cushion (the Seat part) with a piping ring, a pole and a foot (4 parts).
local function stool(ctx: Ctx, k: number, x: number, z: number, face: Vector3, approach: Vector3, cushion: Color3)
	local h = S.StoolHeight
	local seat = Build.Cylinder(ctx.folder, "Stool", 2.5, 0.6, at(ctx, x, F + h - 0.3, z), cushion)
	local trim = if ctx.tier <= 0 then C.WoodDark else C.CreamLight
	local pole = if ctx.tier <= 0 then C.WoodDark else C.Chrome
	Build.Cylinder(seat, "Piping", 2.7, 0.18, at(ctx, x, F + h - 0.62, z), trim)
	Build.Cylinder(seat, "Leg", 0.45, h - 0.7, at(ctx, x, F + (h - 0.7) / 2, z), pole)
	Build.Cylinder(seat, "Foot", 1.8, 0.25, at(ctx, x, F + 0.12, z), C.SteelDark)
	finishSeat(ctx, seat, k, Vector3.new(x, F + h, z), face, approach)
end

-- Market parasol through a table (tier 0 only): soft so it never blocks the camera (2 parts).
local function parasol(parent: Instance, ctx: Ctx, x: number, z: number, topY: number)
	Build.Soft(
		Build.Cylinder(parent, "ParasolPole", 0.2, 7.4 - topY + F, at(ctx, x, (topY + F + 7.4) / 2, z), C.Chrome)
	)
	Build.Soft(Build.Dome(parent, "Parasol", Vector3.new(7.4, 1.8, 7.4), at(ctx, x, F + 7.6, z), ctx.accent))
end

local function plate(parent: Instance, ctx: Ctx, x: number, y: number, z: number)
	local p = Build.Cylinder(parent, "Plate", 1.1, 0.08, at(ctx, x, y + 0.04, z), C.White)
	p.CanCollide = false
end

-- ── Booths ───────────────────────────────────────────────────────────────────

-- Tier 1-2 booth: pedestal table with a chrome edge, two upholstered benches with tall accent backs.
-- Tier 0: a wooden picnic table with plank benches and a parasol. Seat parts are the bench cushions.
local function booth(ctx: Ctx, def: { x: number, z: number, seats: { number } })
	local cx, cz = def.x, def.z
	local len = S.BoothLength
	local inward = if cx > 0 then -1 else 1 -- direction (X) from the table toward the room center
	local picnic = ctx.tier <= 0
	local seatTop = S.BoothSeatHeight
	local tableY = S.BoothTableHeight
	local cushion = if picnic then C.WoodLight else ctx.accent

	-- First seat carries the table and both bench frames.
	local frame = Instance.new("Model")
	frame.Name = "Table"
	local topColor = if picnic then C.Wood else C.CreamLight
	Build.Part(frame, "TableTop", Vector3.new(2.8, 0.3, len - 0.6), at(ctx, cx, F + tableY - 0.15, cz), topColor)
	if picnic then
		for _, dz in { -1, 1 } do
			Build.Part(
				frame,
				"TableLeg",
				Vector3.new(2.2, tableY - 0.3, 0.35),
				at(ctx, cx, F + (tableY - 0.3) / 2, cz + dz * (len / 2 - 1.1)),
				C.WoodDark
			)
		end
		parasol(frame, ctx, cx, cz, F + tableY)
	else
		Build.Part(frame, "TableEdge", Vector3.new(3, 0.14, len - 0.4), at(ctx, cx, F + tableY - 0.32, cz), C.Chrome)
		Build.Cylinder(frame, "TableLeg", 0.5, tableY - 0.4, at(ctx, cx, F + (tableY - 0.4) / 2, cz), C.Chrome)
		Build.Part(frame, "TableFoot", Vector3.new(1.8, 0.2, 2.4), at(ctx, cx, F + 0.1, cz), C.SteelDark)
		-- Napkin dispenser and ketchup at the closed (counter) end of the table
		local endZ = cz - len / 2 + 0.9
		Build.Part(frame, "Napkins", Vector3.new(0.8, 0.7, 0.4), at(ctx, cx, F + tableY + 0.35, endZ), C.Chrome)
		Build.Cylinder(frame, "Ketchup", 0.4, 0.9, at(ctx, cx + 0.6, F + tableY + 0.45, endZ), C.Ketchup)
	end
	for _, side in { -1, 1 } do
		local sx = cx + side * S.BoothSeatOffset
		local baseH = seatTop - 0.45
		local baseColor = if picnic then C.WoodDark else C.CreamShade
		Build.Part(frame, "BenchBase", Vector3.new(2.2, baseH, len), at(ctx, sx, F + baseH / 2, cz), baseColor)
		if not picnic then
			local bx = cx + side * S.BoothBackOffset
			local backH = 4.6
			Build.Part(frame, "BoothBack", Vector3.new(0.8, backH, len), at(ctx, bx, F + backH / 2, cz), ctx.accent)
			Build.Rod(
				frame,
				"BoothPiping",
				0.9,
				len,
				at(ctx, bx, F + backH, cz) * CFrame.Angles(0, math.pi / 2, 0),
				C.CreamLight
			)
		end
	end

	for i, k in def.seats do
		-- Seat 1 of the pair sits on the inner bench (toward the aisle), seat 2 on the outer bench.
		local side = if i == 1 then inward else -inward
		local sx = cx + side * S.BoothSeatOffset
		local seat = Build.Part(
			ctx.folder,
			"Cushion",
			Vector3.new(2.2, 0.45, len - 0.3),
			at(ctx, sx, F + seatTop - 0.225, cz),
			cushion
		)
		if i == 1 then
			frame.Parent = seat
		end
		plate(seat, ctx, cx + side * 0.75, F + tableY, cz - 0.4)
		local top = Vector3.new(sx, F + seatTop, cz)
		local approach = Vector3.new(sx, F, cz + len / 2 + S.BoothApproach)
		finishSeat(ctx, seat, k, top, Vector3.new(-side, 0, 0), approach)
	end
end

-- ── High-top ─────────────────────────────────────────────────────────────────

local function highTop(ctx: Ctx)
	local h = S.HighTop
	local frame = Instance.new("Model")
	frame.Name = "Table"
	local picnic = ctx.tier <= 0
	Build.Cylinder(frame, "TableTop", h.radius * 2, 0.3, at(ctx, h.x, F + h.height - 0.15, h.z), C.CreamLight)
	Build.Cylinder(
		frame,
		"TableEdge",
		h.radius * 2 + 0.2,
		0.14,
		at(ctx, h.x, F + h.height - 0.32, h.z),
		if picnic then C.Wood else ctx.accent
	)
	Build.Cylinder(frame, "TableLeg", 0.5, h.height - 0.4, at(ctx, h.x, F + (h.height - 0.4) / 2, h.z), C.Chrome)
	Build.Cylinder(frame, "TableFoot", 2.2, 0.2, at(ctx, h.x, F + 0.1, h.z), C.SteelDark)
	if picnic then
		parasol(frame, ctx, h.x, h.z, F + h.height)
	end
	local cushion = if picnic then C.WoodLight else ctx.accent
	for i, k in h.seats do
		local a = math.rad(h.angles[i])
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local x, z = h.x + dir.X * h.stoolRadius, h.z + dir.Z * h.stoolRadius
		local approach = Vector3.new(x, F, z + h.approach[i])
		stool(ctx, k, x, z, -dir, approach, cushion)
		local seat = ctx.folder:FindFirstChild(WorldSchema.SeatPrefix .. k)
		if seat then
			if i == 1 then
				frame.Parent = seat
			end
			local px, pz = h.x + dir.X * (h.radius - 0.7), h.z + dir.Z * (h.radius - 0.7)
			plate(seat, ctx, px, F + h.height, pz)
		end
	end
end

-- Builds every seat (1..Timings.Seats.Max) into `folder` for decor `tier` (clears it first).
function Dining.Build(folder: Folder, plotCF: CFrame, plotId: number, accent: Color3, tier: number)
	folder:ClearAllChildren()
	local ctx: Ctx = { folder = folder, plotCF = plotCF, plotId = plotId, accent = accent, tier = tier }
	for k, x in S.StoolX do
		local z = S.StoolZ
		stool(ctx, k, x, z, Vector3.new(0, 0, -1), Vector3.new(x, F, z + S.StoolApproach), accent)
	end
	for _, def in S.Booths do
		booth(ctx, def)
	end
	highTop(ctx)
end

return Dining

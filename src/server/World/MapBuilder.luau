--!strict
-- Procedural map: street, 6 plots, diner shells that grow with decor tiers. Owner: agent E.
-- Builds the instance tree described in Contracts/WorldSchema during Init (before gameplay Start).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Config.Art)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local Build = require("./Build")
local Layout = require("./Layout")
local PropBuilder = require("./PropBuilder")
local Shells = require("./Shells")
local Yard = require("./Yard")

local C = Palette.Color
local P = WorldSchema.Parts
local A = WorldSchema.Attributes
local F = Layout.FloorY
local NEON = Enum.Material.Neon

local MapBuilder = {}

type PlotState = {
	model: Model,
	cf: CFrame,
	accent: Color3,
	tier: number,
	signText: TextLabel,
}

local plots: { [number]: PlotState } = {}

local ORIG_T = "OrigTransparency"
local ORIG_CC = "OrigCanCollide"

local function getOrCreateFolder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = workspace
	return f
end

-- Show or hide a model: hidden = fully transparent, non-colliding, prompts disabled. Reversible.
-- Station food parts (Art.Attributes.Managed) are skipped: StationVisuals hides them with the slot.
local function setVisible(root: Instance, visible: boolean)
	local function apply(inst: Instance)
		if inst:IsA("BasePart") and inst:GetAttribute(Art.Attributes.Managed) == true then
			return
		elseif inst:IsA("BasePart") then
			if not visible then
				if inst:GetAttribute(ORIG_T) == nil then
					inst:SetAttribute(ORIG_T, inst.Transparency)
					inst:SetAttribute(ORIG_CC, inst.CanCollide)
				end
				inst.Transparency = 1
				inst.CanCollide = false
			else
				local t = inst:GetAttribute(ORIG_T)
				local cc = inst:GetAttribute(ORIG_CC)
				if type(t) == "number" then
					inst.Transparency = t
				end
				if type(cc) == "boolean" then
					inst.CanCollide = cc
				end
			end
		elseif inst:IsA("ProximityPrompt") then
			inst.Enabled = visible
		elseif inst:IsA("ParticleEmitter") and not visible then
			inst.Enabled = false
		end
	end
	apply(root)
	for _, d in root:GetDescendants() do
		apply(d)
	end
end

-- ── Street ───────────────────────────────────────────────────────────────────

local function soft(part: BasePart): BasePart
	Build.Soft(part)
	return part
end

-- Retro street lamp: ink pole with a mustard collar, a warm glass globe and a cap.
local function buildLamp(parent: Instance, x: number, z: number)
	local y0 = Layout.SidewalkHeight
	local base = CFrame.new(x, y0, z)
	Build.Cylinder(parent, "LampBase", 1.5, 1, base * CFrame.new(0, 0.5, 0), C.Ink)
	Build.Cylinder(parent, "LampPole", 0.5, 9, base * CFrame.new(0, 5.5, 0), C.Ink)
	Build.Cylinder(parent, "LampCollar", 1, 0.4, base * CFrame.new(0, 9.9, 0), C.Mustard)
	local globe =
		Build.Ball(parent, "LampGlobe", Vector3.new(1.9, 2.2, 1.9), base * CFrame.new(0, 11.1, 0), C.Lamp, NEON)
	globe.CastShadow = false
	Build.Cylinder(parent, "LampCap", 1.1, 0.4, base * CFrame.new(0, 12.3, 0), C.Ink)
	Build.Light(globe, C.Lamp, 24, 1.1)
end

-- Round-canopy tree: trunk plus three overlapping leaf balls.
local function buildTree(parent: Instance, x: number, z: number, scale: number)
	local base = CFrame.new(x, 0, z)
	Build.Cylinder(parent, "Trunk", 1.1 * scale, 5 * scale, base * CFrame.new(0, 2.5 * scale, 0), C.WoodDark)
	Build.Ball(parent, "Canopy", Vector3.new(7, 6, 7) * scale, base * CFrame.new(0, 6.5 * scale, 0), C.Leaf)
	Build.Ball(
		parent,
		"Canopy",
		Vector3.new(4.6, 4.2, 4.6) * scale,
		base * CFrame.new(1.6 * scale, 8.4 * scale, 0.8 * scale),
		C.Leaf
	)
	if scale <= 1 then -- backdrop trees (scaled up, seen from afar) skip the third ball
		Build.Ball(
			parent,
			"Canopy",
			Vector3.new(4, 3.6, 4) * scale,
			base * CFrame.new(-1.8 * scale, 7.8 * scale, -1 * scale),
			C.LeafDark
		)
	end
end

-- Sidewalk bench facing the street (+Z local).
local function buildBench(parent: Instance, cf: CFrame)
	Build.Part(parent, "BenchSeat", Vector3.new(5, 0.35, 1.5), cf * CFrame.new(0, 1.6, 0), C.Wood)
	Build.Part(
		parent,
		"BenchBack",
		Vector3.new(5, 1.2, 0.3),
		cf * CFrame.new(0, 2.6, -0.75) * CFrame.Angles(-0.15, 0, 0),
		C.Wood
	)
	for _, side in { -1, 1 } do
		Build.Part(parent, "BenchLeg", Vector3.new(0.35, 1.5, 1.4), cf * CFrame.new(side * 2.1, 0.75, 0), C.Ink)
	end
end

-- A simple two-story storefront block used to close off the street ends and the backdrop.
local function buildBlock(parent: Instance, cf: CFrame, w: number, h: number, wall: Color3, trim: Color3)
	Build.Part(parent, "Block", Vector3.new(w, h, 14), cf * CFrame.new(0, h / 2, 0), wall)
	Build.Part(parent, "BlockCap", Vector3.new(w + 1, 0.8, 15), cf * CFrame.new(0, h + 0.4, 0), C.CreamLight)
	Build.Part(parent, "BlockBand", Vector3.new(w + 0.2, 0.6, 14.2), cf * CFrame.new(0, h * 0.45, 0), trim)
	for _, row in { 0.28, 0.72 } do
		local win = Build.Part(
			parent,
			"BlockWindows",
			Vector3.new(w - 4, h * 0.18, 0.3),
			cf * CFrame.new(0, h * row, 7),
			C.MintPale,
			Build.Glass
		)
		win.Transparency = 0.2
	end
end

local function buildStreet(map: Folder)
	local half = Layout.StreetWidth / 2
	local walk = Layout.SidewalkDepth
	local len = Layout.StreetLength
	local top = Layout.StreetThickness
	Build.Part(map, "Ground", Layout.GroundSize, CFrame.new(0, -0.5, 0), C.Grass)
	Build.Part(map, "Street", Vector3.new(len, top, Layout.StreetWidth), CFrame.new(0, top / 2, 0), C.Asphalt)
	for _, side in { -1, 1 } do
		Build.Part(
			map,
			"Gutter",
			Vector3.new(len, 0.04, 1.2),
			CFrame.new(0, top + 0.02, side * (half - 0.6)),
			C.AsphaltDark
		)
		local z = side * (half + walk / 2)
		Build.Part(
			map,
			"Sidewalk",
			Vector3.new(len, Layout.SidewalkHeight, walk),
			CFrame.new(0, Layout.SidewalkHeight / 2, z),
			C.Concrete
		)
		Build.Part(
			map,
			"Curb",
			Vector3.new(len, Layout.SidewalkHeight + 0.05, 0.8),
			CFrame.new(0, (Layout.SidewalkHeight + 0.05) / 2, side * (half + 0.4)),
			C.CreamLight
		)
		local seams = math.floor(len / Layout.SidewalkSeamSpacing)
		for i = 1, seams - 1 do
			local x = -len / 2 + i * Layout.SidewalkSeamSpacing
			Build.Part(
				map,
				"Seam",
				Vector3.new(0.25, 0.04, walk - 0.8),
				CFrame.new(x, Layout.SidewalkHeight + 0.02, z + side * 0.4),
				C.ConcreteDark
			)
		end
	end
	-- Center dashes
	local dashSpacing = len / Layout.CenterDashCount
	for i = 1, Layout.CenterDashCount do
		local x = (i - (Layout.CenterDashCount + 1) / 2) * dashSpacing
		Build.Part(map, "Dash", Vector3.new(dashSpacing * 0.45, 0.06, 0.6), CFrame.new(x, top + 0.03, 0), C.Mustard)
	end
	-- Crosswalks
	for _, cx in Layout.CrosswalkX do
		for i = 1, Layout.CrosswalkStripes do
			local x = cx + (i - (Layout.CrosswalkStripes + 1) / 2) * 1.8
			Build.Part(
				map,
				"CrosswalkStripe",
				Vector3.new(1, 0.06, Layout.StreetWidth - 3),
				CFrame.new(x, top + 0.03, 0),
				C.CreamLight
			)
		end
	end
	-- Lamps on both sidewalks, benches facing the street, trees in the walkways between plots
	for _, x in Layout.LampX do
		buildLamp(map, x, -(half + 1.4))
		buildLamp(map, x, half + 1.4)
	end
	for _, x in Layout.BenchX do
		buildBench(map, CFrame.new(x, Layout.SidewalkHeight, -(half + walk - 1.5)))
		buildBench(map, CFrame.new(x, Layout.SidewalkHeight, half + walk - 1.5) * CFrame.Angles(0, math.pi, 0))
	end
	for _, x in Layout.TreeX do
		for _, z in Layout.TreeZ do
			buildTree(map, x, z, 1)
			buildTree(map, x, -z, 1)
		end
	end
	-- Backdrop: a tree line behind the plots and storefront blocks at both street ends
	for i, x in Layout.BackdropX do
		for _, side in { -1, 1 } do
			buildTree(map, x + (i % 2) * 8, side * (Layout.BackdropZ + (i % 3) * 4), 1.5)
		end
	end
	local blockColors = { C.Linen, C.Terracotta, C.MintPale, C.MustardPale }
	for i, z in { -36, -16, 16, 36 } do
		for _, side in { -1, 1 } do
			local cf = CFrame.new(side * Layout.EndBuildingX, 0, z) * CFrame.Angles(0, -side * math.pi / 2, 0)
			buildBlock(map, cf, 18, 16 + (i % 2) * 6, blockColors[(i + (side + 1) / 2) % #blockColors + 1], C.Ink)
		end
	end
	-- Welcome spawn pad for players before they get a plot: a round mint plaza in the street.
	local d = Layout.SpawnPadSize.X
	soft(Build.Cylinder(map, "SpawnRing", d + 2, 0.3, CFrame.new(0, top + 0.15, 0), C.Mustard))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Shape = Enum.PartType.Cylinder
	spawn.Size = Vector3.new(0.5, d, d)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = C.MintPale
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.CFrame = CFrame.new(0, top + 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2)
	spawn.Parent = map
end

-- ── Plots ────────────────────────────────────────────────────────────────────

local function plotCFrame(plotId: number): CFrame
	local idx = (plotId - 1) % Layout.PlotsPerSide -- 0..2 along the street
	local x = (idx - (Layout.PlotsPerSide - 1) / 2) * Layout.PlotSpacing
	local offset = Layout.StreetWidth / 2 + Layout.SidewalkDepth + Layout.PlotSize.Z / 2
	if plotId <= Layout.PlotsPerSide then
		return CFrame.new(x, 0, -offset) -- north side, local +Z already points at the street
	end
	return CFrame.new(x, 0, offset) * CFrame.Angles(0, math.pi, 0)
end

local function accentFor(plotId: number): Color3
	local accents = { C.Ketchup, C.Mint, C.Mustard }
	return accents[(plotId - 1) % #accents + 1]
end

-- Chrome diner stool: accent cushion (the Seat part) on a cream piping ring, chrome pole and foot.
local function buildSeat(seats: Folder, plotCF: CFrame, plotId: number, accent: Color3, k: number)
	local x = Layout.SeatX[k]
	local top = F + Layout.SeatHeight
	local seat = Build.Cylinder(
		seats,
		WorldSchema.SeatPrefix .. k,
		2.5,
		0.6,
		plotCF * CFrame.new(x, top - 0.3, Layout.SeatZ),
		accent
	)
	seat:SetAttribute(A.SeatIndex, k)
	seat:SetAttribute(A.PlotId, plotId)
	Build.Cylinder(seat, "Piping", 2.7, 0.18, plotCF * CFrame.new(x, top - 0.62, Layout.SeatZ), C.CreamLight)
	Build.Cylinder(
		seat,
		"Leg",
		0.45,
		Layout.SeatHeight - 0.7,
		plotCF * CFrame.new(x, F + (Layout.SeatHeight - 0.7) / 2, Layout.SeatZ),
		C.Chrome
	)
	Build.Cylinder(seat, "Foot", 1.8, 0.25, plotCF * CFrame.new(x, F + 0.12, Layout.SeatZ), C.SteelDark)
	local sit = Instance.new("Attachment")
	sit.Name = P.SitAttachment
	sit.Parent = seat
	-- Faces the counter (plot -Z)
	sit.WorldCFrame = plotCF * CFrame.lookAt(Vector3.new(x, top, Layout.SeatZ), Vector3.new(x, top, Layout.SeatZ - 1))
end

-- The diner counter: cream body with a kick plate, chrome rail and accent band on the customer side,
-- an overhanging countertop with a chrome edge, a pink under-glow for Rush Hour and condiments.
local function buildCounter(model: Model, cf: CFrame, accent: Color3): BasePart
	local size = Layout.CounterSize
	local counter = Build.Part(model, P.Counter, size, cf * CFrame.new(0, F + size.Y / 2, Layout.CounterZ), C.Cream)
	local frontZ = Layout.CounterZ + size.Z / 2
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	Build.Part(model, "CounterBand", Vector3.new(size.X, 0.7, 0.12), at(0, F + 2.55, frontZ + 0.05), accent)
	Build.Rod(model, "CounterRail", 0.22, size.X, at(0, F + 1.95, frontZ + 0.1), C.Chrome)
	local topY = F + size.Y + 0.18
	Build.Part(
		model,
		"CounterTop",
		Vector3.new(size.X + 0.8, 0.36, size.Z + 1),
		at(0, topY, Layout.CounterZ + 0.4),
		C.CreamLight
	)
	Build.Rod(model, "CounterEdge", 0.42, size.X + 0.8, at(0, topY, frontZ + 0.9), C.Chrome)
	local glow = Build.Part(
		model,
		"CounterGlow",
		Vector3.new(size.X - 1, 0.12, 0.12),
		at(0, topY - 0.32, frontZ + 0.55),
		C.NeonPink,
		NEON
	)
	Build.RushNeon(glow)
	for i, x in { -16, -8, 8, 16 } do
		local y = topY + 0.18
		Build.Cylinder(model, "Ketchup", 0.42, 1, at(x - 0.35, y + 0.5, Layout.CounterZ + 0.3), C.Ketchup)
		Build.Cylinder(model, "Mustard", 0.42, 1, at(x + 0.2, y + 0.5, Layout.CounterZ + 0.4), C.Mustard)
		if i % 2 == 0 then
			Build.Part(
				model,
				"Napkins",
				Vector3.new(0.9, 0.7, 0.45),
				at(x + 1.2, y + 0.35, Layout.CounterZ + 0.3),
				C.Chrome
			)
		end
	end
	return counter
end

-- Low hedges along the street edge of the lot (with a gap for the path) and a patterned brick path.
-- The rest of the yard (tables, lamps, menu, queue rope) is built per decor tier by Yard via Shells.
local function buildFrontYard(model: Model, cf: CFrame)
	local edgeZ = Layout.PlotSize.Z / 2 - 1
	local pathW = Layout.DoorSize.X + 2
	local hedgeW = Layout.PlotSize.X / 2 - pathW / 2 - 1
	for _, side in { -1, 1 } do
		local x = side * (pathW / 2 + hedgeW / 2 + 0.5)
		Build.Part(model, "HedgeBox", Vector3.new(hedgeW, 0.9, 1.6), cf * CFrame.new(x, F + 0.45, edgeZ), C.Wood)
		Build.Part(model, "Hedge", Vector3.new(hedgeW - 0.3, 1.3, 1.3), cf * CFrame.new(x, F + 1.45, edgeZ), C.Leaf)
	end
	local lawnZ0 = Layout.LawnStartZ
	local lawnD = Layout.PlotSize.Z / 2 - lawnZ0
	Build.Part(
		model,
		"Lawn",
		Vector3.new(Layout.PlotSize.X, 0.04, lawnD),
		cf * CFrame.new(0, F + 0.02, lawnZ0 + lawnD / 2),
		C.Grass
	)
	Yard.Path(model, cf, Layout.WallFrontZ, Layout.PlotSize.Z / 2, true)
end

local function buildSlot(stationsFolder: Folder, plotCF: CFrame, plotId: number, k: number)
	local stationId: Types.StationId = Stations.SlotLayout[k] :: any -- Config/Stations widens the literal type
	local slot = Instance.new("Model")
	slot.Name = WorldSchema.SlotPrefix .. k
	local built = PropBuilder.MakeStation(stationId)
	local root = built.PrimaryPart -- read before reparenting: moving it out clears built.PrimaryPart
	for _, child in built:GetChildren() do
		child.Parent = slot
	end
	slot.PrimaryPart = root
	built:Destroy()
	slot:SetAttribute(A.PlotId, plotId)
	slot:SetAttribute(A.Slot, k)
	slot:SetAttribute(A.StationId, stationId)
	local interact = slot:FindFirstChild(P.Interact)
	if interact then
		interact:SetAttribute(A.PlotId, plotId)
		interact:SetAttribute(A.Slot, k)
		interact:SetAttribute(A.StationId, stationId)
		CollectionService:AddTag(interact, WorldSchema.Tags.StationInteract)
	end
	slot:PivotTo(plotCF * CFrame.new(Layout.SlotX[k], F, Layout.StationZ))
	slot.Parent = stationsFolder
end

-- Crew sign on two wooden posts, off to the side of the entrance path: an ink board (the named Sign
-- part) in a rounded accent frame, cream lettering on both faces, marquee bulbs that light in Rush Hour.
local function addSignGui(sign: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = P.SignGui
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Name = P.SignText
	text.Size = UDim2.fromScale(0.92, 0.8)
	text.Position = UDim2.fromScale(0.04, 0.1)
	text.BackgroundTransparency = 1
	text.Text = "Free Plot"
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = C.CreamLight
	text.Parent = gui
	gui.Parent = sign
	return text
end

local function buildSign(model: Model, plotCF: CFrame, accent: Color3): TextLabel
	local pos = Layout.SignPos
	local size = Layout.SignSize
	local postH = pos.Y - size.Y / 2 - F
	for _, side in { -1, 1 } do
		local x = pos.X + side * (size.X / 2 - 1)
		Build.Part(
			model,
			"SignPost",
			Vector3.new(0.6, postH, 0.6),
			plotCF * CFrame.new(x, F + postH / 2, pos.Z),
			C.WoodDark
		)
	end
	local sign = Build.Part(model, P.Sign, size, plotCF * CFrame.new(pos), C.Ink)
	Build.Pill(
		model,
		"SignFrame",
		Vector3.new(size.X + 0.8, size.Y + 0.6, size.Z - 0.2),
		plotCF * CFrame.new(pos),
		accent
	)
	local bulbs = 3
	for i = 1, bulbs do
		local x = pos.X + (i - (bulbs + 1) / 2) * ((size.X - 3) / (bulbs - 1))
		local bulb = Build.Ball(
			model,
			"SignBulb",
			Vector3.new(0.45, 0.45, 0.45),
			plotCF * CFrame.new(x, pos.Y + size.Y / 2 + 0.6, pos.Z),
			C.Mustard,
			NEON
		)
		Build.RushNeon(bulb, if i == (bulbs + 1) / 2 then 10 else nil, 1.5)
	end
	local text = addSignGui(sign, Enum.NormalId.Back) -- +Z in plot space, toward the street
	addSignGui(sign, Enum.NormalId.Front) -- mirrored for the diner side; SetSignText updates both
	return text
end

local function buildPlot(plotsFolder: Folder, plotId: number)
	local cf = plotCFrame(plotId)
	local accent = accentFor(plotId)
	local model = Instance.new("Model")
	model.Name = WorldSchema.PlotPrefix .. plotId
	model:SetAttribute(A.PlotId, plotId)

	local base = Build.Part(model, P.Base, Layout.PlotSize, cf * CFrame.new(0, F - Layout.PlotSize.Y / 2, 0), C.Sand)
	model.PrimaryPart = base
	buildFrontYard(model, cf)

	Build.Marker(model, P.Spawn, Vector3.new(4, 1, 2.5), cf * CFrame.new(0, F + 0.5, Layout.SpawnZ))
	Build.Marker(model, P.CustomerSpawn, Vector3.new(4, 1, 4), cf * CFrame.new(0, F + 0.5, Layout.CustomerSpawnZ))
	Build.Marker(model, P.Door, Layout.DoorSize, cf * CFrame.new(0, F + Layout.DoorSize.Y / 2, Layout.DoorZ))
	buildCounter(model, cf, accent)

	local signText = buildSign(model, cf, accent)

	local stationsFolder = Instance.new("Folder")
	stationsFolder.Name = P.Stations
	for k = 1, #Stations.SlotLayout do
		buildSlot(stationsFolder, cf, plotId, k)
	end
	stationsFolder.Parent = model

	local seatsFolder = Instance.new("Folder")
	seatsFolder.Name = P.Seats
	for k = 1, Timings.Seats.Max do
		buildSeat(seatsFolder, cf, plotId, accent, k)
	end
	seatsFolder.Parent = model

	local shell = Instance.new("Folder")
	shell.Name = P.Shell
	shell.Parent = model

	model.Parent = plotsFolder
	plots[plotId] = { model = model, cf = cf, accent = accent, tier = -1, signText = signText }
end

function MapBuilder.Init()
	local map = getOrCreateFolder(WorldSchema.Folders.Map)
	getOrCreateFolder(WorldSchema.Folders.Customers)
	getOrCreateFolder(WorldSchema.Folders.Bots)
	local plotsFolder = getOrCreateFolder(WorldSchema.Folders.Plots)

	buildStreet(map)
	for plotId = 1, Timings.Plots.Count do
		buildPlot(plotsFolder, plotId)
		MapBuilder.ApplyDecor(plotId, 0)
		MapBuilder.SetSeatCount(plotId, Timings.Seats.Base)
		MapBuilder.SetStationSlots(plotId, Stations.BaseSlots)
	end
end

function MapBuilder.Start() end

function MapBuilder.GetPlotModel(plotId: number): Model?
	local state = plots[plotId]
	return if state then state.model else nil
end

-- Rebuild the plot's Shell for decor tier 0..2.
function MapBuilder.ApplyDecor(plotId: number, tier: number)
	local state = plots[plotId]
	if not state then
		return
	end
	local clamped = math.clamp(math.floor(tier), 0, 2)
	if state.tier == clamped then
		return
	end
	state.tier = clamped
	local shell = state.model:FindFirstChild(P.Shell)
	if not shell or not shell:IsA("Folder") then
		return
	end
	shell:ClearAllChildren()
	Shells.Build(shell, state.cf, state.accent, clamped)
end

local function setChildrenVisible(folder: Instance?, prefix: string, count: number)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		local n = tonumber(string.sub(child.Name, #prefix + 1))
		if n and string.sub(child.Name, 1, #prefix) == prefix then
			setVisible(child, n <= count)
		end
	end
end

-- Show seats 1..count (hide the rest).
function MapBuilder.SetSeatCount(plotId: number, count: number)
	local state = plots[plotId]
	if state then
		setChildrenVisible(state.model:FindFirstChild(P.Seats), WorldSchema.SeatPrefix, count)
	end
end

-- Show station slots 1..count (slot 5 = ExtraStation pass).
function MapBuilder.SetStationSlots(plotId: number, count: number)
	local state = plots[plotId]
	if state then
		setChildrenVisible(state.model:FindFirstChild(P.Stations), WorldSchema.SlotPrefix, count)
	end
end

-- Already-filtered text for the plot sign.
function MapBuilder.SetSignText(plotId: number, text: string)
	local state = plots[plotId]
	if state then
		local sign = state.signText.Parent and state.signText.Parent.Parent
		if sign then
			for _, d in sign:GetDescendants() do
				if d:IsA("TextLabel") and d.Name == P.SignText then
					d.Text = text
				end
			end
		end
		state.signText.Text = text
	end
end

-- Toggle the VIP booth prop on a plot.
function MapBuilder.SetVIPBooth(plotId: number, enabled: boolean)
	local state = plots[plotId]
	if not state then
		return
	end
	local existing = state.model:FindFirstChild("VIPBooth")
	if not enabled then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local booth = Instance.new("Model")
	booth.Name = "VIPBooth"
	local o = Layout.VIPPos
	local cf = state.cf * CFrame.new(o.X, F, o.Z)
	-- A velvet booth on the patio: pink cushions on an ink base, a round table and a neon VIP sign.
	Build.Part(booth, "Bench", Vector3.new(9, 1, 3.4), cf * CFrame.new(0, 0.5, 0), C.Ink)
	Build.Part(booth, "Cushion", Vector3.new(8.6, 0.7, 3), cf * CFrame.new(0, 1.35, 0.1), C.NeonPink)
	Build.Pill(booth, "Back", Vector3.new(9, 3.6, 0.9), cf * CFrame.new(0, 3, -1.8), C.NeonPink)
	Build.Part(booth, "BackBase", Vector3.new(9.4, 1.6, 1.1), cf * CFrame.new(0, 1.6, -1.8), C.Ink)
	Build.Cylinder(booth, "Table", 4, 0.35, cf * CFrame.new(0, 2.6, 3.2), C.CreamLight)
	Build.Cylinder(booth, "TableEdge", 4.2, 0.15, cf * CFrame.new(0, 2.38, 3.2), C.Chrome)
	Build.Cylinder(booth, "TableLeg", 0.5, 2.3, cf * CFrame.new(0, 1.15, 3.2), C.Chrome)
	Build.Cylinder(booth, "TableFoot", 2, 0.2, cf * CFrame.new(0, 0.1, 3.2), C.SteelDark)
	local sign = Build.Pill(booth, "VIPSign", Vector3.new(5, 1.8, 0.4), cf * CFrame.new(0, 6, -1.8), C.Ink)
	local t = Build.Text(sign, "VIP", C.NeonPink)
	t.Name = "VIPText"
	local tube =
		Build.Part(booth, "VIPNeon", Vector3.new(3.2, 0.15, 0.15), cf * CFrame.new(0, 5.05, -1.55), C.NeonPink, NEON)
	Build.RushNeon(tube, 10, 1.5)
	booth.PrimaryPart = booth:FindFirstChild("Bench") :: BasePart
	booth.Parent = state.model
end

return MapBuilder

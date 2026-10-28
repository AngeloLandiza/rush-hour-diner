--!strict
-- Procedural map: street, 6 plots, diner shells that grow with decor tiers. Owner: agent E.
-- Builds the instance tree described in Contracts/WorldSchema during Init (before gameplay Start).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local Build = require("./Build")
local Layout = require("./Layout")
local PropBuilder = require("./PropBuilder")
local Shells = require("./Shells")

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
local function setVisible(root: Instance, visible: boolean)
	local function apply(inst: Instance)
		if inst:IsA("BasePart") then
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

local function buildLamp(parent: Instance, x: number, z: number, facing: number)
	local base = CFrame.new(x, 0, z)
	Build.Cylinder(parent, "LampBase", 1.6, 0.8, base * CFrame.new(0, Layout.SidewalkHeight + 0.4, 0), C.Ink)
	Build.Cylinder(parent, "LampPole", 0.7, 10, base * CFrame.new(0, Layout.SidewalkHeight + 5, 0), C.Ink)
	Build.Part(
		parent,
		"LampArm",
		Vector3.new(0.5, 0.5, 3),
		base * CFrame.new(0, Layout.SidewalkHeight + 10, facing * 1.5),
		C.Ink
	)
	local bulb = Build.Ball(
		parent,
		"LampBulb",
		Vector3.new(1.8, 1.8, 1.8),
		base * CFrame.new(0, Layout.SidewalkHeight + 9.6, facing * 3),
		C.Mustard,
		NEON
	)
	local light = Instance.new("PointLight")
	light.Color = C.Mustard
	light.Range = 26
	light.Brightness = 1.5
	light.Parent = bulb
end

local function buildStreet(map: Folder)
	local half = Layout.StreetWidth / 2
	Build.Part(map, "Ground", Layout.GroundSize, CFrame.new(0, -0.5, 0), C.Mint)
	Build.Part(
		map,
		"Street",
		Vector3.new(Layout.StreetLength, Layout.StreetThickness, Layout.StreetWidth),
		CFrame.new(0, Layout.StreetThickness / 2, 0),
		C.Ink
	)
	for _, side in { -1, 1 } do
		local z = side * (half + Layout.SidewalkDepth / 2)
		Build.Part(
			map,
			"Sidewalk",
			Vector3.new(Layout.StreetLength, Layout.SidewalkHeight, Layout.SidewalkDepth),
			CFrame.new(0, Layout.SidewalkHeight / 2, z),
			C.Cream
		)
		Build.Part(
			map,
			"Curb",
			Vector3.new(Layout.StreetLength, Layout.SidewalkHeight, 0.6),
			CFrame.new(0, Layout.SidewalkHeight / 2 + 0.02, side * (half + 0.3)),
			C.CreamShade
		)
	end
	-- Center dashes
	local dashSpacing = Layout.StreetLength / Layout.CenterDashCount
	for i = 1, Layout.CenterDashCount do
		local x = (i - (Layout.CenterDashCount + 1) / 2) * dashSpacing
		Build.Part(
			map,
			"Dash",
			Vector3.new(dashSpacing * 0.45, 0.06, 0.7),
			CFrame.new(x, Layout.StreetThickness + 0.03, 0),
			C.Mustard
		)
	end
	-- Crosswalks
	for _, cx in Layout.CrosswalkX do
		for i = 1, Layout.CrosswalkStripes do
			local x = cx + (i - (Layout.CrosswalkStripes + 1) / 2) * 1.8
			Build.Part(
				map,
				"CrosswalkStripe",
				Vector3.new(1, 0.06, Layout.StreetWidth - 3),
				CFrame.new(x, Layout.StreetThickness + 0.03, 0),
				C.Cream
			)
		end
	end
	-- Lamp posts on both sidewalks
	for _, x in Layout.LampX do
		buildLamp(map, x, -(half + 1.2), 1)
		buildLamp(map, x, half + 1.2, -1)
	end
	-- Bushes in the gaps behind the sidewalks
	for _, x in Layout.CrosswalkX do
		for _, side in { -1, 1 } do
			Build.Ball(
				map,
				"Bush",
				Vector3.new(6, 5, 6),
				CFrame.new(x, 2, side * (half + Layout.SidewalkDepth + 6)),
				C.MintDeep
			)
		end
	end
	-- Welcome spawn pad for players before they get a plot
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Size = Layout.SpawnPadSize
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = NEON
	spawn.Color = C.NeonPink
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.CFrame = CFrame.new(0, Layout.StreetThickness + Layout.SpawnPadSize.Y / 2, 0)
	spawn.Transparency = 0.35
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

local function buildSeat(seats: Folder, plotCF: CFrame, plotId: number, k: number)
	local x = Layout.SeatX[k]
	local top = F + Layout.SeatHeight
	local seat = Build.Cylinder(
		seats,
		WorldSchema.SeatPrefix .. k,
		2.6,
		0.8,
		plotCF * CFrame.new(x, top - 0.4, Layout.SeatZ),
		C.Ketchup
	)
	seat:SetAttribute(A.SeatIndex, k)
	seat:SetAttribute(A.PlotId, plotId)
	Build.Cylinder(
		seat,
		"Leg",
		0.6,
		Layout.SeatHeight - 0.8,
		plotCF * CFrame.new(x, F + (Layout.SeatHeight - 0.8) / 2, Layout.SeatZ),
		C.Ink
	)
	local sit = Instance.new("Attachment")
	sit.Name = P.SitAttachment
	sit.Parent = seat
	-- Faces the counter (plot -Z)
	sit.WorldCFrame = plotCF * CFrame.lookAt(Vector3.new(x, top, Layout.SeatZ), Vector3.new(x, top, Layout.SeatZ - 1))
end

local function buildSlot(stationsFolder: Folder, plotCF: CFrame, plotId: number, k: number)
	local stationId: Types.StationId = Stations.SlotLayout[k] :: any -- Config/Stations widens the literal type
	local slot = Instance.new("Model")
	slot.Name = WorldSchema.SlotPrefix .. k
	local built = PropBuilder.MakeStation(stationId)
	for _, child in built:GetChildren() do
		child.Parent = slot
	end
	slot.PrimaryPart = built.PrimaryPart
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

local function buildSign(model: Model, plotCF: CFrame, accent: Color3): TextLabel
	local pos = Layout.SignPos
	local size = Layout.SignSize
	for _, side in { -1, 1 } do
		Build.Cylinder(
			model,
			"SignPost",
			0.8,
			pos.Y + size.Y / 2 - F,
			plotCF * CFrame.new(pos.X + side * (size.X / 2 - 1.5), F + (pos.Y + size.Y / 2 - F) / 2, pos.Z),
			C.Ink
		)
	end
	local sign = Build.Part(model, P.Sign, size, plotCF * CFrame.new(pos), C.Ink)
	Build.Part(
		model,
		"SignTrim",
		size + Vector3.new(0.8, 0.8, -0.2),
		plotCF * CFrame.new(pos + Vector3.new(0, 0, -0.2)),
		accent
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = P.SignGui
	gui.Face = Enum.NormalId.Back -- +Z in plot space, toward the street
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local text = Instance.new("TextLabel")
	text.Name = P.SignText
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = ""
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = C.Cream
	text.Parent = gui
	gui.Parent = sign
	return text
end

local function buildPlot(plotsFolder: Folder, plotId: number)
	local cf = plotCFrame(plotId)
	local accent = accentFor(plotId)
	local model = Instance.new("Model")
	model.Name = WorldSchema.PlotPrefix .. plotId
	model:SetAttribute(A.PlotId, plotId)

	local base = Build.Part(model, P.Base, Layout.PlotSize, cf * CFrame.new(0, F - Layout.PlotSize.Y / 2, 0), C.Cream)
	model.PrimaryPart = base
	-- Accent edge along the street side
	Build.Part(
		model,
		"FrontEdge",
		Vector3.new(Layout.PlotSize.X, 0.1, 2),
		cf * CFrame.new(0, F + 0.05, Layout.PlotSize.Z / 2 - 1),
		accent
	)

	Build.Marker(model, P.Spawn, Vector3.new(4, 1, 2.5), cf * CFrame.new(0, F + 0.5, Layout.SpawnZ))
	Build.Marker(model, P.CustomerSpawn, Vector3.new(4, 1, 4), cf * CFrame.new(0, F + 0.5, Layout.CustomerSpawnZ))
	Build.Marker(model, P.Door, Layout.DoorSize, cf * CFrame.new(0, F + Layout.DoorSize.Y / 2, Layout.DoorZ))
	local counter = Build.Part(
		model,
		P.Counter,
		Layout.CounterSize,
		cf * CFrame.new(0, F + Layout.CounterSize.Y / 2, Layout.CounterZ),
		C.Cream
	)
	Build.Part(
		model,
		"CounterTop",
		Layout.CounterSize + Vector3.new(0.6, -Layout.CounterSize.Y + 0.4, 0.6),
		counter.CFrame * CFrame.new(0, Layout.CounterSize.Y / 2 + 0.2, 0),
		accent
	)

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
		buildSeat(seatsFolder, cf, plotId, k)
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
	Build.Part(booth, "Bench", Vector3.new(9, 1.6, 3.4), cf * CFrame.new(0, 0.8, 0), C.NeonPink, NEON)
	Build.Part(booth, "Back", Vector3.new(9, 3.4, 0.9), cf * CFrame.new(0, 3, -1.8), C.NeonPink, NEON)
	Build.Part(booth, "Table", Vector3.new(5, 0.4, 2.4), cf * CFrame.new(0, 2.4, 3), C.Cream)
	Build.Cylinder(booth, "TableLeg", 0.7, 2.2, cf * CFrame.new(0, 1.1, 3), C.Ink)
	local sign = Build.Part(booth, "VIPSign", Vector3.new(5, 1.8, 0.4), cf * CFrame.new(0, 5.6, -1.8), C.Ink)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "VIP"
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = C.NeonPink
	t.Parent = gui
	gui.Parent = sign
	booth.PrimaryPart = booth:FindFirstChild("Bench") :: BasePart
	booth.Parent = state.model
end

return MapBuilder

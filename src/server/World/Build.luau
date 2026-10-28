--!strict
-- Small part-construction helpers shared by MapBuilder, Shells and PropBuilder. Palette colors only.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require(ReplicatedStorage.Shared.Config.Art)

local Build = {}

local SMOOTH = Enum.Material.SmoothPlastic
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- Cylinder parts have their axis on X; stand them up
local FACING_Z = CFrame.Angles(0, math.pi / 2, 0) -- Cylinder axis along Z (a disc facing +Z)
local SIGN_PPS = 20
local SIGN_FONT = Enum.Font.FredokaOne
local PATTERN_PPS = 8 -- SurfaceGui resolution for painted patterns
Build.FloorPPS = 3 -- resolution for room-sized floors (keeps the texture budget for signs)

Build.Glass = Enum.Material.Glass
Build.WoodMat = Enum.Material.Wood
Build.Neon = Enum.Material.Neon
Build.BrickMat = Enum.Material.Brick

local function finish(part: BasePart, name: string, cf: CFrame, color: Color3, material: Enum.Material?)
	part.Name = name
	part.Anchored = true
	part.CFrame = cf
	part.Color = color
	part.Material = material or SMOOTH
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true
end

function Build.Part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Size = size
	finish(part, name, cf, color, material)
	part.Parent = parent
	return part
end

-- Upright cylinder: `cf` is the center, axis along the CFrame's Y.
function Build.Cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	finish(part, name, cf * UPRIGHT, color, material)
	part.Parent = parent
	return part
end

-- Disc / rod whose axis runs along the CFrame's Z (faces +Z): knobs, portholes, scallops, logs.
function Build.Disc(
	parent: Instance,
	name: string,
	diameter: number,
	thickness: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(thickness, diameter, diameter)
	finish(part, name, cf * FACING_Z, color, material)
	part.Parent = parent
	return part
end

-- Elliptical disc facing +Z (scallops, oval signs): a block with a cylinder SpecialMesh, which, unlike a
-- Cylinder part, stretches to a non-circular cross-section.
function Build.Ellipse(
	parent: Instance,
	name: string,
	width: number,
	height: number,
	thickness: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Size = Vector3.new(thickness, height, width)
	finish(part, name, cf * FACING_Z, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Parent = part
	part.Parent = parent
	return part
end

-- Rod along the CFrame's X axis (rails, handles, beams).
function Build.Rod(
	parent: Instance,
	name: string,
	diameter: number,
	length: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, diameter, diameter)
	finish(part, name, cf, color, material)
	part.Parent = parent
	return part
end

function Build.Ball(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = size
	finish(part, name, cf, color, material)
	part.Parent = parent
	return part
end

-- Ellipsoid (parasols, cushions): a block with a sphere SpecialMesh. Unlike a Ball part, which Roblox
-- forces to a uniform size, it stretches to any proportions.
function Build.Dome(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Size = size
	finish(part, name, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function Build.Wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Size = size
	finish(part, name, cf, color, material)
	part.Parent = parent
	return part
end

function Build.CornerWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): CornerWedgePart
	local part = Instance.new("CornerWedgePart")
	part.Size = size
	finish(part, name, cf, color, material)
	part.Parent = parent
	return part
end

-- Rounded slab: a box whose two X ends are capped with half-cylinders (pill shape seen from the front).
-- `size.Y` is the diameter of the caps. Returns the center box. soft = true makes all three parts Soft.
function Build.Pill(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	soft: boolean?
): Part
	local r = size.Y / 2
	local body = Build.Part(parent, name, Vector3.new(size.X - size.Y, size.Y, size.Z), cf, color, material)
	local parts: { BasePart } = { body }
	for _, side in { -1, 1 } do
		local cap = Build.Disc(
			parent,
			name .. "Cap",
			size.Y,
			size.Z,
			cf * CFrame.new(side * (size.X / 2 - r), 0, 0),
			color,
			material
		)
		table.insert(parts, cap)
	end
	if soft then
		Build.SoftAll(parts)
	end
	return body
end

-- Invisible, non-colliding marker (spawns, interaction points).
function Build.Marker(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local part = Build.Part(parent, name, size, cf, Color3.new(1, 1, 1))
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- Decor that must never block players, customers or the camera (roofs, awnings, strings of lights).
function Build.Soft(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

-- Soft for a list of parts; returns the list.
function Build.SoftAll(parts: { BasePart }): { BasePart }
	for _, p in parts do
		Build.Soft(p)
	end
	return parts
end

-- A neon accent that lights up in Rush Hour (LightingDirector toggles Neon ↔ SmoothPlastic and the light).
-- `lightRange` > 0 adds a shadowless PointLight that only shines in Rush.
function Build.RushNeon(part: BasePart, lightRange: number?, lightBrightness: number?)
	part.CastShadow = false
	if lightRange and lightRange > 0 then
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = lightRange
		light.Brightness = 0
		light.Shadows = false
		light.Parent = part
		part:SetAttribute(Art.Attributes.LitBrightness, lightBrightness or 1)
	end
	CollectionService:AddTag(part, Art.Tags.RushNeon)
end

-- Text on one face of a part. Text ignores scene lighting so signs stay readable (and glow at night).
function Build.Text(part: BasePart, text: string, color: Color3, face: Enum.NormalId?, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = SIGN_PPS
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or SIGN_FONT
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = part
	return t
end

-- A checker pattern painted on one face of a part with a SurfaceGui, so tiles cost no extra parts.
-- `cols` × `rows` cells span the face (or only the [x0, x1] slice of its width, in 0..1). Cells where
-- row + col is even get `color`; the others get `other`, or show the part's own color when nil.
-- On the Top face the pattern's columns run along the part's X axis and its rows along Z.
-- `pps` (pixels per stud) defaults to PATTERN_PPS; big surfaces pass less: SurfaceGui texture memory is
-- budgeted per client, and once it runs out signs and labels stop rendering.
function Build.Checker(
	part: BasePart,
	face: Enum.NormalId,
	cols: number,
	rows: number,
	color: Color3,
	other: Color3?,
	x0: number?,
	x1: number?,
	pps: number?
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Pattern"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or PATTERN_PPS
	gui.LightInfluence = 1
	local left = x0 or 0
	local w = ((x1 or 1) - left) / cols
	local h = 1 / rows
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local cellColor = if (r + c) % 2 == 0 then color else other
			if cellColor then
				local cell = Instance.new("Frame")
				cell.Name = "Cell"
				cell.BorderSizePixel = 0
				cell.BackgroundColor3 = cellColor
				cell.Position = UDim2.fromScale(left + c * w, r * h)
				cell.Size = UDim2.fromScale(w, h)
				cell.Parent = gui
			end
		end
	end
	gui.Parent = part
	return gui
end

-- A warm shadow-casting light (lamps). Stays on in both presets.
function Build.Light(part: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = part
	return light
end

-- Welds every part in the model to its PrimaryPart. Children become massless and non-colliding.
-- anchoredRoot = true keeps the root anchored (tweenable props); false makes a free dish for hand-welding.
function Build.Rig(model: Model, anchoredRoot: boolean)
	local root = model.PrimaryPart
	assert(root, "Build.Rig needs a PrimaryPart")
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	root.Anchored = anchoredRoot
	if anchoredRoot then
		root.Massless = false
	end
end

return Build

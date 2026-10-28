--!strict
-- Small part-construction helpers shared by MapBuilder, Shells and PropBuilder. Palette colors only.
local Build = {}

local SMOOTH = Enum.Material.SmoothPlastic
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- Cylinder parts have their axis on X; stand them up

local function finish(part: BasePart, name: string, cf: CFrame, color: Color3, material: Enum.Material?)
	part.Name = name
	part.Anchored = true
	part.CFrame = cf
	part.Color = color
	part.Material = material or SMOOTH
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
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

-- Invisible, non-colliding marker (spawns, interaction points).
function Build.Marker(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local part = Build.Part(parent, name, size, cf, Color3.new(1, 1, 1))
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- Decor that must never block players, customers or the camera (roofs, awnings, strings of lights).
function Build.Soft(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
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

--!strict
-- Code-built customer looks (no catalog assets): outfit colors on a cached R15 rig, one random
-- accessory, VIP / Hungry cues, and the legendary signature costumes. All data is in
-- Config/Customers.Looks; colors come from Config/Palette. Owner: agent C (CustomerService).
--
-- Speed: the default rig is built once with CreateHumanoidModelFromDescription and cloned per customer;
-- every accessory piece is a cached template part; each legendary is built and scaled once, then cloned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomerConfig = require(ReplicatedStorage.Shared.Config.Customers)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Presets = require(ReplicatedStorage.Shared.VFX.Presets)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)

type PartSpec = CustomerConfig.PartSpec
type BodyColorSpec = CustomerConfig.BodyColorSpec
type EmitterSpec = CustomerConfig.EmitterSpec
type Tokens = { [string]: Color3 }

local LOOKS = CustomerConfig.Looks
local LOOK_FOLDER = "Look"

-- R15 body parts by what they wear.
local SKIN_PARTS = { "Head", "LeftHand", "RightHand" }
local SHIRT_PARTS = { "UpperTorso", "LeftUpperArm", "RightUpperArm" }
local SLEEVE_PARTS = { "LeftLowerArm", "RightLowerArm" } -- shirt with long sleeves, else skin
local PANTS_PARTS = { "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }
local SHOE_PARTS = { "LeftFoot", "RightFoot" }

local Looks = {}

local random = Random.new()
local baseRig: Model? = nil
local baseBuilding = false
local partTemplates: { [PartSpec]: BasePart } = {}
local legendaryTemplates: { [Types.LegendaryId]: Model } = {}
local warnedBudget = false

local function pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

local function color(key: string): Color3
	local c = Palette.Color[key]
	if not c then
		warn(`[Looks] unknown Palette key '{key}'`)
		return Palette.Color.White
	end
	return c
end

local function vec(list: { number }?): Vector3
	if not list then
		return Vector3.zero
	end
	return Vector3.new(list[1], list[2], list[3])
end

-- ── Rig ─────────────────────────────────────────────────────────────────────

local function prepareRig(model: Model)
	-- Part colors are set directly; a BodyColors instance would fight them.
	for _, child in model:GetChildren() do
		if child:IsA("BodyColors") then
			child:Destroy()
		end
	end
	local head = model:FindFirstChild("Head")
	if head and not head:FindFirstChildOfClass("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = LOOKS.FaceTexture
		face.Parent = head
	end
	local folder = Instance.new("Folder")
	folder.Name = LOOK_FOLDER
	folder.Parent = model
end

-- The default R15 rig, built once (yields the first time). Concurrent callers wait for the first build.
local function getBaseRig(): Model?
	while baseBuilding do
		task.wait()
	end
	if baseRig then
		return baseRig
	end
	baseBuilding = true
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	baseBuilding = false
	if ok and result then
		prepareRig(result)
		baseRig = result
	else
		warn(`[Looks] base rig failed: {result}`)
	end
	return baseRig
end

local function paintGroup(model: Model, names: { string }, c: Color3)
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Color = c
		end
	end
end

local function paintBody(model: Model, tokens: Tokens, longSleeves: boolean)
	paintGroup(model, SKIN_PARTS, tokens.skin)
	paintGroup(model, SHIRT_PARTS, tokens.shirt)
	paintGroup(model, SLEEVE_PARTS, if longSleeves then tokens.shirt else tokens.skin)
	paintGroup(model, PANTS_PARTS, tokens.pants)
	paintGroup(model, SHOE_PARTS, tokens.shoes)
end

-- ── Pieces ──────────────────────────────────────────────────────────────────

local function templateFor(spec: PartSpec): BasePart
	local cached = partTemplates[spec]
	if cached then
		return cached
	end
	local part = Instance.new("Part")
	part.Name = "LookPart"
	if spec.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif spec.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	part.Size = vec(spec.size)
	part.Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Reflectance = spec.reflectance or 0
	part.Transparency = spec.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	if string.sub(spec.color, 1, 1) ~= "$" then
		part.Color = color(spec.color)
	end
	if spec.shape == "Ellipsoid" then
		-- A sphere mesh at Scale 1 fills the part's box, so it scales with the part.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	partTemplates[spec] = part
	return part
end

-- One build: the extra-part budget left (Config/Customers.Looks.MaxExtraParts) and the rig's scale.
-- Pieces are added after the rig is scaled, so their sizes and offsets are multiplied here.
type Budget = { left: number, scale: number }

local function addPart(model: Model, spec: PartSpec, tokens: Tokens, budget: Budget)
	if budget.left <= 0 then
		if not warnedBudget then
			warnedBudget = true
			warn("[Looks] look exceeds MaxExtraParts; extra pieces skipped")
		end
		return
	end
	local host = model:FindFirstChild(spec.attach)
	local folder = model:FindFirstChild(LOOK_FOLDER)
	if not (host and host:IsA("BasePart") and folder) then
		return
	end
	budget.left -= 1
	local part = templateFor(spec):Clone()
	if budget.scale ~= 1 then
		part.Size *= budget.scale
	end
	if string.sub(spec.color, 1, 1) == "$" then
		part.Color = tokens[string.sub(spec.color, 2)] or tokens.accent
	end
	local rot = spec.rotation
	local c0 = CFrame.new(vec(spec.anchor) * host.Size / 2 + vec(spec.offset) * budget.scale)
	if rot then
		c0 *= CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	end
	part.CFrame = host.CFrame * c0
	local weld = Instance.new("Weld")
	weld.Part0 = host
	weld.Part1 = part
	weld.C0 = c0
	weld.Parent = part
	part.Parent = folder
end

local function addParts(model: Model, parts: { PartSpec }, tokens: Tokens, budget: Budget)
	for _, spec in parts do
		addPart(model, spec, tokens, budget)
	end
end

local function addEmitter(model: Model, attach: string, spec: EmitterSpec)
	local host = model:FindFirstChild(attach)
	if not host then
		return
	end
	local keypoints = {}
	local count = #spec.colors
	for i, key in spec.colors do
		local t = if count > 1 then (i - 1) / (count - 1) else 0
		table.insert(keypoints, ColorSequenceKeypoint.new(t, color(key)))
	end
	if count == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, color(spec.colors[1])))
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Rumble"
	emitter.Texture = spec.texture
	emitter.Color = ColorSequence.new(keypoints)
	emitter.Size = NumberSequence.new(spec.size[1], spec.size[2])
	emitter.Transparency = NumberSequence.new(spec.transparency[1], spec.transparency[2])
	emitter.Lifetime = NumberRange.new(spec.lifetime[1], spec.lifetime[2])
	emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	emitter.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	emitter.Rate = spec.rate
	emitter.LightEmission = spec.lightEmission
	emitter.Acceleration = vec(spec.acceleration)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Parent = host
end

-- ── Builders ────────────────────────────────────────────────────────────────

local function bodyTokens(spec: BodyColorSpec, accent: string): Tokens
	return {
		skin = color(spec.skin),
		shirt = color(spec.shirt),
		pants = color(spec.pants),
		shoes = color(spec.shoes),
		accent = color(accent),
		hair = color(spec.pants),
	}
end

-- Scales the bare rig and keeps the hips on the ground. HumanoidDescription body scales are clamped to
-- the avatar limits (about ±5%), so a 2.2× Giant Chef needs a real model scale.
local function scaleRig(model: Model, scale: number)
	if scale == 1 then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else nil
	model:ScaleTo(scale)
	if humanoid and hip and humanoid.HipHeight == hip then
		humanoid.HipHeight = hip * scale
	end
end

local function buildLegendaryTemplate(legendaryId: Types.LegendaryId): Model?
	local def = CustomerConfig.Legendary[legendaryId]
	local base = getBaseRig()
	if not (def and base) then
		return nil
	end
	local model = base:Clone()
	scaleRig(model, def.scale)
	local costume = if def.costume then LOOKS.Costumes[def.costume] else nil
	if def.costume and not costume then
		warn(`[Looks] legendary '{legendaryId}' names unknown costume '{def.costume}'`)
	end
	local budget: Budget = { left = LOOKS.MaxExtraParts, scale = def.scale }
	local glow = def.accentColor
	if costume then
		local tokens = bodyTokens(costume.bodyColors, def.accentColor)
		paintBody(model, tokens, costume.bodyColors.longSleeves)
		addParts(model, costume.parts, tokens, budget)
		glow = costume.glow
	else
		local fallback: BodyColorSpec = {
			skin = def.bodyColor,
			shirt = def.accentColor,
			pants = def.bodyColor,
			shoes = def.accentColor,
			longSleeves = true,
		}
		paintBody(model, bodyTokens(fallback, def.accentColor), true)
	end

	local cfg = LOOKS.Legendary
	local auraHost = model:FindFirstChild(cfg.auraAttach)
	if auraHost then
		local aura = Presets.Create("LegendarySparkle", auraHost)
		aura.Name = "LegendaryAura"
		aura.Rate = cfg.auraRate
		aura.Enabled = true
	end
	local lightHost = model:FindFirstChild(cfg.lightAttach)
	if lightHost then
		local light = Instance.new("PointLight")
		light.Name = "LegendaryGlow"
		light.Color = color(glow)
		light.Brightness = cfg.lightBrightness
		light.Range = cfg.lightRange * def.scale
		light.Shadows = false
		light.Parent = lightHost
	end
	return model
end

-- A fresh legendary model (cached template, cloned). Yields only while the base rig is first built.
function Looks.BuildLegendary(legendaryId: Types.LegendaryId): Model?
	local template = legendaryTemplates[legendaryId]
	if not template then
		local built = buildLegendaryTemplate(legendaryId)
		if not built then
			return nil
		end
		-- Another caller may have finished first while we waited for the base rig.
		template = legendaryTemplates[legendaryId] or built
		legendaryTemplates[legendaryId] = template
	end
	return (template :: Model):Clone()
end

-- A fresh non-legendary customer with a random outfit, maybe an accessory, and its kind's cue.
function Looks.BuildCustomer(kind: Types.CustomerKind): Model?
	local base = getBaseRig()
	if not base then
		return nil
	end
	local model = base:Clone()
	local outfit = pick(LOOKS.Outfits)
	local tokens: Tokens = {
		skin = color(pick(LOOKS.SkinTones)),
		shirt = color(outfit.shirt),
		pants = color(outfit.pants),
		shoes = color(outfit.shoes),
		accent = color(outfit.accent),
		hair = color(pick(LOOKS.HairColors)),
	}
	paintBody(model, tokens, random:NextNumber() >= LOOKS.ShortSleeveChance)

	local budget: Budget = { left = LOOKS.MaxExtraParts, scale = 1 }
	local blocked: string? = nil
	if kind == "VIP" then
		addParts(model, LOOKS.VIP.parts, tokens, budget)
		blocked = LOOKS.VIP.blocksSlot
	elseif kind == "Hungry" then
		addParts(model, LOOKS.Hungry.parts, tokens, budget)
		addEmitter(model, LOOKS.Hungry.rumbleAttach, LOOKS.Hungry.rumble)
	end
	if random:NextNumber() < LOOKS.AccessoryChance then
		local options = {}
		for _, accessory in LOOKS.Accessories do
			if accessory.slot ~= blocked then
				table.insert(options, accessory)
			end
		end
		if #options > 0 then
			addParts(model, pick(options).parts, tokens, budget)
		end
	end
	return model
end

-- Builds the base rig and every enabled legendary up front so the first spawns don't stall.
function Looks.Prewarm()
	if not getBaseRig() then
		return
	end
	for id, def in CustomerConfig.Legendary do
		if def.enabled and not legendaryTemplates[id] then
			local built = buildLegendaryTemplate(id)
			if built then
				legendaryTemplates[id] = built
			end
		end
	end
end

return Looks

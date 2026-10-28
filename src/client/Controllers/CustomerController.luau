--!strict
-- CustomerController: order bubbles over customers' heads and the client side of serving.
-- Bubble = white speech bubble with a tail, the dish icon inside a patience ring that drains clockwise
-- and blends green -> yellow -> red, a kind tag (VIP / HUNGRY / legendary name) and a wiggle when time
-- runs low. Legendaries get a pink frame and spinning gold rays. Owner: UI agent.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local Icons = require(script.Parent.Parent.UI.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ticker = require(script.Parent.Parent.UI.Ticker)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Tween = require(script.Parent.Parent.UI.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local CustomerController = {}

local C = Theme.C
local U = Theme.UI

type Bubble = {
	gui: BillboardGui,
	root: Frame,
	face: Frame,
	faceStroke: UIStroke,
	left: Frame,
	right: Frame,
	leftGrad: UIGradient,
	rightGrad: UIGradient,
	iconHost: Frame,
	legendary: boolean,
	dishId: Types.DishId,
	stopRays: (() -> ())?,
	leaving: boolean,
}

local bubbles: { [number]: Bubble } = {}

local TAIL = 20
local FACE_RADIUS = 28
local TAG_HEIGHT = 22
local RAY_COUNT = 8
local RAY_SIZE = 130
local EDGE = 0.001

local HALF_MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.5 + EDGE, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function findHead(id: number): BasePart?
	local folder = workspace:FindFirstChild(WorldSchema.Folders.Customers)
	local model = folder and folder:FindFirstChild(WorldSchema.CustomerPrefix .. id)
	if not model then
		return nil
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return nil
end

local function destroyBubble(b: Bubble)
	if b.stopRays then
		b.stopRays()
	end
	b.gui:Destroy()
end

local function removeBubble(id: number, served: boolean?)
	local b = bubbles[id]
	if not b then
		return
	end
	bubbles[id] = nil
	if b.leaving then
		return
	end
	b.leaving = true
	if served then
		Util.clear(b.iconHost)
		Icons.build("Success", b.iconHost, U.BubbleIcon, { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
		b.left.BackgroundColor3 = C.Success
		b.right.BackgroundColor3 = C.Success
		b.leftGrad.Rotation = 360
		b.rightGrad.Rotation = 180
		b.root.Rotation = 0
		Tween.bounce(b.root, 1.25)
		task.delay(U.BubbleServedSeconds, function()
			Tween.popOut(b.root, function()
				destroyBubble(b)
			end)
		end)
	else
		Tween.popOut(b.root, function()
			destroyBubble(b)
		end)
	end
end

-- One half of the patience ring: a clip frame holding a full circle masked by a hard-edged gradient.
local function ringHalf(parent: Instance, side: number): (Frame, UIGradient)
	local clip = Util.frame(parent, {
		Name = if side == 0 then "Left" else "Right",
		Position = UDim2.fromScale(side * 0.5, 0),
		Size = UDim2.fromScale(0.5, 1),
		ClipsDescendants = true,
		ZIndex = 4,
	})
	local circle = Util.solid(clip, C.PatienceHigh, 0, {
		Position = UDim2.fromScale(-side, 0),
		Size = UDim2.fromScale(2, 1),
		ZIndex = 4,
	})
	Util.pill(circle)
	local grad = Util.new("UIGradient", { Transparency = HALF_MASK }, circle) :: UIGradient
	return circle, grad
end

local function kindTag(parent: Instance, view: Types.CustomerView): Frame?
	local text: string? = nil
	local color = C.Primary
	local textColor = C.Text
	local icon: string? = nil
	if view.kind == "VIP" then
		text, icon = "VIP", "Crown"
	elseif view.kind == "Hungry" then
		text, color, textColor = "HUNGRY!", C.Danger, C.TextInverse
	elseif view.kind == "Legendary" then
		text, color, textColor, icon = string.upper(view.displayName), C.Accent, C.TextInverse, "Star"
	end
	if not text then
		return nil
	end
	local tag = Util.solid(parent, color, 0, {
		Name = "KindTag",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, TAG_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -4,
		ZIndex = 10,
	})
	Util.pill(tag)
	Util.bevel(tag)
	Util.stroke(tag, C.Outline, Theme.Stroke.Thin)
	Util.padding(tag, 0, Theme.Space.SM, 0, Theme.Space.SM)
	Util.list(tag, Enum.FillDirection.Horizontal, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if icon then
		Icons.build(icon, tag, TAG_HEIGHT - 6, { LayoutOrder = 1, ZIndex = 11 })
	end
	local label = Util.display(tag, text, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = Theme.Type.Caption,
		TextColor3 = textColor,
		LayoutOrder = 2,
		ZIndex = 11,
	})
	if textColor == C.TextInverse then
		Util.textStroke(label, C.Outline, Theme.Stroke.Hair + 0.5)
	end
	Util.maxSize(tag, U.BubbleWidth + Theme.Space.XL * 2)
	return tag
end

local function legendaryRays(parent: Instance): () -> ()
	local host = Util.frame(parent, {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, U.BubbleFace / 2),
		Size = UDim2.fromOffset(RAY_SIZE, RAY_SIZE),
		ZIndex = 0,
	})
	for i = 1, RAY_COUNT do
		local ray = Util.frame(host, {
			BackgroundTransparency = 0.35,
			BackgroundColor3 = C.RushWarm,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 16, 1, 0),
			Rotation = (i - 1) * (180 / RAY_COUNT),
			ZIndex = 0,
		})
		Util.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
		}, ray)
	end
	return Tween.spin(host, U.LegendaryRaySeconds)
end

local function createBubble(view: Types.CustomerView, head: BasePart): Bubble
	local dishId: Types.DishId = view.dishId or "Burger" -- caller guarantees a dish
	local legendary = view.kind == "Legendary"
	local gui = Util.new("BillboardGui", {
		Name = "OrderBubble",
		Adornee = head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ClipsDescendants = false,
		MaxDistance = U.BubbleMaxDistance,
		Size = UDim2.fromOffset(U.BubbleWidth, U.BubbleHeight),
		StudsOffset = Vector3.new(0, U.BubbleOffsetY, 0),
		ResetOnSpawn = false,
	}, head) :: BillboardGui

	local root = Util.frame(gui, { Name = "Bubble", Size = UDim2.fromScale(1, 1) })
	local stopRays = if legendary then legendaryRays(root) else nil

	local faceTop = TAG_HEIGHT / 2
	local faceSize = U.BubbleFace
	-- Shadow + tail behind the face.
	local shadow = Util.solid(root, C.Shadow, FACE_RADIUS, {
		BackgroundTransparency = Theme.Depth.ShadowTransparency - 0.1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, faceTop + Theme.Depth.ShadowOffset),
		Size = UDim2.fromOffset(faceSize, faceSize),
		ZIndex = 1,
	})
	shadow.Name = "Shadow"
	local tail = Util.solid(root, C.Raised, 4, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, faceTop + faceSize - 2),
		Size = UDim2.fromOffset(TAIL, TAIL),
		Rotation = 45,
		ZIndex = 2,
	})
	Util.stroke(tail, if legendary then C.Accent else C.Outline, Theme.Stroke.Bold)

	local face = Util.solid(root, C.Raised, FACE_RADIUS, {
		Name = "Face",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, faceTop),
		Size = UDim2.fromOffset(faceSize, faceSize),
		ZIndex = 3,
	})
	local faceStroke = Util.stroke(face, if legendary then C.Accent else C.Outline, Theme.Stroke.Bold)
	if legendary then
		faceStroke.Thickness = Theme.Stroke.Bold + 1.5
	end
	-- Hide the face stroke where the tail joins.
	Util.frame(root, {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Raised,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, faceTop + faceSize - 1),
		Size = UDim2.fromOffset(TAIL - 4, Theme.Stroke.Bold + 3),
		ZIndex = 4,
	})

	-- Patience ring.
	local ring = Util.frame(face, {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(U.BubbleRing, U.BubbleRing),
		ZIndex = 3,
	})
	local track = Util.solid(ring, C.Sunken, 0, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	Util.pill(track)
	local left, leftGrad = ringHalf(ring, 0)
	local right, rightGrad = ringHalf(ring, 1)
	local inner = U.BubbleRing - U.BubbleRingThickness * 2
	local disc = Util.solid(ring, if legendary then C.AccentLight else C.Raised, 0, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(inner, inner),
		ZIndex = 6,
	})
	Util.pill(disc)
	local iconHost = Util.frame(ring, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(U.BubbleIcon, U.BubbleIcon),
		ZIndex = 7,
	})
	Icons.build(dishId, iconHost, U.BubbleIcon, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })

	kindTag(root, view)
	Tween.popIn(root)
	return {
		gui = gui,
		root = root,
		face = face,
		faceStroke = faceStroke,
		left = left,
		right = right,
		leftGrad = leftGrad,
		rightGrad = rightGrad,
		iconHost = iconHost,
		legendary = legendary,
		dishId = dishId,
		stopRays = stopRays,
		leaving = false,
	}
end

local function setRing(b: Bubble, remaining: number, now: number)
	local angle = remaining * 360
	b.rightGrad.Rotation = math.clamp(angle, 0, 180)
	b.leftGrad.Rotation = math.clamp(angle, 180, 360)
	local color = if b.legendary then C.Accent else Theme.patienceColor(remaining)
	b.left.BackgroundColor3 = color
	b.right.BackgroundColor3 = color
	if remaining < U.BubbleLowPatience and remaining > 0 then
		b.root.Rotation = math.sin(now * U.BubbleWiggleSpeed) * U.BubbleWiggleDegrees
		b.faceStroke.Color = if b.legendary then C.Accent else C.PatienceLow
	else
		b.root.Rotation = 0
		b.faceStroke.Color = if b.legendary then C.Accent else C.Outline
	end
end

local function step(now: number)
	for id, view in State.customers do
		local dishId = view.dishId
		local placedAt = view.placedAt
		local patience = view.patienceSeconds
		if view.phase == "Waiting" and dishId and placedAt and patience then
			local b: Bubble? = bubbles[id]
			if b and (b.dishId ~= dishId or not b.gui.Parent) then
				removeBubble(id)
				b = nil
			end
			if not b then
				local head = findHead(id)
				if head then
					b = createBubble(view, head)
					bubbles[id] = b
				end
			end
			if b then
				local remaining = if patience > 0 then Util.clamp01(1 - (now - placedAt) / patience) else 0
				setRing(b, remaining, now)
			end
		elseif bubbles[id] then
			-- Waiting -> Eating means the order was served.
			removeBubble(id, view.phase == "Eating")
		end
	end
	for id in bubbles do
		if not State.customers[id] then
			removeBubble(id)
		end
	end
end

local function dishName(dishId: Types.DishId): string
	return Dishes.Defs[dishId].displayName
end

local function onTriggered(prompt: ProximityPrompt, who: Player)
	if who ~= Players.LocalPlayer then
		return
	end
	local id = Util.findAttribute(prompt.Parent, WorldSchema.Attributes.CustomerId)
	if typeof(id) ~= "number" then
		return
	end
	local held = State.held
	local view = State.customers[id]
	local b = bubbles[id]
	if not held then
		Toast.show("Cook a dish first, then bring it here", "Warning")
		if b then
			Tween.shake(b.root)
		end
		return
	end
	if held.quality == "Burnt" then
		Toast.show("That dish is burnt. Clear it and cook again", "Warning")
		return
	end
	if view and view.dishId and view.dishId ~= held.dishId then
		Toast.show(`They want {dishName(view.dishId)}, you are holding {dishName(held.dishId)}`, "Warning")
		if b then
			Tween.shake(b.root)
			Tween.bounce(b.iconHost, 1.3)
		end
		return
	end
	Net.event("ServeCustomer"):FireServer({ customerId = id })
end

function CustomerController.Init() end

function CustomerController.Start()
	State.waitReady()
	Ticker.add(step)
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	State.Changed.CustomerRemoved:Connect(function(p)
		removeBubble(p.id, p.reason == "Served")
	end)
end

return CustomerController

--!strict
-- CustomerController: order bubbles over customers' heads (dish icon + patience bar, golden for
-- legendaries) and the client side of serving. Owner: agent D.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DishIcon = require(script.Parent.Parent.UI.DishIcon)
local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
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

local C = Theme.Colors
local U = Theme.UI

type Bubble = {
	gui: BillboardGui,
	card: Frame,
	fill: Frame,
	legendary: boolean,
	dishId: Types.DishId,
}

local bubbles: { [number]: Bubble } = {}

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

local function removeBubble(id: number)
	local b = bubbles[id]
	if b then
		bubbles[id] = nil
		b.gui:Destroy()
	end
end

local function createBubble(view: Types.CustomerView, head: BasePart): Bubble
	local dishId: Types.DishId = view.dishId or "Burger" -- caller guarantees a dish
	local legendary = view.kind == "Legendary"
	local gui = Util.new("BillboardGui", {
		Name = "OrderBubble",
		Adornee = head,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = U.BubbleMaxDistance,
		Size = UDim2.fromOffset(U.BubbleWidth, U.BubbleHeight),
		StudsOffset = Vector3.new(0, U.BubbleOffsetY, 0),
	}, head) :: BillboardGui

	local card = Util.card(gui, if legendary then C.Mustard else C.Cream, {
		Size = UDim2.new(1, 0, 1, -(U.BubbleBarHeight + U.Gap)),
	})
	if legendary then
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = C.NeonPink
			stroke.Thickness = U.Stroke + 2
		end
		local grad = Util.new("UIGradient", {
			Color = ColorSequence.new(C.Mustard, C.NeonPink),
		}, card) :: UIGradient
		TweenService:Create(
			grad,
			TweenInfo.new(U.LegendaryShimmerSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
			{ Rotation = 360 }
		):Play()
		Util.label(card, view.displayName, {
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = U.TextSmall,
			TextColor3 = C.White,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	local iconHost = Util.frame(card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if legendary then 0.58 else 0.5),
		Size = UDim2.fromScale(0.7, if legendary then 0.6 else 0.8),
	})
	DishIcon.create(dishId, iconHost)

	local track = Util.card(gui, C.Cream, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, U.BubbleBarHeight),
		ClipsDescendants = true,
	})
	local fill = Util.frame(track, {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Mint,
		Size = UDim2.fromScale(1, 1),
	})
	Tween.popIn(card)
	return { gui = gui, card = card, fill = fill, legendary = legendary, dishId = dishId }
end

local function step(now: number)
	for id, view in State.customers do
		local dishId = view.dishId
		local placedAt = view.placedAt
		local patience = view.patienceSeconds
		if view.phase == "Waiting" and dishId and placedAt and patience then
			local b: Bubble? = bubbles[id]
			if b and b.dishId ~= dishId then
				removeBubble(id)
				b = nil
			end
			if b and not b.gui.Parent then
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
				b.fill.Size = UDim2.fromScale(remaining, 1)
				if b.legendary then
					b.fill.BackgroundColor3 = C.NeonPink
				elseif remaining > U.BubbleMidPatience then
					b.fill.BackgroundColor3 = C.Mint
				elseif remaining > U.BubbleLowPatience then
					b.fill.BackgroundColor3 = C.Mustard
				else
					b.fill.BackgroundColor3 = C.Ketchup
				end
			end
		else
			removeBubble(id)
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
	if not held then
		Toast.show("Cook a dish first, then bring it here", "Warning")
		return
	end
	if held.quality == "Burnt" then
		Toast.show("That dish is burnt. Clear it and cook again", "Warning")
		return
	end
	if view and view.dishId and view.dishId ~= held.dishId then
		Toast.show(`They want {dishName(view.dishId)}, you are holding {dishName(held.dishId)}`, "Warning")
		local b = bubbles[id]
		if b then
			Tween.bounce(b.card)
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
		removeBubble(p.id)
	end)
end

return CustomerController

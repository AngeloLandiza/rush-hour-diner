--!strict
-- TutorialController: first-minute coach mark. A compact glass chip at the bottom (step dots, one
-- short instruction, Skip) plus a bobbing world chevron and a thin pink beam to the station that
-- matches the first customer's order, then to that customer. Completes after the first serve, on
-- Skip, or on timeout. Owner: UI agent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Card = require(script.Parent.Parent.UI.Components.Card)
local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local Icons = require(script.Parent.Parent.UI.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local StationPanel = require(script.Parent.Parent.UI.Screens.StationPanel)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ticker = require(script.Parent.Parent.UI.Ticker)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Tween = require(script.Parent.Parent.UI.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local TutorialController = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local STEPS = 3
-- "Cook a Burger" but "Cook some Fries".
local ARTICLE: { [string]: string } = { Fries = "some" }
local DOT = 8
local SKIP_W = 56
local STEP_DISC = 30

local function stationPart(plotId: number, stationId: Types.StationId): BasePart?
	local plots = workspace:FindFirstChild(WorldSchema.Folders.Plots)
	local plot = plots and plots:FindFirstChild(WorldSchema.PlotPrefix .. plotId)
	local stations = plot and plot:FindFirstChild(WorldSchema.Parts.Stations)
	if not stations then
		return nil
	end
	for _, slot in stations:GetChildren() do
		if slot:GetAttribute(WorldSchema.Attributes.StationId) == stationId then
			local part = slot:FindFirstChild(WorldSchema.Parts.Interact)
			if part and part:IsA("BasePart") then
				return part
			end
		end
	end
	return nil
end

local function customerPart(id: number): BasePart?
	local folder = workspace:FindFirstChild(WorldSchema.Folders.Customers)
	local model = folder and folder:FindFirstChild(WorldSchema.CustomerPrefix .. id)
	local part = model and (model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head"))
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Lowest-id waiting customer on my plot.
local function firstCustomer(): Types.CustomerView?
	local best: Types.CustomerView? = nil
	for _, v in State.customers do
		if v.dishId and v.phase == "Waiting" and (State.myPlotId == nil or v.plotId == State.myPlotId) then
			if not best or v.id < best.id then
				best = v
			end
		end
	end
	return best
end

-- True if a station on my plot cooking this dish is ready to collect.
local function dishReady(dishId: Types.DishId): boolean
	for _, s in State.stations do
		if s.plotId == State.myPlotId and s.dishId == dishId and s.phase == "Ready" then
			return true
		end
	end
	return false
end

function TutorialController.Init() end

function TutorialController.Start()
	State.waitReady()
	local data = State.data
	while not data do
		task.wait(U.ClockSeconds)
		data = State.data
	end
	if not data or data.tutorialDone then
		return
	end
	local startedAt = os.clock()
	local finished = false

	-- ── Coach chip ──────────────────────────────────────────────────────────
	local layer = Root.layer("Tutorial", U.ZTutorial)
	local coach = Card.new({
		parent = layer,
		variant = "glass",
		radius = math.huge,
		name = "CoachMark",
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -U.Margin),
		size = UDim2.new(1, -U.Margin * 2, 0, U.CoachHeight),
	})
	-- Hidden until it has a line to show, so it never flashes up empty.
	coach.instance.Visible = false
	Util.maxSize(coach.instance, U.CoachMaxWidth)
	if coach.stroke then
		coach.stroke.Color = C.Accent
		coach.stroke.Transparency = 0
		coach.stroke.Thickness = Theme.Stroke.Base
	end
	local face = coach.face
	local disc = Util.solid(face, C.Accent, 0, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Space.SM, 0.5, 0),
		Size = UDim2.fromOffset(STEP_DISC, STEP_DISC),
		ZIndex = 3,
	})
	Util.pill(disc)
	Util.bevel(disc)
	Util.stroke(disc, C.Outline, Theme.Stroke.Thin)
	local stepLabel =
		Util.display(disc, "1", { TextSize = Theme.Type.Body + 1, TextColor3 = C.TextInverse, ZIndex = 4 }, C.Outline)
	local textX = STEP_DISC + Space.SM * 2
	local text = Util.label(face, "", {
		Position = UDim2.fromOffset(textX, 4),
		Size = UDim2.new(1, -(textX + SKIP_W + Space.SM), 0, 26),
		TextSize = Theme.Type.Body,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(text, Theme.Type.Body)
	local dots = Util.frame(face, {
		Position = UDim2.fromOffset(textX, 32),
		Size = UDim2.fromOffset(60, DOT),
		ZIndex = 3,
	})
	Util.list(dots, Enum.FillDirection.Horizontal, Space.XS)
	local dotFrames: { Frame } = {}
	for i = 1, STEPS do
		local d = Util.solid(dots, C.TextOnGlassMuted, 0, {
			Size = UDim2.fromOffset(DOT * 2, DOT),
			LayoutOrder = i,
			ZIndex = 3,
		})
		Util.pill(d)
		table.insert(dotFrames, d)
	end
	local skip = Util.new("TextButton", {
		Name = "Skip",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(SKIP_W, Theme.MinTouchTarget),
		ZIndex = 5,
	}, face) :: TextButton
	Util.display(skip, "Skip", {
		TextSize = Theme.Type.Small,
		TextColor3 = C.TextOnGlassMuted,
		ZIndex = 5,
	})
	local stationOpen = false
	local function placeCoach()
		local hide = stationOpen and Root.isShort()
		coach.instance.Visible = not finished and not hide and text.Text ~= ""
		local bottom = U.Margin
		if stationOpen then
			bottom += U.StationPanelHeight + U.Margin + Space.LG
		end
		if State.held then
			bottom += U.HeldChipHeight + U.Gap
		end
		Tween.play(coach.instance, { Position = UDim2.new(0.5, 0, 1, -bottom) }, Theme.Motion.Slide)
	end
	local panelConn = StationPanel.OpenChanged:Connect(function(open)
		stationOpen = open
		placeCoach()
	end)
	local heldConn = State.Changed.Held:Connect(function()
		placeCoach()
	end)

	local currentStep = 0
	local function setStep(n: number, caption: string)
		local first = false
		if text.Text ~= caption then
			first = text.Text == ""
			text.Text = caption
			if first then
				placeCoach()
				Tween.popIn(coach.instance)
			end
		end
		if n == currentStep then
			return
		end
		currentStep = n
		stepLabel.Text = tostring(n)
		for i, d in dotFrames do
			d.BackgroundColor3 = if i <= n then C.Accent else C.TextOnGlassMuted
		end
		if not first then
			Tween.bounce(coach.instance, 1.08)
		end
	end

	-- ── World guide ─────────────────────────────────────────────────────────
	local a0: Attachment? = nil
	local beam: Beam? = nil
	local arrow: BillboardGui? = nil
	local arrowLabel: TextLabel? = nil
	local a1: Attachment? = nil
	local targetPart: BasePart? = nil

	local function clearGuide()
		for _, inst in { beam, a0, a1, arrow } :: { Instance? } do
			if inst then
				inst:Destroy()
			end
		end
		beam, a0, a1, arrow, arrowLabel = nil, nil, nil, nil, nil
		targetPart = nil
	end

	local function guideTo(part: BasePart, caption: string)
		if targetPart == part then
			local l = arrowLabel
			if l and l.Text ~= caption then
				l.Text = caption
			end
			return
		end
		clearGuide()
		targetPart = part
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local s = Instance.new("Attachment")
			s.Name = "TutorialStart"
			s.Parent = root
			local e = Instance.new("Attachment")
			e.Name = "TutorialEnd"
			e.Parent = part
			local b = Instance.new("Beam")
			b.Attachment0 = s
			b.Attachment1 = e
			b.Color = ColorSequence.new(C.Accent)
			b.Transparency = NumberSequence.new(0.15, 0.55)
			b.Width0 = U.TutorialBeamWidth
			b.Width1 = U.TutorialBeamWidth
			b.LightEmission = 1
			b.FaceCamera = true
			b.Segments = 4
			b.Parent = root
			a0, a1, beam = s, e, b
		end
		local gui = Util.new("BillboardGui", {
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Name = "TutorialArrow",
			Adornee = part,
			AlwaysOnTop = true,
			LightInfluence = 0,
			ClipsDescendants = false,
			Size = UDim2.fromOffset(U.TutorialArrowSize * 2, U.TutorialArrowSize + 28),
			StudsOffset = Vector3.new(0, U.TutorialArrowHeight, 0),
		}, part) :: BillboardGui
		local tag = Util.solid(gui, C.Accent, 0, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
		})
		Util.pill(tag)
		Util.bevel(tag)
		Util.stroke(tag, C.Outline, Theme.Stroke.Base)
		Util.padding(tag, 0, Space.MD, 0, Space.MD)
		local label = Util.display(tag, caption, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = Theme.Type.Body,
			TextColor3 = C.TextInverse,
		}, C.Outline)
		Icons.build("Chevron", gui, U.TutorialArrowSize * 0.7, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 30),
		})
		Tween.popIn(tag)
		arrow, arrowLabel = gui, label
	end

	local function teardown()
		finished = true
		clearGuide()
		panelConn:Disconnect()
		heldConn:Disconnect()
		Tween.popOut(coach.instance, function()
			coach.instance:Destroy()
		end)
	end

	local function finish()
		if finished then
			return
		end
		teardown()
		Net.event("CompleteTutorial"):FireServer()
	end

	skip.Activated:Connect(finish)
	Net.event("OrderServed").OnClientEvent:Connect(function(p)
		if p.servedByUserId == Players.LocalPlayer.UserId and not finished then
			setStep(STEPS, "Nice! Keep serving to earn more coins")
			task.delay(Theme.UI.StampSeconds, finish)
		end
	end)
	State.Changed.Data:Connect(function(view)
		if view.tutorialDone and not finished then
			teardown()
		end
	end)
	placeCoach()

	Ticker.add(function()
		if finished then
			return
		end
		if os.clock() - startedAt >= Timings.Tutorial.DurationSeconds then
			finish()
			return
		end
		local customer = firstCustomer()
		if not customer or not customer.dishId then
			clearGuide()
			setStep(1, "Customers are on their way...")
			return
		end
		local dish = Dishes.Defs[customer.dishId]
		local held = State.held
		if held and held.dishId == customer.dishId and held.quality ~= "Burnt" then
			setStep(3, `Bring the {dish.displayName} to your customer`)
			local part = customerPart(customer.id)
			if part then
				guideTo(part, "SERVE")
			end
		else
			local station = Stations.Defs[dish.stationId]
			if dishReady(customer.dishId) then
				setStep(2, `Collect the {dish.displayName} before it burns!`)
			else
				local article = ARTICLE[customer.dishId] or "a"
				setStep(1, `Cook {article} {dish.displayName} at the {station.displayName}`)
			end
			local plotId = State.myPlotId or customer.plotId
			local part = stationPart(plotId, dish.stationId)
			if part then
				guideTo(part, if dishReady(customer.dishId) then "COLLECT" else "COOK HERE")
			end
		end
		local gui = arrow
		if gui then
			local bob = math.sin(os.clock() * U.TutorialBobSpeed) * U.TutorialArrowBobStuds
			gui.StudsOffset = Vector3.new(0, U.TutorialArrowHeight + bob, 0)
		end
	end)
end

return TutorialController

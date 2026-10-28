--!strict
-- TutorialController: first-minute guidance. Beam + arrow to the station that matches the first
-- customer's order, then to that customer. Completes after the first serve or on timeout.
-- Owner: agent D.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local Net = require(ReplicatedStorage.Shared.Net)
local Root = require(script.Parent.Parent.UI.Root)
local State = require(script.Parent.Parent.State)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ticker = require(script.Parent.Parent.UI.Ticker)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local TutorialController = {}

local C = Theme.Colors
local U = Theme.UI

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

function TutorialController.Init() end

function TutorialController.Start()
	State.waitReady()
	local data = State.data
	if not data or data.tutorialDone then
		return
	end
	local startedAt = os.clock()
	local finished = false

	local layer = Root.layer("Tutorial", U.ZToasts - 1)
	local hint = Util.card(layer, C.NeonPink, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(U.StationPanelHeight + U.Margin * 2)),
		Size = UDim2.new(1, -U.Margin * 2, 0, U.TutorialTextHeight),
		Visible = false,
	})
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(U.StationPanelMaxWidth, math.huge) }, hint)
	local hintLabel = Util.label(hint, "", { TextColor3 = C.White })

	local a0: Attachment? = nil
	local beam: Beam? = nil
	local arrow: BillboardGui? = nil
	local arrowLabel: TextLabel? = nil
	local a1: Attachment? = nil
	local targetPart: BasePart? = nil

	local function clearGuide()
		if beam then
			beam:Destroy()
			beam = nil
		end
		if a0 then
			a0:Destroy()
			a0 = nil
		end
		if a1 then
			a1:Destroy()
			a1 = nil
		end
		if arrow then
			arrow:Destroy()
			arrow = nil
		end
		targetPart = nil
	end

	local function guideTo(part: BasePart, caption: string)
		if targetPart == part then
			if arrowLabel then
				arrowLabel.Text = caption
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
			b.Color = ColorSequence.new(C.NeonPink)
			b.Width0 = U.TutorialBeamWidth
			b.Width1 = U.TutorialBeamWidth
			b.LightEmission = 1
			b.FaceCamera = true
			b.Parent = root
			a0, a1, beam = s, e, b
		end
		local gui = Util.new("BillboardGui", {
			Name = "TutorialArrow",
			Adornee = part,
			AlwaysOnTop = true,
			LightInfluence = 0,
			Size = UDim2.fromOffset(U.TutorialArrowSize * 2, U.TutorialArrowSize),
			StudsOffset = Vector3.new(0, U.TutorialArrowHeight, 0),
		}, part) :: BillboardGui
		local label = Util.label(gui, caption, {
			Size = UDim2.fromScale(1, 0.5),
			TextSize = U.TextBody,
			TextColor3 = C.White,
		})
		Util.new("UIStroke", { Color = C.Ink, Thickness = U.ThinStroke }, label)
		local diamond = Util.card(gui, C.NeonPink, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(U.TutorialArrowSize / 3, U.TutorialArrowSize / 3),
			Rotation = 45,
		})
		diamond.Name = "Diamond"
		arrow, arrowLabel = gui, label
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		clearGuide()
		hint:Destroy()
		Net.event("CompleteTutorial"):FireServer()
	end

	Net.event("OrderServed").OnClientEvent:Connect(function(p)
		if p.servedByUserId == Players.LocalPlayer.UserId then
			finish()
		end
	end)
	State.Changed.Data:Connect(function(view)
		if view.tutorialDone and not finished then
			finished = true
			clearGuide()
			hint:Destroy()
		end
	end)

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
			hint.Visible = true
			hintLabel.Text = "Customers are on their way..."
			return
		end
		local dish = Dishes.Defs[customer.dishId]
		local held = State.held
		hint.Visible = true
		if held and held.dishId == customer.dishId then
			hintLabel.Text = `Bring the {dish.displayName} to the customer!`
			local part = customerPart(customer.id)
			if part then
				guideTo(part, "SERVE HERE")
			end
		else
			local station = Stations.Defs[dish.stationId]
			hintLabel.Text = `Cook a {dish.displayName} at the {station.displayName}!`
			local plotId = State.myPlotId or customer.plotId
			local part = stationPart(plotId, dish.stationId)
			if part then
				guideTo(part, "COOK HERE")
			end
		end
		local gui = arrow
		if gui then
			gui.StudsOffset =
				Vector3.new(0, U.TutorialArrowHeight + math.sin(os.clock() * 4) * U.TutorialArrowBobStuds, 0)
		end
	end)
end

return TutorialController

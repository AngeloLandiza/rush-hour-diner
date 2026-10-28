--!strict
-- PromptController: custom ProximityPrompt UI. Every prompt is switched to Style = Custom locally and
-- rendered as a white pill with a keycap (E / F, gamepad X / Y, or a tap hint on touch), the action in
-- Fredoka and the object underneath. Touch/mouse taps call InputHoldBegin/End, so triggering still
-- goes through ProximityPromptService (StationController / CustomerController are unchanged).
-- Serve prompts turn mint when you hold the dish the customer wants. Station prompts hide while that
-- station's panel is open. If building the UI fails, the prompt falls back to the default style.
-- Owner: UI agent.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Parent.UI.Icons)
local State = require(script.Parent.Parent.State)
local StationPanel = require(script.Parent.Parent.UI.Screens.StationPanel)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tween = require(script.Parent.Parent.UI.Tween)
local Util = require(script.Parent.Parent.UI.Util)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local PromptController = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

type Shown = {
	gui: BillboardGui,
	root: Frame,
	face: Frame,
	edge: UIStroke,
	action: TextLabel,
	object: TextLabel,
	isServe: boolean,
	customerId: number?,
}

local shown: { [ProximityPrompt]: Shown } = {}

local GAMEPAD_LABEL: { [string]: string } = {
	ButtonX = "X",
	ButtonY = "Y",
	ButtonA = "A",
	ButtonB = "B",
}

-- BillboardGuis must sit directly in PlayerGui to receive taps.
local function playerGui(): Instance
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string?
	if inputType == Enum.ProximityPromptInputType.Touch then
		return nil
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_LABEL[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	end
	return prompt.KeyboardKeyCode.Name
end

local function customerIdOf(prompt: ProximityPrompt): number?
	local id = Util.findAttribute(prompt.Parent, WorldSchema.Attributes.CustomerId)
	return if typeof(id) == "number" then id else nil
end

local function stationHidden(prompt: ProximityPrompt): boolean
	local open = StationPanel.currentInteract()
	return open ~= nil and prompt.Parent == open
end

-- Mint when the held dish matches the order, otherwise white.
local function refreshServe(s: Shown)
	if not s.isServe then
		return
	end
	local held = State.held
	local view = if s.customerId then State.customers[s.customerId] else nil
	local match = held ~= nil and held.quality ~= "Burnt" and view ~= nil and view.dishId == held.dishId
	s.face.BackgroundColor3 = if match then C.Success else C.Raised
	s.edge.Color = if match then C.SuccessEdge else C.Outline
	s.action.TextColor3 = if match then C.TextInverse else C.Text
	s.object.TextColor3 = if match then C.TextInverse else C.TextMuted
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): Shown
	local isServe = customerIdOf(prompt) ~= nil
	local gui = Util.new("BillboardGui", {
		Name = "RHD_Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		ClipsDescendants = false,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(U.PromptWidth, U.PromptHeight),
		StudsOffset = Vector3.new(0, if isServe then U.CustomerPromptStudsOffsetY else U.PromptStudsOffsetY, 0),
	}, playerGui()) :: BillboardGui

	local hit = Util.new("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}, gui) :: TextButton
	local root = Util.frame(hit, { Name = "Root", Size = UDim2.fromScale(1, 1) })
	local shadow = Util.solid(root, C.Shadow, 0, {
		BackgroundTransparency = Theme.Depth.ShadowTransparency,
		Position = UDim2.fromOffset(0, Theme.Depth.ShadowOffset),
		Size = UDim2.new(1, 0, 1, -Theme.Depth.ShadowOffset),
		ZIndex = 1,
	})
	Util.pill(shadow)
	local face = Util.solid(root, C.Raised, 0, {
		Size = UDim2.new(1, 0, 1, -Theme.Depth.ShadowOffset),
		ZIndex = 2,
	})
	Util.pill(face)
	Util.bevel(face)
	local edge = Util.stroke(face, C.Outline, Theme.Stroke.Base)

	local key = keyText(prompt, inputType)
	local capSize = U.PromptKeySize
	local cap = Util.solid(face, if key then C.Info else C.Primary, 0, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(capSize, capSize),
		ZIndex = 3,
	})
	Util.pill(cap)
	Util.bevel(cap)
	Util.stroke(cap, C.Outline, Theme.Stroke.Thin)
	if key then
		Util.display(cap, key, {
			TextSize = if #key > 1 then Theme.Type.Micro else Theme.Type.Title,
			TextColor3 = C.TextInverse,
			ZIndex = 4,
		}, C.Outline)
	else
		Icons.build(if isServe then "Shop" else "Flame", cap, capSize - 12, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 4,
		})
	end

	local textX = capSize + Space.SM + 2
	local action = Util.display(face, prompt.ActionText, {
		Position = UDim2.fromOffset(textX, 3),
		Size = UDim2.new(1, -(textX + Space.MD), 0.56, 0),
		TextSize = Theme.Type.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(action, Theme.Type.Title)
	local object = Util.label(face, prompt.ObjectText, {
		Position = UDim2.new(0, textX, 0.56, 0),
		Size = UDim2.new(1, -(textX + Space.MD), 0.36, 0),
		TextSize = Theme.Type.Caption,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(object, Theme.Type.Caption)

	hit.MouseButton1Down:Connect(function()
		Tween.press(root)
	end)
	hit.MouseLeave:Connect(function()
		Tween.release(root)
	end)
	hit.MouseButton1Up:Connect(function()
		Tween.release(root)
	end)
	hit.Activated:Connect(function()
		if prompt.Enabled then
			prompt:InputHoldBegin()
			task.defer(function()
				prompt:InputHoldEnd()
			end)
		end
	end)

	Tween.popIn(root)
	local s: Shown = {
		gui = gui,
		root = root,
		face = face,
		edge = edge,
		action = action,
		object = object,
		isServe = isServe,
		customerId = customerIdOf(prompt),
	}
	refreshServe(s)
	gui.Enabled = not stationHidden(prompt)
	return s
end

local function hide(prompt: ProximityPrompt)
	local s = shown[prompt]
	if not s then
		return
	end
	shown[prompt] = nil
	local gui = s.gui
	Tween.popOut(s.root, function()
		gui:Destroy()
	end)
end

local function adopt(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		inst.Style = Enum.ProximityPromptStyle.Custom
	end
end

-- Init (not Start) so prompts are custom before any of them is first shown.
function PromptController.Init()
	for _, d in workspace:GetDescendants() do
		adopt(d)
	end
	workspace.DescendantAdded:Connect(adopt)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		hide(prompt)
		local ok, result = pcall(function()
			return build(prompt, inputType)
		end)
		if ok then
			shown[prompt] = result
		else
			warn(`[PromptController] custom prompt failed, using default: {result}`)
			prompt.Style = Enum.ProximityPromptStyle.Default
		end
	end)
	ProximityPromptService.PromptHidden:Connect(hide)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		local s = shown[prompt]
		if s and who == Players.LocalPlayer then
			Tween.bounce(s.root, 1.15)
		end
	end)

	State.Changed.Held:Connect(function()
		for _, s in shown do
			refreshServe(s)
		end
	end)
	StationPanel.OpenChanged:Connect(function()
		for prompt, s in shown do
			s.gui.Enabled = not stationHidden(prompt)
		end
	end)
end

function PromptController.Start() end

return PromptController

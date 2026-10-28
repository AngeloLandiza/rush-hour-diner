--!strict
-- Station minigame panel (bottom-center action area): dish medallion, phase hint, a striped progress
-- bar or the flip timing track (perfect zone + needle), and one big phase-colored action button with a
-- keycap hint. Renders server state only: it sends intents and never decides outcomes. Owner: UI agent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Card = require(script.Parent.Parent.Components.Card)
local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local Icons = require(script.Parent.Parent.Icons)
local InputController = require(script.Parent.Parent.Parent.Controllers.InputController)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local Root = require(script.Parent.Parent.Root)
local Signal = require(script.Parent.Parent.Parent.Signal)
local Stamp = require(script.Parent.Parent.Components.Stamp)
local State = require(script.Parent.Parent.Parent.State)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Theme = require(script.Parent.Parent.Theme)
local Ticker = require(script.Parent.Parent.Ticker)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

export type StationPanel = {
	Open: (self: StationPanel, plotId: number, slot: number, stationId: Types.StationId, interact: Instance) -> (),
	Close: (self: StationPanel) -> (),
	Render: (self: StationPanel) -> (),
	IsOpenFor: (self: StationPanel, plotId: number, slot: number) -> boolean,
}

local StationPanel = {
	-- Fires true/false when the panel opens/closes (HUD moves the held-dish chip, prompts hide).
	OpenChanged = Signal.new() :: Signal.Signal<boolean>,
}

local openInteract: Instance? = nil

-- The Interact part of the station whose panel is open (nil when closed).
function StationPanel.currentInteract(): Instance?
	return openInteract
end

type PhaseLook =
	{ text: string, variant: Theme.VariantName, enabled: boolean, action: Types.CookAction?, icon: string? }

local LOOK: { [Types.StationPhase]: PhaseLook } = {
	Idle = { text = "HOLD TO COOK", variant = "primary", enabled = true, action = "Start", icon = "Flame" },
	Cooking = { text = "COOKING...", variant = "disabled", enabled = false, action = nil },
	NeedsFlip = { text = "FLIP!", variant = "accent", enabled = true, action = "Flip" },
	Finishing = { text = "ALMOST...", variant = "disabled", enabled = false, action = nil },
	Ready = { text = "COLLECT", variant = "success", enabled = true, action = "Collect" },
	Burnt = { text = "CLEAR", variant = "danger", enabled = true, action = "Clear", icon = "Error" },
}

local HINT: { [Types.StationPhase]: string } = {
	Idle = "Press and hold to start cooking",
	Cooking = "Get ready to flip...",
	NeedsFlip = "Flip in the green zone for PERFECT",
	Finishing = "Almost done",
	Ready = "Grab it before it burns!",
	Burnt = "Burnt! Clear it and try again",
}

local URGENT_BURN_SECONDS = 3
local NEEDLE_OVERHANG = 5

local function distanceTo(inst: Instance): number?
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	if inst:IsA("BasePart") then
		return (root.Position - inst.Position).Magnitude
	end
	return nil
end

local function keyHint(): string?
	if InputController.Mode == "Keyboard" then
		return "SPACE"
	elseif InputController.Mode == "Gamepad" then
		return "A"
	end
	return nil
end

function StationPanel.new(): StationPanel
	local layer = Root.layer("Station", U.ZStation)
	local card = Card.new({
		parent = layer,
		variant = "paper",
		radius = U.PanelRadius,
		name = "StationPanel",
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -U.Margin),
		size = UDim2.new(1, -U.Margin * 2, 0, U.StationPanelHeight),
	})
	local frame = card.instance
	frame.Visible = false
	Util.maxSize(frame, U.StationPanelWidth)
	local face = card.face
	local innerW = U.StationPanelWidth - Space.MD * 2

	-- Header: medallion, title, hint, close.
	local medal = Card.new({
		parent = face,
		variant = "raised",
		radius = math.huge,
		edge = C.Outline,
		position = UDim2.fromOffset(Space.MD, -Space.LG),
		size = UDim2.fromOffset(U.StationBadgeSize, U.StationBadgeSize),
		zIndex = 5,
	})
	if medal.stroke then
		medal.stroke.Thickness = Theme.Stroke.Base
	end
	local iconHost = Util.frame(medal.face, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.74, 0.74),
		ZIndex = 6,
	})
	local textX = U.StationBadgeSize + Space.MD + Space.SM
	local title = Util.display(face, "", {
		Position = UDim2.fromOffset(textX, Space.SM),
		Size = UDim2.new(1, -(textX + Theme.MinTouchTarget + Space.MD), 0, 24),
		TextSize = Theme.Type.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(title, Theme.Type.Title)
	local hint = Util.label(face, "", {
		Position = UDim2.fromOffset(textX, Space.SM + 24),
		Size = UDim2.new(1, -(textX + Theme.MinTouchTarget + Space.MD), 0, 18),
		TextSize = Theme.Type.Caption + 1,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(hint, Theme.Type.Caption + 1)

	-- Progress / flip area.
	local trackY = U.StationBadgeSize + Space.XS
	local bar = ProgressBar.new(
		face,
		UDim2.new(1, -Space.MD * 2, 0, U.StationTrackHeight),
		C.Success,
		U.StationTrackHeight,
		innerW
	)
	bar.instance.Position = UDim2.fromOffset(Space.MD, trackY)
	bar.instance.ZIndex = 3

	local flip = Util.frame(face, {
		Name = "FlipTrack",
		Position = UDim2.fromOffset(Space.MD, trackY),
		Size = UDim2.new(1, -Space.MD * 2, 0, U.StationTrackHeight),
		Visible = false,
		ZIndex = 3,
	})
	local flipTrack =
		Util.solid(flip, C.Primary, 0, { Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 3 })
	Util.pill(flipTrack)
	Util.bevel(flipTrack)
	Util.stroke(flipTrack, C.PrimaryEdge, Theme.Stroke.Thin)
	local perfectZone = Util.solid(flipTrack, C.Success, 0, { Size = UDim2.fromScale(0.3, 1), ZIndex = 4 })
	Util.pill(perfectZone)
	Util.display(perfectZone, "PERFECT", {
		TextSize = Theme.Type.Micro,
		TextColor3 = C.TextInverse,
		ZIndex = 5,
	}, C.Outline)
	Util.display(flipTrack, "GOOD", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Space.MD, 0, 0),
		Size = UDim2.fromScale(0.4, 1),
		TextSize = Theme.Type.Micro,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	})
	local needle = Util.solid(flip, C.Raised, 0, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, U.FlipNeedleWidth, 1, NEEDLE_OVERHANG * 2),
		ZIndex = 8,
	})
	Util.pill(needle)
	Util.stroke(needle, C.Outline, Theme.Stroke.Base)

	local plotId, slot = 0, 0
	local stationId: Types.StationId = "Grill"
	local interactPart: Instance? = nil
	local open = false
	local currentAction: Types.CookAction? = nil
	local lastPhase: Types.StationPhase? = nil
	local lastIcon: Types.DishId? = nil

	local function send(action: Types.CookAction)
		Net.event("CookAction"):FireServer({ plotId = plotId, slot = slot, action = action })
	end

	local actY = U.StationPanelHeight - Space.MD - U.StationActHeight
	local act = Button.new({
		name = "CookActionButton",
		text = "",
		parent = face,
		textSize = Theme.Type.Display - 4,
		iconSize = 30,
		size = UDim2.new(1, -Space.MD * 2, 0, U.StationActHeight),
		position = UDim2.fromOffset(Space.MD, actY),
		onDown = function()
			local a: Types.CookAction? = currentAction
			if a then
				send(a)
			end
		end,
	})
	act.instance.ZIndex = 3
	-- Keycap sticker on the button's top-right corner (never covers the label).
	local keycap = Card.new({
		parent = act.instance,
		variant = "glass",
		radius = Theme.Radius.SM,
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -Space.SM, 0, 2),
		size = UDim2.fromOffset(52, 20),
		shadow = false,
		zIndex = 10,
	})
	keycap.instance.Rotation = 4
	local keyLabel = Util.display(keycap.face, "", {
		TextSize = Theme.Type.Micro,
		TextColor3 = C.TextInverse,
		ZIndex = 11,
	})

	local self: StationPanel
	local closeBtn = Button.new({
		name = "StationCloseButton",
		parent = face,
		variant = "secondary",
		icon = "CloseInk",
		iconSize = 16,
		radius = math.huge,
		lip = Theme.Depth.SmallLip,
		size = UDim2.fromOffset(Theme.MinTouchTarget, Theme.MinTouchTarget),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -Space.SM, 0, Space.SM - 2),
		onActivated = function()
			self:Close()
		end,
	})
	closeBtn.instance.ZIndex = 4

	local function currentState(): Types.StationState?
		return State.getStation(plotId, slot)
	end

	local function stamp(text: string, color: Color3, size: number)
		Stamp.show(text, {
			color = color,
			textSize = size,
			position = UDim2.new(0.5, 0, 1, -(U.StationPanelHeight + U.Margin + Space.XL * 2 + Space.SM)),
			seconds = Theme.UI.StampSeconds * 0.6,
		})
	end

	local function stepBars(now: number)
		local st = currentState()
		if not st then
			return
		end
		bar:Step(now)
		if st.phase == "NeedsFlip" and st.phaseEndsAt then
			local len = st.phaseEndsAt - st.phaseStartedAt
			if len > 0 then
				local f = Util.clamp01((now - st.phaseStartedAt) / len)
				needle.Position = UDim2.fromScale(f, 0.5)
			end
		elseif st.phase == "Ready" and st.phaseEndsAt then
			local left = math.max(0, st.phaseEndsAt - now)
			bar:SetCaption(`BURNS IN {math.ceil(left)}s`)
			bar:SetColor(if left <= URGENT_BURN_SECONDS then C.Danger else C.Success)
		end
	end

	local function transition(from: Types.StationPhase?, to: Types.StationPhase, st: Types.StationState?)
		if from == to then
			return
		end
		if from == "NeedsFlip" and to == "Finishing" and st then
			if st.flipQuality == "Perfect" then
				stamp("PERFECT!", C.Primary, Theme.Type.Hero - 6)
			elseif st.flipQuality == "Good" then
				stamp("GOOD!", C.Success, Theme.Type.Display)
			end
		elseif to == "Burnt" then
			stamp("BURNT!", C.Danger, Theme.Type.Display + 4)
			Tween.shake(frame)
		elseif to == "Ready" or to == "NeedsFlip" then
			act:Bounce()
		end
	end

	self = {
		IsOpenFor = function(_, p: number, s: number): boolean
			return open and plotId == p and slot == s
		end,
		Close = function(_)
			if not open then
				return
			end
			open = false
			openInteract = nil
			InputController.Unbind("RHD_StationAct")
			StationPanel.OpenChanged:Fire(false)
			Tween.popOut(frame, function()
				if not open then
					frame.Visible = false
				end
			end)
		end,
		Open = function(this: StationPanel, p: number, s: number, sid: Types.StationId, interact: Instance)
			Panel.closeAll()
			local wasOpen = open
			plotId, slot, stationId, interactPart = p, s, sid, interact
			open = true
			openInteract = interact
			lastPhase = nil
			lastIcon = nil
			frame.Visible = true
			Tween.popIn(frame)
			InputController.Bind("RHD_StationAct", Theme.Keys.Primary, function(pressed)
				local a: Types.CookAction? = currentAction
				if pressed and a then
					send(a)
				end
			end)
			if not wasOpen then
				StationPanel.OpenChanged:Fire(true)
			end
			this:Render()
		end,
		Render = function(_)
			if not open then
				return
			end
			local st = currentState()
			local phase: Types.StationPhase = if st then st.phase else "Idle"
			local dishId: Types.DishId = if st then st.dishId else Stations.Defs[stationId].dishId
			local look = LOOK[phase]
			local dish = Dishes.Defs[dishId]

			title.Text = `{string.upper(Stations.Defs[stationId].displayName)} · {dish.displayName}`
			if lastIcon ~= dishId then
				Util.clear(iconHost)
				Icons.build(dishId, iconHost, U.StationBadgeSize * 0.74, { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
				lastIcon = dishId
			end

			currentAction = if look.enabled then look.action else nil
			act:SetText(look.text)
			act:SetIcon(look.icon)
			act:SetVariant(look.variant)
			act:SetEnabled(look.enabled)
			local key = if look.enabled then keyHint() else nil
			keycap.instance.Visible = key ~= nil
			keyLabel.Text = key or ""
			hint.Text = HINT[phase]

			local flipping = phase == "NeedsFlip"
			flip.Visible = flipping
			bar.instance.Visible = not flipping
			bar:SetStripes(phase == "Cooking" or phase == "Finishing")
			if flipping and st and st.phaseEndsAt then
				local len = st.phaseEndsAt - st.phaseStartedAt
				perfectZone.Size = UDim2.fromScale(if len > 0 then Util.clamp01(dish.perfectSeconds / len) else 0.3, 1)
			elseif phase == "Idle" or not st then
				bar:SetRange(nil, nil)
				bar:SetFraction(0)
				bar:SetCaption("READY TO COOK")
			elseif phase == "Burnt" then
				bar:SetRange(nil, nil)
				bar:SetColor(C.Info)
				bar:SetFraction(1)
				bar:SetCaption("BURNT")
			elseif phase == "Ready" then
				bar:SetColor(C.Success)
				bar:SetRange(st.phaseStartedAt, st.phaseEndsAt, true)
			else
				bar:SetColor(if phase == "Finishing" then C.Accent else C.Primary)
				bar:SetRange(st.phaseStartedAt, st.phaseEndsAt, false)
				bar:SetCaption(if phase == "Finishing" then "FINISHING" else "COOKING")
			end
			transition(lastPhase, phase, st)
			lastPhase = phase
			stepBars(State.now())
		end,
	}

	InputController.ModeChanged:Connect(function()
		if open then
			self:Render()
		end
	end)
	Ticker.add(function(now)
		if open then
			stepBars(now)
		end
	end)
	local sinceCheck = 0
	Ticker.add(function(_, dt)
		if not open then
			return
		end
		sinceCheck += dt
		if sinceCheck < U.StationCheckSeconds then
			return
		end
		sinceCheck = 0
		local part = interactPart
		if part then
			local d = distanceTo(part)
			if d and d > Timings.Station.InteractRange * U.StationCloseDistanceFactor then
				self:Close()
			end
		end
	end)
	return self
end

return StationPanel

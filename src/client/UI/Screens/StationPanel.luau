--!strict
-- Station minigame panel: HOLD / FLIP / COLLECT / CLEAR, progress bar and flip timing bar.
-- Renders server state only; it sends intents and never decides outcomes. Owner: agent D.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local DishIcon = require(script.Parent.Parent.DishIcon)
local Dishes = require(ReplicatedStorage.Shared.Config.Dishes)
local InputController = require(script.Parent.Parent.Parent.Controllers.InputController)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local Root = require(script.Parent.Parent.Root)
local State = require(script.Parent.Parent.Parent.State)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Theme = require(script.Parent.Parent.Theme)
local Ticker = require(script.Parent.Parent.Ticker)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local C = Theme.Colors
local U = Theme.UI

export type StationPanel = {
	Open: (self: StationPanel, plotId: number, slot: number, stationId: Types.StationId, interact: Instance) -> (),
	Close: (self: StationPanel) -> (),
	Render: (self: StationPanel) -> (),
	IsOpenFor: (self: StationPanel, plotId: number, slot: number) -> boolean,
}

local StationPanel = {}

type PhaseLook = { text: string, color: Color3, textColor: Color3, enabled: boolean, action: Types.CookAction? }

local LOOK: { [Types.StationPhase]: PhaseLook } = {
	Idle = { text = "HOLD TO COOK", color = C.Mint, textColor = C.Ink, enabled = true, action = "Start" },
	Cooking = { text = "COOKING...", color = C.Cream, textColor = C.Ink, enabled = false, action = nil },
	NeedsFlip = { text = "FLIP!", color = C.NeonPink, textColor = C.White, enabled = true, action = "Flip" },
	Finishing = { text = "ALMOST...", color = C.Cream, textColor = C.Ink, enabled = false, action = nil },
	Ready = { text = "COLLECT", color = C.Mustard, textColor = C.Ink, enabled = true, action = "Collect" },
	Burnt = { text = "CLEAR", color = C.Ketchup, textColor = C.White, enabled = true, action = "Clear" },
}

local HINT: { [Types.StationPhase]: string } = {
	Idle = "Press and hold to start cooking",
	Cooking = "Cooking... get ready to flip",
	NeedsFlip = "Flip inside the green zone for Perfect",
	Finishing = "Finishing up",
	Ready = "Grab it before it burns, then serve it",
	Burnt = "Burnt! Clear it and start again",
}

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

function StationPanel.new(): StationPanel
	local layer = Root.layer("Station", U.ZStation)
	local frame = Util.card(layer, C.Cream, {
		Name = "StationPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -U.Margin),
		Size = UDim2.new(1, -U.Margin * 2, 0, U.StationPanelHeight),
		Visible = false,
	})
	Util.new("UISizeConstraint", { MaxSize = Vector2.new(U.StationPanelMaxWidth, math.huge) }, frame)
	Util.padding(frame, U.Gap)

	local iconHost = Util.frame(frame, { Size = UDim2.fromOffset(U.RowHeight, U.RowHeight) })
	local title = Util.label(frame, "", {
		Position = UDim2.fromOffset(U.RowHeight + U.Gap, 0),
		Size = UDim2.new(1, -(U.RowHeight * 2 + U.Gap * 2), 0, U.RowHeight),
		TextSize = U.TextLarge,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local bar = ProgressBar.new(frame, UDim2.new(1, 0, 0, U.StationBarHeight), C.Mint)
	bar.instance.Position = UDim2.fromOffset(0, U.RowHeight + U.Gap)

	-- Flip timing track: green perfect zone, red remainder, ink marker.
	local track = Util.card(frame, C.Mustard, {
		Name = "FlipTrack",
		Position = UDim2.fromOffset(0, U.RowHeight + U.Gap),
		Size = UDim2.new(1, 0, 0, U.StationBarHeight),
		ClipsDescendants = true,
		Visible = false,
	})
	local perfectZone = Util.frame(track, {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Mint,
		Size = UDim2.fromScale(0.3, 1),
	})
	local marker = Util.frame(track, {
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Ink,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(0, U.FlipMarkerWidth, 1, 0),
		ZIndex = 2,
	})

	local hint = Util.label(frame, "", {
		Position = UDim2.fromOffset(0, U.RowHeight + U.StationBarHeight + U.Gap * 2),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = U.TextSmall,
	})

	local plotId, slot = 0, 0
	local stationId: Types.StationId = "Grill"
	local interactPart: Instance? = nil
	local open = false
	local currentAction: Types.CookAction? = nil

	local function send(action: Types.CookAction)
		Net.event("CookAction"):FireServer({ plotId = plotId, slot = slot, action = action })
	end

	local act = Button.new({
		text = "",
		parent = frame,
		size = UDim2.new(1, 0, 0, U.StationBigButtonHeight),
		textSize = U.TextHuge,
		onDown = function()
			local a: Types.CookAction? = currentAction
			if a then
				send(a)
			end
		end,
	})
	act.instance.AnchorPoint = Vector2.new(0, 1)
	act.instance.Position = UDim2.fromScale(0, 1)

	local self: StationPanel
	local closeBtn = Button.new({
		text = "X",
		parent = frame,
		color = C.Ketchup,
		textColor = C.White,
		size = UDim2.fromOffset(Theme.MinTouchTarget, Theme.MinTouchTarget),
		onActivated = function()
			self:Close()
		end,
	})
	closeBtn.instance.AnchorPoint = Vector2.new(1, 0)
	closeBtn.instance.Position = UDim2.fromScale(1, 0)

	local function currentState(): Types.StationState?
		return State.getStation(plotId, slot)
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
				marker.Position = UDim2.fromScale(f, 0)
			end
		end
	end

	self = {
		IsOpenFor = function(_, p: number, s: number): boolean
			return open and plotId == p and slot == s
		end,
		Close = function(_)
			open = false
			frame.Visible = false
			InputController.Unbind("RHD_StationAct")
		end,
		Open = function(this: StationPanel, p: number, s: number, sid: Types.StationId, interact: Instance)
			Panel.closeAll()
			plotId, slot, stationId, interactPart = p, s, sid, interact
			open = true
			frame.Visible = true
			Tween.popIn(frame)
			InputController.Bind("RHD_StationAct", Theme.Keys.Primary, function(pressed)
				local a: Types.CookAction? = currentAction
				if pressed and a then
					send(a)
				end
			end)
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

			title.Text = `{Stations.Defs[stationId].displayName}: {dish.displayName}`
			for _, c in iconHost:GetChildren() do
				c:Destroy()
			end
			DishIcon.create(dishId, iconHost)

			currentAction = if look.enabled then look.action else nil
			act:SetText(look.text)
			act:SetColor(look.color)
			act.instance.TextColor3 = look.textColor
			act:SetEnabled(look.enabled)
			hint.Text = HINT[phase]

			local flipping = phase == "NeedsFlip"
			track.Visible = flipping
			bar.instance.Visible = not flipping
			if flipping and st and st.phaseEndsAt then
				local len = st.phaseEndsAt - st.phaseStartedAt
				perfectZone.Size = UDim2.fromScale(if len > 0 then Util.clamp01(dish.perfectSeconds / len) else 0.3, 1)
				Tween.bounce(act.instance)
			elseif phase == "Idle" or phase == "Burnt" or not st then
				bar:SetRange(nil, nil)
				bar:SetFraction(0)
			elseif phase == "Ready" then
				bar:SetColor(C.Mustard)
				bar:SetRange(st.phaseStartedAt, st.phaseEndsAt, true)
			else
				bar:SetColor(if phase == "Finishing" then C.NeonPink else C.Mint)
				bar:SetRange(st.phaseStartedAt, st.phaseEndsAt, false)
			end
			if phase == "Ready" or phase == "Burnt" then
				Tween.bounce(act.instance)
			end
			stepBars(State.now())
		end,
	}

	Ticker.add(function(now)
		if not open then
			return
		end
		stepBars(now)
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

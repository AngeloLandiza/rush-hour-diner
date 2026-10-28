--!strict
-- Crew modal: your diner card (rename for owners, leave for crew), then every other diner with an
-- initial avatar, seat pips and a Join button (server enforces friendship). Owner: UI agent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Card = require(script.Parent.Parent.Components.Card)
local Icons = require(script.Parent.Parent.Icons)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local CrewPanel = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local AVATAR = 44
local PIP = 10
local AVATAR_COLORS = { C.Primary, C.Success, C.Accent, C.Info, C.Danger }

local function myPlot(): Types.PlotInfo?
	for _, plot in State.plots do
		if plot.plotId == State.myPlotId then
			return plot
		end
	end
	return nil
end

local function dinerName(plot: Types.PlotInfo): string
	local title: string = plot.crewName or ""
	if title == "" then
		title = `{plot.ownerName or "Chef"}'s Diner`
	end
	return title
end

local function sectionLabel(parent: Instance, text: string, order: number)
	Util.display(parent, string.upper(text), {
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = Theme.Type.Small,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
end

local function avatar(parent: Instance, name: string, index: number)
	local disc = Util.solid(parent, AVATAR_COLORS[(index - 1) % #AVATAR_COLORS + 1], 0, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Space.SM + 2, 0.5, 0),
		Size = UDim2.fromOffset(AVATAR, AVATAR),
		ZIndex = 3,
	})
	Util.pill(disc)
	Util.bevel(disc)
	Util.stroke(disc, C.Outline, Theme.Stroke.Base)
	Util.display(disc, string.upper(string.sub(name, 1, 1)), {
		TextSize = Theme.Type.Heading - 2,
		TextColor3 = C.TextInverse,
		ZIndex = 4,
	}, C.Outline)
end

local function seatPips(parent: Instance, x: number, filled: number, total: number)
	local row = Util.frame(parent, {
		Position = UDim2.new(0, x, 0.5, 6),
		Size = UDim2.new(1, -x, 0, PIP),
		ZIndex = 3,
	})
	Util.list(row, Enum.FillDirection.Horizontal, Space.XS)
	for i = 1, total do
		local on = i <= filled
		local dot = Util.solid(row, if on then C.Success else C.Sunken, 0, {
			Size = UDim2.fromOffset(PIP, PIP),
			LayoutOrder = i,
			ZIndex = 3,
		})
		Util.pill(dot)
		Util.stroke(dot, if on then C.SuccessEdge else C.SunkenDeep, Theme.Stroke.Hair + 0.5)
	end
end

function CrewPanel.new(): Panel.Panel
	local panel = Panel.new("Crew", { icon = "Crew", accent = C.Success })
	local body = panel.Body
	Util.list(body, Enum.FillDirection.Vertical, Space.SM)
	local me = Players.LocalPlayer

	sectionLabel(body, "Your diner", 1)
	local mineCard = Card.new({
		parent = body,
		variant = "raised",
		size = UDim2.new(1, 0, 0, U.CardHeight),
		layoutOrder = 2,
	})
	Icons.build("Shop", mineCard.face, U.CardIcon * 0.8, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Space.MD, 0.5, 0),
		ZIndex = 3,
	})
	local textX = U.CardIcon + Space.MD
	local mineTitle = Util.display(mineCard.face, "", {
		Position = UDim2.fromOffset(textX, Space.SM + 2),
		Size = UDim2.new(1, -(textX + Space.MD), 0, 24),
		TextSize = Theme.Type.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	Util.fit(mineTitle, Theme.Type.Title)
	local mineSub = Util.label(mineCard.face, "", {
		Position = UDim2.fromOffset(textX, 30),
		Size = UDim2.new(1, -(textX + Space.MD), 0, 14),
		TextSize = Theme.Type.Caption + 1,
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	local minePips = Util.frame(mineCard.face, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })

	-- Rename row (owner only)
	local nameCard = Card.new({
		parent = body,
		variant = "raised",
		size = UDim2.new(1, 0, 0, U.CardHeight - Space.MD),
		layoutOrder = 3,
	})
	local well = Card.new({
		parent = nameCard.face,
		variant = "sunken",
		radius = Theme.Radius.MD,
		position = UDim2.fromOffset(Space.SM + 2, Space.SM + 2),
		size = UDim2.new(1, -(Space.SM * 2 + 4 + U.PriceButtonWidth - 16 + Space.SM), 1, -(Space.SM * 2 + 4)),
		zIndex = 3,
	})
	local box = Util.new("TextBox", {
		Name = "CrewName",
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		TextSize = Theme.Type.Body + 1,
		TextColor3 = C.Text,
		PlaceholderText = "Name your diner",
		PlaceholderColor3 = C.TextMuted,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Position = UDim2.fromOffset(Space.MD, 0),
		Size = UDim2.new(1, -Space.MD * 2, 1, 0),
		ZIndex = 4,
	}, well.face) :: TextBox
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > Timings.Text.MaxCrewNameLength then
			box.Text = string.sub(box.Text, 1, Timings.Text.MaxCrewNameLength)
		end
	end)
	local function submit()
		Net.event("SetCrewName"):FireServer({ name = box.Text })
	end
	Button.new({
		text = "Save",
		icon = "CheckWhite",
		iconSize = 16,
		parent = nameCard.face,
		variant = "success",
		textSize = Theme.Type.Body + 1,
		size = UDim2.fromOffset(U.PriceButtonWidth - 16, U.PriceButtonHeight + Theme.Depth.Lip),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -Space.SM - 2, 0.5, 0),
		onActivated = submit,
	})

	local leave = Button.new({
		text = "Leave crew",
		parent = body,
		variant = "danger",
		textSize = Theme.Type.Body + 1,
		size = UDim2.new(1, 0, 0, Theme.MinTouchTarget + Theme.Depth.Lip),
		layoutOrder = 4,
		onActivated = function()
			Net.event("LeaveCrew"):FireServer()
		end,
	})

	sectionLabel(body, "Join a friend's diner", 5)
	local list = Util.frame(body, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 6,
	})
	Util.list(list, Enum.FillDirection.Vertical, Space.SM)

	local function refresh()
		local mine = myPlot()
		local owner = State.isOwner()
		nameCard.instance.Visible = owner
		leave.instance.Visible = mine ~= nil and not owner
		mineCard.instance.Visible = mine ~= nil
		Util.clear(minePips)
		if mine then
			mineTitle.Text = dinerName(mine)
			local players = #mine.crewUserIds + 1
			mineSub.Text = if owner
				then `You own this diner · {players} chef(s)`
				else `Crew of {mine.ownerName or "a friend"}`
			seatPips(minePips, textX, players, Timings.Plots.MaxCrew + 1)
			if owner and not box:IsFocused() then
				box.Text = mine.crewName or ""
			end
		end

		Util.clear(list)
		local shown = 0
		for _, plot in State.plots do
			if plot.ownerUserId and plot.ownerUserId ~= me.UserId then
				shown += 1
				local card = Card.new({
					parent = list,
					variant = "raised",
					size = UDim2.new(1, 0, 0, U.CardHeight - Space.SM),
					layoutOrder = plot.plotId,
				})
				local face = card.face
				avatar(face, plot.ownerName or "Chef", plot.plotId)
				local x = AVATAR + Space.MD + Space.SM
				local title = Util.display(face, dinerName(plot), {
					Position = UDim2.new(0, x, 0.5, -22),
					Size = UDim2.new(1, -(x + U.PriceButtonWidth + Space.MD), 0, 24),
					TextSize = Theme.Type.Body + 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				})
				Util.fit(title, Theme.Type.Body + 1)
				local players = #plot.crewUserIds + 1
				seatPips(face, x, players, Timings.Plots.MaxCrew + 1)
				local alreadyHere = plot.plotId == State.myPlotId
				local full = #plot.crewUserIds >= Timings.Plots.MaxCrew
				local join = Button.new({
					text = if alreadyHere then "Joined" elseif full then "Full" else "Join",
					icon = if alreadyHere then "CheckWhite" else nil,
					iconSize = 16,
					parent = face,
					variant = if alreadyHere then "success" else "primary",
					textSize = Theme.Type.Body + 1,
					size = UDim2.fromOffset(U.PriceButtonWidth - 8, U.PriceButtonHeight + Theme.Depth.Lip),
					anchor = Vector2.new(1, 0.5),
					position = UDim2.new(1, -Space.SM - 2, 0.5, 0),
					onActivated = function()
						if not alreadyHere and not full then
							Net.event("JoinCrew"):FireServer({ ownerUserId = plot.ownerUserId })
						end
					end,
				})
				join:SetEnabled(alreadyHere or not full)
			end
		end
		if shown == 0 then
			local empty =
				Card.new({ parent = list, variant = "sunken", size = UDim2.new(1, 0, 0, U.CardHeight - Space.SM) })
			Icons.build("Crew", empty.face, 34, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, Space.MD, 0.5, 0),
				ZIndex = 3,
			})
			Util.label(empty.face, "No other diners yet. Invite a friend!", {
				Position = UDim2.fromOffset(58, 0),
				Size = UDim2.new(1, -70, 1, 0),
				TextColor3 = C.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			})
		end
	end

	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	State.Changed.Plots:Connect(refresh)
	State.Changed.Snapshot:Connect(refresh)
	panel.OnOpen = refresh
	refresh()
	return panel
end

return CrewPanel

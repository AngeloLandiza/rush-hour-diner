--!strict
-- Crew panel: join another diner (server enforces friendship), leave, rename your diner.
-- Owner: agent D.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.Components.Panel)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local CrewPanel = {}

local function myPlot(): Types.PlotInfo?
	for _, plot in State.plots do
		if plot.plotId == State.myPlotId then
			return plot
		end
	end
	return nil
end

function CrewPanel.new(): Panel.Panel
	local panel = Panel.new("Crew")
	local body = panel.Body
	Util.list(body, Enum.FillDirection.Vertical, Theme.UI.Gap)
	local me = Players.LocalPlayer

	-- Rename row (owner only)
	local nameRow = Util.card(body, Theme.Colors.White, {
		Size = UDim2.new(1, 0, 0, Theme.UI.RowHeight + Theme.UI.Gap),
		LayoutOrder = 1,
	})
	local box = Util.new("TextBox", {
		Name = "CrewName",
		BackgroundColor3 = Theme.Colors.Cream,
		BorderSizePixel = 0,
		Font = Theme.Font,
		TextSize = Theme.UI.TextBody,
		TextColor3 = Theme.Colors.Ink,
		PlaceholderText = "Diner name",
		PlaceholderColor3 = Theme.shade(Theme.Colors.Cream, Theme.UI.DisabledShade),
		ClearTextOnFocus = false,
		Text = "",
		Position = UDim2.fromOffset(Theme.UI.Gap, Theme.UI.Gap),
		Size = UDim2.new(1, -108, 1, -Theme.UI.Gap * 2),
	}, nameRow) :: TextBox
	Util.corner(box, Theme.UI.SmallCorner)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > Timings.Text.MaxCrewNameLength then
			box.Text = string.sub(box.Text, 1, Timings.Text.MaxCrewNameLength)
		end
	end)
	local function submit()
		Net.event("SetCrewName"):FireServer({ name = box.Text })
	end
	local save = Button.new({
		text = "Save",
		parent = nameRow,
		color = Theme.Colors.Mint,
		size = UDim2.fromOffset(88, Theme.MinTouchTarget),
		onActivated = submit,
	})
	save.instance.AnchorPoint = Vector2.new(1, 0.5)
	save.instance.Position = UDim2.new(1, -Theme.UI.Gap, 0.5, 0)

	local leave = Button.new({
		text = "Leave crew",
		parent = body,
		color = Theme.Colors.Ketchup,
		textColor = Theme.Colors.White,
		size = UDim2.new(1, 0, 0, Theme.MinTouchTarget),
		layoutOrder = 2,
		onActivated = function()
			Net.event("LeaveCrew"):FireServer()
		end,
	})

	local list = Util.frame(body, {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	})
	Util.list(list, Enum.FillDirection.Vertical, Theme.UI.Gap)

	local function refresh()
		local mine = myPlot()
		local owner = State.isOwner()
		nameRow.Visible = owner
		leave.instance.Visible = mine ~= nil and not owner
		if owner and mine and not box:IsFocused() then
			box.Text = mine.crewName or ""
		end
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local shown = 0
		for _, plot in State.plots do
			if plot.ownerUserId and plot.ownerUserId ~= me.UserId then
				shown += 1
				local row = Util.card(list, Theme.Colors.White, {
					Size = UDim2.new(1, 0, 0, Theme.UI.ListRowHeight),
					LayoutOrder = plot.plotId,
				})
				local title: string = plot.crewName or ""
				if not title or title == "" then
					title = `{plot.ownerName or "Chef"}'s diner`
				end
				Util.label(row, title, {
					Size = UDim2.new(1, -112, 0.55, 0),
					Position = UDim2.fromOffset(Theme.UI.Gap, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				Util.label(row, `{#plot.crewUserIds + 1}/{Timings.Plots.MaxCrew + 1} players`, {
					Size = UDim2.new(1, -112, 0.4, 0),
					Position = UDim2.new(0, Theme.UI.Gap, 0.55, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = Theme.UI.TextSmall,
				})
				local alreadyHere = plot.plotId == State.myPlotId
				local full = #plot.crewUserIds >= Timings.Plots.MaxCrew
				local join = Button.new({
					text = if alreadyHere then "Joined" else "Join crew",
					parent = row,
					color = Theme.Colors.Mint,
					size = UDim2.fromOffset(96, Theme.MinTouchTarget),
					onActivated = function()
						Net.event("JoinCrew"):FireServer({ ownerUserId = plot.ownerUserId })
					end,
				})
				join:SetEnabled(not alreadyHere and not full)
				join.instance.AnchorPoint = Vector2.new(1, 0.5)
				join.instance.Position = UDim2.new(1, -Theme.UI.Gap, 0.5, 0)
			end
		end
		if shown == 0 then
			Util.label(list, "No other diners yet", { Size = UDim2.new(1, 0, 0, Theme.UI.RowHeight) })
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

--!strict
-- Leaderboard panel: lifetime coins and best Rush Hour tabs. Owner: agent D.
local Players = game:GetService("Players")

local Panel = require(script.Parent.Parent.Components.Panel)
local State = require(script.Parent.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(game:GetService("ReplicatedStorage").Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local LeaderboardPanel = {}

local LIFETIME = "Lifetime"
local RUSH = "Rush Hour"

local function fill(frame: Frame, entries: { Types.LeaderboardEntry })
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if #entries == 0 then
		Util.label(frame, "No scores yet", { Size = UDim2.new(1, 0, 0, Theme.UI.RowHeight) })
		return
	end
	for rank, entry in entries do
		if rank > Theme.UI.LeaderboardRows then
			break
		end
		local isMe = entry.userId == Players.LocalPlayer.UserId
		local row = Util.card(frame, if isMe then Theme.Colors.Mustard else Theme.Colors.White, {
			Size = UDim2.new(1, 0, 0, Theme.UI.RowHeight),
			LayoutOrder = rank,
		})
		Util.label(row, `#{rank}`, {
			Size = UDim2.new(0, 48, 1, 0),
			Position = UDim2.fromOffset(Theme.UI.Gap, 0),
			TextSize = Theme.UI.TextLarge,
		})
		Util.label(row, entry.name, {
			Size = UDim2.new(1, -170, 1, 0),
			Position = UDim2.fromOffset(56, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		Util.label(row, Util.comma(entry.value), {
			Size = UDim2.new(0, 100, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -Theme.UI.Gap, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
end

function LeaderboardPanel.new(): Panel.Panel
	local panel = Panel.new("Leaderboard")
	local tabs = Tabs.new(panel.Body, { LIFETIME, RUSH })
	local function refresh()
		fill(tabs.content[LIFETIME], State.leaderboard.lifetime)
		fill(tabs.content[RUSH], State.leaderboard.rushHour)
	end
	State.Changed.Leaderboard:Connect(refresh)
	panel.OnOpen = refresh
	refresh()
	return panel
end

return LeaderboardPanel

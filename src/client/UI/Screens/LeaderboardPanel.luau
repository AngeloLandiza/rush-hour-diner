--!strict
-- Leaderboard modal: Lifetime / Rush Hour tabs. Rows carry a medal (gold, silver, bronze, then a plain
-- number), the name, and the score with a coin. The local player's row is highlighted. Owner: UI agent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Card = require(script.Parent.Parent.Components.Card)
local Icons = require(script.Parent.Parent.Icons)
local Panel = require(script.Parent.Parent.Components.Panel)
local State = require(script.Parent.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local LeaderboardPanel = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local LIFETIME = "Lifetime"
local RUSH = "Rush Hour"
local MEDAL = 34
local SCORE_W = 110

local MEDAL_COLORS: { [number]: { face: Color3, edge: Color3 } } = {
	{ face = C.Gold, edge = C.GoldDeep },
	{ face = C.Neutral, edge = C.NeutralEdge },
	{ face = C.Bronze, edge = C.BronzeDeep },
}

local function emptyState(frame: Frame)
	local card = Card.new({ parent = frame, variant = "sunken", size = UDim2.new(1, 0, 0, U.CardHeight) })
	Icons.build("Trophy", card.face, 36, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Space.MD, 0.5, 0),
		ZIndex = 3,
	})
	Util.label(card.face, "No scores yet. Serve some customers!", {
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -72, 1, 0),
		TextColor3 = C.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
end

local function fill(frame: Frame, entries: { Types.LeaderboardEntry })
	Util.clear(frame)
	if #entries == 0 then
		emptyState(frame)
		return
	end
	for rank, entry in entries do
		if rank > U.LeaderboardRows then
			break
		end
		local isMe = entry.userId == Players.LocalPlayer.UserId
		local card = Card.new({
			parent = frame,
			variant = if isMe then "accent" else "raised",
			color = if isMe then C.PrimaryLight else nil,
			edge = if isMe then C.PrimaryEdge else nil,
			size = UDim2.new(1, 0, 0, U.LeaderRowHeight),
			layoutOrder = rank,
		})
		local face = card.face
		local medalColors = MEDAL_COLORS[rank]
		local medal = Util.solid(face, if medalColors then medalColors.face else C.Sunken, 0, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Space.SM, 0.5, 0),
			Size = UDim2.fromOffset(MEDAL, MEDAL),
			ZIndex = 3,
		})
		Util.pill(medal)
		Util.bevel(medal)
		Util.stroke(medal, if medalColors then medalColors.edge else C.SunkenDeep, Theme.Stroke.Base)
		Util.display(medal, tostring(rank), {
			TextSize = Theme.Type.Title - 2,
			TextColor3 = C.Text,
			ZIndex = 4,
		})
		local name = Util.display(face, entry.name, {
			Position = UDim2.fromOffset(MEDAL + Space.MD + 4, 0),
			Size = UDim2.new(1, -(MEDAL + Space.MD + 4 + SCORE_W + Space.SM), 1, 0),
			TextSize = Theme.Type.Body + 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		})
		name.TextColor3 = C.Text
		local score = Util.frame(face, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -Space.MD, 0, 0),
			Size = UDim2.new(0, SCORE_W, 1, 0),
			ZIndex = 3,
		})
		Util.list(
			score,
			Enum.FillDirection.Horizontal,
			Space.XS,
			Enum.HorizontalAlignment.Right,
			Enum.VerticalAlignment.Center
		)
		Util.display(score, Util.short(entry.value), {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = Theme.Type.Title - 2,
			TextColor3 = C.Text,
			LayoutOrder = 1,
			ZIndex = 3,
		})
		Icons.build("Coin", score, 20, { LayoutOrder = 2, ZIndex = 3 })
	end
end

function LeaderboardPanel.new(): Panel.Panel
	local panel = Panel.new("Leaderboard", { icon = "Trophy", accent = C.Info })
	local tabs = Tabs.new(panel, { { name = LIFETIME, icon = "Coin" }, { name = RUSH, icon = "Flame" } })
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

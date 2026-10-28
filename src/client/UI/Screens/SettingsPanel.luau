--!strict
-- Settings modal: music and sound-effect switches, each in an icon row. Owner: UI agent.
local Card = require(script.Parent.Parent.Components.Card)
local Icons = require(script.Parent.Parent.Icons)
local Panel = require(script.Parent.Parent.Components.Panel)
local SettingsController = require(script.Parent.Parent.Parent.Controllers.SettingsController)
local Theme = require(script.Parent.Parent.Theme)
local Toggle = require(script.Parent.Parent.Components.Toggle)
local Util = require(script.Parent.Parent.Util)

local SettingsPanel = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space
local ICON = 34

local ROWS: { { key: SettingsController.Key, title: string, sub: string, icon: string } } = {
	{ key = "music", title = "Music", sub = "Diner tunes and the Rush Hour beat", icon = "Music" },
	{ key = "sfx", title = "Sound effects", sub = "Sizzles, dings and coin clinks", icon = "Speaker" },
}

function SettingsPanel.new(): Panel.Panel
	local panel = Panel.new("Settings", { icon = "Gear", accent = C.Info })
	Util.list(panel.Body, Enum.FillDirection.Vertical, Space.SM)
	local refreshers: { () -> () } = {}
	for i, row in ROWS do
		local card = Card.new({
			parent = panel.Body,
			variant = "raised",
			size = UDim2.new(1, 0, 0, U.SettingRowHeight),
			layoutOrder = i,
		})
		local face = card.face
		Icons.build(row.icon, face, ICON, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Space.MD, 0.5, 0),
			ZIndex = 3,
		})
		local x = ICON + Space.MD * 2
		local textW = -(x + U.ToggleWidth + Space.LG * 2)
		Util.display(face, row.title, {
			Position = UDim2.new(0, x, 0.5, -20),
			Size = UDim2.new(1, textW, 0, 22),
			TextSize = Theme.Type.Title - 2,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		local sub = Util.label(face, row.sub, {
			Position = UDim2.new(0, x, 0.5, 2),
			Size = UDim2.new(1, textW, 0, 18),
			TextSize = Theme.Type.Caption + 1,
			TextColor3 = C.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})
		Util.fit(sub, Theme.Type.Caption + 1)
		local toggle = Toggle.new(face, function()
			SettingsController.Set(row.key, not SettingsController.Get(row.key))
		end)
		toggle.instance.ZIndex = 4
		local function refresh()
			toggle:Set(SettingsController.Get(row.key))
		end
		SettingsController.Changed:Connect(refresh)
		table.insert(refreshers, refresh)
		refresh()
	end
	panel.OnOpen = function()
		for _, fn in refreshers do
			fn()
		end
	end
	return panel
end

return SettingsPanel

--!strict
-- Settings panel: music and sfx toggles. Owner: agent D.
local Button = require(script.Parent.Parent.Components.Button)
local Panel = require(script.Parent.Parent.Components.Panel)
local SettingsController = require(script.Parent.Parent.Parent.Controllers.SettingsController)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

local SettingsPanel = {}

local ROWS: { { key: SettingsController.Key, title: string } } = {
	{ key = "music", title = "Music" },
	{ key = "sfx", title = "Sound effects" },
}

function SettingsPanel.new(): Panel.Panel
	local panel = Panel.new("Settings")
	Util.list(panel.Body, Enum.FillDirection.Vertical, Theme.UI.Gap)
	local refreshers: { () -> () } = {}
	for i, row in ROWS do
		local card = Util.card(panel.Body, Theme.Colors.White, {
			Size = UDim2.new(1, 0, 0, Theme.UI.SettingRowHeight),
			LayoutOrder = i,
		})
		Util.label(card, row.title, {
			Size = UDim2.new(1, -110, 1, 0),
			Position = UDim2.fromOffset(Theme.UI.Margin, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = Theme.UI.TextLarge,
		})
		local toggle: Button.Button
		local function refresh()
			local on = SettingsController.Get(row.key)
			toggle:SetText(if on then "ON" else "OFF")
			toggle:SetColor(if on then Theme.Colors.Mint else Theme.Colors.Ketchup)
		end
		toggle = Button.new({
			text = "ON",
			parent = card,
			size = UDim2.fromOffset(88, Theme.MinTouchTarget),
			onActivated = function()
				SettingsController.Set(row.key, not SettingsController.Get(row.key))
				Tween.bounce(card)
			end,
		})
		toggle.instance.AnchorPoint = Vector2.new(1, 0.5)
		toggle.instance.Position = UDim2.new(1, -Theme.UI.Gap, 0.5, 0)
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

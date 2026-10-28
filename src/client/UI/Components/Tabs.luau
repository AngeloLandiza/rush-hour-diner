--!strict
-- A row of tab buttons above one content frame per tab. Owner: agent D.
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)
local Button = require(script.Parent.Button)

export type Tabs = {
	content: { [string]: Frame },
	Select: (self: Tabs, name: string) -> (),
	Selected: string,
}

local Tabs = {}

-- body is a ScrollingFrame; a vertical list layout is added to it.
function Tabs.new(body: Instance, names: { string }, onSelect: ((string) -> ())?): Tabs
	Util.list(body, Enum.FillDirection.Vertical, Theme.UI.Gap)
	local row = Util.frame(body, {
		Name = "TabRow",
		Size = UDim2.new(1, 0, 0, Theme.UI.TabHeight),
		LayoutOrder = 0,
	})
	Util.list(row, Enum.FillDirection.Horizontal, Theme.UI.Gap)
	local buttons: { [string]: Button.Button } = {}
	local content: { [string]: Frame } = {}

	local self: Tabs
	self = {
		content = content,
		Selected = names[1],
		Select = function(this: Tabs, name: string)
			this.Selected = name
			for tabName, frame in content do
				frame.Visible = tabName == name
			end
			for tabName, b in buttons do
				b:SetColor(if tabName == name then Theme.Colors.Mustard else Theme.Colors.Mint)
			end
			if onSelect then
				onSelect(name)
			end
		end,
	}

	for i, name in names do
		buttons[name] = Button.new({
			text = name,
			parent = row,
			size = UDim2.new(1 / #names, -Theme.UI.Gap, 1, 0),
			layoutOrder = i,
			onActivated = function()
				self:Select(name)
			end,
		})
		local frame = Util.frame(body, {
			Name = name .. "Tab",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
		})
		Util.list(frame, Enum.FillDirection.Vertical, Theme.UI.Gap)
		content[name] = frame
	end
	self:Select(names[1])
	return self
end

return Tabs

--!strict
-- Segmented tab control pinned in a Panel's toolbar: sunken pill track with a raised white thumb that
-- slides to the selected tab. One content frame per tab inside the panel body. Owner: UI agent.
local Icons = require(script.Parent.Parent.Icons)
local Panel = require(script.Parent.Panel)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Item = { name: string, icon: string? }

export type Tabs = {
	content: { [string]: Frame },
	Select: (self: Tabs, name: string) -> (),
	Selected: string,
	SetBadge: (self: Tabs, name: string, on: boolean) -> (),
}

local Tabs = {}

local C = Theme.C
local U = Theme.UI
local INSET = 3
local ICON = 18

function Tabs.new(panel: Panel.Panel, items: { Item }, onSelect: ((string) -> ())?): Tabs
	panel:SetToolbarHeight(U.TabHeight)
	local body = panel.Body
	Util.list(body, Enum.FillDirection.Vertical, Theme.Space.SM)

	local track = Util.solid(panel.Toolbar, C.Sunken, 0, { Name = "TabTrack", Size = UDim2.fromScale(1, 1) })
	Util.pill(track)
	Util.stroke(track, C.SunkenDeep, Theme.Stroke.Thin)
	local n = #items
	local thumb = Util.frame(track, {
		Name = "Thumb",
		Position = UDim2.fromOffset(INSET, INSET),
		Size = UDim2.new(1 / n, -INSET * 2, 1, -INSET * 2 - Theme.Depth.SmallLip),
		ZIndex = 2,
	})
	local thumbLip = Util.solid(thumb, C.NeutralDeep, 0, {
		Position = UDim2.fromOffset(0, Theme.Depth.SmallLip),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	Util.pill(thumbLip)
	local thumbFace = Util.solid(thumb, C.Raised, 0, { Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	Util.pill(thumbFace)
	Util.stroke(thumbFace, C.NeutralEdge, Theme.Stroke.Thin)

	local content: { [string]: Frame } = {}
	local labels: { [string]: TextLabel } = {}
	local dots: { [string]: Frame } = {}

	local self: Tabs
	self = {
		content = content,
		Selected = items[1].name,
		Select = function(this: Tabs, name: string)
			this.Selected = name
			for i, item in items do
				local on = item.name == name
				content[item.name].Visible = on
				labels[item.name].TextColor3 = if on then C.Text else C.TextMuted
				if on then
					Tween.play(thumb, { Position = UDim2.new((i - 1) / n, INSET, 0, INSET) }, Theme.Motion.Slide)
				end
			end
			body.CanvasPosition = Vector2.zero
			if onSelect then
				onSelect(name)
			end
		end,
		SetBadge = function(_, name: string, on: boolean)
			local d = dots[name]
			if d then
				d.Visible = on
			end
		end,
	}

	for i, item in items do
		local hit = Util.new("TextButton", {
			Name = item.name .. "Tab",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Position = UDim2.fromScale((i - 1) / n, 0),
			Size = UDim2.fromScale(1 / n, 1),
			ZIndex = 5,
		}, track) :: TextButton
		local row = Util.frame(hit, { Size = UDim2.new(1, 0, 1, -Theme.Depth.SmallLip), ZIndex = 5 })
		Util.list(
			row,
			Enum.FillDirection.Horizontal,
			Theme.Space.XS,
			Enum.HorizontalAlignment.Center,
			Enum.VerticalAlignment.Center
		)
		if item.icon then
			Icons.build(item.icon, row, ICON, { LayoutOrder = 1, ZIndex = 5 })
		end
		local label = Util.display(row, item.name, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			TextSize = Theme.Type.Small + 1,
			TextColor3 = C.TextMuted,
			LayoutOrder = 2,
			ZIndex = 5,
		})
		labels[item.name] = label
		local dot = Util.solid(hit, C.Danger, 0, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 5),
			Size = UDim2.fromOffset(9, 9),
			ZIndex = 6,
			Visible = false,
		})
		Util.pill(dot)
		Util.stroke(dot, C.TextInverse, Theme.Stroke.Hair + 0.5)
		dots[item.name] = dot
		hit.MouseButton1Down:Connect(function()
			Tween.press(row)
		end)
		hit.MouseButton1Up:Connect(function()
			Tween.release(row)
		end)
		hit.MouseLeave:Connect(function()
			Tween.release(row)
		end)
		hit.Activated:Connect(function()
			self:Select(item.name)
		end)

		local frame = Util.frame(body, {
			Name = item.name .. "Content",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
		})
		Util.list(frame, Enum.FillDirection.Vertical, Theme.Space.SM)
		content[item.name] = frame
	end
	self:Select(items[1].name)
	return self
end

return Tabs

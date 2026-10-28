--!strict
-- Modal panel with title bar, close button and scrolling body. One open at a time. Owner: agent D.
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)
local Button = require(script.Parent.Button)

export type Panel = {
	instance: Frame,
	Body: ScrollingFrame,
	Open: (self: Panel) -> (),
	Close: (self: Panel) -> (),
	Toggle: (self: Panel) -> (),
	IsOpen: (self: Panel) -> boolean,
	OnOpen: (() -> ())?,
	_open: boolean,
}

local Panel = {}

local openPanel: Panel? = nil

function Panel.closeAll()
	if openPanel then
		openPanel:Close()
	end
end

function Panel.new(title: string): Panel
	local layer = Root.layer("Panels", Theme.UI.ZPanels)
	local frame = Util.card(layer, Theme.Colors.Cream, {
		Name = title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Theme.UI.PanelTopInset),
		Size = UDim2.new(1, -Theme.UI.Margin * 2, 1, -(Theme.UI.PanelTopInset + Theme.UI.PanelBottomInset)),
		Visible = false,
	})
	Util.new("UISizeConstraint", {
		MaxSize = Vector2.new(Theme.UI.PanelMaxWidth, Theme.UI.PanelMaxHeight),
	}, frame)

	local bar = Util.card(frame, Theme.Colors.Mint, {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, Theme.UI.TitleBarHeight),
	})
	Util.label(bar, title, {
		Size = UDim2.new(1, -Theme.MinTouchTarget - Theme.UI.Margin * 2, 1, 0),
		Position = UDim2.fromOffset(Theme.UI.Margin, 0),
		TextSize = Theme.UI.TextLarge,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Ink,
	})

	local body = Util.new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, Theme.UI.TitleBarHeight + Theme.UI.Gap),
		Size = UDim2.new(1, 0, 1, -(Theme.UI.TitleBarHeight + Theme.UI.Gap)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = Theme.UI.Gap,
		ScrollBarImageColor3 = Theme.Colors.Ink,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, frame) :: ScrollingFrame
	Util.padding(body, Theme.UI.Margin)

	local self: Panel
	self = {
		instance = frame,
		Body = body,
		OnOpen = nil,
		_open = false,
		Open = function(this: Panel)
			if openPanel and openPanel ~= this then
				openPanel:Close()
			end
			openPanel = this
			this._open = true
			this.instance.Visible = true
			Tween.popIn(this.instance)
			if this.OnOpen then
				this.OnOpen()
			end
		end,
		Close = function(this: Panel)
			this._open = false
			this.instance.Visible = false
			if openPanel == this then
				openPanel = nil
			end
		end,
		Toggle = function(this: Panel)
			if this._open then
				this:Close()
			else
				this:Open()
			end
		end,
		IsOpen = function(this: Panel): boolean
			return this._open
		end,
	}

	local closeBtn = Button.new({
		text = "X",
		parent = bar,
		color = Theme.Colors.Ketchup,
		textColor = Theme.Colors.White,
		size = UDim2.fromOffset(Theme.MinTouchTarget, Theme.MinTouchTarget),
		onActivated = function()
			self:Close()
		end,
	})
	closeBtn.instance.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.instance.Position = UDim2.new(1, -2, 0.5, 0)
	return self
end

return Panel

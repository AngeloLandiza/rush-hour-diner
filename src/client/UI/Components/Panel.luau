--!strict
-- Modal panel: dimmed scrim (tap to close), cream paper card with a colored header band, an icon
-- medallion that breaks the top edge, a round close button, an optional pinned toolbar (tabs) and a
-- scrolling body. One modal open at a time. Owner: UI agent.
local Button = require(script.Parent.Button)
local Card = require(script.Parent.Card)
local Icons = require(script.Parent.Parent.Icons)
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Tooltip)
local Tween = require(script.Parent.Parent.Tween)
local Util = require(script.Parent.Parent.Util)

export type Options = {
	icon: string?,
	accent: Color3?, -- header band color
	maxHeight: number?, -- cap for short content (default Theme.UI.PanelMaxHeight)
}

export type Panel = {
	instance: Frame,
	Body: ScrollingFrame,
	Toolbar: Frame,
	Open: (self: Panel) -> (),
	Close: (self: Panel) -> (),
	Toggle: (self: Panel) -> (),
	IsOpen: (self: Panel) -> boolean,
	SetToolbarHeight: (self: Panel, height: number) -> (),
	OnOpen: (() -> ())?,
	_open: boolean,
}

local Panel = {}

local C = Theme.C
local U = Theme.UI
local Space = Theme.Space

local openPanel: Panel? = nil
local scrim: TextButton? = nil

local OPEN_FROM = 0.86

local function getScrim(layer: Frame): TextButton
	if scrim then
		return scrim
	end
	local s = Util.new("TextButton", {
		Name = "Scrim",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 0,
		Selectable = false,
	}, layer) :: TextButton
	s.Activated:Connect(function()
		Panel.closeAll()
	end)
	scrim = s
	return s
end

local function showScrim(on: boolean)
	local s = scrim
	if not s then
		return
	end
	if on then
		s.Visible = true
		Tween.play(s, { BackgroundTransparency = Theme.Depth.ScrimTransparency }, Theme.Motion.Fade)
	else
		local t = Tween.play(s, { BackgroundTransparency = 1 }, Theme.Motion.Fade)
		t.Completed:Once(function()
			if not openPanel then
				s.Visible = false
			end
		end)
	end
end

function Panel.closeAll()
	if openPanel then
		openPanel:Close()
	end
end

function Panel.isAnyOpen(): boolean
	return openPanel ~= nil
end

function Panel.new(title: string, opts: Options?): Panel
	local o: Options = opts or {}
	local layer = Root.layer("Panels", U.ZPanels)
	getScrim(layer)
	local accent = o.accent or C.Danger

	local root = Util.frame(layer, {
		Name = title .. "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, (U.PanelTopInset - U.PanelBottomInset) / 2),
		Size = UDim2.new(1, -U.Margin * 2, 1, -(U.PanelTopInset + U.PanelBottomInset)),
		Visible = false,
		ZIndex = 1,
	})
	Util.maxSize(root, U.PanelMaxWidth, o.maxHeight or U.PanelMaxHeight)
	local card = Card.new({ parent = root, variant = "paper", radius = U.PanelRadius })
	local face = card.face

	-- Header band (rounded top, square bottom).
	local header = Util.solid(face, accent, U.PanelRadius, {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, U.PanelHeaderHeight),
	})
	Util.gradient(header, C.Highlight, Theme.shade(C.Highlight, Theme.Depth.BevelDarken * 2))
	Util.frame(header, {
		BackgroundTransparency = 0,
		BackgroundColor3 = accent,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, U.PanelRadius),
	})
	Util.frame(header, {
		Name = "Rule",
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.shade(accent, 0.35),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, Theme.Stroke.Thin),
		ZIndex = 2,
	})

	local titleX = Space.MD
	if o.icon then
		local medal = Card.new({
			parent = header,
			variant = "raised",
			radius = math.huge,
			size = UDim2.fromOffset(U.PanelBadgeSize, U.PanelBadgeSize),
			position = UDim2.fromOffset(Space.SM, -Space.MD),
			zIndex = 5,
			edge = C.Outline,
		})
		if medal.stroke then
			medal.stroke.Thickness = Theme.Stroke.Base
		end
		Icons.build(o.icon, medal.face, U.PanelBadgeSize * 0.66, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.66, 0.66),
		})
		titleX = U.PanelBadgeSize + Space.SM * 2
	end
	Util.display(header, string.upper(title), {
		Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -(titleX + Theme.MinTouchTarget + Space.MD), 1, 0),
		TextSize = Theme.Type.Heading,
		TextColor3 = C.TextInverse,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}, C.Outline)

	local toolbar = Util.frame(face, {
		Name = "Toolbar",
		Position = UDim2.fromOffset(Space.MD, U.PanelHeaderHeight + Space.SM),
		Size = UDim2.new(1, -Space.MD * 2, 0, 0),
		Visible = false,
	})

	local body = Util.new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, U.PanelHeaderHeight + Space.XS),
		Size = UDim2.new(1, 0, 1, -(U.PanelHeaderHeight + Space.XS + Space.XS)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = Space.XS,
		ScrollBarImageColor3 = C.SunkenDeep,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
	}, face) :: ScrollingFrame
	Util.padding(body, Space.SM, Space.MD, Space.MD, Space.MD)

	local self: Panel
	self = {
		instance = root,
		Body = body,
		Toolbar = toolbar,
		OnOpen = nil,
		_open = false,
		Open = function(this: Panel)
			if openPanel and openPanel ~= this then
				openPanel:Close()
			end
			openPanel = this
			this._open = true
			Tooltip.hide()
			showScrim(true)
			this.instance.Visible = true
			local s = Tween.scaleOf(this.instance)
			s.Scale = OPEN_FROM
			Tween.play(s, { Scale = 1 }, Theme.Motion.PopIn)
			if this.OnOpen then
				this.OnOpen()
			end
		end,
		Close = function(this: Panel)
			if not this._open then
				return
			end
			this._open = false
			if openPanel == this then
				openPanel = nil
			end
			showScrim(openPanel ~= nil)
			local t =
				Tween.play(Tween.scaleOf(this.instance), { Scale = Theme.MotionScale.PopOutTo }, Theme.Motion.PopOut)
			t.Completed:Once(function()
				if not this._open then
					this.instance.Visible = false
				end
			end)
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
		SetToolbarHeight = function(_, height: number)
			toolbar.Visible = height > 0
			toolbar.Size = UDim2.new(1, -Space.MD * 2, 0, height)
			local top = U.PanelHeaderHeight + Space.SM + (if height > 0 then height + Space.XS else 0)
			body.Position = UDim2.fromOffset(0, top)
			body.Size = UDim2.new(1, 0, 1, -(top + Space.XS))
		end,
	}

	Button.new({
		name = title .. "CloseButton",
		parent = header,
		variant = "danger",
		icon = "Close",
		iconSize = 18,
		radius = math.huge,
		lip = Theme.Depth.SmallLip,
		size = UDim2.fromOffset(Theme.MinTouchTarget, Theme.MinTouchTarget),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -Space.SM + 2, 0.5, 0),
		onActivated = function()
			self:Close()
		end,
	}).instance.ZIndex =
		6
	return self
end

return Panel

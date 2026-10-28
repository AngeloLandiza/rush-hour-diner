--!strict
-- Layered card: transparent root (for layouts) > soft drop shadow > face (content goes in .face).
-- Variants: "paper" (cream panel), "raised" (white), "sunken" (inset well), "glass" (dark HUD),
-- "accent" (custom color). Owner: UI agent.
local Theme = require(script.Parent.Parent.Theme)
local Util = require(script.Parent.Parent.Util)

export type CardVariant = "paper" | "raised" | "sunken" | "glass" | "accent"

export type Options = {
	parent: Instance?,
	variant: CardVariant?,
	color: Color3?, -- face color for "accent"
	edge: Color3?, -- stroke color override
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	radius: number?, -- px; nil = theme default, math.huge = pill
	shadow: boolean?,
	layoutOrder: number?,
	name: string?,
	zIndex: number?,
}

export type Card = {
	instance: Frame,
	face: Frame,
	stroke: UIStroke?,
	shadow: Frame?,
	SetColor: (self: Card, color: Color3) -> (),
}

local Card = {}

local C = Theme.C
local Depth = Theme.Depth

local function round(f: Frame, radius: number?)
	if radius == math.huge then
		Util.pill(f)
	else
		Util.corner(f, radius or Theme.Radius.LG)
	end
end

function Card.new(opts: Options): Card
	local variant: CardVariant = opts.variant or "raised"
	local root = Util.frame(opts.parent, {
		Name = opts.name or "Card",
		Size = opts.size or UDim2.fromScale(1, 1),
		Position = opts.position or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		LayoutOrder = opts.layoutOrder or 0,
		ZIndex = opts.zIndex or 1,
	})

	local shadow: Frame? = nil
	if opts.shadow ~= false and variant ~= "sunken" then
		local s = Util.frame(root, {
			Name = "Shadow",
			BackgroundTransparency = Depth.ShadowTransparency,
			BackgroundColor3 = C.Shadow,
			Position = UDim2.fromOffset(0, Depth.ShadowOffset),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		})
		round(s, opts.radius)
		shadow = s
	end

	local faceColor = if variant == "paper"
		then C.Surface
		elseif variant == "sunken" then C.Sunken
		elseif variant == "glass" then C.Glass
		elseif variant == "accent" then opts.color or C.Primary
		else C.Raised
	local face = Util.frame(root, {
		Name = "Face",
		BackgroundTransparency = if variant == "glass" then Depth.GlassTransparency else 0,
		BackgroundColor3 = faceColor,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	round(face, opts.radius)

	local stroke: UIStroke? = nil
	if variant == "glass" then
		stroke = Util.stroke(face, C.GlassEdge, Theme.Stroke.Thin, Depth.GlassEdgeTransparency)
	elseif variant == "sunken" then
		stroke = Util.stroke(face, C.SunkenDeep, Theme.Stroke.Thin)
	elseif variant == "paper" then
		stroke = Util.stroke(face, opts.edge or C.Outline, Theme.Stroke.Base)
	else
		stroke = Util.stroke(face, opts.edge or C.NeutralEdge, Theme.Stroke.Thin)
	end
	if variant == "raised" or variant == "accent" then
		Util.bevel(face)
	end

	local self: Card = {
		instance = root,
		face = face,
		stroke = stroke,
		shadow = shadow,
		SetColor = function(this: Card, color: Color3)
			this.face.BackgroundColor3 = color
		end,
	}
	return self
end

return Card

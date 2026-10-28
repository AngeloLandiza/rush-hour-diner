--!strict
-- UI theme: resolves Config/UI tokens into Color3 roles, fonts, TweenInfos and button variants.
-- Every color is derived from Config/Palette. Spec: docs/UI_STYLE.md. Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UIConfig = require(ReplicatedStorage.Shared.Config.UI)

local P = Palette.Color

export type Variant = {
	face: Color3,
	lip: Color3,
	edge: Color3,
	text: Color3,
	textStroke: Color3?,
}
export type VariantName =
	"primary"
	| "secondary"
	| "success"
	| "premium"
	| "danger"
	| "accent"
	| "info"
	| "disabled"
	| "ghost"

local function resolve(spec: UIConfig.ColorSpec): Color3
	local base = P[spec.base] or P.Ink
	local mix, t = spec.mix, spec.t
	if mix and t then
		return base:Lerp(P[mix] or P.Ink, t)
	end
	return base
end

local C: { [string]: Color3 } = {}
for name, spec in UIConfig.Colors do
	C[name] = resolve(spec)
end

local function role(name: string?): Color3?
	if name then
		return C[name]
	end
	return nil
end

local Variants: { [string]: Variant } = {}
for name, spec in UIConfig.Variants do
	Variants[name] = {
		face = C[spec.face],
		lip = C[spec.lip],
		edge = C[spec.edge],
		text = C[spec.text],
		textStroke = role(spec.textStroke),
	}
end

local function enumFont(name: string): Enum.Font
	local ok, item = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	if ok and typeof(item) == "EnumItem" then
		return item :: any
	end
	return Enum.Font.FredokaOne
end

local function easing(name: string?, fallback: Enum.EasingStyle): Enum.EasingStyle
	local ok, item = pcall(function()
		return (Enum.EasingStyle :: any)[name]
	end)
	return if ok and typeof(item) == "EnumItem" then item :: any else fallback
end

local function direction(name: string?): Enum.EasingDirection
	if name == "In" then
		return Enum.EasingDirection.In
	elseif name == "InOut" then
		return Enum.EasingDirection.InOut
	end
	return Enum.EasingDirection.Out
end

local Motion: { [string]: TweenInfo } = {}
for name, spec in UIConfig.Motion do
	Motion[name] = TweenInfo.new(spec.seconds, easing(spec.style, Enum.EasingStyle.Quad), direction(spec.direction))
end

local Theme = {
	Colors = P, -- raw Palette colors (icons and world-tinted art)
	Hex = Palette.Hex,
	C = C, -- color roles
	Variants = Variants,
	Fonts = {
		Display = Font.fromEnum(enumFont(UIConfig.Fonts.Display)),
		Body = Font.fromEnum(enumFont(UIConfig.Fonts.Body)),
		Heavy = Font.fromEnum(enumFont(UIConfig.Fonts.Heavy)),
	},
	DisplayEnum = enumFont(UIConfig.Fonts.Display), -- for TextService measurement
	Type = UIConfig.Type,
	Space = UIConfig.Space,
	Radius = UIConfig.Radius,
	Stroke = UIConfig.Stroke,
	Depth = UIConfig.Depth,
	Motion = Motion,
	MotionScale = UIConfig.MotionScale,
	MotionSeconds = UIConfig.Motion,
	Images = UIConfig.Images,
	UI = UIConfig.Layout,
	FX = UIConfig.FX,
	Camera = UIConfig.Camera,
	Skeleton = UIConfig.Skeleton,
	MinTouchTarget = UIConfig.Layout.MinTouchTarget,

	-- Toast kind -> accent role and icon name.
	ToastKinds = {
		Info = { color = C.Info, deep = C.InfoDeep, icon = "Info" },
		Success = { color = C.Success, deep = C.SuccessDeep, icon = "Check" },
		Warning = { color = C.Primary, deep = C.PrimaryDeep, icon = "Warning" },
		Error = { color = C.Danger, deep = C.DangerDeep, icon = "Error" },
		Reward = { color = C.Gold, deep = C.GoldDeep, icon = "Coin" },
	} :: { [Types.ToastKind]: { color: Color3, deep: Color3, icon: string } },

	-- Keyboard / gamepad equivalents of touch buttons.
	Keys = {
		Primary = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA },
		Back = { Enum.KeyCode.ButtonB },
		Shop = { Enum.KeyCode.B },
		Leaderboard = { Enum.KeyCode.L },
		Crew = { Enum.KeyCode.C },
		Settings = { Enum.KeyCode.O },
		Daily = { Enum.KeyCode.R },
	},
}

-- Darkens a color toward Ink.
function Theme.shade(color: Color3, amount: number): Color3
	return color:Lerp(P.Ink, amount)
end

-- Lightens a color toward White.
function Theme.tint(color: Color3, amount: number): Color3
	return color:Lerp(P.White, amount)
end

-- Patience ring color: green (full) -> yellow -> red (empty), blended continuously.
function Theme.patienceColor(remaining: number): Color3
	local mid = UIConfig.Layout.BubbleMidPatience
	local low = UIConfig.Layout.BubbleLowPatience
	if remaining >= mid then
		return C.PatienceMid:Lerp(C.PatienceHigh, math.clamp((remaining - mid) / (1 - mid), 0, 1))
	elseif remaining >= low then
		return C.PatienceLow:Lerp(C.PatienceMid, (remaining - low) / (mid - low))
	end
	return C.PatienceLow
end

function Theme.variant(name: VariantName): Variant
	return Variants[name] or Variants.primary
end

return Theme

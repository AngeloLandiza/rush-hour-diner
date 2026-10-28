--!strict
-- Full-width legendary banner with a bouncy slide-in. Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Customers = require(ReplicatedStorage.Shared.Config.Customers)
local Root = require(script.Parent.Parent.Root)
local Theme = require(script.Parent.Parent.Theme)
local Tween = require(script.Parent.Parent.Tween)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.Util)

local LegendaryBanner = {}

local C = Theme.Colors
local U = Theme.UI

local current: Frame? = nil

local function headline(a: Types.LegendaryAnnouncement): (string, string)
	if a.servedByName then
		local sub = if a.tip then `+{Util.comma(a.tip)} tip!` else ""
		return `{a.servedByName} served {a.displayName}!`, sub
	end
	local def = Customers.Legendary[a.legendaryId]
	if def then
		return (string.gsub(def.announcement, "{owner}", a.ownerName)), "Go serve them!"
	end
	return `{a.displayName} arrived at {a.ownerName}'s diner!`, "Go serve them!"
end

function LegendaryBanner.show(a: Types.LegendaryAnnouncement)
	if current then
		current:Destroy()
		current = nil
	end
	local layer = Root.layer("Banner", U.ZBanner)
	local banner = Util.card(layer, C.Mustard, {
		Name = "LegendaryBanner",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(-1, U.BannerYScale),
		Size = UDim2.new(1, 0, 0, U.BannerHeight),
	})
	Util.new("UIGradient", { Color = ColorSequence.new(C.Mustard, C.NeonPink), Rotation = 0 }, banner)
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.White
	end
	local main, sub = headline(a)
	local title = Util.label(banner, main, {
		Size = UDim2.new(1, -U.Margin * 2, 0.6, 0),
		Position = UDim2.fromOffset(U.Margin, 0),
		TextSize = U.TextLarge,
		TextColor3 = C.Ink,
	})
	Util.label(banner, sub, {
		Size = UDim2.new(1, -U.Margin * 2, 0.35, 0),
		Position = UDim2.new(0, U.Margin, 0.62, 0),
		TextSize = U.TextBody,
		TextColor3 = C.White,
	})
	current = banner

	Tween.to(banner, { Position = UDim2.fromScale(0, U.BannerYScale) }, U.PopInSeconds + 0.2, Enum.EasingStyle.Back)
	task.delay(U.PopInSeconds, function()
		if title.Parent then
			Tween.bounce(title)
		end
	end)
	task.delay(U.BannerSeconds, function()
		if banner.Parent then
			local out = Tween.to(
				banner,
				{ Position = UDim2.fromScale(1, U.BannerYScale) },
				U.PopInSeconds,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.In
			)
			out.Completed:Once(function()
				banner:Destroy()
				if current == banner then
					current = nil
				end
			end)
		end
	end)
end

return LegendaryBanner

--!strict
-- FXController: floating "+N", coin burst and tip explosion at the served customer.
-- Owner: agent D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Presets = require(ReplicatedStorage.Shared.VFX.Presets)
local Remotes = require(ReplicatedStorage.Shared.Contracts.Remotes)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tween = require(script.Parent.Parent.UI.Tween)
local Util = require(script.Parent.Parent.UI.Util)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local FXController = {}

local FX = Theme.FX
local C = Theme.Colors

local function findAnchor(customerId: number): BasePart?
	local folder = workspace:FindFirstChild(WorldSchema.Folders.Customers)
	local model = folder and folder:FindFirstChild(WorldSchema.CustomerPrefix .. customerId)
	if not model or not model:IsA("Model") then
		return nil
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function burst(name: Presets.PresetName, parent: Instance, scale: number)
	local ok, err = pcall(function()
		Presets.Burst(name, parent, scale)
	end)
	if not ok then
		warn(`[FX] {name} failed: {err}`)
	end
end

local function floatText(anchor: BasePart, text: string, color: Color3, size: number)
	local gui = Util.new("BillboardGui", {
		Name = "FloatText",
		Adornee = anchor,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(FX.FloatTextWidth, FX.FloatTextHeight),
		StudsOffset = Vector3.new(0, FX.FloatTextOffsetY, 0),
	}, anchor) :: BillboardGui
	local label = Util.label(gui, text, { TextSize = size, TextColor3 = color })
	local stroke = Util.new("UIStroke", { Color = C.Ink, Thickness = Theme.UI.Stroke }, label)
	Tween.popIn(label)
	Tween.to(
		gui,
		{ StudsOffset = Vector3.new(0, FX.FloatTextOffsetY + FX.FloatTextRiseStuds, 0) },
		FX.FloatTextSeconds,
		Enum.EasingStyle.Quad
	)
	task.delay(FX.FloatTextSeconds * 0.5, function()
		Tween.to(label, { TextTransparency = 1 }, FX.FloatTextSeconds * 0.5)
		Tween.to(stroke, { Transparency = 1 }, FX.FloatTextSeconds * 0.5)
	end)
	task.delay(FX.FloatTextSeconds, function()
		gui:Destroy()
	end)
end

local function onServed(p: Remotes.OrderServedPayload)
	local anchor = findAnchor(p.customerId)
	if not anchor then
		return
	end
	local coinScale = math.min(FX.CoinBurstMaxScale, FX.CoinBurstBaseScale + p.total * FX.CoinBurstPerCoin)
	burst("CoinBurst", anchor, coinScale)
	if p.tip > 0 then
		local tipScale = math.min(FX.TipMaxScale, FX.TipBaseScale + p.tipFraction * FX.TipPerFraction)
		burst("TipExplosion", anchor, tipScale)
	end
	if p.kind == "Legendary" then
		burst("LegendarySparkle", anchor, FX.LegendaryBurstScale)
	end
	local mine = p.servedByUserId == game:GetService("Players").LocalPlayer.UserId
	floatText(anchor, `+{Util.comma(p.total)}`, if mine then C.Mustard else C.Mint, Theme.UI.TextHuge)
end

function FXController.Init() end

function FXController.Start()
	State.waitReady()
	Net.event("OrderServed").OnClientEvent:Connect(onServed)
end

return FXController

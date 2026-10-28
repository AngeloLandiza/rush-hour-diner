--!strict
-- FXController: coin burst + tip explosion at the served customer, a floating gold "+N" (with a
-- "BIG TIP!" / combo kicker) and, for the local server's own serves, coins flying into the HUD counter.
-- Owner: UI agent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinFly = require(script.Parent.Parent.UI.CoinFly)
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
local C = Theme.C

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

local function floatText(anchor: BasePart, text: string, kicker: string?, mine: boolean)
	local gui = Util.new("BillboardGui", {
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Name = "FloatText",
		Adornee = anchor,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(FX.FloatTextWidth, FX.FloatTextHeight),
		StudsOffset = Vector3.new(0, FX.FloatTextOffsetY, 0),
	}, anchor) :: BillboardGui
	local root = Util.frame(gui, { Size = UDim2.fromScale(1, 1) })
	local strokes: { UIStroke } = {}
	local labels: { TextLabel } = {}
	local main = Util.display(root, text, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 0.62),
		TextSize = Theme.Type.Hero - 4,
		TextColor3 = if mine then C.Gold else C.Success,
	})
	table.insert(strokes, Util.textStroke(main, C.Outline, Theme.Stroke.Bold))
	Util.gradient(main, C.Highlight, if mine then C.GoldLight else C.SuccessLight)
	table.insert(labels, main)
	if kicker then
		local k = Util.display(root, kicker, {
			Size = UDim2.fromScale(1, 0.36),
			TextSize = Theme.Type.Title,
			TextColor3 = C.TextInverse,
			Rotation = -5,
		})
		table.insert(strokes, Util.textStroke(k, C.Accent, Theme.Stroke.Base))
		table.insert(labels, k)
	end
	Tween.bounce(root, 1.6)
	Tween.to(
		gui,
		{ StudsOffset = Vector3.new(0, FX.FloatTextOffsetY + FX.FloatTextRiseStuds, 0) },
		FX.FloatTextSeconds,
		Enum.EasingStyle.Quad
	)
	task.delay(FX.FloatTextSeconds * 0.55, function()
		for _, l in labels do
			Tween.to(l, { TextTransparency = 1 }, FX.FloatTextSeconds * 0.45)
		end
		for _, s in strokes do
			Tween.to(s, { Transparency = 1 }, FX.FloatTextSeconds * 0.45)
		end
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
	local mine = p.servedByUserId == Players.LocalPlayer.UserId
	local kicker: string? = nil
	if p.kind == "Legendary" then
		kicker = "LEGENDARY!"
	elseif p.tipFraction >= FX.BigTipFraction then
		kicker = "BIG TIP!"
	elseif mine and not p.byBot and p.combo >= 2 then
		kicker = `COMBO ×{p.combo}`
	end
	floatText(anchor, `+{Util.coins(p.total)}`, kicker, mine)
	if mine then
		CoinFly.fromWorld(anchor.Position, p.total)
	end
end

function FXController.Init() end

function FXController.Start()
	State.waitReady()
	Net.event("OrderServed").OnClientEvent:Connect(onServed)
end

return FXController

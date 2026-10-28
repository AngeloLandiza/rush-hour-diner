--!strict
-- Thin wrapper over Roblox AnalyticsService (funnels, economy, custom events). Owner: orchestrator.
-- Never throws: analytics failures must not break gameplay.
local RobloxAnalytics = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Contracts.Events)

local AnalyticsService = {}

-- Onboarding funnel steps, logged once per player session in order.
local ONBOARDING_STEPS = { "PlotClaimed", "FirstDishCooked", "FirstOrderServed", "TutorialCompleted", "FirstUpgrade" }
local onboardingStep: { [Player]: number } = {}

local function advanceOnboarding(player: Player, stepName: string)
	local nextStep = (onboardingStep[player] or 0) + 1
	if ONBOARDING_STEPS[nextStep] ~= stepName then
		return
	end
	onboardingStep[player] = nextStep
	AnalyticsService.LogOnboarding(player, nextStep, stepName)
end

function AnalyticsService.Init()
	Events.PlotClaimed:Connect(function(_plotId, owner)
		advanceOnboarding(owner, "PlotClaimed")
	end)
	Events.DishCooked:Connect(function(player)
		advanceOnboarding(player, "FirstDishCooked")
	end)
	Events.OrderServed:Connect(function(result)
		if not result.byBot then
			advanceOnboarding(result.player, "FirstOrderServed")
		end
	end)
	Events.TutorialCompleted:Connect(function(player)
		advanceOnboarding(player, "TutorialCompleted")
	end)
	Events.UpgradePurchased:Connect(function(player)
		advanceOnboarding(player, "FirstUpgrade")
	end)
	Players.PlayerRemoving:Connect(function(player)
		onboardingStep[player] = nil
	end)
end

function AnalyticsService.Start() end

function AnalyticsService.LogEvent(player: Player, eventName: string, value: number?)
	pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value or 1)
	end)
end

-- flow: "Source" (coins in) or "Sink" (coins out). itemSku e.g. an upgrade id or dish id.
function AnalyticsService.LogEconomy(
	player: Player,
	flow: "Source" | "Sink",
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string?
)
	pcall(function()
		local flowType = if flow == "Source"
			then Enum.AnalyticsEconomyFlowType.Source
			else Enum.AnalyticsEconomyFlowType.Sink
		RobloxAnalytics:LogEconomyEvent(player, flowType, "Coins", amount, endingBalance, transactionType, itemSku)
	end)
end

-- Onboarding funnel: step numbers start at 1 and must be logged in order per player session.
function AnalyticsService.LogOnboarding(player: Player, step: number, stepName: string)
	pcall(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName)
	end)
end

return AnalyticsService

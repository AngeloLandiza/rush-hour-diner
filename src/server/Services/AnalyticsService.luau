--!strict
-- Thin wrapper over Roblox AnalyticsService (funnels, economy, custom events). Owner: orchestrator.
-- Never throws: analytics failures must not break gameplay.
local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsService = {}

function AnalyticsService.Init() end

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

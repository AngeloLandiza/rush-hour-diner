--!strict
-- Plot claiming (auto on join), crew join/leave (friends only), crew names (filtered). Owner: agent C.
-- Handles remotes: JoinCrew, LeaveCrew, SetCrewName. Broadcasts PlotsChanged. Sets Player attr PlotId.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local PlotService = {}

function PlotService.Init() end

function PlotService.Start() end

-- Plot the player currently works on (owned or crew).
function PlotService.GetPlotOf(player: Player): number?
	return nil
end

function PlotService.GetOwnedPlot(player: Player): number?
	return nil
end

function PlotService.GetOwner(plotId: number): Player?
	return nil
end

-- Owner + crew currently on the plot.
function PlotService.GetMembers(plotId: number): { Player }
	return {}
end

function PlotService.IsMember(player: Player, plotId: number): boolean
	return false
end

function PlotService.GetPlotInfo(plotId: number): Types.PlotInfo?
	return nil
end

function PlotService.GetAllPlotInfo(): { Types.PlotInfo }
	return {}
end

return PlotService

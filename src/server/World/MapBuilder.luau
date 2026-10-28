--!strict
-- Procedural map: street, 6 plots, diner shells that grow with decor tiers. Owner: agent E.
-- Builds the instance tree described in Contracts/WorldSchema during Init (before gameplay Start).
local MapBuilder = {}

function MapBuilder.Init() end

function MapBuilder.Start() end

function MapBuilder.GetPlotModel(plotId: number): Model?
	return nil
end

-- Rebuild the plot's Shell for decor tier 0..2.
function MapBuilder.ApplyDecor(plotId: number, tier: number) end

-- Show seats 1..count (hide the rest).
function MapBuilder.SetSeatCount(plotId: number, count: number) end

-- Show station slots 1..count (slot 5 = ExtraStation pass).
function MapBuilder.SetStationSlots(plotId: number, count: number) end

-- Already-filtered text for the plot sign.
function MapBuilder.SetSignText(plotId: number, text: string) end

-- Toggle the VIP booth prop on a plot.
function MapBuilder.SetVIPBooth(plotId: number, enabled: boolean) end

return MapBuilder

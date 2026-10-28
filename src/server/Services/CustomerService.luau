--!strict
-- Customer spawning, pathing, seating, patience, orders, serving + payout, legendary announcements,
-- auto-server bot. Owner: agent C. Handles remote: ServeCustomer.
-- Sends CustomerUpdate, CustomerRemoved, OrderServed, LegendaryAnnounce.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Contracts.Types)

local CustomerService = {}

function CustomerService.Init() end

function CustomerService.Start() end

function CustomerService.GetCustomer(id: number): Types.Customer?
	return nil
end

function CustomerService.GetCustomersOnPlot(plotId: number): { Types.Customer }
	return {}
end

function CustomerService.GetAllViews(): { Types.CustomerView }
	return {}
end

-- Debug / admin: force a legendary customer onto a plot. Returns the customer id or nil if no seat.
function CustomerService.SpawnLegendary(plotId: number, legendaryId: Types.LegendaryId): number?
	return nil
end

return CustomerService

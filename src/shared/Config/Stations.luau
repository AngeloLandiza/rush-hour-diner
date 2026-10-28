--!strict
-- Station definitions. Data only. Owner: orchestrator (numbers tunable by the balance pass).
local Types = require("../Contracts/Types")

export type StationDef = {
	id: Types.StationId,
	displayName: string,
	dishId: Types.DishId,
	order: number,
}

local Stations = {
	Defs = {
		Grill = { id = "Grill", displayName = "Grill", dishId = "Burger", order = 1 },
		Fryer = { id = "Fryer", displayName = "Fryer", dishId = "Fries", order = 2 },
		Oven = { id = "Oven", displayName = "Oven", dishId = "Pizza", order = 3 },
		Soda = { id = "Soda", displayName = "Soda Fountain", dishId = "Drink", order = 4 },
	} :: { [Types.StationId]: StationDef },

	-- Slot k on every plot holds this station. Slot 5 exists only with the ExtraStation pass.
	SlotLayout = { "Grill", "Fryer", "Oven", "Soda", "Grill" } :: { Types.StationId },
	BaseSlots = 4,
	ExtraStationSlots = 1,
}

return Stations

--!strict
-- ⚠ CONTRACT — owned by the orchestrator. Agents request changes in their report; never edit directly.
-- Instance names and attributes the World builders (agent E) create and gameplay/client code (C, D) reads.
--
-- Workspace
--   Map/                         static street, decor (MapBuilder)
--   Plots/
--     Plot_<n>/  (Model, attr PlotId)        PrimaryPart = Base, faces +Z toward the street
--       Base                     floor part, Anchored
--       Spawn                    Part: where owner/crew spawn & teleport (CanCollide false, Transparency 1)
--       CustomerSpawn            Part: where customers appear (street side)
--       Door                     Part: diner entrance, customers walk Spawn→Door→Seat
--       Counter                  Part
--       Sign                     Part with SurfaceGui "SignGui" > TextLabel "Text" (crew name)
--       Stations/
--         Slot_<k>/  (Model, attrs PlotId, Slot, StationId)   k = 1..MaxStationSlots
--           Interact             Part: ProximityPrompt parent; the station's interaction point
--             FX                 Attachment for steam/sizzle/fire emitters (find with FindFirstChild(name, true))
--       Seats/
--         Seat_<k>  (Part, attr SeatIndex)  k = 1..MaxSeats; Seat attachment "Sit" faces the table
--       Shell/                   walls/roof/decor props, rebuilt by MapBuilder.ApplyDecor
--   Customers/
--     Customer_<id> (Model, attrs CustomerId, PlotId, Kind, LegendaryId?)  "Head" exists (R15)
--   Bots/
--     AutoServer_<plotId> (Model)
local WorldSchema = {
	Folders = {
		Map = "Map",
		Plots = "Plots",
		Customers = "Customers",
		Bots = "Bots",
	},
	PlotPrefix = "Plot_",
	SlotPrefix = "Slot_",
	SeatPrefix = "Seat_",
	CustomerPrefix = "Customer_",
	AutoServerPrefix = "AutoServer_",
	Parts = {
		Base = "Base",
		Spawn = "Spawn",
		CustomerSpawn = "CustomerSpawn",
		Door = "Door",
		Counter = "Counter",
		Sign = "Sign",
		SignGui = "SignGui",
		SignText = "Text",
		Stations = "Stations",
		Seats = "Seats",
		Shell = "Shell",
		Interact = "Interact",
		FXAttachment = "FX",
		SitAttachment = "Sit",
	},
	Attributes = {
		PlotId = "PlotId",
		Slot = "Slot",
		StationId = "StationId",
		SeatIndex = "SeatIndex",
		CustomerId = "CustomerId",
		Kind = "Kind",
		LegendaryId = "LegendaryId",
		-- On Player instances (set by server, read by client/chat):
		PlayerPlotId = "PlotId", -- plot the player works on
		VIPBooth = "VIPBooth", -- owns VIP Booth pass (chat tag)
	},
	-- SoundService SoundGroups created by AudioDirector; the client mutes them locally per settings.
	SoundGroups = {
		Music = "Music",
		Sfx = "Sfx",
	},
	-- ProximityPrompt conventions (server creates prompts; client listens via ProximityPromptService):
	--   Station "Cook":  KeyboardKeyCode E, GamepadKeyCode ButtonX, Exclusivity OnePerButton
	--   Customer "Serve": KeyboardKeyCode F, GamepadKeyCode ButtonY, Exclusivity OnePerButton (distinct key from Cook)
	--   Hidden slots/seats must set prompt.Enabled = false.
	-- CollectionService tags
	Tags = {
		StationInteract = "StationInteract", -- Interact parts
		CustomerModel = "Customer",
		RushNeon = "RushNeon", -- neon signs/bulbs that LightingDirector lights up during Rush Hour
	},
}

return WorldSchema

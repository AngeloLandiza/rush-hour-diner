--!strict
-- World layout constants (studs). The street runs along the X axis; plots sit on both sides of it.
-- Every plot is built in its own local frame (+Z = toward the street) and then placed with a CFrame.
local Layout = {
	-- Street (centered on the origin, running along X)
	StreetLength = 340,
	StreetWidth = 24,
	StreetThickness = 0.2,
	SidewalkDepth = 8,
	SidewalkHeight = 0.5,
	GroundSize = Vector3.new(340, 1, 230),
	CrosswalkX = { -35, 35 },
	CrosswalkStripes = 6,
	CenterDashCount = 14,
	LampX = { -105, -35, 35, 105 },
	SpawnPadSize = Vector3.new(14, 1, 14),

	-- Plots
	PlotSize = Vector3.new(60, 1, 50),
	PlotSpacing = 70, -- center-to-center along X
	PlotsPerSide = 3,
	FloorY = 0.5, -- top surface of Base (plot local y)

	-- Positions inside a plot (plot local space; +Z = street, +X = right when facing the street)
	SlotX = { -14.25, -4.75, 4.75, 14.25, 23.75 },
	StationZ = -19,
	InteractOffsetZ = 5.2, -- Interact part in front of the station
	CounterZ = -9,
	CounterSize = Vector3.new(48, 3.5, 3),
	SeatZ = -4,
	SeatX = { -4, 4, -12, 12, -20, 20 },
	SeatHeight = 2.4,
	SpawnZ = -12,
	DoorZ = 6,
	DoorSize = Vector3.new(8, 7, 1),
	CustomerSpawnZ = 22,
	SignPos = Vector3.new(20, 6.5, 17),
	SignSize = Vector3.new(18, 5, 0.8),
	VIPPos = Vector3.new(-20, 0, 14),

	-- Shell
	WallX = 29.5,
	WallBackZ = -24.5,
	WallFrontZ = 6,
}

return Layout

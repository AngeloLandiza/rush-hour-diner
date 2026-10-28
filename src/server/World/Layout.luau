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
	GroundSize = Vector3.new(1400, 1, 1000),
	CrosswalkX = { -35, 35 },
	CrosswalkStripes = 6,
	CenterDashCount = 14,
	LampX = { -105, -35, 35, 105 },
	SpawnPadSize = Vector3.new(14, 1, 14),
	SidewalkSeamSpacing = 24,
	TreeX = { -35, 35 }, -- the walkways between plots
	TreeZ = { 27, 48 }, -- distance from the street center
	BenchX = { -52, -18, 18, 52 },
	BackdropZ = 92, -- tree line and backdrop behind the plots (distance from the street center)
	BackdropX = { -140, -70, 0, 70, 140 },
	EndBuildingX = 185, -- storefront blocks closing the street ends

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
	SignPos = Vector3.new(21, 4.6, 16),
	SignSize = Vector3.new(9, 2.8, 0.5),
	VIPPos = Vector3.new(-20, 0, 14),
	LawnStartZ = 12, -- front lawn from here to the street edge of the lot

	-- Front yard props (World/Yard), mirrored on both sides of the path. Everything stays outside the
	-- customer walk: CustomerSpawn → Door runs down the path (x = 0), Door → seats stays at z < DoorZ.
	Yard = {
		PathBorder = 0.6, -- cream border each side of the brick path
		RunnerWidth = 2.6, -- checker inlay down the middle of the path
		RunnerCell = 1.3,
		StandPathZ0 = -1, -- tier 0: brick path continues from the stand deck to the door line
		TableX = 13,
		TableZ = 9,
		RopeX = 5.7, -- queue rope stanchions just outside the path edges
		RopeZ = { 9.6, 15.4 },
		LampX = 6.4,
		LampZ = 22.4,
		MenuPos = Vector3.new(-8.5, 0, 20.6), -- chalkboard A-frame by the path mouth
		PlanterX = 27.3, -- tier 0 corner planters (tiers 1-2 have facade planters)
		PlanterZ = 10.5,
		ScooterPos = Vector3.new(21.5, 0, 20.8), -- tier 2 delivery scooter
	},

	-- Shell
	WallX = 29.5,
	WallBackZ = -24.5,
	WallFrontZ = 6,
}

return Layout

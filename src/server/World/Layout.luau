--!strict
-- World layout constants (studs). The street runs along the X axis; plots sit on both sides of it.
-- Every plot is built in its own local frame (+Z = toward the street) and then placed with a CFrame.
--
-- Plot plan (plot local, +Z = street, lot spans x ±55, z ±45):
--   z -45 … -40   back hedge
--   z -39.5       back wall; stations at z -34, Spawn at z -27, counter at z -24 (customer face -22.5)
--   z -19         5 counter stools; behind them the cross aisle (stool Approach points at z -15.4)
--   z -14 … -6    the table row: booth T1 (right), booth T2 (left), high-top T3 (right outer),
--                 VIP booth (left outer). The middle (|x| < 9) stays clear: it is the customer aisle.
--   z 2           Door: dining room entrance (tiers 1-2) / garden arch (tier 0); front wall line
--   z 2 … 18      tier 2 covered patio (decor tables)
--   z 41          CustomerSpawn at the street edge; brick path from the street to the Door along x = 0
-- Every seat is within 16 studs of the counter's customer face; every walking leg
-- (CustomerSpawn → Door → Approach → Sit) is a straight line clear of furniture and walls.
local Layout = {
	-- Street (centered on the origin, running along X)
	StreetLength = 440,
	StreetWidth = 24,
	StreetThickness = 0.2,
	SidewalkDepth = 8,
	SidewalkHeight = 0.5,
	GroundSize = Vector3.new(2048, 1, 2048), -- the largest a part can be
	GroundTopY = 0.02,
	CrosswalkX = { -62.5, 62.5 },
	CrosswalkStripes = 6,
	CenterDashCount = 18,
	LampX = { -190, -62.5, 62.5, 190 },
	SpawnPadSize = Vector3.new(14, 1, 14),
	SidewalkSeamSpacing = 24,
	BenchX = { -158, -92, -30, 30, 92, 158 },
	BackdropZ = 128, -- tree line behind the plots (distance from the street center)
	BackdropX = { -260, -190, -120, -50, 20, 90, 160, 230 },
	EndBuildingX = 236, -- storefront blocks closing the street ends
	EndBuildingZ = { -42, -20, 20, 42 },
	Skyline = { -- town blocks behind the backdrop trees (distance from the street center)
		X = { -270, -205, -140, -75, -10, 55, 120, 185, 250 },
		Z = 152,
		Stagger = 8,
		Width = 44,
		Heights = { 22, 30, 18, 26 },
	},

	-- Walkways between neighbouring plots (perpendicular to the street): paving, trees and lamps.
	Walkway = {
		X = { -62.5, 62.5 },
		Width = 15,
		PaveWidth = 6,
		TreeZ = { 36, 64, 94 }, -- distance from the street center
		LampZ = { 50, 80 },
	},

	-- Plots
	PlotSize = Vector3.new(110, 1, 90),
	PlotSpacing = 125, -- center-to-center along X (15 studs of walkway between lots)
	PlotsPerSide = 3,
	FloorY = 0.5, -- top surface of Base (plot local y)
	LawnStripes = 15,

	-- Kitchen and counter (plot local space; +Z = street, +X = right when facing the street)
	SlotX = { -14.25, -4.75, 4.75, 14.25, 23.75 },
	StationZ = -34,
	InteractOffsetZ = 5.2, -- Interact part in front of the station
	CounterZ = -24,
	CounterSize = Vector3.new(40, 3.5, 3),
	SpawnZ = -27,
	DoorZ = 1.2, -- just inside the front wall line (WallFrontZ), so diagonal legs clear the door jambs
	DoorSize = Vector3.new(8, 7, 1),
	CustomerSpawnZ = 41,
	SignPos = Vector3.new(17, 4.6, 39),
	SignSize = Vector3.new(9, 2.8, 0.5),
	VIPPos = Vector3.new(-26.5, 0, -11), -- VIP booth, facing +X into the room

	-- Seating. Seat k: 1..5 counter stools (nearest the pass first), 6..12 tables (nearest first).
	Seating = {
		StoolX = { 0, -5, 5, -10, 10 },
		StoolZ = -19,
		StoolHeight = 2.4, -- cushion top above the floor (counter stools and high-top stools)
		StoolApproach = 3.6, -- Approach point this far behind a stool (toward the street)
		-- Booths: long axis along Z, open end toward the street. Seats face each other across the table.
		BoothLength = 5,
		BoothSeatOffset = 2.6, -- seat center from the table center (X)
		BoothBackOffset = 4, -- back center from the table center (X)
		BoothSeatHeight = 1.95,
		BoothTableHeight = 3.1,
		BoothApproach = 1.3, -- Approach point this far past the booth's open end
		Booths = {
			{ x = 15, z = -9.5, seats = { 6, 7 } }, -- inner seat first
			{ x = -15, z = -9.5, seats = { 8, 9 } },
		},
		-- High-top round table with three backless stools (inner, front, outer). Approach points sit in
		-- front of each stool (toward the street); stools are below waist height so they never block.
		HighTop = {
			x = 25.2,
			z = -11.2,
			radius = 1.9,
			height = 3.8,
			stoolRadius = 3,
			seats = { 10, 11, 12 },
			angles = { 180, 90, 0 }, -- degrees from +X toward +Z (street)
			approach = { 4.8, 3.6, 3.8 }, -- Approach distance in front of each stool (+Z)
		},
	},

	-- Shell footprints per tier
	WallX = 31, -- tiers 0-1 half width (wall centers)
	WallXBig = 40, -- tier 2 half width
	WallBackZ = -39.5,
	WallFrontZ = 2,
	DiningZ0 = -22.5, -- dining floor starts at the counter's customer face
	StandFrontZ = -16, -- tier 0 deck edge (just past the stools)
	PatioZ1 = 18, -- tier 2 patio front edge

	-- Front yard props (World/Yard), mirrored on both sides of the path. Everything stays outside the
	-- customer walk: CustomerSpawn → Door runs down the path (x = 0).
	Yard = {
		PathBorder = 0.6, -- cream border each side of the brick path
		RunnerWidth = 2.6, -- checker inlay down the middle of the path
		RunnerCell = 1.3,
		TableX = 20, -- decor parasol tables on the lawn (tiers 0-1)
		TableZ = 13,
		TableZBig = 29,
		RopeX = 5.7, -- queue rope stanchions just outside the path edges
		RopeZ = { 5, 11 },
		LampX = 6.4,
		LampZ = { 24, 36 },
		MenuPos = Vector3.new(-8.5, 0, 38.5), -- chalkboard A-frame by the path mouth
		ArchHalf = 4.7, -- tier 0 garden arch posts at the Door
		LotTrees = { -- decor trees around the lot edge (plot local x, z, scale)
			{ -47, -30, 1.1 },
			{ 47, -30, 1.1 },
			{ -48, 6, 1 },
			{ 48, 6, 1 },
			{ -44, 30, 1.2 },
			{ 44, 30, 1.2 },
		},
		FlowerBedX = 33, -- flower beds either side of the lawn
		FlowerBedZ = 28,
		ScooterPos = Vector3.new(26, 0, 36), -- tier 2 delivery scooter
	},
}

return Layout

--!strict
-- Server entry. Boots services in dependency order: every module's Init() runs (in order), then
-- every Start(). A service may require only services listed before it. See docs/ARCHITECTURE.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
Net.setupServer()

local Guard = require(script.Util.Guard)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Services = script.Services
local World = script.World

type Module = { Init: () -> (), Start: () -> () }

local AnalyticsService = require(Services.AnalyticsService)
local DataService = require(Services.DataService)
local RushHourService = require(Services.RushHourService)
local PurchaseService = require(Services.PurchaseService)
local LeaderboardService = require(Services.LeaderboardService)
local MapBuilder = require(World.MapBuilder)
local PropBuilder = require(World.PropBuilder)
local LightingDirector = require(World.LightingDirector)
local AudioDirector = require(World.AudioDirector)
local PlotService = require(Services.PlotService)
local StationService = require(Services.StationService)
local CustomerService = require(Services.CustomerService)

local BOOT_ORDER: { { name: string, module: Module } } = {
	{ name = "AnalyticsService", module = AnalyticsService },
	{ name = "DataService", module = DataService },
	{ name = "RushHourService", module = RushHourService },
	{ name = "PurchaseService", module = PurchaseService },
	{ name = "LeaderboardService", module = LeaderboardService },
	{ name = "PropBuilder", module = PropBuilder },
	{ name = "MapBuilder", module = MapBuilder },
	{ name = "LightingDirector", module = LightingDirector },
	{ name = "AudioDirector", module = AudioDirector },
	{ name = "PlotService", module = PlotService },
	{ name = "StationService", module = StationService },
	{ name = "CustomerService", module = CustomerService },
}

for _, entry in BOOT_ORDER do
	local ok, err = pcall(function()
		entry.module.Init()
	end)
	if not ok then
		warn(`[Boot] {entry.name}.Init failed: {err}`)
	end
end

-- Snapshot for late-joining clients (composed from each service's public API).
-- Waits (bounded by Timings.Data.DataWaitTimeoutSeconds) for the profile so a fresh joiner's snapshot
-- carries `data`; otherwise the client would apply `data = nil` over the first DataSync it already got.
Guard.onInvoke("GetSnapshot", function(player: Player)
	DataService.WaitForData(player)
	return {
		data = DataService.GetView(player),
		plots = PlotService.GetAllPlotInfo(),
		myPlotId = PlotService.GetPlotOf(player),
		stations = StationService.GetAllStates(),
		customers = CustomerService.GetAllViews(),
		rushHour = RushHourService.GetState(),
		leaderboard = LeaderboardService.GetSnapshot(),
		serverTime = workspace:GetServerTimeNow(),
	}
end)

for _, entry in BOOT_ORDER do
	task.spawn(function()
		local ok, err = pcall(function()
			entry.module.Start()
		end)
		if not ok then
			warn(`[Boot] {entry.name}.Start failed: {err}`)
		end
	end)
end

-- Hard constraint: R15 avatars only (StarterPlayer.GameSettingsAvatar = R15 in default.project.json).
local function checkRig(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", Timings.Plots.CharacterWaitSeconds)
	if humanoid and humanoid:IsA("Humanoid") and humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn(`[Boot] Non-R15 character for {player.UserId}; check universe Avatar settings`)
	end
end

local function watchRig(player: Player)
	player.CharacterAdded:Connect(function(character)
		checkRig(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(checkRig, player, character)
	end
end

Players.PlayerAdded:Connect(watchRig)
for _, player in Players:GetPlayers() do
	watchRig(player)
end

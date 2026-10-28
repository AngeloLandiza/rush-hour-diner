--!strict
-- Plot claiming (auto on join), crew join/leave (friends only), crew names (filtered). Owner: agent C.
-- Handles remotes: JoinCrew, LeaveCrew, SetCrewName. Broadcasts PlotsChanged. Sets Player attr PlotId.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UpgradeLogic = require(ReplicatedStorage.Shared.Logic.Upgrades)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local Guard = require(script.Parent.Parent.Util.Guard)
local DataService = require(script.Parent.DataService)
local PurchaseService = require(script.Parent.PurchaseService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local MAX_USER_ID = 2 ^ 53
local SPAWN_LIFT = Vector3.new(0, Timings.Plots.SpawnLiftStuds, 0)
local FREE_SIGN_TEXT = "Free Plot"
local SIGN_SUFFIX = "'s Diner"

type Plot = {
	plotId: number,
	owner: Player?,
	crew: { Player },
	crewName: string?,
	decorTier: number,
	seatCount: number,
	stationSlots: number,
}

local PlotService = {}

local plots: { Plot } = {}
local current: { [Player]: number } = {} -- plot each player is currently on
local owned: { [Player]: number } = {}
local handled: { [Player]: boolean } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local started = false

local function newPlot(plotId: number): Plot
	return {
		plotId = plotId,
		owner = nil,
		crew = {},
		crewName = nil,
		decorTier = 0,
		seatCount = Timings.Seats.Base,
		stationSlots = Stations.BaseSlots,
	}
end

local function ownerDefaultName(owner: Player): string
	return `{owner.DisplayName}{SIGN_SUFFIX}`
end

local function infoOf(plot: Plot): Types.PlotInfo
	local crewIds = {}
	for _, member in plot.crew do
		table.insert(crewIds, member.UserId)
	end
	local owner = plot.owner
	return {
		plotId = plot.plotId,
		ownerUserId = if owner then owner.UserId else nil,
		ownerName = if owner then owner.DisplayName else nil,
		crewUserIds = crewIds,
		crewName = plot.crewName,
		decorTier = plot.decorTier,
		seatCount = plot.seatCount,
		stationSlots = plot.stationSlots,
	}
end

local function broadcast()
	Net.event("PlotsChanged"):FireAllClients(PlotService.GetAllPlotInfo())
end

local function isValidPlotId(plotId: any): boolean
	return Guard.isInt(plotId, 1, Timings.Plots.Count)
end

-- Recompute seats/decor/slots from the owner's upgrades and passes and push them into the world.
local function syncLayout(plot: Plot)
	local owner = plot.owner
	if not owner then
		return
	end
	local data = DataService.GetData(owner)
	local levels = if data then data.upgrades else {}
	plot.decorTier = UpgradeLogic.decorTier(levels)
	plot.seatCount = math.min(UpgradeLogic.seatCount(levels), Timings.Seats.Max)
	local slots = Stations.BaseSlots
	if PurchaseService.OwnsPass(owner, "ExtraStation") then
		slots += Stations.ExtraStationSlots
	end
	plot.stationSlots = slots
	local vip = PurchaseService.OwnsPass(owner, "VIPBooth")
	owner:SetAttribute(WorldSchema.Attributes.VIPBooth, vip)

	MapBuilder.ApplyDecor(plot.plotId, plot.decorTier)
	MapBuilder.SetSeatCount(plot.plotId, plot.seatCount)
	MapBuilder.SetStationSlots(plot.plotId, plot.stationSlots)
	MapBuilder.SetVIPBooth(plot.plotId, vip)
	Events.PlotLayoutChanged:Fire(plot.plotId)
	broadcast()
end

local function teleportToPlot(player: Player, plotId: number)
	local model = MapBuilder.GetPlotModel(plotId)
	local spawn = model and model:FindFirstChild(WorldSchema.Parts.Spawn)
	local character = player.Character
	if not (spawn and spawn:IsA("BasePart") and character) then
		return
	end
	if not character:FindFirstChild("HumanoidRootPart") then
		character:WaitForChild("HumanoidRootPart", Timings.Plots.CharacterWaitSeconds)
	end
	if character.Parent and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(spawn.CFrame + SPAWN_LIFT)
	end
end

local function crewList(plot: Plot): { Player }
	return table.clone(plot.crew)
end

-- Moves `player` onto plotId (their own or someone else's), updating crew lists and attributes.
local function moveTo(player: Player, plotId: number, teleport: boolean)
	local oldId = current[player]
	if oldId == plotId then
		if teleport then
			teleportToPlot(player, plotId)
		end
		return
	end
	if oldId then
		local old = plots[oldId]
		local index = table.find(old.crew, player)
		if index then
			table.remove(old.crew, index)
			Events.CrewChanged:Fire(oldId, crewList(old))
		end
	end
	local plot = plots[plotId]
	current[player] = plotId
	if plot.owner ~= player then
		table.insert(plot.crew, player)
	end
	player:SetAttribute(WorldSchema.Attributes.PlayerPlotId, plotId)
	if plot.owner ~= player then
		Events.CrewChanged:Fire(plotId, crewList(plot))
	end
	broadcast()
	if teleport then
		teleportToPlot(player, plotId)
	end
end

local function returnHome(player: Player)
	local own = owned[player]
	if own then
		moveTo(player, own, true)
	end
end

local function claim(player: Player)
	for _, plot in plots do
		if plot.owner == nil then
			plot.owner = player
			plot.crew = {}
			plot.crewName = ownerDefaultName(player)
			owned[player] = plot.plotId
			MapBuilder.SetSignText(plot.plotId, plot.crewName :: string)
			syncLayout(plot)
			Events.PlotClaimed:Fire(plot.plotId, player)
			moveTo(player, plot.plotId, true)
			return
		end
	end
	warn(`[PlotService] No free plot for {player.UserId}`)
end

local function release(player: Player)
	local plotId = owned[player]
	if not plotId then
		return
	end
	local plot = plots[plotId]
	-- Crew go back to their own diners before the plot is cleared.
	for _, member in table.clone(plot.crew) do
		if member.Parent == Players then
			returnHome(member)
		end
		local index = table.find(plot.crew, member)
		if index then
			table.remove(plot.crew, index)
		end
		if current[member] == plotId then
			current[member] = nil
			member:SetAttribute(WorldSchema.Attributes.PlayerPlotId, nil)
		end
	end
	owned[player] = nil
	plot.owner = nil
	plot.crew = {}
	plot.crewName = nil
	plot.decorTier = 0
	plot.seatCount = Timings.Seats.Base
	plot.stationSlots = Stations.BaseSlots
	MapBuilder.ApplyDecor(plotId, 0)
	MapBuilder.SetSeatCount(plotId, plot.seatCount)
	MapBuilder.SetStationSlots(plotId, plot.stationSlots)
	MapBuilder.SetVIPBooth(plotId, false)
	MapBuilder.SetSignText(plotId, FREE_SIGN_TEXT)
	Events.PlotReleased:Fire(plotId)
	Events.PlotLayoutChanged:Fire(plotId)
	broadcast()
end

local function leave(player: Player)
	local plotId = current[player]
	if plotId and owned[player] ~= plotId then
		local plot = plots[plotId]
		local index = table.find(plot.crew, player)
		if index then
			table.remove(plot.crew, index)
			Events.CrewChanged:Fire(plotId, crewList(plot))
		end
	end
	current[player] = nil
	release(player)
	local list = connections[player]
	if list then
		for _, conn in list do
			conn:Disconnect()
		end
		connections[player] = nil
	end
	handled[player] = nil
end

local function onPlayer(player: Player)
	if handled[player] then
		return
	end
	handled[player] = true
	local conns: { RBXScriptConnection } = {}
	connections[player] = conns
	table.insert(
		conns,
		player.CharacterAdded:Connect(function()
			local plotId = current[player]
			if plotId then
				teleportToPlot(player, plotId)
			end
		end)
	)
	task.spawn(function()
		local data = DataService.WaitForData(player, Timings.Data.LoadWaitSeconds)
		if not data or player.Parent ~= Players or not handled[player] then
			return
		end
		claim(player)
	end)
end

local function ownerPlot(player: Player): Plot?
	local id = owned[player]
	return if id then plots[id] else nil
end

local function plotOwnedBy(userId: number): Plot?
	for _, plot in plots do
		if plot.owner and plot.owner.UserId == userId then
			return plot
		end
	end
	return nil
end

local function handleJoinCrew(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local ownerUserId = (payload :: any).ownerUserId
	if not Guard.isInt(ownerUserId, 1, MAX_USER_ID) then
		return
	end
	local target = plotOwnedBy(ownerUserId)
	if not target or target.owner == player or current[player] == target.plotId then
		return
	end
	-- Players who host their own crew cannot walk away from it.
	local mine = ownerPlot(player)
	if mine and #mine.crew > 0 then
		return
	end
	if #target.crew >= Timings.Plots.MaxCrew then
		return
	end
	local okFriends, friends = pcall(function()
		return player:IsFriendsWithAsync(ownerUserId)
	end)
	if not okFriends or friends ~= true then
		return
	end
	-- Re-check after the yield above.
	if #target.crew >= Timings.Plots.MaxCrew or target.owner == nil or target.owner.UserId ~= ownerUserId then
		return
	end
	moveTo(player, target.plotId, true)
end

local function handleSetCrewName(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local name = (payload :: any).name
	if not Guard.isString(name, Timings.Text.MaxCrewNameLength) then
		return
	end
	local plot = ownerPlot(player)
	if not plot then
		return
	end
	local trimmed = string.match(name :: string, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(trimmed, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(filtered) ~= "string" or filtered == "" then
		return
	end
	if plot.owner ~= player then
		return
	end
	plot.crewName = filtered
	MapBuilder.SetSignText(plot.plotId, filtered)
	broadcast()
end

function PlotService.Init()
	for i = 1, Timings.Plots.Count do
		plots[i] = newPlot(i)
	end

	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(leave)

	Events.UpgradePurchased:Connect(function(player)
		local plot = ownerPlot(player)
		if plot then
			syncLayout(plot)
		end
	end)
	Events.PassOwnershipChanged:Connect(function(player)
		local plot = ownerPlot(player)
		if plot then
			syncLayout(plot)
		end
	end)

	Guard.onEvent("JoinCrew", handleJoinCrew)
	Guard.onEvent("LeaveCrew", function(player)
		returnHome(player)
	end)
	Guard.onEvent("SetCrewName", handleSetCrewName)
end

function PlotService.Start()
	if started then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

-- Plot the player currently works on (owned or crew).
function PlotService.GetPlotOf(player: Player): number?
	return current[player]
end

function PlotService.GetOwnedPlot(player: Player): number?
	return owned[player]
end

function PlotService.GetOwner(plotId: number): Player?
	local plot = plots[plotId]
	return if plot then plot.owner else nil
end

-- Owner + crew currently on the plot.
function PlotService.GetMembers(plotId: number): { Player }
	local plot = plots[plotId]
	if not plot then
		return {}
	end
	local members = {}
	local owner = plot.owner
	if owner and current[owner] == plotId then
		table.insert(members, owner)
	end
	for _, member in plot.crew do
		table.insert(members, member)
	end
	return members
end

function PlotService.IsMember(player: Player, plotId: number): boolean
	return isValidPlotId(plotId) and current[player] == plotId
end

function PlotService.GetPlotInfo(plotId: number): Types.PlotInfo?
	local plot = plots[plotId]
	return if plot then infoOf(plot) else nil
end

function PlotService.GetAllPlotInfo(): { Types.PlotInfo }
	local list = {}
	for _, plot in plots do
		table.insert(list, infoOf(plot))
	end
	return list
end

return PlotService

--!strict
-- Server-authoritative cook state machine per plot slot, held items, Auto-Chef AFK income. Owner: agent C.
-- Handles remote: CookAction. Sends StationUpdate, HeldItemChanged.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cooking = require(ReplicatedStorage.Shared.Logic.Cooking)
local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Offline = require(ReplicatedStorage.Shared.Logic.Offline)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local AudioDirector = require(script.Parent.Parent.World.AudioDirector)
local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local PlotService = require(script.Parent.PlotService)
local PropBuilder = require(script.Parent.Parent.World.PropBuilder)
local PurchaseService = require(script.Parent.PurchaseService)

local HAND_OFFSET =
	CFrame.new(Timings.Station.HeldDishOffset.X, Timings.Station.HeldDishOffset.Y, Timings.Station.HeldDishOffset.Z)

type Held = { item: Types.HeldItem, prop: Model? }
type SlotRuntime =
	{ state: Types.StationState, interact: BasePart?, fxAttachment: Attachment?, prompt: ProximityPrompt? }

local VALID_ACTIONS: { [string]: boolean } = { Start = true, Flip = true, Collect = true, Clear = true }

local StationService = {}

local slots: { [number]: { [number]: SlotRuntime } } = {}
local held: { [Player]: Held } = {}
local playerConns: { [Player]: { RBXScriptConnection } } = {}
local now = workspace.GetServerTimeNow

local function serverNow(): number
	return now(workspace)
end

local function plotUpgrades(plotId: number): { [Types.UpgradeId]: number }
	local owner = PlotService.GetOwner(plotId)
	local data = owner and DataService.GetData(owner)
	return if data then data.upgrades else {}
end

local function freshState(plotId: number, slot: number): Types.StationState
	local stationId: Types.StationId = Stations.SlotLayout[slot]
	return {
		plotId = plotId,
		slot = slot,
		stationId = stationId,
		phase = "Idle",
		dishId = Stations.Defs[stationId].dishId,
		cookerUserId = nil,
		phaseStartedAt = serverNow(),
		phaseEndsAt = nil,
		flipQuality = nil,
	}
end

local function sfxParent(rt: SlotRuntime): Instance?
	return rt.fxAttachment or rt.interact
end

local function sendTo(plotId: number, state: Types.StationState)
	local remote = Net.event("StationUpdate")
	for _, member in PlotService.GetMembers(plotId) do
		remote:FireClient(member, state)
	end
end

-- Workspace.Plots.Plot_<n>.Stations.Slot_<k>, looked up each time so a rebuilt plot is still found.
local function slotModel(plotId: number, slot: number): Instance?
	local model = MapBuilder.GetPlotModel(plotId)
	local stationsFolder = model and model:FindFirstChild(WorldSchema.Parts.Stations)
	return stationsFolder and stationsFolder:FindFirstChild(`{WorldSchema.SlotPrefix}{slot}`)
end

-- Mirrors the phase and flip quality onto the slot model for World/StationVisuals.
local function publishState(state: Types.StationState)
	local model = slotModel(state.plotId, state.slot)
	if model then
		model:SetAttribute(WorldSchema.Attributes.StationPhase, state.phase)
		model:SetAttribute(WorldSchema.Attributes.StationQuality, state.flipQuality)
	end
end

-- Commits a new state, running side effects (SFX, attributes) for phase changes and notifying the plot.
-- Station VFX are driven by World/StationVisuals from the Phase/Quality attributes, not here.
local function commit(rt: SlotRuntime, new: Types.StationState)
	local old = rt.state
	rt.state = new
	if old.phase == new.phase and old.flipQuality == new.flipQuality and old.cookerUserId == new.cookerUserId then
		return
	end
	if old.phase ~= new.phase or old.flipQuality ~= new.flipQuality then
		publishState(new)
	end
	if old.phase ~= new.phase then
		local parent = sfxParent(rt)
		if new.phase == "Cooking" then
			AudioDirector.PlaySfx("Sizzle", parent)
		elseif new.phase == "Finishing" then
			AudioDirector.PlaySfx("Flip", parent)
		elseif new.phase == "Ready" then
			AudioDirector.PlaySfx("Ding", parent)
		elseif new.phase == "Burnt" then
			AudioDirector.PlaySfx("Burnt", parent)
			Events.StationBurnt:Fire(new.plotId, new.slot)
		end
	end
	sendTo(new.plotId, new)
end

local function clearHeld(player: Player)
	local h = held[player]
	if not h then
		return
	end
	held[player] = nil
	if h.prop then
		h.prop:Destroy()
	end
	if player.Parent == Players then
		Net.event("HeldItemChanged"):FireClient(player, { item = nil })
	end
end

local function weldProp(player: Player, dishId: Types.DishId): Model?
	local character = player.Character
	if not character then
		return nil
	end
	local hand = character:FindFirstChild("RightHand")
		or character:WaitForChild("RightHand", Timings.Station.CharacterWaitSeconds)
	if not (hand and hand:IsA("BasePart")) then
		return nil
	end
	local prop = PropBuilder.MakeDish(dishId)
	local root = prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		prop:Destroy()
		return nil
	end
	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end
	prop:PivotTo(hand.CFrame * HAND_OFFSET)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = root
	weld.Parent = root
	prop.Parent = character
	return prop
end

local function giveHeld(player: Player, item: Types.HeldItem)
	clearHeld(player)
	local entry: Held = { item = item, prop = nil }
	held[player] = entry
	Net.event("HeldItemChanged"):FireClient(player, { item = item })
	entry.prop = weldProp(player, item.dishId)
	-- The player may have lost the item (or left) while the prop was being attached.
	if held[player] ~= entry then
		if entry.prop then
			entry.prop:Destroy()
		end
	end
end

local function slotCount(plotId: number): number
	local info = PlotService.GetPlotInfo(plotId)
	return if info then info.stationSlots else 0
end

local function refreshPrompts(plotId: number)
	local active = PlotService.GetOwner(plotId) ~= nil
	local count = slotCount(plotId)
	for slot, rt in slots[plotId] do
		if rt.prompt then
			rt.prompt.Enabled = active and slot <= count
		end
	end
end

local function buildSlot(plotId: number, slot: number): SlotRuntime
	local rt: SlotRuntime = { state = freshState(plotId, slot), interact = nil, fxAttachment = nil, prompt = nil }
	local slotRoot = slotModel(plotId, slot)
	local interact = slotRoot and slotRoot:FindFirstChild(WorldSchema.Parts.Interact)
	if interact and interact:IsA("BasePart") then
		rt.interact = interact
		interact:SetAttribute(WorldSchema.Attributes.PlotId, plotId)
		interact:SetAttribute(WorldSchema.Attributes.Slot, slot)
		CollectionService:AddTag(interact, WorldSchema.Tags.StationInteract)
		local prompt = interact:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
		prompt.ActionText = "Cook"
		prompt.ObjectText = Stations.Defs[Stations.SlotLayout[slot]].displayName
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = Timings.Station.InteractRange
		prompt.Enabled = false
		prompt.Parent = interact
		rt.prompt = prompt
	end
	local fx = slotRoot and slotRoot:FindFirstChild(WorldSchema.Parts.FXAttachment, true)
	if fx and fx:IsA("Attachment") then
		rt.fxAttachment = fx
	end
	publishState(rt.state)
	return rt
end

local function resetPlot(plotId: number)
	for slot, rt in slots[plotId] do
		rt.state = freshState(plotId, slot)
		publishState(rt.state)
	end
	refreshPrompts(plotId)
end

local function handleCookAction(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local p = payload :: any
	if
		not Guard.isInt(p.plotId, 1, Timings.Plots.Count)
		or not Guard.isInt(p.slot, 1, #Stations.SlotLayout)
		or not Guard.isOneOf(p.action, VALID_ACTIONS)
	then
		return
	end
	local plotId: number, slot: number = p.plotId, p.slot
	local action: Types.CookAction = p.action
	if not PlotService.IsMember(player, plotId) or slot > slotCount(plotId) then
		return
	end
	local rt = slots[plotId][slot]
	if not rt.interact or not Guard.isNear(player, rt.interact.Position, Timings.Station.InteractRange) then
		return
	end
	if action == "Collect" and held[player] then
		Net.event("Toast"):FireClient(player, { text = "Your hands are full!", kind = "Warning" })
		return
	end
	local sched = Cooking.schedule(rt.state.dishId, plotUpgrades(plotId))
	local ok, newState, quality = Cooking.applyAction(rt.state, action, serverNow(), sched, player.UserId)
	if not ok then
		return
	end
	commit(rt, newState)
	if action == "Collect" and (quality == "Perfect" or quality == "Good") then
		giveHeld(player, { kind = "Dish", dishId = newState.dishId, quality = quality })
		Events.DishCooked:Fire(player, plotId, newState.dishId, quality)
	end
end

local function trackPlayer(player: Player)
	if playerConns[player] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	playerConns[player] = conns
	table.insert(
		conns,
		player:GetAttributeChangedSignal(WorldSchema.Attributes.PlayerPlotId):Connect(function()
			clearHeld(player)
			local plotId = player:GetAttribute(WorldSchema.Attributes.PlayerPlotId)
			if type(plotId) == "number" and slots[plotId] then
				local remote = Net.event("StationUpdate")
				for _, rt in slots[plotId] do
					remote:FireClient(player, rt.state)
				end
			end
		end)
	)
	table.insert(
		conns,
		player.CharacterRemoving:Connect(function()
			clearHeld(player)
		end)
	)
end

local function untrackPlayer(player: Player)
	clearHeld(player)
	local conns = playerConns[player]
	if conns then
		for _, conn in conns do
			conn:Disconnect()
		end
		playerConns[player] = nil
	end
end

local function simulate()
	local t = serverNow()
	for plotId, plotSlots in slots do
		if PlotService.GetOwner(plotId) then
			local upgrades = plotUpgrades(plotId)
			for _, rt in plotSlots do
				if rt.state.phase ~= "Idle" and rt.state.phase ~= "Burnt" then
					local sched = Cooking.schedule(rt.state.dishId, upgrades)
					commit(rt, Cooking.advance(rt.state, t, sched))
				end
			end
		end
	end
end

local function autoChefTick()
	for plotId in slots do
		local owner = PlotService.GetOwner(plotId)
		if owner and owner.Parent == Players and PurchaseService.OwnsPass(owner, "AutoChef") then
			local data = DataService.GetData(owner)
			if data then
				local amount = Offline.autoChefIncome(data.upgrades, Timings.AutoChef.TickSeconds)
				if amount > 0 then
					DataService.AddCoins(owner, amount, "AutoChef")
				end
			end
		end
	end
end

function StationService.Init()
	for plotId = 1, Timings.Plots.Count do
		slots[plotId] = {}
		for slot = 1, #Stations.SlotLayout do
			slots[plotId][slot] = buildSlot(plotId, slot)
		end
	end

	Events.PlotClaimed:Connect(function(plotId)
		resetPlot(plotId)
	end)
	Events.PlotReleased:Connect(function(plotId)
		resetPlot(plotId)
	end)
	Events.PlotLayoutChanged:Connect(function(plotId)
		if slots[plotId] then
			refreshPrompts(plotId)
			for _, rt in slots[plotId] do
				publishState(rt.state)
			end
		end
	end)

	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(untrackPlayer)
	Guard.onEvent("CookAction", handleCookAction)
end

function StationService.Start()
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	for plotId in slots do
		refreshPrompts(plotId)
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				simulate()
			end)
			if not ok then
				warn(`[StationService] simulate failed: {err}`)
			end
			task.wait(Timings.Station.TickSeconds)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Timings.AutoChef.TickSeconds)
			local ok, err = pcall(function()
				autoChefTick()
			end)
			if not ok then
				warn(`[StationService] autoChef failed: {err}`)
			end
		end
	end)
end

function StationService.GetHeldItem(player: Player): Types.HeldItem?
	local h = held[player]
	return if h then h.item else nil
end

-- Removes and returns the player's held item (used when serving).
function StationService.TakeHeldItem(player: Player): Types.HeldItem?
	local h = held[player]
	if not h then
		return nil
	end
	clearHeld(player)
	return h.item
end

function StationService.GetStations(plotId: number): { Types.StationState }
	local list = {}
	local plotSlots = slots[plotId]
	if plotSlots then
		for slot = 1, #Stations.SlotLayout do
			table.insert(list, plotSlots[slot].state)
		end
	end
	return list
end

function StationService.GetAllStates(): { Types.StationState }
	local list = {}
	for plotId = 1, Timings.Plots.Count do
		for _, state in StationService.GetStations(plotId) do
			table.insert(list, state)
		end
	end
	return list
end

-- For the auto-server bot: removes a Ready dish of dishId from the plot's stations, returns its quality.
function StationService.TakeReadyDish(plotId: number, dishId: Types.DishId): Types.CookQuality?
	local plotSlots = slots[plotId]
	local owner = PlotService.GetOwner(plotId)
	if not plotSlots or not owner then
		return nil
	end
	local count = slotCount(plotId)
	local upgrades = plotUpgrades(plotId)
	for slot = 1, count do
		local rt = plotSlots[slot]
		if rt.state.phase == "Ready" and rt.state.dishId == dishId then
			local sched = Cooking.schedule(dishId, upgrades)
			local ok, newState, quality = Cooking.applyAction(rt.state, "Collect", serverNow(), sched, owner.UserId)
			if ok and (quality == "Perfect" or quality == "Good") then
				commit(rt, newState)
				return quality
			end
		end
	end
	return nil
end

return StationService

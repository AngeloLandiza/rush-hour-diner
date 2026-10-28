--!strict
-- Customer spawning, pathing, seating, patience, orders, serving + payout, legendary announcements,
-- auto-server bot. Owner: agent C. Handles remote: ServeCustomer.
-- Sends CustomerUpdate, CustomerRemoved, OrderServed, LegendaryAnnounce.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CustomerConfig = require(ReplicatedStorage.Shared.Config.Customers)
local EconomyLogic = require(ReplicatedStorage.Shared.Logic.Economy)
local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local Net = require(ReplicatedStorage.Shared.Net)
local Orders = require(ReplicatedStorage.Shared.Logic.Orders)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local Presets = require(ReplicatedStorage.Shared.VFX.Presets)
local Remotes = require(ReplicatedStorage.Shared.Contracts.Remotes)
local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Timings = require(ReplicatedStorage.Shared.Config.Timings)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UpgradeLogic = require(ReplicatedStorage.Shared.Logic.Upgrades)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local DataService = require(script.Parent.DataService)
local Guard = require(script.Parent.Parent.Util.Guard)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local PlotService = require(script.Parent.PlotService)
local PropBuilder = require(script.Parent.Parent.World.PropBuilder)
local PurchaseService = require(script.Parent.PurchaseService)
local RushHourService = require(script.Parent.RushHourService)
local StationService = require(script.Parent.StationService)

local SPAWN_LIFT = Vector3.new(0, Timings.Customers.SpawnLiftStuds, 0)
local BOT_LIFT = Vector3.new(0, Timings.AutoServer.LiftStuds, 0)
local MAX_CUSTOMER_ID = 2 ^ 31
-- TODO(contract): Timings.Customers.SitRootLiftStuds (HumanoidRootPart centre above the seat top when seated)
local FACE_TEXTURE = "rbxasset://textures/face.png" -- built-in engine content
local sitTracks: { [Rec]: AnimationTrack } = {}

type Rec = {
	data: Types.Customer,
	dishId: Types.DishId,
	patience: number,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	prompt: ProximityPrompt?,
	dead: boolean,
	reserved: boolean, -- the bot is delivering to this customer
}

type PlotRuntime = { nextSpawnAt: number, bot: Model?, botBusy: boolean, botNextAt: number }

local CustomerService = {}

local customers: { [number]: Rec } = {}
local plotRt: { [number]: PlotRuntime } = {}
local combos: { [Player]: number } = {}
local nextId = 1
local random = Random.new()
local paletteKeys: { string } = {}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function rng(): number
	return random:NextNumber()
end

local function pick<T>(list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[random:NextInteger(1, #list)]
end

local function nonZero(ids: { number }): { number }
	local out = {}
	for _, id in ids do
		if id ~= 0 then
			table.insert(out, id)
		end
	end
	return out
end

local function getFolder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

local function displayName(data: Types.Customer): string
	if data.legendaryId then
		local def = CustomerConfig.Legendary[data.legendaryId]
		if def then
			return def.displayName
		end
	end
	local kind = CustomerConfig.Kinds[data.kind]
	return if kind then kind.displayName else data.kind
end

local function viewOf(rec: Rec): Types.CustomerView
	local data = rec.data
	local order = data.order
	return {
		id = data.id,
		plotId = data.plotId,
		kind = data.kind,
		legendaryId = data.legendaryId,
		displayName = displayName(data),
		phase = data.phase,
		dishId = if order then order.dishId else nil,
		placedAt = if order then order.placedAt else nil,
		patienceSeconds = if order then order.patienceSeconds else nil,
	}
end

local function sendView(rec: Rec)
	if rec.prompt then
		rec.prompt.Enabled = rec.data.phase == "Waiting" and not rec.reserved
	end
	Net.event("CustomerUpdate"):FireAllClients(viewOf(rec))
end

local function removeRec(rec: Rec, reason: Types.LeaveReason)
	if rec.dead then
		return
	end
	rec.dead = true
	customers[rec.data.id] = nil
	if rec.model then
		rec.model:Destroy()
	end
	local payload: Remotes.CustomerRemovedPayload = { id = rec.data.id, reason = reason }
	Net.event("CustomerRemoved"):FireAllClients(payload)
	Events.CustomerLeft:Fire(rec.data, reason)
end

local function plotParts(plotId: number): (BasePart?, BasePart?, Model?)
	local model = MapBuilder.GetPlotModel(plotId)
	if not model then
		return nil, nil, nil
	end
	local spawn = model:FindFirstChild(WorldSchema.Parts.CustomerSpawn)
	local door = model:FindFirstChild(WorldSchema.Parts.Door)
	return if spawn and spawn:IsA("BasePart") then spawn else nil,
		if door and door:IsA("BasePart") then door else nil,
		model
end

local function seatPart(plotId: number, seatIndex: number): BasePart?
	local model = MapBuilder.GetPlotModel(plotId)
	local seats = model and model:FindFirstChild(WorldSchema.Parts.Seats)
	local seat = seats and seats:FindFirstChild(`{WorldSchema.SeatPrefix}{seatIndex}`)
	return if seat and seat:IsA("BasePart") then seat else nil
end

-- ── Models ──────────────────────────────────────────────────────────────────

local function colorOf(key: string?): Color3?
	return if key then Palette.Color[key] else nil
end

local function buildDescription(kind: Types.CustomerKind, legendaryId: Types.LegendaryId?): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	local def = if legendaryId then CustomerConfig.Legendary[legendaryId] else nil
	if kind == "Legendary" and def then
		local body = colorOf(def.bodyColor)
		local accent = colorOf(def.accentColor)
		if body then
			desc.HeadColor = body
			desc.LeftArmColor = body
			desc.RightArmColor = body
			desc.LeftLegColor = body
			desc.RightLegColor = body
		end
		desc.TorsoColor = accent or body or desc.TorsoColor
		desc.HeightScale = def.scale
		desc.WidthScale = def.scale
		desc.DepthScale = def.scale
		desc.HeadScale = def.scale
		return desc
	end
	local pools = CustomerConfig.OutfitPools
	local skin = colorOf(pick(pools.SkinTones))
	if skin then
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = skin
	end
	local torso = colorOf(pick(paletteKeys))
	if torso then
		desc.TorsoColor = torso
	end
	local legs = colorOf(pick(paletteKeys))
	if legs then
		desc.LeftLegColor = legs
		desc.RightLegColor = legs
	end
	desc.Shirt = pick(nonZero(pools.Shirts)) or 0
	desc.Pants = pick(nonZero(pools.Pants)) or 0
	local hat = pick(nonZero(pools.Hats))
	if hat then
		desc.HatAccessory = tostring(hat)
	end
	return desc
end

local function createModel(rec: Rec): boolean
	local data = rec.data
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(
			buildDescription(data.kind, data.legendaryId),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or rec.dead then
		if ok and model then
			model:Destroy()
		end
		return false
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		model:Destroy()
		return false
	end
	model.Name = `{WorldSchema.CustomerPrefix}{data.id}`
	model:SetAttribute(WorldSchema.Attributes.CustomerId, data.id)
	model:SetAttribute(WorldSchema.Attributes.PlotId, data.plotId)
	model:SetAttribute(WorldSchema.Attributes.Kind, data.kind)
	model:SetAttribute(WorldSchema.Attributes.LegendaryId, data.legendaryId)
	local head = model:FindFirstChild("Head")
	if head and not head:FindFirstChildOfClass("Decal") then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = FACE_TEXTURE
		face.Parent = head
	end
	humanoid.WalkSpeed = Timings.Customers.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local spawn = plotParts(data.plotId)
	if spawn then
		model:PivotTo(spawn.CFrame + SPAWN_LIFT)
	end
	model.Parent = getFolder(WorldSchema.Folders.Customers)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	CollectionService:AddTag(model, WorldSchema.Tags.CustomerModel)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Serve"
	prompt.ObjectText = displayName(data)
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.MaxActivationDistance = Timings.Serve.InteractRange
	prompt.Enabled = false
	prompt.Parent = root

	rec.model, rec.humanoid, rec.root, rec.prompt = model, humanoid, root, prompt
	return true
end

-- ── Movement ────────────────────────────────────────────────────────────────

local function flatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- Walks to `target`; falls back to teleporting if the path is blocked or takes too long.
local function walkTo(rec: Rec, target: Vector3)
	local humanoid, root, model = rec.humanoid, rec.root, rec.model
	if not (humanoid and root and model) then
		return
	end
	local distance = flatDistance(root.Position, target)
	local timeout = distance / Timings.Customers.WalkSpeed * Timings.Customers.Walk.TimeoutFactor
		+ Timings.Customers.Walk.TimeoutSlackSeconds
	local started = os.clock()
	local lastIssued = -math.huge
	while not rec.dead and flatDistance(root.Position, target) > Timings.Customers.Walk.ArriveDistance do
		local t = os.clock() - started
		if t > timeout then
			model:PivotTo(CFrame.new(target + SPAWN_LIFT))
			return
		end
		if t - lastIssued >= Timings.Customers.Walk.ReissueSeconds then
			lastIssued = t
			humanoid:MoveTo(target)
		end
		task.wait(0.1)
	end
end

local function sitAt(rec: Rec, seat: BasePart)
	local humanoid, root, model = rec.humanoid, rec.root, rec.model
	if not (humanoid and root and model) then
		return
	end
	local attachment = seat:FindFirstChild(WorldSchema.Parts.SitAttachment)
	local cf = if attachment and attachment:IsA("Attachment") then attachment.WorldCFrame else seat.CFrame
	-- Keep only position + facing (-Z of the attachment), then lift the root so the hips rest on the seat top.
	local pos = cf.Position + Vector3.new(0, Timings.Customers.SitRootLiftStuds, 0)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	model:PivotTo(CFrame.lookAt(pos, pos + look.Unit))
	root.Anchored = true
	local played = false
	pcall(function()
		local animate = model:FindFirstChild("Animate")
		local sitValue = animate and animate:FindFirstChild("sit")
		local anim = sitValue and sitValue:FindFirstChildOfClass("Animation")
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if anim and animator then
			local track = animator:LoadAnimation(anim)
			track.Looped = true
			track:Play()
			sitTracks[rec] = track
			played = true
		end
	end)
	if not played then
		humanoid.Sit = true
	end
end

local function standUp(rec: Rec)
	local track = sitTracks[rec]
	if track then
		sitTracks[rec] = nil
		pcall(function()
			track:Stop()
		end)
	end
	if rec.root then
		rec.root.Anchored = false
	end
	if rec.humanoid then
		rec.humanoid.Sit = false
	end
end

-- ── Announcements ───────────────────────────────────────────────────────────

local function announceLegendary(rec: Rec, servedByName: string?, tip: number?)
	local legendaryId = rec.data.legendaryId
	local def = if legendaryId then CustomerConfig.Legendary[legendaryId] else nil
	local owner = PlotService.GetOwner(rec.data.plotId)
	if not (legendaryId and def and owner) then
		return
	end
	local ownerName = owner.DisplayName
	local text = (string.gsub(def.announcement, "{owner}", function()
		return ownerName
	end))
	local payload: Types.LegendaryAnnouncement = {
		legendaryId = legendaryId,
		displayName = def.displayName,
		plotId = rec.data.plotId,
		ownerName = ownerName,
		servedByName = servedByName,
		tip = tip,
		text = text,
	}
	Net.event("LegendaryAnnounce"):FireAllClients(payload)
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

local function leaveAndDespawn(rec: Rec, reason: Types.LeaveReason)
	rec.data.phase = "Leaving"
	sendView(rec)
	standUp(rec)
	local spawn, door = plotParts(rec.data.plotId)
	if door then
		walkTo(rec, door.Position)
	end
	if spawn and not rec.dead then
		walkTo(rec, spawn.Position)
	end
	removeRec(rec, reason)
end

local function runCustomer(rec: Rec)
	local data = rec.data
	if not createModel(rec) then
		removeRec(rec, "Impatient")
		return
	end
	sendView(rec)
	local _, door = plotParts(data.plotId)
	if door then
		walkTo(rec, door.Position)
	end
	local seat = seatPart(data.plotId, data.seatIndex)
	if seat and not rec.dead then
		walkTo(rec, seat.Position)
		if rec.dead then
			return
		end
		sitAt(rec, seat)
	end
	if rec.dead then
		return
	end

	local order: Types.Order = { dishId = rec.dishId, placedAt = serverNow(), patienceSeconds = rec.patience }
	data.order = order
	data.phase = "Waiting"
	sendView(rec)
	if data.kind == "Legendary" then
		Events.LegendaryArrived:Fire(data)
		announceLegendary(rec, nil, nil)
		if rec.root then
			Presets.Burst("LegendarySparkle", rec.root)
		end
	end

	while not rec.dead and data.phase == "Waiting" do
		task.wait(Timings.Customers.WaitPollSeconds)
		if not rec.dead and not rec.reserved and Orders.remainingPatience(order, serverNow()) <= 0 then
			break
		end
	end
	if rec.dead then
		return
	end
	if data.phase == "Eating" then
		task.wait(Timings.Customers.EatSeconds)
		if not rec.dead then
			leaveAndDespawn(rec, "Served")
		end
	else
		leaveAndDespawn(rec, "Impatient")
	end
end

local function occupiedSeats(plotId: number): { [number]: boolean }
	local used = {}
	for _, rec in customers do
		if rec.data.plotId == plotId and rec.data.phase ~= "Leaving" then
			used[rec.data.seatIndex] = true
		end
	end
	return used
end

local function walkingCount(plotId: number): number
	local n = 0
	for _, rec in customers do
		if rec.data.plotId == plotId and rec.data.phase == "Walking" then
			n += 1
		end
	end
	return n
end

-- Frees one seat for a Legendary by sending away the Regular with no order yet, else the one with the
-- least patience left. Never bumps a Legendary, a VIP, or a customer mid-serve.
local function makeRoom(plotId: number, seatCount: number): number?
	local best: Rec? = nil
	local bestScore = math.huge
	local now = serverNow()
	for _, rec in customers do
		local d = rec.data
		if
			d.plotId == plotId
			and (d.kind == "Regular" or d.kind == "Hungry")
			and d.phase ~= "Leaving"
			and not rec.reserved
			and not rec.dead
			and d.seatIndex <= seatCount
		then
			local order = d.order
			local score = if order then Orders.remainingPatience(order, now) else -math.huge
			if score < bestScore then
				best, bestScore = rec, score
			end
		end
	end
	if not best then
		return nil
	end
	local seatIndex = best.data.seatIndex
	removeRec(best, "Impatient")
	return seatIndex
end

local function spawnCustomer(plotId: number, forcedLegendary: Types.LegendaryId?): number?
	local owner = PlotService.GetOwner(plotId)
	local ownerData = owner and DataService.GetData(owner)
	local info = PlotService.GetPlotInfo(plotId)
	if not (owner and ownerData and info) then
		return nil
	end
	local upgrades = ownerData.upgrades
	local seatCount = math.min(UpgradeLogic.seatCount(upgrades), Timings.Seats.Max)
	local used = occupiedSeats(plotId)
	local seatIndex: number? = nil
	for k = 1, seatCount do
		if not used[k] then
			seatIndex = k
			break
		end
	end
	local kind: Types.CustomerKind, legendaryId: Types.LegendaryId?
	if forcedLegendary then
		kind, legendaryId = "Legendary", forcedLegendary
	else
		kind, legendaryId = Orders.rollKind(rng, RushHourService.IsActive())
	end
	if not seatIndex and kind == "Legendary" then
		seatIndex = makeRoom(plotId, seatCount)
		if not seatIndex then
			warn("[CustomerService] SpawnLegendary: no seat")
			return nil
		end
	end
	if not seatIndex then
		return nil
	end
	if not forcedLegendary and kind ~= "Legendary" and walkingCount(plotId) >= Timings.Customers.MaxQueuedPerPlot then
		return nil
	end

	local available: { Types.DishId } = {}
	for k = 1, info.stationSlots do
		local dishId = Stations.Defs[Stations.SlotLayout[k]].dishId
		if not table.find(available, dishId) then
			table.insert(available, dishId)
		end
	end
	local id = nextId
	nextId += 1
	local rec: Rec = {
		data = {
			id = id,
			plotId = plotId,
			kind = kind,
			legendaryId = legendaryId,
			seatIndex = seatIndex,
			phase = "Walking",
			order = nil,
			spawnedAt = serverNow(),
		},
		dishId = Orders.pickDish(rng, kind, legendaryId, available),
		patience = Orders.patienceSeconds(kind, legendaryId, upgrades),
		model = nil,
		humanoid = nil,
		root = nil,
		prompt = nil,
		dead = false,
		reserved = false,
	}
	customers[id] = rec
	Events.CustomerSpawned:Fire(rec.data)
	task.spawn(function()
		local ok, err = pcall(function()
			runCustomer(rec)
		end)
		if not ok then
			warn(`[CustomerService] customer {id} failed: {err}`)
			removeRec(rec, "Impatient")
		end
	end)
	return id
end

-- ── Serving ─────────────────────────────────────────────────────────────────

-- Steps 3-8 of "Serve -> pay". `payer` receives the coins and the combo; for bot serves it is the owner.
local function completeServe(rec: Rec, payer: Player, quality: Types.CookQuality, byBot: boolean)
	local data = rec.data
	local order = data.order
	local owner = PlotService.GetOwner(data.plotId)
	local ownerData = owner and DataService.GetData(owner)
	if not (order and owner and ownerData) or rec.dead then
		return
	end
	data.phase = "Eating"
	rec.reserved = false
	sendView(rec)

	local wait = serverNow() - order.placedAt
	local ctx: Types.PayoutContext = {
		dishId = order.dishId,
		kind = data.kind,
		legendaryId = data.legendaryId,
		waitSeconds = wait,
		patienceSeconds = order.patienceSeconds,
		quality = quality,
		combo = combos[payer] or 0,
		ownerUpgrades = ownerData.upgrades,
		crewSize = math.max(1, #PlotService.GetMembers(data.plotId)),
		rushHour = RushHourService.IsActive(),
		hasTipsPass = PurchaseService.OwnsPass(payer, "TipsX2"),
		tipBoostPct = PurchaseService.GetTipBoostPct(payer),
	}
	local payout = EconomyLogic.computePayout(ctx)
	combos[payer] = payout.combo
	DataService.AddCoins(payer, payout.total, "Serve")

	local result: Types.ServeResult = {
		player = payer,
		plotId = data.plotId,
		customerId = data.id,
		kind = data.kind,
		legendaryId = data.legendaryId,
		dishId = order.dishId,
		payout = payout,
		byBot = byBot,
	}
	Events.OrderServed:Fire(result)
	local payload: Remotes.OrderServedPayload = {
		customerId = data.id,
		plotId = data.plotId,
		servedByUserId = payer.UserId,
		kind = data.kind,
		legendaryId = data.legendaryId,
		dishId = order.dishId,
		total = payout.total,
		tip = payout.tip,
		tipFraction = payout.tipFraction,
		combo = payout.combo,
		byBot = byBot,
	}
	Net.event("OrderServed"):FireAllClients(payload)
	if data.kind == "Legendary" then
		announceLegendary(rec, payer.DisplayName, payout.tip)
	end
end

local function handleServe(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	local customerId = (payload :: any).customerId
	if not Guard.isInt(customerId, 1, MAX_CUSTOMER_ID) then
		return
	end
	local rec = customers[customerId]
	if not rec or rec.dead or rec.reserved or rec.data.phase ~= "Waiting" or not rec.data.order then
		return
	end
	if not PlotService.IsMember(player, rec.data.plotId) then
		return
	end
	local root = rec.root
	if not root or not Guard.isNear(player, root.Position, Timings.Serve.InteractRange) then
		return
	end
	local heldItem = StationService.GetHeldItem(player)
	if not heldItem or heldItem.dishId ~= rec.data.order.dishId or heldItem.quality == "Burnt" then
		return
	end
	local owner = PlotService.GetOwner(rec.data.plotId)
	if not (owner and DataService.GetData(owner)) then
		return
	end
	local taken = StationService.TakeHeldItem(player)
	if not taken then
		return
	end
	completeServe(rec, player, taken.quality, false)
end

-- ── Auto-server bot ─────────────────────────────────────────────────────────

local function counterCFrame(plotId: number): CFrame?
	local model = MapBuilder.GetPlotModel(plotId)
	local counter = model and model:FindFirstChild(WorldSchema.Parts.Counter)
	if counter and counter:IsA("BasePart") then
		return counter.CFrame + BOT_LIFT + Vector3.new(0, counter.Size.Y / 2, 0)
	end
	return nil
end

local function tweenModel(model: Model, target: CFrame, seconds: number)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	local conn = value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Value = target })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	value:Destroy()
end

local function destroyBot(runtime: PlotRuntime)
	if runtime.bot then
		runtime.bot:Destroy()
		runtime.bot = nil
	end
end

local function ensureBot(plotId: number, runtime: PlotRuntime, wanted: boolean)
	if not wanted then
		destroyBot(runtime)
		return
	end
	if runtime.bot and runtime.bot.Parent then
		return
	end
	local home = counterCFrame(plotId)
	local bot = PropBuilder.MakeAutoServerBot()
	bot.Name = `{WorldSchema.AutoServerPrefix}{plotId}`
	if home then
		bot:PivotTo(home)
	end
	bot.Parent = getFolder(WorldSchema.Folders.Bots)
	runtime.bot = bot
end

local function botTick(plotId: number, runtime: PlotRuntime, owner: Player, t: number)
	local bot = runtime.bot
	if not bot or runtime.botBusy or t < runtime.botNextAt then
		return
	end
	runtime.botNextAt = t + Timings.AutoServer.DeliverSeconds
	local waiting: { Rec } = {}
	for _, rec in customers do
		if rec.data.plotId == plotId and rec.data.phase == "Waiting" and not rec.reserved and rec.data.order then
			table.insert(waiting, rec)
		end
	end
	table.sort(waiting, function(a, b)
		return (a.data.order :: Types.Order).placedAt < (b.data.order :: Types.Order).placedAt
	end)
	for _, rec in waiting do
		local quality = StationService.TakeReadyDish(plotId, (rec.data.order :: Types.Order).dishId)
		if quality == "Perfect" or quality == "Good" then
			local delivered: Types.CookQuality = quality
			rec.reserved = true
			runtime.botBusy = true
			sendView(rec)
			task.spawn(function()
				local half = Timings.AutoServer.DeliverSeconds / 2
				local home = bot:GetPivot()
				local ok, err = pcall(function()
					local root = rec.root
					if root then
						local toward = (home.Position - root.Position)
						local dir = if toward.Magnitude > 0 then toward.Unit else Vector3.zero
						tweenModel(
							bot,
							CFrame.new(root.Position + dir * Timings.AutoServer.StandOffStuds + BOT_LIFT),
							half
						)
					end
					if not rec.dead and owner.Parent == Players then
						completeServe(rec, owner, delivered, true)
					end
					if bot.Parent then
						tweenModel(bot, home, half)
					end
				end)
				if not ok then
					warn(`[CustomerService] bot delivery failed: {err}`)
				end
				rec.reserved = false
				runtime.botBusy = false
			end)
			return
		end
	end
end

-- ── Loop & events ───────────────────────────────────────────────────────────

local function despawnPlot(plotId: number)
	for _, rec in customers do
		if rec.data.plotId == plotId then
			removeRec(rec, "PlotReleased")
		end
	end
	local runtime = plotRt[plotId]
	if runtime then
		destroyBot(runtime)
	end
	plotRt[plotId] = nil
end

local function plotTick(plotId: number, t: number)
	local owner = PlotService.GetOwner(plotId)
	local data = owner and DataService.GetData(owner)
	if not (owner and data) then
		return
	end
	local runtime = plotRt[plotId]
	if not runtime then
		runtime = {
			nextSpawnAt = t + Timings.Customers.FirstCustomerDelaySeconds,
			bot = nil,
			botBusy = false,
			botNextAt = 0,
		}
		plotRt[plotId] = runtime
	end
	ensureBot(plotId, runtime, UpgradeLogic.hasAutoServer(data.upgrades))
	botTick(plotId, runtime, owner, t)

	if t >= runtime.nextSpawnAt and #PlotService.GetMembers(plotId) > 0 then
		if spawnCustomer(plotId, nil) then
			-- spawnInterval already includes the Rush Hour multiplier.
			runtime.nextSpawnAt = t + Orders.spawnInterval(RushHourService.IsActive())
		end
	end
end

function CustomerService.Init()
	for key in Palette.Color do
		table.insert(paletteKeys, key)
	end
	table.sort(paletteKeys)

	Events.PlotClaimed:Connect(function(plotId)
		plotRt[plotId] = {
			nextSpawnAt = serverNow() + Timings.Customers.FirstCustomerDelaySeconds,
			bot = nil,
			botBusy = false,
			botNextAt = 0,
		}
	end)
	Events.PlotReleased:Connect(despawnPlot)
	Players.PlayerRemoving:Connect(function(player)
		combos[player] = nil
	end)
	Guard.onEvent("ServeCustomer", handleServe)

	if RunService:IsStudio() then
		-- Studio command bar: workspace:SetAttribute("DebugLegendary", "<key of Config/Customers.Legendary>")
		workspace:GetAttributeChangedSignal("DebugLegendary"):Connect(function()
			local key = workspace:GetAttribute("DebugLegendary")
			if type(key) ~= "string" or key == "" then
				return
			end
			workspace:SetAttribute("DebugLegendary", "")
			if CustomerConfig.Legendary[key] == nil then
				warn(`[CustomerService] DebugLegendary: unknown legendary '{key}'`)
				return
			end
			for plotId = 1, Timings.Plots.Count do
				if PlotService.GetOwner(plotId) then
					CustomerService.SpawnLegendary(plotId, key)
					return
				end
			end
			warn("[CustomerService] DebugLegendary: no owned plot")
		end)
	end
end

function CustomerService.Start()
	task.spawn(function()
		while true do
			local t = serverNow()
			for plotId = 1, Timings.Plots.Count do
				local ok, err = pcall(function()
					plotTick(plotId, t)
				end)
				if not ok then
					warn(`[CustomerService] plot {plotId} tick failed: {err}`)
				end
			end
			task.wait(Timings.Customers.LoopSeconds)
		end
	end)
end

function CustomerService.GetCustomer(id: number): Types.Customer?
	local rec = customers[id]
	return if rec then rec.data else nil
end

function CustomerService.GetCustomersOnPlot(plotId: number): { Types.Customer }
	local list = {}
	for _, rec in customers do
		if rec.data.plotId == plotId then
			table.insert(list, rec.data)
		end
	end
	return list
end

function CustomerService.GetAllViews(): { Types.CustomerView }
	local list = {}
	for _, rec in customers do
		table.insert(list, viewOf(rec))
	end
	return list
end

-- Debug / admin: force a legendary customer onto a plot. Returns the customer id or nil if no seat.
function CustomerService.SpawnLegendary(plotId: number, legendaryId: Types.LegendaryId): number?
	if not CustomerConfig.Legendary[legendaryId] then
		return nil
	end
	return spawnCustomer(plotId, legendaryId)
end

return CustomerService

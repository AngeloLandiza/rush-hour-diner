--!strict
-- Music (Roblox licensed library ids) and SFX (generated, from assets/manifest.json). Owner: agent E.
-- Swaps music on Rush Hour; plays server-side positional SFX (sizzle, ding, cash, rush horn).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.Audio)
local Events = require(ReplicatedStorage.Shared.Contracts.Events)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)
local MapBuilder = require("./MapBuilder")

local AudioDirector = {}

local ROLLOFF_MIN = 12
local ROLLOFF_MAX = 90
local CLEANUP_SECONDS = 15

local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local musicSound: Sound

local function getGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local function assetUrl(id: number): string
	return "rbxassetid://" .. tostring(id)
end

local function playMusic(trackName: string)
	local track = AudioConfig.Music[trackName]
	if not track or track.id == 0 then
		musicSound:Stop()
		return
	end
	local url = assetUrl(track.id)
	if musicSound.SoundId ~= url then
		musicSound.SoundId = url
	end
	musicSound.Volume = track.volume
	if not musicSound.IsPlaying then
		musicSound:Play()
	end
end

-- The Sound's parent must be a part or attachment to be positional.
local function resolveEmitter(parent: Instance?): Instance?
	if parent == nil then
		return nil
	end
	if parent:IsA("BasePart") or parent:IsA("Attachment") then
		return parent
	end
	if parent:IsA("Model") and parent.PrimaryPart then
		return parent.PrimaryPart
	end
	return nil
end

local function plotCounter(plotId: number): Instance?
	local plot = MapBuilder.GetPlotModel(plotId)
	return if plot then plot:FindFirstChild(WorldSchema.Parts.Counter) else nil
end

function AudioDirector.Init()
	musicGroup = getGroup(WorldSchema.SoundGroups.Music)
	sfxGroup = getGroup(WorldSchema.SoundGroups.Sfx)

	musicSound = Instance.new("Sound")
	musicSound.Name = "MusicPlayer"
	musicSound.Looped = true
	musicSound.SoundGroup = musicGroup
	musicSound.Parent = SoundService

	Events.RushHourStarted:Connect(function()
		playMusic("Rush")
		AudioDirector.PlaySfx("RushHorn")
	end)
	Events.RushHourEnded:Connect(function()
		playMusic("Day")
	end)
	Events.OrderServed:Connect(function(result)
		AudioDirector.PlaySfx("Cash", plotCounter(result.plotId))
	end)
	Events.DishCooked:Connect(function(_player, plotId)
		AudioDirector.PlaySfx("Ding", plotCounter(plotId))
	end)
	Events.LegendaryArrived:Connect(function()
		AudioDirector.PlaySfx("Legendary")
	end)
end

function AudioDirector.Start()
	playMusic("Day")
end

-- Play a named SFX (Config/Audio key) at a part/attachment, or globally if parent is nil.
function AudioDirector.PlaySfx(name: string, parent: Instance?)
	local cfg = AudioConfig.Sfx[name]
	if not cfg or cfg.id == 0 then
		return
	end
	local emitter = resolveEmitter(parent)
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. name
	sound.SoundId = assetUrl(cfg.id)
	sound.Volume = cfg.volume
	sound.SoundGroup = sfxGroup
	if emitter then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = ROLLOFF_MIN
		sound.RollOffMaxDistance = ROLLOFF_MAX
	end
	sound.Parent = emitter or SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	Debris:AddItem(sound, CLEANUP_SECONDS)
	sound:Play()
end

return AudioDirector

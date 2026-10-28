--!strict
-- SettingsController: music/sfx toggles (muting SoundGroups locally) and the [VIP] chat tag.
-- Owner: agent D.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(script.Parent.Parent.Signal)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

export type Key = "music" | "sfx"

local SettingsController = {
	Changed = Signal.new() :: Signal.Signal<Key>,
}

local GROUP_FOR: { [Key]: string } = {
	music = WorldSchema.SoundGroups.Music,
	sfx = WorldSchema.SoundGroups.Sfx,
}

local overrides: { [string]: boolean } = {} -- optimistic local values until DataSync confirms
local baseVolume: { [string]: number } = {}

function SettingsController.Get(key: Key): boolean
	local o = overrides[key]
	if o ~= nil then
		return o
	end
	local data = State.data
	if data then
		return data.settings[key]
	end
	return true
end

local function applyGroup(key: Key)
	local group = SoundService:FindFirstChild(GROUP_FOR[key])
	if not group or not group:IsA("SoundGroup") then
		return
	end
	if baseVolume[key] == nil then
		baseVolume[key] = group.Volume
	end
	group.Volume = if SettingsController.Get(key) then baseVolume[key] else 0
end

local function applyAll()
	applyGroup("music")
	applyGroup("sfx")
end

function SettingsController.Set(key: Key, value: boolean)
	overrides[key] = value
	applyGroup(key)
	SettingsController.Changed:Fire(key)
	Net.event("SetSetting"):FireServer({ key = key, value = value })
end

local function setupChatTag()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		if source then
			local speaker = Players:GetPlayerByUserId(source.UserId)
			if speaker and speaker:GetAttribute(WorldSchema.Attributes.VIPBooth) == true then
				props.PrefixText = `<font color="#{Theme.Hex.Mustard}">[VIP]</font> {message.PrefixText}`
			end
		end
		return props
	end
end

function SettingsController.Init() end

function SettingsController.Start()
	State.waitReady()
	State.Changed.Data:Connect(function(view)
		-- Server value is now authoritative; drop optimistic overrides that match it.
		for key, value in overrides do
			if (view.settings :: any)[key] == value then
				overrides[key] = nil
			end
		end
		applyAll()
	end)
	SoundService.ChildAdded:Connect(function()
		applyAll()
	end)
	applyAll()
	setupChatTag()
end

return SettingsController

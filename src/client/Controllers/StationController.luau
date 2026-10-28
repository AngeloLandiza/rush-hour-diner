--!strict
-- StationController: opens the cook minigame when the player triggers a station prompt.
-- Owner: agent D.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = require(script.Parent.Parent.State)
local StationPanel = require(script.Parent.Parent.UI.Screens.StationPanel)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local Util = require(script.Parent.Parent.UI.Util)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local StationController = {}

local panel: StationPanel.StationPanel? = nil

local function onTriggered(prompt: ProximityPrompt, who: Player)
	if who ~= Players.LocalPlayer then
		return
	end
	local parent = prompt.Parent
	if not parent or not CollectionService:HasTag(parent, WorldSchema.Tags.StationInteract) then
		return
	end
	local plotId = Util.findAttribute(parent, WorldSchema.Attributes.PlotId)
	local slot = Util.findAttribute(parent, WorldSchema.Attributes.Slot)
	local stationId = Util.findAttribute(parent, WorldSchema.Attributes.StationId)
	if typeof(plotId) ~= "number" or typeof(slot) ~= "number" or typeof(stationId) ~= "string" then
		return
	end
	local p = panel
	if p then
		p:Open(plotId, slot, stationId :: Types.StationId, parent)
	end
end

function StationController.Init() end

function StationController.Start()
	State.waitReady()
	local p = StationPanel.new()
	panel = p
	ProximityPromptService.PromptTriggered:Connect(onTriggered)
	State.Changed.Station:Connect(function(s)
		if p:IsOpenFor(s.plotId, s.slot) then
			p:Render()
		end
	end)
	State.Changed.Snapshot:Connect(function()
		p:Render()
	end)
end

return StationController

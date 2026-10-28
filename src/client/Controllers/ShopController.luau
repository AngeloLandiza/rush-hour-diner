--!strict
-- ShopController: owns the shop panel and its toggle. Owner: agent D.
local Panel = require(script.Parent.Parent.UI.Components.Panel)
local ShopPanel = require(script.Parent.Parent.UI.Screens.ShopPanel)
local State = require(script.Parent.Parent.State)

local ShopController = {}

local panel: Panel.Panel? = nil

local function get(): Panel.Panel
	if not panel then
		panel = ShopPanel.new()
	end
	return panel :: Panel.Panel
end

function ShopController.Toggle()
	get():Toggle()
end

function ShopController.Init() end

function ShopController.Start()
	State.waitReady()
	get()
end

return ShopController

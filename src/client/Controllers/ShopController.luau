--!strict
-- ShopController: owns the shop modal, its toggle and deep links into a tab. Owner: UI agent.
local ShopPanel = require(script.Parent.Parent.UI.Screens.ShopPanel)
local State = require(script.Parent.Parent.State)

local ShopController = {}

local shop: ShopPanel.Shop? = nil

local function get(): ShopPanel.Shop
	local s = shop
	if not s then
		s = ShopPanel.new()
		shop = s
	end
	return s :: ShopPanel.Shop
end

function ShopController.Toggle()
	get().panel:Toggle()
end

-- Open the shop on a tab ("Upgrades" | "Passes" | "Products").
function ShopController.Open(tab: string?)
	local s = get()
	if tab then
		s.SelectTab(tab)
	end
	if not s.panel:IsOpen() then
		s.panel:Open()
	end
end

function ShopController.Init() end

function ShopController.Start()
	State.waitReady()
	get()
end

return ShopController

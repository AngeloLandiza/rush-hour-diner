--!strict
-- Client entry. Boots controllers: every Init() in order, then every Start(). Owner: UI agent (order),
-- orchestrator (boot pattern).
local Controllers = script.Controllers

type Module = { Init: () -> (), Start: () -> () }

local BOOT_ORDER: { { name: string, module: Module } } = {
	{ name = "State", module = require(script.State) },
	{ name = "InputController", module = require(Controllers.InputController) },
	{ name = "SettingsController", module = require(Controllers.SettingsController) },
	{ name = "HUDController", module = require(Controllers.HUDController) },
	{ name = "ShopController", module = require(Controllers.ShopController) },
	{ name = "StationController", module = require(Controllers.StationController) },
	{ name = "CustomerController", module = require(Controllers.CustomerController) },
	{ name = "PromptController", module = require(Controllers.PromptController) },
	{ name = "NotifyController", module = require(Controllers.NotifyController) },
	{ name = "FXController", module = require(Controllers.FXController) },
	{ name = "TutorialController", module = require(Controllers.TutorialController) },
}

for _, entry in BOOT_ORDER do
	local ok, err = pcall(function()
		entry.module.Init()
	end)
	if not ok then
		warn(`[ClientBoot] {entry.name}.Init failed: {err}`)
	end
end

for _, entry in BOOT_ORDER do
	task.spawn(function()
		local ok, err = pcall(function()
			entry.module.Start()
		end)
		if not ok then
			warn(`[ClientBoot] {entry.name}.Start failed: {err}`)
		end
	end)
end

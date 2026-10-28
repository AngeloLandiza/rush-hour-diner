--!strict
-- Exact upgrade effects as short card lines ("Grill cook time −33%", "+1 seat (2 → 3)", "Tips +25%").
-- Every number is derived from the Config/Upgrades effect spec through Logic/Upgrades, evaluated at the
-- player's current levels and at the next level, so the copy can never drift from the rules.
-- Owner: UI agent.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local Types = require(ReplicatedStorage.Shared.Contracts.Types)
local UpgradeLogic = require(ReplicatedStorage.Shared.Logic.Upgrades)

local UpgradeText = {}

type Levels = { [Types.UpgradeId]: number }

export type Colors = {
	value: string, -- hex for the current / only value
	gain: string, -- hex for the next value after the arrow
}

local MINUS = "−"
local ARROW = "→"

local function pct(x: number): number
	return math.floor(x * 100 + 0.5)
end

local function signed(x: number): string
	local p = pct(x)
	return if p < 0 then `{MINUS}{-p}%` else `+{p}%`
end

local function font(hex: string, text: string): string
	return `<font color="#{hex}">{text}</font>`
end

-- The levels table with id bumped by one (clamped to its max).
local function bumped(levels: Levels, def: Types.UpgradeDef): Levels
	local out = table.clone(levels)
	out[def.id] = math.min(UpgradeLogic.getLevel(levels, def.id) + 1, def.maxLevel)
	return out
end

-- Effect value of an upgrade's kind at the given levels, as a number the card formats.
local function value(def: Types.UpgradeDef, levels: Levels): number
	local effect = def.effect
	if effect.kind == "StationSpeed" then
		-- Cook time is divided by the multiplier: report the time saved as a negative fraction.
		return 1 / UpgradeLogic.stationSpeedMultiplier(levels, effect.stationId) - 1
	elseif effect.kind == "Patience" then
		return UpgradeLogic.patienceMultiplier(levels) - 1
	elseif effect.kind == "Seats" then
		return UpgradeLogic.seatCount(levels)
	elseif effect.kind == "TipMultiplier" then
		return UpgradeLogic.tipMultiplier(levels) - 1
	elseif effect.kind == "Decor" then
		return UpgradeLogic.decorTipPct(levels)
	end
	return if UpgradeLogic.hasAutoServer(levels) then 1 else 0
end

-- Rich-text effect line. Shows "current → next" once the upgrade has been bought at least once and
-- isn't maxed; before the first level it shows what you get; when maxed it shows what you have.
function UpgradeText.effect(def: Types.UpgradeDef, levels: Levels, colors: Colors): string
	local level = UpgradeLogic.getLevel(levels, def.id)
	local maxed = level >= def.maxLevel
	local cur = value(def, levels)
	local nxt = value(def, bumped(levels, def))
	local showBoth = level > 0 and not maxed
	local shown = if maxed then cur else nxt

	local function range(fmt: (number) -> string): string
		if showBoth then
			return `{font(colors.value, fmt(cur))} {ARROW} {font(colors.gain, fmt(nxt))}`
		end
		return font(if maxed then colors.value else colors.gain, fmt(shown))
	end

	local effect = def.effect
	if effect.kind == "StationSpeed" then
		local station = Stations.Defs[effect.stationId]
		local name = if station then station.displayName else effect.stationId
		return `{name} cook time {range(signed)}`
	elseif effect.kind == "Patience" then
		return `Customer patience {range(signed)}`
	elseif effect.kind == "Seats" then
		if maxed then
			return `{font(colors.value, tostring(cur))} seats`
		end
		local delta = nxt - cur
		local gain = font(colors.gain, if delta == 1 then "+1 seat" else `+{delta} seats`)
		local from = font(colors.value, tostring(cur))
		local to = font(colors.gain, tostring(nxt))
		return `{gain} ({from} {ARROW} {to})`
	elseif effect.kind == "TipMultiplier" then
		return `Tips {range(signed)}`
	elseif effect.kind == "Decor" then
		return `Decor: {range(signed)} tip`
	end
	return def.description
end

return UpgradeText

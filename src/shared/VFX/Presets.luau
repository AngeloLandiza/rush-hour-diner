--!strict
-- ParticleEmitter presets: steam, sizzle, fire, coin burst, tip explosion. Owner: agent E.
-- Used by the server (station FX) and the client FXController (coin burst / tip explosion).
local Presets = {}

export type PresetName = "Steam" | "Sizzle" | "Fire" | "CoinBurst" | "TipExplosion" | "LegendarySparkle"

-- Create a configured emitter (Enabled = false) parented to `parent`.
function Presets.Create(name: PresetName, parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = false
	emitter.Parent = parent
	return emitter
end

-- One-shot burst. scale (default 1) multiplies count/size — the tip explosion scales with tip size.
function Presets.Burst(name: PresetName, parent: Instance, scale: number?) end

return Presets

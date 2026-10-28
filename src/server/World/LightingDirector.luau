--!strict
-- Future lighting, Atmosphere, ColorCorrection, Bloom; Day preset and the Rush Hour tween. Owner: agent E.
-- Listens to Events.RushHourStarted/Ended.
local LightingDirector = {}

function LightingDirector.Init() end

function LightingDirector.Start() end

-- Tween to a Config/Lighting preset ("Day" | "Rush").
function LightingDirector.Apply(presetName: string, instant: boolean?) end

return LightingDirector

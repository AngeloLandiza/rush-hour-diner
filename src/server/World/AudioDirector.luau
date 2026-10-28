--!strict
-- Music (Roblox licensed library ids) and SFX (generated, from assets/manifest.json). Owner: agent E.
-- Swaps music on Rush Hour; plays server-side positional SFX (sizzle, ding, cash, rush horn).
local AudioDirector = {}

function AudioDirector.Init() end

function AudioDirector.Start() end

-- Play a named SFX (Config/Audio key) at a part/attachment, or globally if parent is nil.
function AudioDirector.PlaySfx(name: string, parent: Instance?) end

return AudioDirector

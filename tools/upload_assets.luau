--!strict
-- Uploads assets/sfx/*.wav through the Roblox Open Cloud Assets API, writes assets/manifest.json
-- ({ name = assetId }) and rewrites the SFX ids in src/shared/Config/Audio.luau.
--
-- Usage:  lune run tools/upload_assets [--dry-run] [--force]
--   --dry-run  print the plan only; needs no environment variables and makes no requests
--   --force    re-upload files that already have an id in assets/manifest.json
-- Environment (never printed):
--   ROBLOX_API_KEY                 Open Cloud key with asset:read and asset:write
--   ROBLOX_CREATOR_USER_ID   or    ROBLOX_CREATOR_GROUP_ID
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local SFX_DIR = "assets/sfx"
local MANIFEST = "assets/manifest.json"
local AUDIO_CONFIG = "src/shared/Config/Audio.luau"
local ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
local OPERATIONS_URL = "https://apis.roblox.com/assets/v1/operations/"
local POLL_SECONDS = 2
local POLL_ATTEMPTS = 60
local BOUNDARY = "----RushHourDinerBoundary7f3a9c"

local dryRun = false
local force = false
for _, arg in process.args do
	if arg == "--dry-run" then
		dryRun = true
	elseif arg == "--force" then
		force = true
	else
		print(`unknown argument {arg}`)
		process.exit(2)
	end
end

local function fail(message: string): never
	print("error: " .. message)
	process.exit(1)
end

-- ── Plan ─────────────────────────────────────────────────────────────────────

local manifest: { [string]: number } = {}
if fs.isFile(MANIFEST) then
	local decoded = serde.decode("json", fs.readFile(MANIFEST))
	if type(decoded) == "table" then
		for k, v in decoded do
			if type(k) == "string" and type(v) == "number" then
				manifest[k] = v
			end
		end
	end
end

local files: { string } = {}
if fs.isDir(SFX_DIR) then
	for _, entry in fs.readDir(SFX_DIR) do
		if string.match(entry, "%.wav$") then
			table.insert(files, entry)
		end
	end
end
table.sort(files)
if #files == 0 then
	fail(`no .wav files in {SFX_DIR}; run: lune run tools/gen_sfx`)
end

local function nameOf(file: string): string
	return (string.gsub(file, "%.wav$", ""))
end

local creatorKind: string? = nil
local creatorId: string? = nil
local apiKey = process.env.ROBLOX_API_KEY
local userId = process.env.ROBLOX_CREATOR_USER_ID
local groupId = process.env.ROBLOX_CREATOR_GROUP_ID
if userId and userId ~= "" then
	creatorKind, creatorId = "userId", userId
elseif groupId and groupId ~= "" then
	creatorKind, creatorId = "groupId", groupId
end

if dryRun then
	print("DRY RUN: no requests will be made and no files will be written")
	print(`POST {ASSETS_URL} (assetType Audio, multipart: request + fileContent)`)
	print(`creator: {creatorKind or "<set ROBLOX_CREATOR_USER_ID or ROBLOX_CREATOR_GROUP_ID>"}`)
	print(`api key: {if apiKey and apiKey ~= "" then "set" else "<set ROBLOX_API_KEY>"}`)
	for _, file in files do
		local name = nameOf(file)
		local existing = manifest[name]
		local size = fs.readFile(`{SFX_DIR}/{file}`)
		local action = if existing and not force then `skip (already id {existing})` else "upload"
		print(`  {file} ({#size} bytes) -> displayName "RHD_{name}": {action}`)
	end
	print(`then write {MANIFEST} and update the ids in {AUDIO_CONFIG}`)
	return
end

if not apiKey or apiKey == "" then
	fail("ROBLOX_API_KEY is not set")
end
if not creatorKind or not creatorId then
	fail("set ROBLOX_CREATOR_USER_ID or ROBLOX_CREATOR_GROUP_ID")
end
local key: string = apiKey
local kind: string = creatorKind
local creator: string = creatorId

-- ── Upload ───────────────────────────────────────────────────────────────────

local function request(method: string, url: string, headers: { [string]: string }, body: string?): any
	headers["x-api-key"] = key
	local response = net.request({ url = url, method = method, headers = headers, body = body })
	if not response.ok then
		-- Status and body only; the key is never part of either.
		fail(`{method} {url} failed: {response.statusCode} {response.statusMessage}\n{response.body}`)
	end
	return serde.decode("json", response.body)
end

local function multipart(name: string, file: string): string
	local meta = serde.encode("json", {
		assetType = "Audio",
		displayName = "RHD_" .. name,
		description = "Rush Hour Diner generated SFX: " .. name,
		creationContext = { creator = { [kind] = creator } },
	})
	local content = fs.readFile(`{SFX_DIR}/{file}`)
	return `--{BOUNDARY}\r\n`
		.. 'Content-Disposition: form-data; name="request"\r\n'
		.. "Content-Type: application/json\r\n\r\n"
		.. meta
		.. "\r\n"
		.. `--{BOUNDARY}\r\n`
		.. `Content-Disposition: form-data; name="fileContent"; filename="{file}"\r\n`
		.. "Content-Type: audio/wav\r\n\r\n"
		.. content
		.. "\r\n"
		.. `--{BOUNDARY}--\r\n`
end

local function upload(name: string, file: string): number
	local op = request("POST", ASSETS_URL, {
		["Content-Type"] = "multipart/form-data; boundary=" .. BOUNDARY,
	}, multipart(name, file))
	local opPath = op.path
	if type(opPath) ~= "string" then
		fail(`upload of {file} returned no operation path`)
	end
	local opId = string.match(opPath, "operations/(.+)$") or opPath
	for _ = 1, POLL_ATTEMPTS do
		local status = request("GET", OPERATIONS_URL .. opId, {}, nil)
		if status.done then
			if status.error then
				fail(`upload of {file} failed: {serde.encode("json", status.error)}`)
			end
			local assetId = tonumber(status.response and status.response.assetId)
			if not assetId then
				fail(`upload of {file} finished without an assetId`)
			end
			return assetId
		end
		task.wait(POLL_SECONDS)
	end
	fail(`timed out waiting for {file} to process`)
end

for _, file in files do
	local name = nameOf(file)
	if manifest[name] and not force then
		print(`skip {name} (id {manifest[name]})`)
	else
		print(`uploading {file} ...`)
		manifest[name] = upload(name, file)
		print(`  {name} -> {manifest[name]}`)
		-- Save after every upload so a later failure loses nothing.
		fs.writeFile(MANIFEST, serde.encode("json", manifest, true))
	end
end
fs.writeFile(MANIFEST, serde.encode("json", manifest, true))

-- ── Rewrite Config/Audio.luau ─────────────────────────────────────────────────

local source = fs.readFile(AUDIO_CONFIG)
local updated = 0
for name, assetId in manifest do
	local pattern = "(\n\t\t" .. name .. " = { id = )%d+"
	local replaced, count = string.gsub(source, pattern, function(prefix: string)
		return prefix .. tostring(assetId)
	end)
	if count > 0 then
		source = replaced
		updated += 1
	end
end
fs.writeFile(AUDIO_CONFIG, source)
print(`done: {updated} ids written to {AUDIO_CONFIG}`)

--!strict
-- Creates the game passes and developer products listed in Config/Products through Open Cloud and
-- writes their ids back into src/shared/Config/Products.luau. Idempotent: an item whose name already
-- exists in the universe is reused, not created again.
--
-- Usage: lune run tools/create_products [--dry-run]
-- Env:   ROBLOX_API_KEY (game-pass + developer-product read/write), ROBLOX_UNIVERSE_ID
-- The key is passed to curl on stdin (-H @-), so it never appears in argv or output.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Products = require("../src/shared/Config/Products")

local CONFIG_PATH = "src/shared/Config/Products.luau"
local API = "https://apis.roblox.com"

local dryRun = table.find(process.args, "--dry-run") ~= nil
local apiKey = process.env.ROBLOX_API_KEY
local universeId = process.env.ROBLOX_UNIVERSE_ID

if not universeId or universeId == "" then
	error("ROBLOX_UNIVERSE_ID is not set")
end
if not dryRun and (not apiKey or apiKey == "") then
	error("ROBLOX_API_KEY is not set")
end

type Response = { status: number, body: any }

local function curl(args: { string }): Response
	local full = { "-sS", "-w", "\n%{http_code}", "-H", "@-" }
	table.move(args, 1, #args, #full + 1, full)
	local result = process.exec("curl", full, { stdio = { stdin = `x-api-key: {apiKey}\n` } })
	if not result.ok then
		error(`curl failed: {result.stderr}`)
	end
	local body, status = string.match(result.stdout, "^(.*)\n(%d+)$")
	assert(body and status, "unexpected curl output")
	local ok, decoded = pcall(serde.decode, "json" :: any, body)
	return { status = tonumber(status) :: number, body = if ok then decoded else body }
end

-- Existing items by name, so reruns never create duplicates.
local function listExisting(path: string, listField: string, idField: string): { [string]: number }
	local byName: { [string]: number } = {}
	local pageToken = ""
	repeat
		local url = `{API}/{path}?pageSize=100` .. (if pageToken ~= "" then `&pageToken={pageToken}` else "")
		local res = curl({ url })
		if res.status ~= 200 then
			error(`list {path} failed: HTTP {res.status} {serde.encode("json", res.body)}`)
		end
		for _, item in res.body[listField] or {} do
			byName[item.name] = item[idField]
		end
		pageToken = res.body.nextPageToken or ""
	until pageToken == ""
	return byName
end

local function create(path: string, def: { [string]: any }, idField: string): (number?, string?)
	local res = curl({
		"-X",
		"POST",
		`{API}/{path}`,
		"--form-string",
		`name={def.displayName}`,
		"--form-string",
		`description={def.description}`,
		"--form-string",
		"isForSale=true",
		"--form-string",
		`price={def.priceRobux}`,
	})
	if res.status ~= 200 then
		return nil, `HTTP {res.status} {serde.encode("json", res.body)}`
	end
	return res.body[idField], nil
end

local source = fs.readFile(CONFIG_PATH)
local function writeId(key: string, id: number)
	local replaced, count = string.gsub(source, "(%s" .. key .. " = {%s*id = )%d+", "%1" .. tostring(id))
	assert(count == 1, `could not find id field for {key} in {CONFIG_PATH}`)
	source = replaced
end

local groups = {
	{
		label = "Pass",
		defs = Products.Passes :: { [string]: any },
		path = `game-passes/v1/universes/{universeId}/game-passes`,
		listPath = `game-passes/v1/universes/{universeId}/game-passes/creator`,
		listField = "gamePasses",
		idField = "gamePassId",
	},
	{
		label = "Product",
		defs = Products.Products :: { [string]: any },
		path = `developer-products/v2/universes/{universeId}/developer-products`,
		listPath = `developer-products/v2/universes/{universeId}/developer-products/creator`,
		listField = "developerProducts",
		idField = "productId",
	},
}

local failures = 0
for _, group in groups do
	local existing = if dryRun then {} else listExisting(group.listPath, group.listField, group.idField)
	local keys = {}
	for key in group.defs do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local def = group.defs[key]
		if dryRun then
			print(`[dry-run] {group.label} {key}: "{def.displayName}" for {def.priceRobux} R$`)
			continue
		end
		local id = existing[def.displayName]
		local note = "exists"
		if not id then
			local err
			id, err = create(group.path, def, group.idField)
			note = "created"
			if not id then
				failures += 1
				print(`FAIL {group.label} {key}: {err}`)
				continue
			end
		end
		writeId(key, id :: number)
		print(`{note} {group.label} {key} = {id}`)
	end
end

if not dryRun then
	fs.writeFile(CONFIG_PATH, source)
	print(`wrote ids to {CONFIG_PATH}`)
end
if failures > 0 then
	process.exit(1)
end

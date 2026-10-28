--!strict
-- Runs every tests/**/*.spec.luau file. Usage: lune run tools/test [filter]
local fs = require("@lune/fs")
local process = require("@lune/process")
local TestLib = require("./testlib")

local filter = process.args[1]

local function collect(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			collect(path, out)
		elseif string.match(name, "%.spec%.luau$") and (filter == nil or string.find(path, filter, 1, true)) then
			table.insert(out, path)
		end
	end
end

local files: { string } = {}
collect("tests", files)
table.sort(files)

for _, path in files do
	local modulePath = "../" .. string.gsub(path, "%.luau$", "")
	local ok, err = pcall(require, modulePath)
	if not ok then
		local r = TestLib.results()
		r.failed += 1
		table.insert(r.failures, path .. " failed to load\n    " .. tostring(err))
	end
end

local r = TestLib.results()
for _, failure in r.failures do
	print("FAIL " .. failure)
end
print(`{#files} spec files, {r.passed} passed, {r.failed} failed`)
if r.failed > 0 then
	process.exit(1)
end

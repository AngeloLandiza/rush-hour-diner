--!strict
-- Minimal test framework for Lune. Spec files call describe/it/expect from this module.

export type Expect = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNear: (expected: number, epsilon: number?) -> (),
	toBeTruthy: () -> (),
	toBeFalsy: () -> (),
	toBeGreaterThan: (n: number) -> (),
	toBeLessThan: (n: number) -> (),
	toBeAtLeast: (n: number) -> (),
	toBeAtMost: (n: number) -> (),
	toThrow: () -> (),
}

local TestLib = {}

local results = { passed = 0, failed = 0, failures = {} :: { string } }
local prefix: { string } = {}

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function fmt(v: any): string
	if type(v) == "table" then
		local parts = {}
		for k, x in v do
			table.insert(parts, tostring(k) .. "=" .. fmt(x))
		end
		table.sort(parts)
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

function TestLib.describe(name: string, fn: () -> ())
	table.insert(prefix, name)
	fn()
	table.remove(prefix)
end

function TestLib.it(name: string, fn: () -> ())
	local full = table.concat(prefix, " > ") .. " > " .. name
	local ok, err = pcall(fn)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, full .. "\n    " .. tostring(err))
	end
end

function TestLib.expect(actual: any): Expect
	local function fail(msg: string)
		error(msg, 3)
	end
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				fail(`expected {fmt(expected)}, got {fmt(actual)}`)
			end
		end,
		toEqual = function(expected: any)
			if not deepEqual(actual, expected) then
				fail(`expected {fmt(expected)}, got {fmt(actual)}`)
			end
		end,
		toBeNear = function(expected: number, epsilon: number?)
			if math.abs(actual - expected) > (epsilon or 1e-6) then
				fail(`expected ~{expected}, got {fmt(actual)}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected truthy, got {fmt(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected falsy, got {fmt(actual)}`)
			end
		end,
		toBeGreaterThan = function(n: number)
			if not (actual > n) then
				fail(`expected > {n}, got {fmt(actual)}`)
			end
		end,
		toBeLessThan = function(n: number)
			if not (actual < n) then
				fail(`expected < {n}, got {fmt(actual)}`)
			end
		end,
		toBeAtLeast = function(n: number)
			if not (actual >= n) then
				fail(`expected >= {n}, got {fmt(actual)}`)
			end
		end,
		toBeAtMost = function(n: number)
			if not (actual <= n) then
				fail(`expected <= {n}, got {fmt(actual)}`)
			end
		end,
		toThrow = function()
			if pcall(actual) then
				fail("expected function to throw")
			end
		end,
	}
end

function TestLib.results()
	return results
end

return TestLib

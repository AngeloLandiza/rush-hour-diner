--!strict
-- Procedurally generates the game's SFX as 16-bit mono 44.1 kHz WAV files into assets/sfx/.
-- Deterministic (seeded). Usage: lune run tools/gen_sfx
local fs = require("@lune/fs")

local RATE = 44100
local OUT_DIR = "assets/sfx"
local PEAK = 0.8
local TAU = math.pi * 2

-- xorshift32 PRNG so output is identical on every machine.
local function newRng(seed: number): () -> number
	local state = seed
	return function(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state / 4294967296 * 2 - 1 -- -1..1
	end
end

type Samples = { number }

local function silence(seconds: number): Samples
	local n = math.floor(seconds * RATE)
	local out = table.create(n, 0)
	return out
end

local function mixInto(dst: Samples, src: Samples, offsetSeconds: number)
	local offset = math.floor(offsetSeconds * RATE)
	for i, v in src do
		local j = i + offset
		if j <= #dst then
			dst[j] += v
		end
	end
end

-- Attack/exponential decay envelope.
local function envAD(t: number, attack: number, decayRate: number): number
	local a = if t < attack then t / attack else 1
	return a * math.exp(-decayRate * t)
end

local function tone(seconds: number, freq: number, harmonics: { number }, attack: number, decay: number): Samples
	local out = silence(seconds)
	for i = 1, #out do
		local t = (i - 1) / RATE
		local s = 0
		for h, amp in harmonics do
			s += amp * math.sin(TAU * freq * h * t)
		end
		out[i] = s * envAD(t, attack, decay)
	end
	return out
end

local function normalize(samples: Samples)
	local peak = 0
	for _, v in samples do
		peak = math.max(peak, math.abs(v))
	end
	if peak == 0 then
		return
	end
	for i, v in samples do
		samples[i] = v / peak * PEAK
	end
end

local sounds: { [string]: () -> Samples } = {}

-- Filtered noise with random crackle bursts.
function sounds.Sizzle(): Samples
	local rng = newRng(1001)
	local out = silence(1.2)
	local prev, hp = 0, 0
	local crackle = 0
	for i = 1, #out do
		local t = (i - 1) / RATE
		local n = rng()
		hp = n - prev * 0.85 -- crude high-pass
		prev = n
		if rng() > 0.9985 then
			crackle = 1
		end
		crackle *= 0.9985
		local env = math.min(t / 0.04, 1) * math.min((1.2 - t) / 0.4, 1)
		out[i] = hp * (0.35 + 0.65 * crackle) * env
	end
	return out
end

function sounds.Ding(): Samples
	return tone(0.9, 1318.5, { 1, 0.4, 0.2, 0.08 }, 0.004, 5)
end

function sounds.Cash(): Samples
	local out = silence(0.8)
	mixInto(out, tone(0.5, 1568, { 1, 0.35, 0.15 }, 0.003, 7), 0)
	mixInto(out, tone(0.6, 2093, { 1, 0.35, 0.15 }, 0.003, 6), 0.11)
	return out
end

-- Brassy saw chord (F major) with slow attack and a one-pole low-pass.
function sounds.RushHorn(): Samples
	local seconds = 1.6
	local out = silence(seconds)
	local notes = { 174.61, 220, 261.63 }
	local lp = 0
	for i = 1, #out do
		local t = (i - 1) / RATE
		local s = 0
		for k, f in notes do
			local detune = 1 + (k - 2) * 0.003
			for h = 1, 12 do
				s += math.sin(TAU * f * detune * h * t) / h
			end
		end
		local env = math.min(t / 0.06, 1) * math.min((seconds - t) / 0.3, 1)
		lp += (s - lp) * 0.25
		out[i] = lp * env
	end
	return out
end

-- Whoosh: noise through a sweeping band-pass.
function sounds.Flip(): Samples
	local rng = newRng(2002)
	local seconds = 0.35
	local out = silence(seconds)
	local low, band = 0, 0
	for i = 1, #out do
		local t = (i - 1) / RATE
		local p = t / seconds
		local fc = 400 + 2600 * p
		local f = 2 * math.sin(math.pi * fc / RATE)
		local n = rng()
		low += f * band
		local high = n - low - 0.3 * band
		band += f * high
		out[i] = band * math.sin(math.pi * p) ^ 1.5
	end
	return out
end

-- Buzzer: detuned square waves with tremolo.
function sounds.Burnt(): Samples
	local seconds = 0.7
	local out = silence(seconds)
	for i = 1, #out do
		local t = (i - 1) / RATE
		local a = if math.sin(TAU * 110 * t) >= 0 then 1 else -1
		local b = if math.sin(TAU * 117 * t) >= 0 then 1 else -1
		local trem = 0.75 + 0.25 * math.sin(TAU * 18 * t)
		local env = math.min(t / 0.01, 1) * math.min((seconds - t) / 0.15, 1)
		out[i] = (a + b) * 0.5 * trem * env
	end
	return out
end

-- Arpeggio fanfare: C E G C E G, then a held major chord.
function sounds.Legendary(): Samples
	local out = silence(2)
	local arp = { 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568 }
	for i, f in arp do
		mixInto(out, tone(0.5, f, { 1, 0.5, 0.25, 0.1 }, 0.005, 5), (i - 1) * 0.1)
	end
	local start = #arp * 0.1
	for _, f in { 1046.5, 1318.5, 1568, 2093 } do
		mixInto(out, tone(1.3, f, { 1, 0.4, 0.15 }, 0.01, 2.2), start)
	end
	return out
end

local function wav(samples: Samples): string
	local n = #samples
	local data = buffer.create(n * 2)
	for i, v in samples do
		local s = math.clamp(math.floor(v * 32767 + 0.5), -32768, 32767)
		buffer.writei16(data, (i - 1) * 2, s)
	end
	local dataSize = n * 2
	local header = "RIFF"
		.. string.pack("<I4", 36 + dataSize)
		.. "WAVEfmt "
		.. string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, RATE, RATE * 2, 2, 16)
		.. "data"
		.. string.pack("<I4", dataSize)
	return header .. buffer.tostring(data)
end

if not fs.isDir("assets") then
	fs.writeDir("assets")
end
if not fs.isDir(OUT_DIR) then
	fs.writeDir(OUT_DIR)
end

local names = {}
for name in sounds do
	table.insert(names, name)
end
table.sort(names)

for _, name in names do
	local samples = sounds[name]()
	normalize(samples)
	local bytes = wav(samples)
	fs.writeFile(`{OUT_DIR}/{name}.wav`, bytes)
	print(`wrote {OUT_DIR}/{name}.wav ({#bytes} bytes, {string.format("%.2f", #samples / RATE)}s)`)
end

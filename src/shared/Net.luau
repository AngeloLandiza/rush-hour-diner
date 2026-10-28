--!strict
-- Remote instance access. Owner: orchestrator. Names must exist in Contracts/Remotes.
-- Server: Net.setupServer() once at boot creates ReplicatedStorage.Remotes/*.
-- Either side: Net.event(name) / Net.func(name) (client waits for the instance).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require("./Contracts/Remotes")

local FOLDER_NAME = "Remotes"

local Net = {}

local function isEvent(name: string): boolean
	return (Remotes.ClientToServer :: any)[name] ~= nil or (Remotes.ServerToClient :: any)[name] ~= nil
end

local function isFunction(name: string): boolean
	return (Remotes.Functions :: any)[name] ~= nil
end

local function folder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(existing and existing:IsA("Folder"), "Net.setupServer() must run before remotes are used")
		return existing
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.setupServer()
	assert(RunService:IsServer(), "Net.setupServer is server-only")
	if ReplicatedStorage:FindFirstChild(FOLDER_NAME) then
		return
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	for _, group in { Remotes.ClientToServer, Remotes.ServerToClient } :: { { [string]: string } } do
		for name in group do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = f
		end
	end
	for name in Remotes.Functions :: { [string]: string } do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = f
	end
	f.Parent = ReplicatedStorage
end

function Net.event(name: string): RemoteEvent
	assert(isEvent(name), `Unknown remote event '{name}' (add it to Contracts/Remotes)`)
	local f = folder()
	local remote = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(remote and remote:IsA("RemoteEvent"), `Remote event '{name}' missing`)
	return remote
end

function Net.func(name: string): RemoteFunction
	assert(isFunction(name), `Unknown remote function '{name}' (add it to Contracts/Remotes)`)
	local f = folder()
	local remote = if RunService:IsServer() then f:FindFirstChild(name) else f:WaitForChild(name)
	assert(remote and remote:IsA("RemoteFunction"), `Remote function '{name}' missing`)
	return remote
end

return Net

--!strict
-- CameraController: frames the opening shot and keeps the gameplay camera comfortable.
--   * Once per (character, plot): as soon as the PlotId attribute is set, the character has a root and
--     the root stands on that plot's Spawn, a short scripted move swoops from an establishing shot over
--     the street into an elevated 3/4 view of the player's own diner (kitchen, counter, seated
--     customers and the character all in frame), then hands that exact angle and zoom to the standard
--     Custom camera. State-driven (signals + a cheap poll), so join/claim/teleport timing doesn't
--     matter; re-runs on respawn and plot change. If it hasn't run FallbackSeconds after joining, the
--     final framing is applied directly.
--   * Zoom is clamped to a comfortable range (Config/UI.Camera ZoomMin..ZoomMax).
--   * A render-step guard lifts the camera over the counter instead of letting it clip into it.
-- Owner: UI agent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local WorldSchema = require(ReplicatedStorage.Shared.Contracts.WorldSchema)

local CameraController = {}

local Cam = Theme.Camera
local INTRO: TweenInfo = Theme.Motion.CameraIntro
local GUARD_STEP = "RHD_CameraGuard"
local HANDOFF_STEP = "RHD_CameraHandoff"
local EPSILON = 1e-3

local player = Players.LocalPlayer
local token = 0 -- bumps on every new intro so a stale one stops
local owner: number? = nil -- token of the intro that currently holds the Scriptable camera

type Shot = { focus: Vector3, zoom: number, pitch: number, yaw: number }

local function plotModel(plotId: number): Model?
	local plots = workspace:FindFirstChild(WorldSchema.Folders.Plots)
	local plot = plots and plots:FindFirstChild(WorldSchema.PlotPrefix .. plotId)
	if plot and plot:IsA("Model") then
		return plot
	end
	return nil
end

local function plotBase(plot: Model): BasePart?
	local base = plot.PrimaryPart or plot:FindFirstChild(WorldSchema.Parts.Base)
	if base and base:IsA("BasePart") then
		return base
	end
	return nil
end

local function myPlotId(): number?
	local id = player:GetAttribute(WorldSchema.Attributes.PlayerPlotId)
	return if typeof(id) == "number" then id else nil
end

local function counterPart(): BasePart?
	local id = myPlotId()
	local plot = id and plotModel(id)
	local counter = plot and plot:FindFirstChild(WorldSchema.Parts.Counter)
	if counter and counter:IsA("BasePart") then
		return counter
	end
	return nil
end

-- Width / height of the screen the framing is computed for (honors the Studio DebugViewport preview).
local function aspect(camera: Camera): number
	local size = camera.ViewportSize
	local debugSize = Root.gui():GetAttribute("DebugViewport")
	if RunService:IsStudio() and typeof(debugSize) == "Vector2" then
		size = debugSize
	end
	return if size.Y > 0 then size.X / size.Y else 1
end

-- Orbit distance: the default zoom, pulled back on narrow (portrait) screens until FrameHalfWidth
-- studs either side of the player fit the horizontal field of view.
local function framingZoom(camera: Camera): number
	local halfV = math.rad(camera.FieldOfView) / 2
	local halfH = math.atan(math.tan(halfV) * aspect(camera))
	local needed = Cam.FrameHalfWidth / math.max(math.tan(halfH), EPSILON)
	return math.clamp(needed, Cam.Zoom, math.max(Cam.Zoom, Cam.PortraitZoomMax))
end

-- Camera CFrame for a shot, in the plot's frame (+Z = street, +X = right when facing the street).
local function shotCFrame(basis: CFrame, shot: Shot): CFrame
	local street = basis:VectorToWorldSpace(Vector3.zAxis)
	local right = basis:VectorToWorldSpace(Vector3.xAxis)
	local yaw, pitch = math.rad(shot.yaw), math.rad(shot.pitch)
	local flat = street * math.cos(yaw) + right * math.sin(yaw)
	local dir = flat * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	return CFrame.lookAt(shot.focus + dir * shot.zoom, shot.focus)
end

local function lerpShot(a: Shot, b: Shot, t: number): Shot
	return {
		focus = a.focus:Lerp(b.focus, t),
		zoom = a.zoom + (b.zoom - a.zoom) * t,
		pitch = a.pitch + (b.pitch - a.pitch) * t,
		yaw = a.yaw + (b.yaw - a.yaw) * t,
	}
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function setZoomRange(minZoom: number, maxZoom: number)
	player.CameraMinZoomDistance = minZoom
	player.CameraMaxZoomDistance = maxZoom
end

-- Gives the camera back to the Custom controller, unless a newer intro has already taken it over.
local function release(camera: Camera, myToken: number)
	if owner == myToken then
		owner = nil
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function finalShot(root: BasePart, zoom: number): Shot
	return {
		focus = root.Position + Vector3.new(0, Cam.SubjectHeight, 0),
		zoom = zoom,
		pitch = Cam.PitchDegrees,
		yaw = Cam.YawDegrees,
	}
end

-- Hands the final framing to the Custom camera. When it (re)enables it restores its own last orbit,
-- so for a few frames the framing is re-applied right after its update (Camera priority + 1); from
-- then on it orbits from the current look vector. The zoom stays pinned until it has settled.
local function handoff(camera: Camera, myToken: number, basis: CFrame, root: BasePart, zoom: number)
	-- The engine skips assigning the new character as CameraSubject while the camera is Scriptable
	-- (respawn during an intro), so always point the Custom camera at this character's humanoid.
	local character = root.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	setZoomRange(zoom, zoom)
	local final = finalShot(root, zoom)
	camera.CFrame = shotCFrame(basis, final)
	camera.Focus = CFrame.new(final.focus)
	release(camera, myToken)
	if camera.CameraType ~= Enum.CameraType.Custom and owner == nil then
		camera.CameraType = Enum.CameraType.Custom
	end
	local frames = 0
	local done = Instance.new("BindableEvent")
	local stepName = `{HANDOFF_STEP}_{myToken}`
	RunService:BindToRenderStep(stepName, Enum.RenderPriority.Camera.Value + 1, function()
		frames += 1
		if myToken == token and root.Parent and camera.CameraType == Enum.CameraType.Custom then
			camera.CFrame = shotCFrame(basis, finalShot(root, zoom))
		end
		if frames >= Cam.HandoffFrames then
			RunService:UnbindFromRenderStep(stepName)
			done:Fire()
		end
	end)
	done.Event:Wait()
	done:Destroy()
	if myToken == token then
		setZoomRange(Cam.ZoomMin, Cam.ZoomMax)
	end
end

-- The scripted move: establishing shot over the street -> final 3/4 framing, then handoff.
local function playIntro(myToken: number, basis: CFrame, root: BasePart)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local zoom = framingZoom(camera)
	local f = Cam.IntroFocus
	local startShot: Shot = {
		focus = basis:PointToWorldSpace(Vector3.new(f.X, f.Y, f.Z)),
		zoom = Cam.IntroZoom,
		pitch = Cam.IntroPitchDegrees,
		yaw = Cam.IntroYawDegrees,
	}
	-- Pin the zoom while the Custom controller is still active so it adopts the framing distance.
	setZoomRange(zoom, zoom)
	owner = myToken
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shotCFrame(basis, startShot)
	local started = os.clock()
	local duration = INTRO.Time
	while true do
		task.wait()
		if myToken ~= token or not root.Parent then
			release(camera, myToken)
			return
		end
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = TweenService:GetValue(t, INTRO.EasingStyle, INTRO.EasingDirection)
		local shot = lerpShot(startShot, finalShot(root, zoom), eased)
		camera.CFrame = shotCFrame(basis, shot)
		camera.Focus = CFrame.new(shot.focus)
		if t >= 1 then
			break
		end
	end
	handoff(camera, myToken, basis, root, zoom)
end

-- Runs fn as the newest camera job (any older intro stops at its next frame).
local function run(label: string, fn: (myToken: number) -> ())
	token += 1
	local myToken = token
	task.spawn(function()
		local ok, err = pcall(function()
			fn(myToken)
		end)
		if not ok then
			warn(`[CameraController] {label} failed: {err}`)
			local camera = workspace.CurrentCamera
			if camera then
				release(camera, myToken)
			end
			if myToken == token then
				setZoomRange(Cam.ZoomMin, Cam.ZoomMax)
			end
		end
	end)
end

-- ── State-driven trigger ────────────────────────────────────────────────────
-- The intro plays once per (character, plot) pair, the first time all of these hold: the PlotId
-- attribute is set, the character has a HumanoidRootPart, and that root stands within
-- ArriveDistance of the plot's Spawn (the server teleport has landed). Every relevant signal and a
-- cheap poll re-evaluate it, so the order and timing of plot claim, spawn and teleport don't matter.
local framedCharacter: Model? = nil
local framedPlot: number? = nil
local everFramed = false
local joinedAt = os.clock()

type Ready = { plotId: number, character: Model, root: BasePart, basis: CFrame }

local function readyState(): Ready?
	local plotId = myPlotId()
	local character = player.Character
	if not (plotId and character) then
		return nil
	end
	local root = rootOf(character)
	local plot = plotModel(plotId)
	local base = plot and plotBase(plot)
	local spawn = plot and plot:FindFirstChild(WorldSchema.Parts.Spawn)
	if not (root and base and spawn and spawn:IsA("BasePart")) then
		return nil
	end
	if (root.Position - spawn.Position).Magnitude > Cam.ArriveDistance then
		return nil
	end
	return { plotId = plotId, character = character, root = root, basis = base.CFrame }
end

local function evaluate()
	local ready = readyState()
	if not ready or (ready.character == framedCharacter and ready.plotId == framedPlot) then
		return
	end
	framedCharacter, framedPlot = ready.character, ready.plotId
	everFramed = true
	run("intro", function(myToken)
		playIntro(myToken, ready.basis, ready.root)
	end)
end

-- Safety net: if nothing has framed the shot FallbackSeconds after joining, apply the final framing
-- directly (no animation), oriented to the plot when there is one, else to the character's facing.
local function fallback()
	if everFramed or os.clock() - joinedAt < Cam.FallbackSeconds then
		return
	end
	local character = player.Character
	local root = character and rootOf(character)
	local camera = workspace.CurrentCamera
	if not (root and camera) then
		return
	end
	everFramed = true
	local plotId = myPlotId()
	local plot = plotId and plotModel(plotId)
	local base = plot and plotBase(plot)
	local basis: CFrame
	if base then
		basis = base.CFrame
	else
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		basis = if flat.Magnitude > EPSILON then CFrame.lookAt(Vector3.zero, flat) else CFrame.identity
	end
	local framedRoot: BasePart = root
	run("fallback", function(myToken)
		handoff(camera, myToken, basis, framedRoot, framingZoom(camera))
	end)
end

-- Keeps the camera out of the counter: if it ends up inside (or just above) the counter's box, it is
-- lifted along its orbit sphere to clear the top, keeping the same distance to the focus.
local function guardCounter()
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local counter = counterPart()
	if not counter then
		return
	end
	local pos = camera.CFrame.Position
	local half = counter.Size / 2
	local m = Cam.CounterMargin
	local localPos = counter.CFrame:PointToObjectSpace(pos)
	local inside = math.abs(localPos.X) < half.X + m
		and math.abs(localPos.Z) < half.Z + m
		and localPos.Y > -half.Y - m
		and localPos.Y < half.Y + Cam.CounterClearance
	if not inside then
		return
	end
	local focus = camera.Focus.Position
	local topY = counter.CFrame:PointToWorldSpace(Vector3.new(0, half.Y, 0)).Y + Cam.CounterClearance
	local dist = (pos - focus).Magnitude
	local dy = topY - focus.Y
	local newPos: Vector3
	if dist > EPSILON and math.abs(dy) < dist then
		local flat = Vector3.new(pos.X - focus.X, 0, pos.Z - focus.Z)
		if flat.Magnitude < EPSILON then
			local look = camera.CFrame.LookVector
			flat = Vector3.new(-look.X, 0, -look.Z)
		end
		if flat.Magnitude < EPSILON then
			return
		end
		newPos = focus + flat.Unit * math.sqrt(dist * dist - dy * dy) + Vector3.new(0, dy, 0)
	else
		newPos = Vector3.new(pos.X, topY, pos.Z)
	end
	camera.CFrame = CFrame.lookAt(newPos, focus)
end

function CameraController.Init()
	setZoomRange(Cam.ZoomMin, Cam.ZoomMax)
end

function CameraController.Start()
	RunService:BindToRenderStep(GUARD_STEP, Enum.RenderPriority.Camera.Value + 1, guardCounter)
	player.CharacterAdded:Connect(function(character)
		evaluate()
		character.ChildAdded:Connect(function()
			evaluate()
		end)
	end)
	if player.Character then
		player.Character.ChildAdded:Connect(function()
			evaluate()
		end)
	end
	player:GetAttributeChangedSignal(WorldSchema.Attributes.PlayerPlotId):Connect(evaluate)
	evaluate()
	-- Cheap poll for what has no signal (the teleport landing) and for the fallback timer.
	while true do
		task.wait(Cam.PollSeconds)
		evaluate()
		fallback()
	end
end

return CameraController

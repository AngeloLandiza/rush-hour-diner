--!strict
-- CameraController: frames the opening shot and keeps the gameplay camera comfortable.
--   * On first spawn, each respawn and each plot change (LocalPlayer "PlotId"), a short scripted move
--     swoops from an establishing shot over the street into an elevated 3/4 view of the player's own
--     diner (kitchen, counter, seated customers and the character all in frame), then hands that exact
--     angle and zoom to the standard Custom camera.
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
local function shotCFrame(base: BasePart, shot: Shot): CFrame
	local basis = base.CFrame
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

local function waitFrame()
	task.wait()
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

local function frameDiner(myToken: number)
	local camera = workspace.CurrentCamera
	local plotId = myPlotId()
	local plot = plotId and plotModel(plotId)
	local base = plot and plotBase(plot)
	local character = player.Character
	if not (camera and base and character) then
		return
	end
	-- Wait for the root part and for the server's teleport onto the plot (it lands just after spawn
	-- or a plot change). Polled per frame: the character can still be assembling its parts.
	local spawn = (plot :: Model):FindFirstChild(WorldSchema.Parts.Spawn)
	local deadline = os.clock() + Cam.ArriveTimeoutSeconds
	local found: BasePart? = nil
	while true do
		found = rootOf(character)
		local arrived = found ~= nil
			and not (
				spawn
				and spawn:IsA("BasePart")
				and (found.Position - spawn.Position).Magnitude > Cam.ArriveDistance
			)
		if arrived or os.clock() >= deadline then
			break
		end
		waitFrame()
		if myToken ~= token or not character.Parent then
			return
		end
	end
	if not found then
		return
	end
	local root: BasePart = found

	local zoom = framingZoom(camera)
	local function finalShot(): Shot
		return {
			focus = root.Position + Vector3.new(0, Cam.SubjectHeight, 0),
			zoom = zoom,
			pitch = Cam.PitchDegrees,
			yaw = Cam.YawDegrees,
		}
	end
	local f = Cam.IntroFocus
	local startShot: Shot = {
		focus = base.CFrame:PointToWorldSpace(Vector3.new(f.X, f.Y, f.Z)),
		zoom = Cam.IntroZoom,
		pitch = Cam.IntroPitchDegrees,
		yaw = Cam.IntroYawDegrees,
	}

	-- Pin the zoom while the Custom controller is still active so it adopts the framing distance, then
	-- take over with a scripted move.
	setZoomRange(zoom, zoom)
	owner = myToken
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shotCFrame(base, startShot)

	local started = os.clock()
	local duration = INTRO.Time
	while true do
		waitFrame()
		if myToken ~= token or not root.Parent then
			release(camera, myToken)
			return
		end
		local t = math.clamp((os.clock() - started) / duration, 0, 1)
		local eased = TweenService:GetValue(t, INTRO.EasingStyle, INTRO.EasingDirection)
		local shot = lerpShot(startShot, finalShot(), eased)
		camera.CFrame = shotCFrame(base, shot)
		camera.Focus = CFrame.new(shot.focus)
		if t >= 1 then
			break
		end
	end

	-- Hand the angle back to the Custom camera. When it re-enables it restores its own last orbit, so for
	-- a few frames we re-apply the framing right after its update (Camera priority + 1): from then on it
	-- orbits from the current look vector. The zoom stays pinned until it has settled.
	local final = finalShot()
	camera.CFrame = shotCFrame(base, final)
	camera.Focus = CFrame.new(final.focus)
	release(camera, myToken)
	local frames = 0
	local done = Instance.new("BindableEvent")
	local stepName = `{HANDOFF_STEP}_{myToken}`
	RunService:BindToRenderStep(stepName, Enum.RenderPriority.Camera.Value + 1, function()
		frames += 1
		if myToken == token and root.Parent and camera.CameraType == Enum.CameraType.Custom then
			local shot = finalShot()
			camera.CFrame = shotCFrame(base, shot)
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

local function startIntro()
	token += 1
	local myToken = token
	task.spawn(function()
		local ok, err = pcall(function()
			frameDiner(myToken)
		end)
		if not ok then
			warn(`[CameraController] intro failed: {err}`)
			local camera = workspace.CurrentCamera
			if camera then
				release(camera, myToken)
			end
		end
		if myToken == token then
			setZoomRange(Cam.ZoomMin, Cam.ZoomMax)
		end
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
	player.CharacterAdded:Connect(function()
		startIntro()
	end)
	player:GetAttributeChangedSignal(WorldSchema.Attributes.PlayerPlotId):Connect(function()
		if myPlotId() then
			startIntro()
		end
	end)
	if player.Character and myPlotId() then
		startIntro()
	end
end

return CameraController

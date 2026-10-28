--!strict
-- InputController: keyboard / gamepad equivalents for touch buttons, plus input-mode detection.
-- Owner: agent D.
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(script.Parent.Parent.Signal)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Mode = string -- "Touch" | "Keyboard" | "Gamepad"

local InputController = {
	Mode = "Keyboard",
	ModeChanged = Signal.new() :: Signal.Signal<Mode>,
}

local function modeFor(inputType: Enum.UserInputType): Mode?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType == Enum.UserInputType.Keyboard or inputType == Enum.UserInputType.MouseButton1 then
		return "Keyboard"
	elseif string.find(inputType.Name, "Gamepad") then
		return "Gamepad"
	end
	return nil
end

-- Bind keys/buttons to a handler. handler(true) on press, handler(false) on release.
function InputController.Bind(id: string, keys: { Enum.KeyCode }, handler: (pressed: boolean) -> ())
	ContextActionService:BindAction(id, function(_, state, _)
		if state == Enum.UserInputState.Begin then
			handler(true)
		elseif state == Enum.UserInputState.End then
			handler(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys))
end

-- Bind keys/buttons ABOVE the default character controls and sink them, so they never reach the
-- PlayerModule's actions (e.g. Space / ButtonA no longer jump while a station panel is open).
-- Same handler semantics as Bind: handler(true) on Begin, handler(false) on End.
function InputController.BindExclusive(id: string, keys: { Enum.KeyCode }, handler: (pressed: boolean) -> ())
	ContextActionService:BindActionAtPriority(id, function(_, state, _)
		if state == Enum.UserInputState.Begin then
			handler(true)
		elseif state == Enum.UserInputState.End then
			handler(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + Theme.Input.ExclusivePriorityOffset, table.unpack(keys))
end

function InputController.Unbind(id: string)
	ContextActionService:UnbindAction(id)
end

function InputController.Init()
	local initial = modeFor(UserInputService:GetLastInputType())
	if initial then
		InputController.Mode = initial
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		InputController.Mode = "Touch"
	end
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local mode = modeFor(inputType)
		if mode and mode ~= InputController.Mode then
			InputController.Mode = mode
			InputController.ModeChanged:Fire(mode)
		end
	end)
end

function InputController.Start() end

return InputController

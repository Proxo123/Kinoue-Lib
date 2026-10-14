local UserInputService = game:GetService("UserInputService")

local Util = require(script.Parent.Parent.internal.Util)

local Input = {}

local function finishCapture(window, input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    local control = window.Capturing
    window.Capturing = nil
    control.Down = false
    if input.KeyCode == Enum.KeyCode.Escape then
        control.Render(control:Get())
    else
        control:Set(input.KeyCode)
    end
end

local function onKeyBegan(window, input, processed)
    if window.Capturing then
        finishCapture(window, input)
        return
    end
    if processed or UserInputService:GetFocusedTextBox() then
        return
    end
    if input.KeyCode == window.ToggleKey and window.ToggleKey ~= Enum.KeyCode.Unknown then
        window:SetVisible(not window.Open)
        return
    end
    if input.KeyCode == Enum.KeyCode.Unknown then
        return
    end
    for _, control in ipairs(window.Keybinds) do
        if control.Enabled and input.KeyCode == control:Get() then
            control.Down = true
            if control.Pressed then
                window:Dispatch(control.Pressed, input)
            end
        end
    end
end

local function onKeyEnded(window, input)
    if input.KeyCode == Enum.KeyCode.Unknown then
        return
    end
    for _, control in ipairs(window.Keybinds) do
        if control.Down and input.KeyCode == control:Get() then
            control.Down = false
            if control.Released then
                window:Dispatch(control.Released, input)
            end
        end
    end
end

function Input.bindKeys(window)
    window.Scope:Connect(UserInputService.InputBegan, function(input, processed)
        onKeyBegan(window, input, processed)
    end)
    window.Scope:Connect(UserInputService.InputEnded, function(input)
        onKeyEnded(window, input)
    end)
end

function Input.bindPointer(window)
    local scope = window.Scope
    local dragStart, dragPosition, moveConnection

    local function onMove(input)
        if not window.Open then
            return
        end

        local resize = window.Resizing
        if resize and (input.UserInputType == Enum.UserInputType.MouseMovement or input == resize.Input) then
            local delta = input.Position - resize.Start
            window:SetSize(Vector2.new(resize.Size.X + delta.X, resize.Size.Y + delta.Y), resize.Origin)
            return
        end

        if not dragStart then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= window.DragInput then
            return
        end
        local delta = input.Position - dragStart
        window.RestPosition = UDim2.new(
            dragPosition.X.Scale,
            math.round(dragPosition.X.Offset + delta.X),
            dragPosition.Y.Scale,
            math.round(dragPosition.Y.Offset + delta.Y)
        )
        window.Root.Position = window.RestPosition
        window:SnapPosition(true)
    end

    local function track()
        if not moveConnection then
            moveConnection = scope:Connect(UserInputService.InputChanged, onMove)
        end
    end

    local function untrack()
        if moveConnection and not dragStart and not window.Resizing then
            scope:Release(moveConnection)
            moveConnection = nil
        end
    end

    scope:Connect(window.Header.InputBegan, function(input)
        if not window.Open or not Util.isPointer(input) then
            return
        end
        window.Root.Position = window.RestPosition
        dragStart = input.Position
        dragPosition = window.Root.Position
        window.DragInput = input
        track()
    end)

    scope:Connect(UserInputService.InputEnded, function(input)
        if Util.sameInput(input, window.DragInput) then
            dragStart = nil
            window.DragInput = nil
        end
        if window.Resizing and Util.sameInput(input, window.Resizing.Input) then
            window.Resizing = nil
        end
        untrack()
    end)

    scope:Connect(window.ResizeHandle.InputBegan, function(input)
        if not window.Open or not window.Resizable or not Util.isPointer(input) then
            return
        end
        window:ClosePopup()
        window.RestPosition = window.Root.Position
        dragStart = nil
        window.DragInput = nil
        window.Resizing = {
            Input = input,
            Start = input.Position,
            Size = Vector2.new(window.Root.Size.X.Offset, window.Root.Size.Y.Offset),
            Origin = window:GetPosition(),
        }
        track()
    end)
end

return Input

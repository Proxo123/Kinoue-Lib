local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Control = require(script.Parent.Control)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local PANEL_WIDTH = 214
local PANEL_HEIGHT = 175
local FIELD_WIDTH = 182
local FIELD_HEIGHT = 116
local SCREEN_MARGIN = 8

local ColorPicker = {}

local function rainbow()
    local keypoints = {}
    for index = 0, 6 do
        keypoints[index + 1] = ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1))
    end
    return ColorSequence.new(keypoints)
end

local function buildPanel(window, control, info)
    local panel = Util.frame(window.Screen, {
        Name = "ColorPicker",
        Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Outline,
        ZIndex = 50,
    })
    Util.label(panel, info.Text or control.Id, {
        Position = UDim2.fromOffset(6, 2),
        Size = UDim2.new(1, -12, 0, 20),
        ZIndex = 51,
    })

    local field = Util.button(panel, "", {
        Name = "SaturationValue",
        Position = UDim2.fromOffset(6, 26),
        Size = UDim2.fromOffset(FIELD_WIDTH, FIELD_HEIGHT),
        BorderSizePixel = 0,
        ZIndex = 51,
    })
    local white = Util.frame(field, {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 52,
    })
    Util.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, white)
    local black = Util.frame(field, {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        ZIndex = 53,
    })
    Util.new("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
    }, black)
    local marker = Util.frame(field, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(5, 5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 1,
        BorderColor3 = Color3.new(0, 0, 0),
        ZIndex = 54,
    })

    local hue = Util.button(panel, "", {
        Name = "Hue",
        Position = UDim2.fromOffset(194, 26),
        Size = UDim2.fromOffset(14, FIELD_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 51,
    })
    Util.new("UIGradient", { Rotation = 90, Color = rainbow() }, hue)
    local hueMarker = Util.frame(hue, {
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 54,
    })

    local hex = Util.textbox(panel, {
        Name = "Hex",
        Position = UDim2.fromOffset(6, 148),
        Size = UDim2.fromOffset(138, 21),
        ZIndex = 51,
    })
    local reset = Util.button(panel, "Reset", {
        Position = UDim2.fromOffset(150, 148),
        Size = UDim2.fromOffset(58, 21),
        ZIndex = 51,
    })

    return {
        Panel = panel,
        Field = field,
        Marker = marker,
        Hue = hue,
        HueMarker = hueMarker,
        Hex = hex,
        Reset = reset,
    }
end

function ColorPicker.add(group, id, info)
    info = info or {}
    local window = group.Window
    local control = Control.new(group, id, info.Value or Color3.new(1, 1, 1), function(value)
        assert(typeof(value) == "Color3", "ColorPicker requires Color3")
        return value
    end, info.Callback)

    control.Row = Control.row(group)
    Util.label(control.Row, info.Text or id, { Size = UDim2.new(1, -85, 1, 0) })
    control.Root = Util.button(control.Row, "", {
        Position = UDim2.new(1, -30, 0, 4),
        Size = UDim2.fromOffset(28, 15),
    })

    local renderPopup = nil

    control.Render = function(value)
        control.Root.BackgroundColor3 = value
        control.Root.BackgroundTransparency = control.Enabled and 0 or Theme.DisabledTransparency
        if not control.Enabled and window.PopupOwner == control then
            window:ClosePopup()
        end
        if renderPopup then
            renderPopup(value)
        end
    end

    Control.closePopupWhenHidden(control, window)

    local function open()
        if not control.Enabled or not window.Open or window.Dead then
            return
        end
        if window.PopupOwner == control then
            window:ClosePopup()
            return
        end
        window:ClosePopup()
        window.PopupOwner = control

        local scope = Util.scope()
        local parts = buildPanel(window, control, info)
        local h, s, v = control:Get():ToHSV()
        local editing = false

        renderPopup = function(value)
            if not editing then
                local nextHue, nextSaturation, nextValue = value:ToHSV()
                if nextSaturation > 0 and nextValue > 0 then
                    h = nextHue
                end
                s, v = nextSaturation, nextValue
            end
            parts.Field.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            parts.Marker.Position = UDim2.fromOffset(math.round(s * FIELD_WIDTH), math.round((1 - v) * FIELD_HEIGHT))
            parts.HueMarker.Position = UDim2.fromOffset(0, math.round(h * FIELD_HEIGHT))
            parts.Hex.Text = "#" .. value:ToHex()
        end
        renderPopup(control:Get())

        local function position()
            local screen = window.Screen.AbsoluteSize
            local origin, size = control.Root.AbsolutePosition, control.Root.AbsoluteSize
            local y = origin.Y + size.Y + 4
            if y + PANEL_HEIGHT > screen.Y - SCREEN_MARGIN then
                y = origin.Y - PANEL_HEIGHT - 4
            end
            local x = origin.X + size.X - PANEL_WIDTH
            parts.Panel.Position = UDim2.fromOffset(
                math.clamp(x, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.X - PANEL_WIDTH - SCREEN_MARGIN)),
                math.clamp(y, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.Y - PANEL_HEIGHT - SCREEN_MARGIN))
            )
        end
        position()
        scope:Connect(RunService.RenderStepped, position)

        local dragging, dragInput
        local function update(point)
            if not dragging then
                return
            end
            local target = dragging == "Hue" and parts.Hue or parts.Field
            local origin, size = target.AbsolutePosition, target.AbsoluteSize
            if dragging == "Hue" then
                h = math.clamp((point.Y - origin.Y) / math.max(1, size.Y), 0, 1)
            else
                s = math.clamp((point.X - origin.X) / math.max(1, size.X), 0, 1)
                v = 1 - math.clamp((point.Y - origin.Y) / math.max(1, size.Y), 0, 1)
            end
            editing = true
            control:Set(Color3.fromHSV(h, s, v))
            editing = false
        end

        local function bindDrag(target, mode)
            scope:Connect(target.InputBegan, function(input)
                if not Util.isPointer(input) then
                    return
                end
                dragging, dragInput = mode, input
                update(input.Position)
            end)
        end
        bindDrag(parts.Hue, "Hue")
        bindDrag(parts.Field, "Field")

        scope:Connect(UserInputService.InputChanged, function(input)
            if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
                update(input.Position)
            end
        end)
        scope:Connect(UserInputService.InputEnded, function(input)
            if Util.sameInput(input, dragInput) then
                dragging, dragInput = nil, nil
            end
        end)

        scope:Connect(parts.Hex.FocusLost, function()
            local value = parts.Hex.Text:gsub("%s", ""):gsub("^#", "")
            if value:match("^%x%x%x%x%x%x$") then
                control:Set(Color3.fromHex(value))
            else
                renderPopup(control:Get())
                window:SetStatus("Use a six-digit hex color")
            end
        end)
        scope:Connect(parts.Reset.Activated, function()
            control:Set(info.Value or Color3.new(1, 1, 1))
        end)
        Control.dismissPopupOnOutsideInput(scope, window, parts.Panel, control.Root)

        window.PopupClose = function()
            renderPopup = nil
            scope:Destroy()
            parts.Panel:Destroy()
            window.PopupOwner = nil
        end
    end

    window.Scope:Connect(control.Root.Activated, open)

    function control:Open()
        if window.PopupOwner ~= self then
            open()
        end
        return self
    end

    function control:Close()
        if window.PopupOwner == self then
            window:ClosePopup()
        end
        return self
    end

    Util.protect(control, { "Open", "Close" })
    control.Render(control:Get())
    return control
end

return ColorPicker

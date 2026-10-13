local U = require(script.Parent.Util)
local T = require(script.Parent.Theme)
local Input = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local ColorPicker = {}
function ColorPicker.attach(group, c, info)
    local window, renderPopup = group.Window, nil
    c.Render = function(value)
        c.Root.BackgroundColor3 = value
        c.Root.BackgroundTransparency = c.Enabled and 0 or 0.55
        if not c.Enabled and window.PopupOwner == c then window:ClosePopup() end
        if renderPopup then renderPopup(value) end
    end
    local originalVisible = c.SetVisible
    function c:SetVisible(value)
        if not value and window.PopupOwner == self then window:ClosePopup() end
        return originalVisible(self, value)
    end
    local function open()
        if not c.Enabled or not window.Open or window.Dead then return end
        if window.PopupOwner == c then window:ClosePopup() return end
        window:ClosePopup(); window.PopupOwner = c
        local scope = U.scope()
        local panel = U.frame(window.Screen, { Name = "ColorPicker", Size = UDim2.fromOffset(214, 175), BackgroundColor3 = T.Panel, BorderSizePixel = 1, BorderColor3 = T.Outline, ZIndex = 50 })
        U.label(panel, info.Text or c.Id, { Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 0, 20), ZIndex = 51 })
        local sv = U.button(panel, "", { Name = "SaturationValue", Position = UDim2.fromOffset(6, 26), Size = UDim2.fromOffset(182, 116), BorderSizePixel = 0, ZIndex = 51 })
        local white = U.frame(sv, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 52 })
        U.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, white)
        local black = U.frame(sv, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 53 })
        U.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, black)
        local marker = U.frame(sv, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 1, BorderColor3 = Color3.new(0, 0, 0), ZIndex = 54 })
        local hue = U.button(panel, "", { Name = "Hue", Position = UDim2.fromOffset(194, 26), Size = UDim2.fromOffset(14, 116), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 51 })
        local rainbow = {}
        for index = 0, 6 do rainbow[index + 1] = ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(index / 6, 1, 1)) end
        U.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rainbow) }, hue)
        local hueMarker = U.frame(hue, { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 54 })
        local hex = U.new("TextBox", { Name = "Hex", Position = UDim2.fromOffset(6, 148), Size = UDim2.fromOffset(138, 21), BackgroundColor3 = T.Input, BorderSizePixel = 1, BorderColor3 = T.Outline, Font = T.Font, TextSize = T.TextSize, TextScaled = false, TextColor3 = T.Text, ClearTextOnFocus = false, ZIndex = 51 }, panel)
        local reset = U.button(panel, "Reset", { Position = UDim2.fromOffset(150, 148), Size = UDim2.fromOffset(58, 21), ZIndex = 51 })
        local h, s, v = c:Get():ToHSV()
        local editing = false
        renderPopup = function(value)
            if not editing then
                local nextHue, nextSaturation, nextValue = value:ToHSV()
                if nextSaturation > 0 and nextValue > 0 then h = nextHue end
                s, v = nextSaturation, nextValue
            end
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            marker.Position = UDim2.fromOffset(math.round(s * 182), math.round((1 - v) * 116))
            hueMarker.Position = UDim2.fromOffset(0, math.round(h * 116))
            hex.Text = "#" .. value:ToHex()
        end
        renderPopup(c:Get())
        local function position()
            local screen, origin, size = window.Screen.AbsoluteSize, c.Root.AbsolutePosition, c.Root.AbsoluteSize
            local y = origin.Y + size.Y + 4
            if y + 175 > screen.Y - 8 then y = origin.Y - 179 end
            panel.Position = UDim2.fromOffset(math.clamp(origin.X + size.X - 214, 8, math.max(8, screen.X - 222)), math.clamp(y, 8, math.max(8, screen.Y - 183)))
        end
        position(); scope:Connect(Run.RenderStepped, position)
        local dragging, touch
        local function update(point)
            if not dragging then return end
            local target = dragging == "Hue" and hue or sv
            local a, b = target.AbsolutePosition, target.AbsoluteSize
            if dragging == "Hue" then h = math.clamp((point.Y - a.Y) / math.max(1, b.Y), 0, 1)
            else s = math.clamp((point.X - a.X) / math.max(1, b.X), 0, 1); v = 1 - math.clamp((point.Y - a.Y) / math.max(1, b.Y), 0, 1) end
            editing = true; c:Set(Color3.fromHSV(h, s, v)); editing = false
        end
        local function bind(target, mode)
            scope:Connect(target.InputBegan, function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                dragging, touch = mode, input; update(input.Position)
            end)
        end
        bind(hue, "Hue"); bind(sv, "SV")
        scope:Connect(Input.InputChanged, function(input)
            if dragging and (input == touch or input.UserInputType == Enum.UserInputType.MouseMovement) then update(input.Position) end
        end)
        scope:Connect(Input.InputEnded, function(input) if U.sameInput(input, touch) then dragging, touch = nil, nil end end)
        scope:Connect(hex.FocusLost, function()
            local value = hex.Text:gsub("%s", ""):gsub("^#", "")
            if value:match("^%x%x%x%x%x%x$") then c:Set(Color3.fromHex(value))
            else renderPopup(c:Get()); window:SetStatus("Use a six-digit hex color") end
        end)
        scope:Connect(reset.Activated, function() c:Set(info.Value or Color3.new(1, 1, 1)) end)
        scope:Connect(Input.InputBegan, function(input)
            if input.KeyCode == Enum.KeyCode.Escape then window:ClosePopup() return end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local function inside(gui)
                local a, b, p = gui.AbsolutePosition, gui.AbsoluteSize, input.Position
                return p.X >= a.X and p.X <= a.X + b.X and p.Y >= a.Y and p.Y <= a.Y + b.Y
            end
            if not inside(panel) and not inside(c.Root) then window:ClosePopup() end
        end)
        window.PopupClose = function() renderPopup = nil; scope:Destroy(); panel:Destroy(); window.PopupOwner = nil end
    end
    window.Scope:Connect(c.Root.Activated, open)
    function c:Open() if window.PopupOwner ~= self then open() end return self end
    function c:Close() if window.PopupOwner == self then window:ClosePopup() end return self end
    U.protect(c, { "Open", "Close" })
    c.Render(c:Get())
end
return ColorPicker

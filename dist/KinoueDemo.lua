local Library = (function()
local __factories, __cache, __loading = {}, {}, {}
local __require

__factories["Controls/Button"] = function()
local Control = __require("Controls/Control")
local Keybind = __require("Controls/Keybind")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local TEXT_PADDING = 14
local ROW_GAP = 4

local Button = {}

local function width(text, fixed)
    return fixed or (Util.textWidth(text) + TEXT_PADDING)
end

function Button.add(group, info)
    info = info or {}
    local window = group.Window
    local row = Control.row(group)
    local baseText = info.Text or "Button"
    local button = Util.button(row, baseText, {
        Size = UDim2.fromOffset(width(baseText, info.Width), Theme.RowHeight),
        BorderColor3 = info.Primary and Theme.Color.Accent or Theme.Color.Outline,
    })
    local result = {
        Root = button,
        Row = row,
        Enabled = info.Disabled ~= true,
        DisplayName = baseText,
        Notify = info.Notify,
    }

    local function render()
        local shown = baseText
        if result.Keybind and Keybind.isBound(result.Keybind:Get()) then
            shown = shown .. " [" .. Util.keyName(result.Keybind:Get()) .. "]"
        end
        button.Text = shown
        button.Size = UDim2.fromOffset(width(shown, info.Width), Theme.RowHeight)
    end

    local function activate()
        if result.Enabled then
            window:Dispatch(info.Callback)
            Control.notify(window, result, nil)
        end
    end

    local function paint()
        button.TextColor3 = result.Enabled and Theme.Text or Theme.Muted
        button.TextTransparency = 0
    end

    function result:SetEnabled(value)
        value = value == true
        if self.Enabled == value and self.Rendered then
            return self
        end
        self.Enabled = value
        self.Rendered = true
        paint()
        return self
    end

    function result:SetText(value)
        baseText = tostring(value)
        result.DisplayName = baseText
        render()
    end

    window.Scope:Connect(button.Activated, activate)
    Control.searchable(group, function()
        return baseText
    end, function()
        return row
    end)

    local config = Keybind.options(info.Keybind)
    if config then
        local changed = config.Callback
        config.Pressed = config.Pressed or activate
        config.Callback = function(value)
            render()
            if changed then
                changed(value)
            end
        end
        config.Name = config.Name or baseText
        local keyId = config.Id or window:UniqueId(baseText .. "Key")
        result.Keybind = Keybind.attach(group, row, keyId, config, true)
        render()
    end

    result:SetEnabled(result.Enabled)
    table.insert(window.ThemeHooks, paint)
    return Util.protect(result, { "SetEnabled", "SetText" })
end

function Button.addRow(group, definitions)
    local window = group.Window
    local row = Control.row(group)
    Util.list(row, true, ROW_GAP)
    local buttons = {}
    for _, info in ipairs(definitions) do
        local button = Util.button(row, info.Text, {
            Size = UDim2.fromOffset(width(info.Text, info.Width), Theme.RowHeight),
            BorderColor3 = info.Primary and Theme.Color.Accent or Theme.Color.Outline,
        })
        window.Scope:Connect(button.Activated, function()
            window:Dispatch(info.Callback)
        end)
        table.insert(buttons, button)
    end
    return buttons
end

return Button
end

__factories["Controls/Collapsible"] = function()
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local OPEN_DURATION = 0.18
local CLOSE_DURATION = 0.14

local Collapsible = {}
Collapsible.__index = Collapsible

function Collapsible.new(window, parent, indent)
    indent = indent or 0
    local clip = Util.frame(parent, {
        Name = "Collapsible",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
    })
    local container = Util.frame(clip, {
        Position = UDim2.fromOffset(indent, 0),
        Size = UDim2.new(1, -indent, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(container, false, Theme.ControlGap)

    local self = setmetatable({
        Window = window,
        Clip = clip,
        Container = container,
        Open = false,
        Version = 0,
        Listeners = {},
    }, Collapsible)

    window.Scope:Connect(container:GetPropertyChangedSignal("AbsoluteSize"), function()
        if self.Open then
            window.Scope:Tween(clip, 0, { Size = self:OpenSize() }, true)
        end
    end)

    return self
end

function Collapsible:OpenSize()
    return UDim2.new(1, 0, 0, self.Container.AbsoluteSize.Y)
end

function Collapsible:OnChanged(listener)
    table.insert(self.Listeners, listener)
end

function Collapsible:SetOpen(open, instant)
    open = open == true
    if self.Open == open then
        return self
    end
    self.Open = open
    self.Version += 1

    local window = self.Window
    local version = self.Version
    local reduced = instant or window.ReducedMotion
    if open then
        self.Clip.Visible = true
        window.Scope:Tween(self.Clip, OPEN_DURATION, { Size = self:OpenSize() }, reduced)
    else
        window.Scope:Tween(self.Clip, CLOSE_DURATION, { Size = UDim2.new(1, 0, 0, 0) }, reduced)
        if reduced then
            self.Clip.Visible = false
        else
            task.delay(CLOSE_DURATION, function()
                if not window.Dead and version == self.Version then
                    self.Clip.Visible = false
                end
            end)
        end
    end

    for _, listener in ipairs(self.Listeners) do
        listener(open, reduced)
    end
    return self
end

function Collapsible:Toggle()
    return self:SetOpen(not self.Open)
end

return Collapsible
end

__factories["Controls/ColorPicker"] = function()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Control = __require("Controls/Control")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

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
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
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
    end, info.Callback, info)

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
end

__factories["Controls/Control"] = function()
local UserInputService = game:GetService("UserInputService")

local Model = __require("internal/Model")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local Control = {}

function Control.row(group, height)
    return Util.frame(group.Container, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or Theme.RowHeight),
    })
end

local function describe(control, value)
    local notify = control.Notify
    if type(notify) == "function" then
        return notify(value)
    end
    if type(notify) == "string" then
        return notify
    end
    local name = control.DisplayName
    if type(value) == "boolean" then
        return name .. (value and " enabled" or " disabled")
    end
    if typeof(value) == "EnumItem" then
        if value == Enum.KeyCode.Unknown then
            return name .. " unbound"
        end
        return name .. " bound to " .. value.Name
    end
    if typeof(value) == "Color3" then
        return name .. " set to #" .. value:ToHex()
    end
    if type(value) == "number" then
        return name .. ": " .. string.format("%g", value)
    end
    if value == nil then
        return name
    end
    return name .. ": " .. tostring(value)
end

function Control.notify(window, control, value)
    if not control.Notify or window.SuppressNotify then
        return
    end
    local ok, message = pcall(describe, control, value)
    if not ok then
        Util.warn("Notification failed: " .. tostring(message))
    elseif message then
        window:Notify({ Text = message })
    end
end

function Control.searchable(group, name, target)
    group.Window:AddSearchEntry({
        Kind = "Setting",
        Name = name,
        Group = group,
        Target = target,
    })
end

function Control.new(group, id, initial, normalize, callback, info)
    info = info or {}
    local window = group.Window
    local control

    local function wrap(fn)
        return function(value)
            window:Dispatch(fn, value)
            window:ConfigChanged()
            Control.notify(window, control, value)
        end
    end

    control = Model.control(initial, normalize, wrap(callback))
    control.Enabled = true
    control.DisplayName = info.Name or info.Text or id
    control.Notify = info.Notify

    function control:SetCallback(fn)
        self.Callback = wrap(fn)
        return self
    end

    function control:SetEnabled(value)
        value = value == true
        if self.Enabled == value then
            return self
        end
        self.Enabled = value
        if not value and window.Capturing == self then
            window.Capturing = nil
        end
        if self.Root then
            self.Root.Active = self.Enabled
        end
        if self.Render then
            self.Render(self:Get())
        end
        return self
    end

    function control:SetVisible(value)
        self.Row.Visible = value == true
        return self
    end

    Util.protect(control, { "Set", "SetEnabled", "SetVisible" })
    window:Register(id, control)
    if not info.Inline and info.Searchable ~= false then
        Control.searchable(group, control.DisplayName, function()
            return control.Row
        end)
    end
    return control
end

function Control.closePopupWhenHidden(control, window)
    local setVisible = control.SetVisible
    function control:SetVisible(value)
        if not value and window.PopupOwner == self then
            window:ClosePopup()
        end
        return setVisible(self, value)
    end
end

function Control.dismissPopupOnOutsideInput(scope, window, popup, anchor)
    scope:Connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            window:ClosePopup()
            return
        end
        if not Util.isPointer(input) then
            return
        end
        if not Util.contains(popup, input.Position) and not Util.contains(anchor, input.Position) then
            window:ClosePopup()
        end
    end)
end

return Control
end

__factories["Controls/Disclosure"] = function()
local Collapsible = __require("Controls/Collapsible")
local Icons = __require("internal/Icons")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local ICON_SIZE = 10
local TEXT_INSET = 16
local CONTENT_INDENT = 8

local Disclosure = {}

function Disclosure.add(group, title, newGroup, open)
    local window = group.Window
    local frame = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(frame, false, 0)

    local button = Util.button(frame, title, {
        Name = "Header",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    Util.new("UIPadding", { PaddingLeft = UDim.new(0, TEXT_INSET) }, button)
    local icon = Icons.chevron(button, ICON_SIZE, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, -TEXT_INSET / 2, 0.5, 0),
        Color = Theme.Color.Muted,
    })

    local section = Collapsible.new(window, frame, CONTENT_INDENT)
    local child = newGroup(window, section.Container)
    child.Header = button
    child.Icon = icon
    child.Section = section
    child.Parent = group
    child.Label = title
    child.Reveal = function()
        section:SetOpen(true, true)
    end
    window:AddSearchEntry({
        Kind = "Section",
        Name = title,
        Group = group,
        Target = function()
            return button
        end,
    })

    local function paint()
        icon:SetColor(section.Open and Theme.Text or Theme.Muted)
        button.TextColor3 = section.Open and Theme.Text or Theme.Muted
    end

    section:OnChanged(function(isOpen, reduced)
        icon:SetRotation(window, isOpen and 90 or 0, reduced)
        paint()
    end)
    table.insert(window.ThemeHooks, paint)

    function child:SetOpen(value)
        section:SetOpen(value)
        return self
    end

    function child:IsOpen()
        return section.Open
    end

    Util.protect(child, { "SetOpen" })

    window.Scope:Connect(button.Activated, function()
        section:Toggle()
    end)

    if open then
        section:SetOpen(true, true)
    end
    return child
end

return Disclosure
end

__factories["Controls/Dropdown"] = function()
local RunService = game:GetService("RunService")

local Control = __require("Controls/Control")
local Model = __require("internal/Model")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local OPTION_HEIGHT = 23
local MAX_MENU_HEIGHT = 184
local SCREEN_MARGIN = 8

local Dropdown = {}

local function openMenu(window, control, options)
    local scope = Util.scope()
    local menu = Util.new("ScrollingFrame", {
        Name = "Dropdown",
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ZIndex = 50,
        CanvasSize = UDim2.fromOffset(0, #options * OPTION_HEIGHT),
        ScrollBarThickness = 3,
    }, window.Screen)
    Util.list(menu, false, 0)

    local function position()
        local screen = window.Screen.AbsoluteSize
        local size = control.Root.AbsoluteSize
        local origin = control.Root.AbsolutePosition
        local height = math.min(#options * OPTION_HEIGHT, MAX_MENU_HEIGHT, screen.Y - 2 * SCREEN_MARGIN)
        local y = origin.Y + size.Y
        if y + height > screen.Y - SCREEN_MARGIN then
            y = math.max(SCREEN_MARGIN, origin.Y - height)
        end
        local x = math.clamp(origin.X, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.X - size.X - SCREEN_MARGIN))
        menu.Position = UDim2.fromOffset(x, y)
        menu.Size = UDim2.fromOffset(size.X, height)
    end
    position()

    for _, option in ipairs(options) do
        local entry = Util.button(menu, "", {
            Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
            BorderSizePixel = 0,
            BackgroundColor3 = option.Value == control:Get() and Theme.Selected or Theme.Panel,
            ZIndex = 51,
        })
        Util.label(entry, option.Label, {
            Position = UDim2.fromOffset(5, 0),
            Size = UDim2.new(1, -60, 1, 0),
            ZIndex = 52,
        })
        if option.Meta ~= nil then
            Util.label(entry, tostring(option.Meta), {
                Position = UDim2.fromOffset(Util.textWidth(option.Label) + 12, 0),
                Size = UDim2.new(0, 48, 1, 0),
                TextColor3 = Theme.Color.Muted,
                TextSize = Theme.SmallSize,
                ZIndex = 52,
            })
        end
        scope:Connect(entry.Activated, function()
            control:Set(option.Value)
            window:ClosePopup()
        end)
    end

    scope:Connect(RunService.RenderStepped, position)
    Control.dismissPopupOnOutsideInput(scope, window, menu, control.Root)

    window.PopupClose = function()
        scope:Destroy()
        menu:Destroy()
        window.PopupOwner = nil
    end
end

function Dropdown.add(group, id, info)
    info = info or {}
    local window = group.Window
    local options = Model.options(info.Options or {})

    local function find(value)
        for _, option in ipairs(options) do
            if option.Value == value then
                return option
            end
        end
        return nil
    end

    local initial = info.Value
    if initial == nil and options[1] then
        initial = options[1].Value
    end

    local control = Control.new(group, id, initial, function(value)
        assert(value == nil or find(value), "Unknown dropdown value: " .. tostring(value))
        return value
    end, info.Callback, info)
    control.Window = window

    control.Row = Control.row(group, 41)
    Util.label(control.Row, info.Text or id, { Size = UDim2.new(1, 0, 0, 18) })
    control.Root = Util.button(control.Row, "", {
        Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, Theme.RowHeight),
    })
    local name = Util.label(control.Root, "", {
        Position = UDim2.fromOffset(5, 0),
        Size = UDim2.new(1, -20, 1, 0),
    })
    local meta = Util.label(control.Root, "", {
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        Size = UDim2.new(0, 50, 1, 0),
    })
    Util.label(control.Root, "▾", {
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.new(0, 12, 1, 0),
        TextColor3 = Theme.Color.Muted,
    })

    control.Render = function(value)
        local option = find(value)
        name.Text = option and option.Label or "None"
        meta.Text = option and option.Meta and tostring(option.Meta) or ""
        meta.Position = UDim2.fromOffset(Util.textWidth(name.Text) + 12, 0)
        name.TextTransparency = control.Enabled and 0 or Theme.DisabledTransparency
        if not control.Enabled and window.PopupOwner == control then
            window:ClosePopup()
        end
    end

    Control.closePopupWhenHidden(control, window)

    function control:UpdateOptions(values)
        window:ClosePopup()
        options = Model.options(values)
        local current = self:Get()
        local selected = find(current) and current or (options[1] and options[1].Value)
        local unchanged = selected == current
        self:SetSilent(selected)
        if unchanged then
            self.Render(selected)
        end
    end
    Util.protect(control, { "UpdateOptions" })

    local function toggle()
        if not control.Enabled or #options == 0 then
            return
        end
        if window.PopupOwner == control then
            window:ClosePopup()
            return
        end
        window:ClosePopup()
        window.PopupOwner = control
        openMenu(window, control, options)
    end
    window.Scope:Connect(control.Root.Activated, toggle)

    control.Render(control:Get())
    return control
end

return Dropdown
end

__factories["Controls/Keybind"] = function()
local Control = __require("Controls/Control")
local Icons = __require("internal/Icons")
local Theme = __require("internal/Theme")
local Tooltip = __require("internal/Tooltip")
local Util = __require("internal/Util")

local LABEL_INSET = 110
local KEY_HEIGHT = 20
local KEY_PADDING = 4
local CLEAR_SIZE = 14
local WARNING_SIZE = 12
local ICON_GAP = 2

local Keybind = {}

local function normalize(value)
    assert(typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode, "Keybind requires Enum.KeyCode")
    return value
end

function Keybind.isBound(key)
    return key ~= nil and key ~= Enum.KeyCode.Unknown
end

function Keybind.options(keybind)
    if keybind == true then
        return {}
    end
    if type(keybind) == "table" then
        return table.clone(keybind)
    end
    return nil
end

local function conflictText(control)
    if #control.Conflicts == 0 then
        return nil
    end
    local names = {}
    for _, other in ipairs(control.Conflicts) do
        table.insert(names, other.DisplayName)
    end
    return "Also bound to: " .. table.concat(names, ", ")
end

function Keybind.attach(group, row, id, info, inline, inset)
    inset = inset or 0
    local clearable = info.Clearable ~= false
    local window = group.Window
    local control = Control.new(group, id, info.Value or Enum.KeyCode.Unknown, normalize, info.Callback, {
        Name = info.Name,
        Text = info.Text,
        Notify = info.Notify,
        Inline = inline,
    })
    control.Pressed = info.Pressed
    control.Released = info.Released
    control.Row = row
    control.Conflicts = {}
    control.Root = Util.button(row, "", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -inset, 0.5, 0),
        Size = UDim2.fromOffset(LABEL_INSET, KEY_HEIGHT),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    control.Clear = Util.button(row, "×", {
        Name = "Unbind",
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.fromOffset(CLEAR_SIZE, CLEAR_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
    })
    control.Warning = Icons.warning(row, WARNING_SIZE, {
        Name = "Conflict",
        AnchorPoint = Vector2.new(1, 0.5),
    })
    control.Warning.Root.Visible = false

    local hidden = false
    local keyWidth = LABEL_INSET

    local function layout()
        local offset = inset + keyWidth + ICON_GAP
        if control.Clear.Visible then
            control.Clear.Position = UDim2.new(1, -offset, 0.5, 0)
            offset += CLEAR_SIZE + ICON_GAP
        end
        control.Warning.Root.Position = UDim2.new(1, -offset, 0.5, 0)
    end

    local function show(text)
        keyWidth = Util.textWidth(text, Theme.SmallSize) + KEY_PADDING
        control.Root.Text = text
        control.Root.Size = UDim2.fromOffset(keyWidth, KEY_HEIGHT)
        layout()
    end

    control.PaintConflict = function()
        local conflicted = #control.Conflicts > 0
        control.Root.TextColor3 = conflicted and Theme.Danger or Theme.Muted
        control.Warning:SetColor(Theme.Danger)
        control.Warning.Root.Visible = conflicted and not hidden
        layout()
    end

    control.Render = function(value)
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        control.Root.TextTransparency = transparency
        control.Clear.TextTransparency = transparency
        control.Root.Visible = not hidden
        control.Clear.Visible = clearable and not hidden and Keybind.isBound(value)
        show("[" .. Util.keyName(value) .. "]")
        window:UpdateKeyConflicts()
    end

    function control:Unbind()
        local wasCapturing = window.Capturing == self
        if wasCapturing then
            window.Capturing = nil
        end
        if self.Down then
            self.Down = false
            if self.Released then
                window:Dispatch(self.Released)
            end
        end
        self:Set(Enum.KeyCode.Unknown)
        if wasCapturing then
            self.Render(self:Get())
        end
        return self
    end

    window.Scope:Connect(control.Root.Activated, function()
        if not control.Enabled then
            return
        end
        if window.Capturing then
            window.Capturing.Render(window.Capturing:Get())
        end
        window.Capturing = control
        show("[Press a key]")
    end)

    window.Scope:Connect(control.Clear.Activated, function()
        if control.Enabled and clearable then
            control:Unbind()
        end
    end)

    local function tooltip()
        return conflictText(control)
    end
    Tooltip.bind(window, control.Root, tooltip)
    Tooltip.bind(window, control.Warning.Root, tooltip)

    if inline then
        function control:SetVisible(value)
            hidden = value ~= true
            self.Render(self:Get())
            return self
        end
        Util.protect(control, { "SetVisible" })
    end
    Util.protect(control, { "Unbind" })

    table.insert(window.Keybinds, control)
    control.Render(control:Get())
    return control
end

function Keybind.add(group, id, info)
    info = info or {}
    local row = Control.row(group)
    Util.label(row, info.Text or id, { Size = UDim2.new(1, -LABEL_INSET, 1, 0) })
    return Keybind.attach(group, row, id, info)
end

return Keybind
end

__factories["Controls/Label"] = function()
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local Label = {}

function Label.add(group, text, small)
    local label = Util.label(group.Container, text, {
        TextSize = small and Theme.SmallSize or Theme.TextSize,
        TextColor3 = small and Theme.Color.Muted or Theme.Color.Text,
    })
    local result = { Root = label }

    function result:SetText(value)
        label.Text = tostring(value)
    end

    function result:SetVisible(value)
        label.Visible = value
    end

    return Util.protect(result, { "SetText", "SetVisible" })
end

return Label
end

__factories["Controls/Preview"] = function()
local Label = __require("Controls/Label")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local GRID_SPACING = 10
local GRID_INSET = 8
local CONTENT_INSET = 24
local PIXEL_FILL = 0.84

local Preview = {}

local function samePoints(a, b)
    if #a ~= #b then
        return false
    end
    for index, point in ipairs(a) do
        if point.X ~= b[index].X or point.Y ~= b[index].Y then
            return false
        end
    end
    return true
end

local function bounds(points)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, point in ipairs(points) do
        minX = math.min(minX, point.X)
        minY = math.min(minY, point.Y)
        maxX = math.max(maxX, point.X)
        maxY = math.max(maxY, point.Y)
    end
    return minX, minY, maxX, maxY
end

function Preview.add(group, info)
    info = info or {}
    local window = group.Window
    local preview = { Points = {}, Parts = {} }

    preview.Root = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, info.Height or 148),
        BorderColor3 = Theme.Color.Outline,
        BorderSizePixel = 1,
        ClipsDescendants = true,
    })
    local grid = Util.frame(preview.Root, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 1,
    })
    local drawing = Util.frame(preview.Root, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 2,
    })
    local count = Label.add(group, "0 / 0")
    local track = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Theme.Color.Hover,
    })
    local fill = Util.frame(track, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })

    local dots, columns, rows = {}, -1, -1

    local function layoutGrid(size)
        local nextColumns = math.max(0, math.floor((size.X - 2 * GRID_INSET) / GRID_SPACING) + 1)
        local nextRows = math.max(0, math.floor((size.Y - 2 * GRID_INSET) / GRID_SPACING) + 1)
        if nextColumns == columns and nextRows == rows then
            return
        end
        for key, dot in pairs(dots) do
            if dot.Position.X.Offset > size.X - GRID_INSET or dot.Position.Y.Offset > size.Y - GRID_INSET then
                dot:Destroy()
                dots[key] = nil
            end
        end
        for y = GRID_INSET, size.Y - GRID_INSET, GRID_SPACING do
            for x = GRID_INSET, size.X - GRID_INSET, GRID_SPACING do
                local key = x .. ":" .. y
                if not dots[key] then
                    dots[key] = Util.frame(grid, {
                        Position = UDim2.fromOffset(x, y),
                        Size = UDim2.fromOffset(1, 1),
                        BackgroundColor3 = Theme.Color.Outline,
                        BackgroundTransparency = 0.35,
                    })
                end
            end
        end
        columns, rows = nextColumns, nextRows
    end

    local function layoutPoints(size)
        local points = preview.Points
        if #points == 0 then
            return
        end
        local minX, minY, maxX, maxY = bounds(points)
        local spanX, spanY = maxX - minX + 1, maxY - minY + 1
        local cell = math.max(1, math.min((size.X - CONTENT_INSET) / spanX, (size.Y - CONTENT_INSET) / spanY))
        local offsetX, offsetY = (size.X - spanX * cell) / 2, (size.Y - spanY * cell) / 2
        for index, point in ipairs(points) do
            local part = preview.Parts[index]
            part.Position = UDim2.fromOffset(offsetX + (point.X - minX) * cell, offsetY + (point.Y - minY) * cell)
            part.Size = UDim2.fromOffset(cell * PIXEL_FILL, cell * PIXEL_FILL)
        end
    end

    local function layout()
        local size = preview.Root.AbsoluteSize
        layoutGrid(size)
        layoutPoints(size)
    end

    function preview:SetPoints(points)
        if samePoints(points, self.Points) then
            return self
        end
        for index = #self.Parts, #points + 1, -1 do
            self.Parts[index]:Destroy()
            self.Parts[index] = nil
        end
        for index = #self.Parts + 1, #points do
            self.Parts[index] = Util.frame(drawing, { BackgroundColor3 = Theme.Color.Accent })
            Util.new("UICorner", { CornerRadius = UDim.new(0, 1) }, self.Parts[index])
        end
        self.Points = table.clone(points)
        layout()
        self:SetCount(0, #points)
        return self
    end

    function preview:SetCount(current, total)
        if self.Current == current and self.Total == total then
            return
        end
        self.Current, self.Total = current, total
        count:SetText(string.format("%d / %d", current, total))
        fill.Size = UDim2.fromScale(total > 0 and math.clamp(current / total, 0, 1) or 0, 1)
    end

    function preview:Recoil()
        if window.ReducedMotion then
            return
        end
        window.Scope:Tween(drawing, 0.06, { Position = UDim2.fromOffset(-3, -2) }, false)
        task.delay(0.06, function()
            if not window.Dead then
                window.Scope:Tween(drawing, 0.19, { Position = UDim2.fromOffset(0, 0) }, false)
            end
        end)
    end

    window.Scope:Connect(preview.Root:GetPropertyChangedSignal("AbsoluteSize"), layout)
    preview:SetPoints(info.Points or {})
    return Util.protect(preview, { "SetPoints", "SetCount", "Recoil" })
end

return Preview
end

__factories["Controls/Slider"] = function()
local UserInputService = game:GetService("UserInputService")

local Control = __require("Controls/Control")
local Model = __require("internal/Model")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local Slider = {}

function Slider.add(group, id, info)
    info = info or {}
    local window = group.Window
    local minimum, maximum, step = info.Min or 0, info.Max or 100, info.Step or 1
    assert(maximum > minimum and step > 0, "Slider requires Max > Min and Step > 0")

    local control = Control.new(group, id, info.Value or minimum, function(value)
        return Model.number(value, minimum, maximum, step)
    end, info.Callback, info)

    control.Row = Control.row(group, 35)
    Util.label(control.Row, info.Text or id, { Size = UDim2.new(0.65, 0, 0, 18) })
    local output = Util.label(control.Row, "", {
        Position = UDim2.new(0.65, 0, 0, 0),
        Size = UDim2.new(0.35, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = Util.button(control.Row, "", {
        Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, 16),
    })
    control.Root = track
    local fill = Util.frame(track, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })
    local thumb = Util.frame(track, {
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = Theme.Color.Text,
    })

    local suffix = info.Suffix and " " .. info.Suffix or ""
    control.Render = function(value)
        local fraction = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(fraction, 1)
        thumb.Position = UDim2.fromScale(fraction, 0)
        output.Text = string.format(info.Format or "%g", value) .. suffix
        output.TextTransparency = control.Enabled and 0 or Theme.DisabledTransparency
    end

    local scope = window.Scope
    local dragging, moved, ended

    local function update(x)
        if not control.Enabled then
            return
        end
        local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        control:Set(minimum + fraction * (maximum - minimum))
    end

    local function stop()
        dragging = nil
        scope:Release(moved)
        scope:Release(ended)
        moved, ended = nil, nil
    end

    scope:Connect(track.InputBegan, function(input)
        if not control.Enabled or not Util.isPointer(input) then
            return
        end
        dragging = input
        if not moved then
            moved = scope:Connect(UserInputService.InputChanged, function(changed)
                if changed.UserInputType == Enum.UserInputType.MouseMovement or changed == dragging then
                    update(changed.Position.X)
                end
            end)
            ended = scope:Connect(UserInputService.InputEnded, function(released)
                if Util.sameInput(released, dragging) then
                    stop()
                end
            end)
        end
        update(input.Position.X)
    end)

    control.Render(control:Get())
    return control
end

return Slider
end

__factories["Controls/Textbox"] = function()
local Control = __require("Controls/Control")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local Textbox = {}

function Textbox.add(group, id, info)
    info = info or {}
    local maxLength = info.MaxLength or 256
    local control = Control.new(group, id, info.Value or "", function(value)
        return tostring(value or ""):sub(1, maxLength)
    end, info.Callback, info)

    control.Row = Control.row(group, 41)
    Util.label(control.Row, info.Text or id, { Size = UDim2.new(1, 0, 0, 18) })
    control.Root = Util.textbox(control.Row, {
        Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, Theme.RowHeight),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = control:Get(),
        PlaceholderText = info.Placeholder or "",
    })
    Util.new("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 5),
    }, control.Root)

    control.Render = function(value)
        control.Root.Text = value
        control.Root.TextEditable = control.Enabled
    end

    group.Window.Scope:Connect(control.Root.FocusLost, function()
        if control.Enabled then
            control:Set(control.Root.Text)
        end
    end)

    return control
end

return Textbox
end

__factories["Controls/Toggle"] = function()
local Collapsible = __require("Controls/Collapsible")
local Control = __require("Controls/Control")
local Keybind = __require("Controls/Keybind")
local Icons = __require("internal/Icons")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local KEYBIND_INSET = 95
local COG_SIZE = 18
local COG_ICON_SIZE = 14
local COG_GAP = 4
local SETTINGS_INDENT = 20
local GUIDE_OFFSET = 6

local Toggle = {}

local function buildRow(group, subToggle)
    if not subToggle then
        local row = Control.row(group)
        return row, row
    end
    local holder = Util.frame(group.Container, {
        Name = "SubToggle",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(holder, false, Theme.ControlGap)
    local row = Util.frame(holder, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, Theme.RowHeight),
    })
    return holder, row
end

local function attachSettings(group, control, window, row, newGroup)
    local cog = Util.button(row, "", {
        Name = "SettingsButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(COG_SIZE, COG_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local icon = Icons.gear(cog, COG_ICON_SIZE)
    local panel = Collapsible.new(window, control.Row, SETTINGS_INDENT)
    Util.frame(panel.Clip, {
        Name = "Guide",
        Position = UDim2.fromOffset(GUIDE_OFFSET, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = Theme.Color.Outline,
    })

    control.SettingsButton = cog
    control.SettingsIcon = icon
    control.SettingsPanel = panel
    control.Settings = newGroup(window, panel.Container)
    control.Settings.Parent = group
    control.Settings.Label = control.DisplayName
    control.Settings.Reveal = function()
        panel:SetOpen(true, true)
    end

    local function paint()
        icon:SetColor(panel.Open and Theme.Accent or Theme.Muted)
    end
    panel:OnChanged(function(open, reduced)
        icon:SetRotation(window, open and 90 or 0, reduced)
        paint()
    end)
    table.insert(window.ThemeHooks, paint)

    window.Scope:Connect(cog.Activated, function()
        panel:Toggle()
    end)

    function control:SetSettingsOpen(open)
        panel:SetOpen(open)
        return self
    end

    function control:IsSettingsOpen()
        return panel.Open
    end

    Util.protect(control, { "SetSettingsOpen" })
    return COG_SIZE + COG_GAP
end

function Toggle.add(group, id, info, newGroup)
    info = info or {}
    local window = group.Window
    local control = Control.new(group, id, info.Value == true, function(value)
        return value == true
    end, info.Callback, info)

    local keybind = info.Keybind
    if keybind == nil and window.BindableToggles then
        keybind = true
    end
    keybind = Keybind.options(keybind)

    local holder, row = buildRow(group, info.SubToggle == true)
    control.Row = holder

    local rightInset = 0
    if info.SubToggle == true then
        rightInset = attachSettings(group, control, window, row, newGroup)
    end

    local hit = Util.button(row, "", {
        Size = UDim2.new(1, -(rightInset + (keybind and KEYBIND_INSET or 0)), 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    control.Root = hit

    local box = Util.frame(hit, {
        Position = UDim2.new(0, 0, 0.5, -6),
        Size = UDim2.fromOffset(13, 13),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Outline,
    })
    local name = Util.label(hit, info.Text or id, {
        Position = UDim2.fromOffset(20, 0),
        Size = UDim2.new(1, -20, 1, 0),
    })

    control.Render = function(value)
        window.Scope:Tween(box, 0.16, {
            BackgroundColor3 = value and Theme.Accent or Theme.Panel,
            BorderColor3 = value and Theme.Accent or Theme.Outline,
        }, window.ReducedMotion)
        name.TextTransparency = control.Enabled and 0 or Theme.DisabledTransparency
    end

    window.Scope:Connect(hit.Activated, function()
        if control.Enabled then
            control:Set(not control:Get())
        end
    end)

    if keybind then
        keybind.Pressed = keybind.Pressed
            or function()
                if control.Enabled then
                    control:Set(not control:Get())
                end
            end
        keybind.Name = keybind.Name or control.DisplayName
        local keyId = keybind.Id or window:UniqueId(id .. "Key")
        control.Keybind = Keybind.attach(group, row, keyId, keybind, true, rightInset)
    end

    control.Render(control:Get())
    return control
end

return Toggle
end

__factories["Controls"] = function()
local Util = __require("internal/Util")
local Button = __require("Controls/Button")
local ColorPicker = __require("Controls/ColorPicker")
local Disclosure = __require("Controls/Disclosure")
local Dropdown = __require("Controls/Dropdown")
local Keybind = __require("Controls/Keybind")
local Label = __require("Controls/Label")
local Preview = __require("Controls/Preview")
local Slider = __require("Controls/Slider")
local Textbox = __require("Controls/Textbox")
local Toggle = __require("Controls/Toggle")

local Group = {}
Group.__index = Group

function Group.new(window, container, page, frame)
    return setmetatable({
        Window = window,
        Page = page,
        Frame = frame,
        Container = container,
    }, Group)
end

function Group:AddLabel(text, small)
    return Label.add(self, text, small)
end

function Group:AddToggle(id, info)
    return Toggle.add(self, id, info, Group.new)
end

function Group:AddKeybind(id, info)
    return Keybind.add(self, id, info)
end

function Group:AddSlider(id, info)
    return Slider.add(self, id, info)
end

function Group:AddTextbox(id, info)
    return Textbox.add(self, id, info)
end

function Group:AddDropdown(id, info)
    return Dropdown.add(self, id, info)
end

function Group:AddButton(info)
    return Button.add(self, info)
end

function Group:AddButtons(definitions)
    return Button.addRow(self, definitions)
end

function Group:AddDisclosure(title, open)
    return Disclosure.add(self, title, Group.new, open)
end

function Group:AddColorPicker(id, info)
    return ColorPicker.add(self, id, info)
end

function Group:AddPreview(info)
    return Preview.add(self, info)
end

Util.protect(Group, {
    "AddLabel",
    "AddToggle",
    "AddKeybind",
    "AddSlider",
    "AddTextbox",
    "AddDropdown",
    "AddButton",
    "AddButtons",
    "AddDisclosure",
    "AddColorPicker",
    "AddPreview",
})

return Group
end

__factories["KeySystem"] = function()
local HttpService = game:GetService("HttpService")
local Util = __require("internal/Util")

local KeySystem = {}
KeySystem.__index = KeySystem

local MESSAGES = {
    invalid_credentials = "Invalid key or saved login.",
    hwid_mismatch = "Key is bound to another device.",
    license_expired = "Key expired.",
    license_revoked = "Key revoked.",
    session_expired = "Enter your key again.",
    rate_limited = "Too many attempts. Try again shortly.",
    script_unavailable = "Script unavailable.",
    invalid_request = "Invalid request.",
    unsupported_executor = "Unsupported executor: HWID unavailable.",
    unsupported_http = "Unsupported executor: HTTP unavailable.",
    unsupported_loader = "Unsupported executor: loadstring unavailable.",
    connection_failed = "Could not connect to the key server.",
    timeout = "Connection timed out.",
    invalid_response = "Invalid key server response.",
    script_failed = "Script failed to load.",
}

local function fingerprint()
    local providers = { gethwid, get_hwid, type(syn) == "table" and syn.get_hwid or nil }
    for _, provider in pairs(providers) do
        if type(provider) == "function" then
            local ok, value = pcall(provider)
            if ok and type(value) == "string" and #value > 0 and #value <= 512 and value:find("%S") then
                return value
            end
        end
    end
end

local function endpoint(value, localhost)
    assert(type(value) == "string" and not value:find("[?#@%s]"), "Endpoint must be an HTTPS service URL")
    local allowed = value:match("^https://[^/]+")
        or localhost and (value:match("^http://127%.0%.0%.1:%d+") or value:match("^http://localhost:%d+"))
    assert(allowed, "Endpoint requires HTTPS; AllowLocalhost only permits a loopback development service")
    if not value:match("^https://") then
        local host = value:match("^http://([^/]+)")
        assert(
            host and (host:match("^127%.0%.0%.1:%d+$") or host:match("^localhost:%d+$")),
            "Only loopback HTTP is allowed"
        )
    end
    return value:gsub("/+$", "")
end

function KeySystem:_status(text)
    if not self.Dead and not self.Window.Dead then
        self.Window:SetStatus(text)
    end
end

function KeySystem:_busy(value)
    self.Busy = value
    if not self.Window.Dead then
        self.Key:SetEnabled(not value and self.Supported)
        self.RedeemButton:SetEnabled(not value and self.Supported)
        self.Remember:SetEnabled(not value and self.CanRemember)
    end
end

function KeySystem:_fail(code)
    self.State, self.Error = "error", code
    self.Job = nil
    self:_busy(false)
    self:_status(MESSAGES[code] or "Key verification failed.")
    if self.Options.OnError then
        self.Window:Dispatch(self.Options.OnError, code, MESSAGES[code])
    end
end

function KeySystem:_clearCache()
    self.Token = nil
    self.Remembered = false
    if type(delfile) == "function" then
        pcall(delfile, self.CachePath)
    elseif type(writefile) == "function" then
        pcall(writefile, self.CachePath, "")
    end
end

function KeySystem:_save(response)
    if not self.Remember:Get() or not self.CanRemember then
        return
    end
    local saved = pcall(function()
        local folder = ""
        for segment in self.CachePath:gmatch("([^/]+)/") do
            folder = folder == "" and segment or folder .. "/" .. segment
            if type(isfolder) ~= "function" or not isfolder(folder) then
                pcall(makefolder, folder)
            end
        end
        writefile(
            self.CachePath,
            HttpService:JSONEncode({
                Version = 1,
                Application = self.Application,
                Endpoint = self.Endpoint,
                Token = response.token,
                ExpiresAt = response.expires_at,
            })
        )
    end)
    self.Remembered = saved
end

function KeySystem:_api(route, credentials, raw)
    local body = { application = self.Application, hwid = self.Hwid }
    for key, value in pairs(credentials) do
        body[key] = value
    end
    local ok, response = pcall(self.Request, {
        Url = self.Endpoint .. "/v1/" .. route,
        Method = "POST",
        Timeout = self.Timeout,
        Headers = { ["Content-Type"] = "application/json", Accept = raw and "text/plain" or "application/json" },
        Body = HttpService:JSONEncode(body),
    })
    if not ok or type(response) ~= "table" or type(response.StatusCode) ~= "number" then
        return nil, "connection_failed"
    end
    if response.StatusCode >= 200 and response.StatusCode < 300 and raw then
        if type(response.Body) ~= "string" or #response.Body < 1 or #response.Body > 2097152 then
            return nil, "invalid_response"
        end
        return response.Body
    end
    local decoded, value = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decoded or type(value) ~= "table" then
        return nil, "invalid_response"
    end
    if response.StatusCode < 200 or response.StatusCode >= 300 then
        return nil, MESSAGES[value.error] and value.error or "connection_failed"
    end
    if
        type(value.token) ~= "string"
        or #value.token < 32
        or #value.token > 256
        or type(value.expires_at) ~= "number"
        or value.expires_at ~= value.expires_at
        or value.expires_at == math.huge
        or value.expires_at <= os.time()
    then
        return nil, "invalid_response"
    end
    return value
end

function KeySystem:_run(route, credentials)
    if self.Dead or self.Loaded or self.Busy or not self.Supported then
        return false
    end
    self.Generation += 1
    local generation = self.Generation
    self.State, self.Error = "checking", nil
    self:_busy(true)
    self:_status("Checking key...")
    self.Job = task.defer(function()
        if self.Dead or generation ~= self.Generation then
            return
        end
        local response, code = self:_api(route, credentials)
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not response then
            if
                code == "invalid_credentials"
                or code == "hwid_mismatch"
                or code == "license_expired"
                or code == "license_revoked"
                or code == "session_expired"
            then
                self:_clearCache()
            end
            self:_fail(code)
            return
        end
        self.Token = response.token
        self:_save(response)
        self.Key:SetSilent("")
        self:_status("Loading...")
        local source, downloadError = self:_api("script", { token = self.Token }, true)
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not source then
            self:_fail(downloadError)
            return
        end
        local loader = loadstring(source)
        if type(loader) ~= "function" then
            self:_fail("script_failed")
            return
        end
        self.State = "loading"
        self.Window:SetVisible(false)
        local loaded, result = pcall(loader)
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not loaded then
            self.Window:SetVisible(true)
            self:_fail("script_failed")
            return
        end
        self.Loaded, self.Result, self.State, self.Job, self.Busy = true, result, "loaded", nil, false
        self.Completing = true
        self.Window:Destroy()
        if type(result) == "table" then
            local window = result.Window or result
            if type(window) == "table" and type(window.SetLogoutHandler) == "function" then
                self:AttachWindow(window)
            end
        end
        if self.Options.OnLoaded then
            pcall(self.Options.OnLoaded, result)
        end
    end)
    task.delay(self.Timeout, function()
        if not self.Dead and self.Busy and generation == self.Generation and self.State ~= "loading" then
            self.Generation += 1
            if self.Job and type(task.cancel) == "function" then
                pcall(task.cancel, self.Job)
            end
            self.Job = nil
            self:_fail("timeout")
        end
    end)
    return true
end

function KeySystem:Redeem(key)
    if self.Dead then
        return false
    end
    key = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
    if #key < 16 or #key > 256 then
        self:_status("Enter a valid key.")
        return false
    end
    return self:_run("redeem", { key = key })
end

function KeySystem:Forget()
    if self.Dead or self.Loaded or self.Busy then
        return
    end
    self:_clearCache()
    self.Key:SetSilent("")
    self:_status("Enter key.")
end

function KeySystem:AttachWindow(window)
    assert(
        type(window) == "table" and type(window.SetLogoutHandler) == "function",
        "AttachWindow requires a Kinoue window"
    )
    if self.Dead then
        return self
    end
    if self.SessionWindow and not self.SessionWindow.Dead then
        self.SessionWindow:SetLogoutHandler(nil)
    end
    self.SessionWindow = window
    window:SetLogoutHandler(function()
        self:Logout()
    end)
    return self
end

function KeySystem:Logout()
    if self.Dead or not self.Loaded or self.Busy then
        return false
    end
    local result = self.Result
    local unload = self.Options.OnUnload
    if not unload and type(result) == "table" and type(result.Destroy) == "function" then
        unload = function()
            result:Destroy()
        end
    end
    if not unload and self.SessionWindow then
        unload = function()
            self.SessionWindow:Destroy()
        end
    end
    if not unload then
        return false
    end
    self.Generation += 1
    self.State, self.Busy = "logging_out", true
    local generation, token = self.Generation, self.Token
    self:_clearCache()
    if token then
        local request = self.Request
        local parameters = {
            Url = self.Endpoint .. "/v1/logout",
            Method = "POST",
            Timeout = self.Timeout,
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ application = self.Application, hwid = self.Hwid, token = token }),
        }
        task.defer(function()
            pcall(request, parameters)
        end)
    end
    self.LogoutJob = task.defer(function()
        if self.Dead or generation ~= self.Generation then
            return
        end
        local ok, message = pcall(unload, result)
        self.LogoutJob = nil
        if self.Dead or generation ~= self.Generation then
            return
        end
        if not ok then
            self.State, self.Busy = "loaded", false
            Util.warn("Logout cleanup failed: " .. tostring(message))
            if self.SessionWindow and not self.SessionWindow.Dead then
                self.SessionWindow:SetStatus("Could not unload script.")
            end
            return
        end
        if self.SessionWindow and not self.SessionWindow.Dead then
            self.SessionWindow:Destroy()
        end
        self.SessionWindow, self.Result, self.Loaded = nil, nil, false
        self.State, self.Error = "ready", nil
        self:_buildWindow()
        self:_busy(false)
        self:_status("Enter key.")
    end)
    return true
end

function KeySystem:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    self.Generation += 1
    if self.Job and type(task.cancel) == "function" and self.Job ~= coroutine.running() then
        pcall(task.cancel, self.Job)
    end
    if self.LogoutJob and type(task.cancel) == "function" and self.LogoutJob ~= coroutine.running() then
        pcall(task.cancel, self.LogoutJob)
    end
    if self.SessionWindow and not self.SessionWindow.Dead then
        self.SessionWindow:SetLogoutHandler(nil)
    end
    self.LogoutJob, self.SessionWindow = nil, nil
    self.Job, self.Hwid, self.Token = nil, nil, nil
    if not self.Window.Dead then
        self.Window:Destroy()
    end
end

function KeySystem:_buildWindow()
    local options = self.Options
    self.Completing = false
    self.Window = self.Library:CreateWindow({
        Name = options.Name or "Kinoue",
        Id = options.Id or "Kinoue_Key_" .. self.Application,
        Size = Vector2.new(420, 320),
        MinSize = Vector2.new(320, 280),
        Resizable = false,
        ShowSettings = false,
        ReplaceExisting = true,
        Background = options.Background,
    })
    local page = self.Window:AddTab("Key")
    page:SetTitle("")
    local group = page:AddGroupbox("Access", "Left")
    self.Key = group:AddTextbox("KeySystem.Key", { Text = "Key", MaxLength = 256 })
    self.Key.Persist = false
    self.Remember = group:AddToggle("KeySystem.Remember", {
        Text = "Remember",
        Keybind = false,
        Value = self.CanRemember and options.Remember ~= false,
        Callback = function(value)
            if not value then
                self:_clearCache()
            end
        end,
    })
    self.Remember:SetEnabled(self.CanRemember)
    self.RedeemButton = group:AddButton({
        Text = "Redeem",
        Callback = function()
            self:Redeem(self.Key.Root.Text)
        end,
    })
    self.Window.Scope:Connect(self.Key.Root.FocusLost, function(enter)
        if enter then
            self:Redeem(self.Key.Root.Text)
        end
    end)
    self.Window:OnDestroy(function()
        if not self.Completing then
            self:Destroy()
        end
    end)
end

function KeySystem.new(library, options)
    options = options or {}
    local application = options.Application
    assert(
        type(application) == "string" and #application <= 64 and application:match("^[a-z][a-z0-9_-]*$"),
        "Application requires a lowercase application ID"
    )
    local self = setmetatable({
        Options = options,
        Library = library,
        Application = application,
        Endpoint = endpoint(options.Endpoint, options.AllowLocalhost == true),
        Generation = 0,
        State = "ready",
        Dead = false,
        Busy = false,
        Loaded = false,
    }, KeySystem)
    self.Timeout = math.clamp(tonumber(options.Timeout) or 20, 5, 60)
    self.CachePath = (options.CachePath or "Kinoue/keys/" .. application .. ".json"):gsub("\\", "/")
    assert(
        self.CachePath:match("^[%w_./-]+$") and not self.CachePath:find("%.%.") and self.CachePath:sub(1, 1) ~= "/",
        "CachePath must be an executor workspace path"
    )
    self.CanRemember = type(readfile) == "function" and type(writefile) == "function" and type(makefolder) == "function"
    self.Hwid = fingerprint()
    self.Request = request or http_request or (type(syn) == "table" and syn.request)
    self.Supported = self.Hwid ~= nil and type(self.Request) == "function" and type(loadstring) == "function"
    self:_buildWindow()
    if not self.Supported then
        local code = not self.Hwid and "unsupported_executor"
            or type(self.Request) ~= "function" and "unsupported_http"
            or "unsupported_loader"
        self:_fail(code)
        Util.warn(MESSAGES[code])
        return self
    end
    self:_status("Enter key.")
    if self.Remember:Get() then
        local ok, cache = pcall(function()
            return HttpService:JSONDecode(readfile(self.CachePath))
        end)
        if
            ok
            and type(cache) == "table"
            and cache.Version == 1
            and cache.Application == self.Application
            and cache.Endpoint == self.Endpoint
            and type(cache.Token) == "string"
            and #cache.Token >= 32
            and #cache.Token <= 256
            and type(cache.ExpiresAt) == "number"
            and cache.ExpiresAt > os.time()
        then
            self:_run("session", { token = cache.Token })
        end
    end
    return self
end

Util.protect(KeySystem, { "Redeem", "Forget", "AttachWindow", "Logout", "Destroy" })
return KeySystem
end

__factories["Window/Background"] = function()
local RunService = game:GetService("RunService")
local Media = __require("internal/LocalMedia")
local Util = __require("internal/Util")

local Background = {}
local DEFAULTS = { Enabled = false, File = "", Opacity = 0.6, PanelOpacity = 0.8, Fit = "Cover", Speed = 1 }
local FIT = { Cover = Enum.ScaleType.Crop, Contain = Enum.ScaleType.Fit, Stretch = Enum.ScaleType.Stretch }

local function active(state)
    return state.Options.Enabled and state.Media ~= nil and state.Options.Opacity > 0
end

local function paint(state, index)
    if index == state.Index then
        return
    end
    local frame = state.Media.Frames[index]
    state.Image.Image = frame.Image
    state.Image.ImageRectOffset = frame.Offset
    state.Image.ImageRectSize = frame.Size
    state.Index = index
end

function Background.init(window, options)
    window.BackgroundState = { Options = table.clone(DEFAULTS), Surfaces = {}, Generation = 0, Time = 0 }
    if options then
        Background.set(window, options)
    end
end

function Background.surface(window, object)
    local state = window.BackgroundState
    local entry = window.Fade and window.Fade.Entries[object]
    state.Surfaces[object] = entry and entry.Base.BackgroundTransparency or object.BackgroundTransparency
    if active(state) then
        object.BackgroundTransparency = 1 - state.Options.PanelOpacity
    end
    window.Scope:Connect(object.Destroying, function()
        state.Surfaces[object] = nil
    end)
end

function Background.mount(window)
    local state = window.BackgroundState
    state.Image = Util.new("ImageLabel", {
        Name = "BackgroundMedia",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 0,
        Visible = false,
        Image = "",
        ImageTransparency = 1,
        ScaleType = FIT[state.Options.Fit],
    }, window.Root)
    Background.sync(window)
    Background.load(window)
end

function Background.sync(window)
    local state = window.BackgroundState
    if not state or not state.Image then
        return
    end
    local enabled = active(state)
    state.Image.Visible = enabled
    state.Image.ImageTransparency = 1 - state.Options.Opacity
    state.Image.ScaleType = FIT[state.Options.Fit]
    for object, original in pairs(state.Surfaces) do
        object.BackgroundTransparency = enabled and (1 - state.Options.PanelOpacity) or original
    end
    local playing = enabled and window.Open and not window.ReducedMotion and #state.Media.Frames > 1
    if not playing and state.Connection then
        window.Scope:Release(state.Connection)
        state.Connection = nil
    elseif playing and not state.Connection then
        state.Connection = window.Scope:Connect(RunService.RenderStepped, function(delta)
            state.Time = (state.Time + (delta or 1 / 60) * state.Options.Speed) % state.Media.Duration
            local low, high = 1, #state.Media.Frames
            while low < high do
                local mid = math.floor((low + high) / 2)
                if state.Time < state.Media.Frames[mid].End then
                    high = mid
                else
                    low = mid + 1
                end
            end
            paint(state, low)
        end)
    end
end

local function cancel(state)
    state.Generation += 1
    if state.Job and task.cancel then
        pcall(task.cancel, state.Job)
    end
    state.Job = nil
    state.Loading = false
end

function Background.load(window)
    local state = window.BackgroundState
    cancel(state)
    if not state.Image or not state.Options.Enabled or state.Options.File == "" then
        return
    end
    local path, generation = state.Options.File, state.Generation
    state.Loading, state.Error = true, nil
    state.Job = task.defer(function()
        local budget = os.clock()
        local function checkpoint()
            assert(not window.Dead and generation == state.Generation, "Background load cancelled")
            if os.clock() - budget >= 0.003 then
                RunService.Heartbeat:Wait()
                budget = os.clock()
                assert(not window.Dead and generation == state.Generation, "Background load cancelled")
            end
        end
        local ok, result = pcall(function()
            checkpoint()
            local media = Media.load(path, checkpoint)
            checkpoint()
            local failed = false
            game:GetService("ContentProvider"):PreloadAsync(media.Pages, function(_, status)
                if status ~= Enum.AssetFetchStatus.Success then
                    failed = true
                end
            end)
            checkpoint()
            assert(not failed, "Roblox could not load the background image")
            for _, frame in ipairs(media.Frames) do
                frame.Offset, frame.Size = Vector2.new(frame.X, frame.Y), Vector2.new(frame.Width, frame.Height)
            end
            return media
        end)
        if window.Dead or generation ~= state.Generation then
            return
        end
        state.Job, state.Loading = nil, false
        Util.withContext(function()
            if ok then
                state.Media, state.LoadedFile = result, path
                state.Time, state.Index = 0, nil
                paint(state, 1)
                Background.sync(window)
            else
                state.Error = tostring(result):gsub("^.-:%d+: ", "")
                window:Notify({ Title = "Background", Text = state.Error })
            end
        end)
    end)
end

function Background.set(window, options, reload)
    local state = window.BackgroundState
    if window.Dead then
        return
    end
    if type(options) == "string" then
        options = { File = options, Enabled = true }
    end
    assert(type(options) == "table", "SetBackground requires a file path or options table")
    local nextOptions = table.clone(state.Options)
    for key, value in pairs(options) do
        assert(DEFAULTS[key] ~= nil, "Unknown background option: " .. tostring(key))
        if key == "Enabled" then
            assert(type(value) == "boolean", "Background Enabled requires a boolean")
        elseif key == "File" then
            assert(type(value) == "string" and #value <= 1024 and not value:find("%z"), "Invalid background file path")
        elseif key == "Fit" then
            assert(FIT[value], "Background Fit must be Cover, Contain, or Stretch")
        else
            assert(
                type(value) == "number" and value == value and math.abs(value) < math.huge,
                "Invalid background " .. key
            )
            value = math.clamp(value, key == "Speed" and 0.1 or 0, key == "Speed" and 4 or 1)
        end
        nextOptions[key] = value
    end
    local changedFile = nextOptions.File ~= state.Options.File
    local changedEnabled = nextOptions.Enabled ~= state.Options.Enabled
    state.Options = nextOptions
    for key, value in pairs(nextOptions) do
        local control = window.Controls["UI.Background." .. key]
        if control then
            control:SetSilent(value)
        end
    end
    if changedFile or changedEnabled or reload then
        cancel(state)
        if nextOptions.File == "" then
            state.Media, state.LoadedFile, state.Index, state.Error = nil, nil, nil, nil
            if state.Image then
                state.Image.Image = ""
            end
        end
        if nextOptions.Enabled and nextOptions.File ~= "" and (reload or state.LoadedFile ~= nextOptions.File) then
            Background.load(window)
        end
    end
    Background.sync(window)
    if window.ConfigChanged then
        window:ConfigChanged()
    end
end

function Background.destroy(window)
    local state = window.BackgroundState
    cancel(state)
    if state.Connection then
        window.Scope:Release(state.Connection)
        state.Connection = nil
    end
    state.Media = nil
    table.clear(state.Surfaces)
end

return Background
end

__factories["Window/Chrome"] = function()
local RunService = game:GetService("RunService")

local Icons = __require("internal/Icons")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local HEADER_HEIGHT = 32
local TAB_BAR_HEIGHT = 30
local FOOTER_HEIGHT = 22
local ACCENT_WIDTH = 364
local ACCENT_FRAME_RATE = 30
local ACCENT_CYCLE_FRAMES = 150
local SETTINGS_BUTTON_SIZE = 20
local SETTINGS_ICON_SIZE = 16
local HEADER_BUTTON_MARGIN = 6
local HEADER_BUTTON_GAP = 4
local VERSION_TEXT_SIZE = 11

local Background = __require("Window/Background")

local Chrome = {}
Chrome.HEADER_HEIGHT = HEADER_HEIGHT
Chrome.SEARCH_OFFSET = HEADER_BUTTON_MARGIN + SETTINGS_BUTTON_SIZE + HEADER_BUTTON_GAP

local function buildRoot(window, options)
    local position = options.Position or UDim2.fromScale(0.5, 0.5)
    window.Root = Util.new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(
            position.X.Scale,
            position.X.Offset - window.Size.X / 2,
            position.Y.Scale,
            position.Y.Offset - window.Size.Y / 2
        ),
        Size = UDim2.fromOffset(window.Size.X, window.Size.Y),
        BackgroundColor3 = Theme.Color.Background,
        BorderColor3 = Theme.Color.Outline,
        BorderSizePixel = 1,
        ClipsDescendants = true,
    }, window.Screen)
    window.RestPosition = window.Root.Position
end

local function buildHeader(window, options)
    window.Header = Util.frame(window.Root, {
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundColor3 = Theme.Color.Panel,
        Active = true,
    })
    Util.label(window.Header, options.Name or "Kinoue", {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -(Chrome.SEARCH_OFFSET + SETTINGS_BUTTON_SIZE + 8), 1, 0),
        TextSize = Theme.TextSize + 1,
    })
    Util.frame(window.Header, {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Color.Outline,
    })
end

local function buildSettingsButton(window)
    window.SettingsButton = Util.button(window.Header, "", {
        Name = "SettingsButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -HEADER_BUTTON_MARGIN, 0.5, 0),
        Size = UDim2.fromOffset(SETTINGS_BUTTON_SIZE, SETTINGS_BUTTON_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    window.SettingsIcon = Icons.gear(window.SettingsButton, SETTINGS_ICON_SIZE)
end

function Chrome.paintSettingsButton(window)
    window.SettingsIcon:SetColor(window.SettingsOpen and Theme.Accent or Theme.Muted)
    window.SettingsIcon:SetRotation(window, window.SettingsOpen and 90 or 0)
end

local function buildAccent(window)
    window.Accent = Util.frame(window.Root, {
        Name = "RainbowAccent",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT - 1),
        Size = UDim2.fromOffset(ACCENT_WIDTH, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 4,
    })
    local gradient = Util.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.12, 0),
            NumberSequenceKeypoint.new(0.88, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, window.Accent)

    local keypoints, lastFrame = {}, -1
    local function animate()
        if not window.RainbowAccent then
            gradient.Color = ColorSequence.new(Theme.Accent)
            return
        end
        local frame = window.ReducedMotion and 0 or math.floor(os.clock() * ACCENT_FRAME_RATE)
        if frame == lastFrame then
            return
        end
        lastFrame = frame
        local phase = window.ReducedMotion and 0 or (frame / ACCENT_CYCLE_FRAMES) % 1
        for index = 0, 6 do
            local hue = (index / 6 + phase) % 1
            keypoints[index + 1] = ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(hue, 0.56, 0.93))
        end
        gradient.Color = ColorSequence.new(keypoints)
    end

    window.UpdateAccent = function()
        if window.AccentScope then
            window.AccentScope:Destroy()
            window.AccentScope = nil
        end
        if not window.Open then
            return
        end
        lastFrame = -1
        animate()
        if window.RainbowAccent and not window.ReducedMotion then
            window.AccentScope = Util.scope()
            window.AccentScope:Connect(RunService.RenderStepped, animate)
        end
    end
    window.UpdateAccent()
end

local function buildBody(window)
    window.Tabs = Util.new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, HEADER_HEIGHT),
        Size = UDim2.new(1, 0, 0, TAB_BAR_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Color.Background,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.X,
    }, window.Root)
    Util.padding(window.Tabs, 4)
    Util.list(window.Tabs, true, 0)

    window.Body = Util.frame(window.Root, {
        Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_BAR_HEIGHT),
        Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_BAR_HEIGHT + FOOTER_HEIGHT)),
        BackgroundTransparency = 1,
    })
end

local function buildFooter(window, options)
    window.Footer = Util.frame(window.Root, {
        Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT),
        Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
        BackgroundColor3 = Theme.Color.Panel,
    })
    Util.frame(window.Footer, {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Color.Outline,
    })
    window.Status = Util.label(window.Footer, "Ready", {
        Position = UDim2.fromOffset(7, 0),
        Size = UDim2.new(0.7, -7, 1, 0),
        TextSize = Theme.SmallSize,
    })
    local reserved = 7
    if window.Version then
        local text = "v" .. window.Version
        local width = Util.textWidth(text, VERSION_TEXT_SIZE)
        window.VersionLabel = Util.label(window.Footer, text, {
            Name = "Version",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -7, 0, 0),
            Size = UDim2.new(0, width, 1, 0),
            TextSize = VERSION_TEXT_SIZE,
            TextColor3 = Theme.Color.Muted,
            TextTransparency = 0.25,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        reserved += width + 8
    end
    Util.label(window.Footer, options.Footer or "", {
        Position = UDim2.new(0.7, 0, 0, 0),
        Size = UDim2.new(0.3, -reserved, 1, 0),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
end

local function buildResizeHandle(window)
    window.ResizeHandle = Util.button(window.Root, "", {
        Name = "ResizeHandle",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 100,
        Visible = window.Resizable,
    })
end

function Chrome.build(window, options)
    buildRoot(window, options)
    buildHeader(window, options)
    buildSettingsButton(window)
    Chrome.paintSettingsButton(window)
    buildAccent(window)
    buildBody(window)
    buildFooter(window, options)
    Background.surface(window, window.Header)
    Background.surface(window, window.Tabs)
    Background.surface(window, window.Footer)
    buildResizeHandle(window)
end

function Chrome.layoutAccent(window)
    local width = window.Root.AbsoluteSize.X
    local accentWidth = math.floor(math.min(ACCENT_WIDTH, width * 0.546) / 2) * 2
    window.Accent.Size = UDim2.fromOffset(accentWidth, 1)
    window.Accent.Position = UDim2.new(0.5, -accentWidth / 2, 0, HEADER_HEIGHT - 1)
end

return Chrome
end

__factories["Window/Config"] = function()
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Util = __require("internal/Util")

local CONFIG_VERSION = 1
local SAVE_INTERVAL = 0.5

local Config = {}

local function encodeValue(value)
    if typeof(value) == "EnumItem" then
        return { Type = "KeyCode", Name = value.Name }
    end
    if typeof(value) == "Color3" then
        return { Type = "Color3", R = value.R, G = value.G, B = value.B }
    end
    return value
end

local function decodeValue(value)
    if type(value) == "table" and value.Type == "KeyCode" then
        return Enum.KeyCode[value.Name]
    end
    if type(value) == "table" and value.Type == "Color3" then
        return Color3.new(value.R, value.G, value.B)
    end
    return value
end

function Config:GetConfig()
    local values = {}
    for id, control in pairs(self.Controls) do
        if control.Persist ~= false then
            values[id] = encodeValue(control:Get())
        end
    end
    return { Version = CONFIG_VERSION, Values = values }
end

function Config:LoadConfig(config)
    assert(
        type(config) == "table" and config.Version == CONFIG_VERSION and type(config.Values) == "table",
        "Unsupported UI config"
    )
    local suppressed = self.SuppressNotify
    self.SuppressNotify = true
    for id, saved in pairs(config.Values) do
        local control = self.Controls[id]
        if control then
            local ok, message = pcall(function()
                control:Set(decodeValue(saved))
            end)
            if not ok then
                Util.warn("Skipped saved value for " .. id .. ": " .. tostring(message))
            end
        end
    end
    self.SuppressNotify = suppressed
end

function Config:EncodeConfig()
    return HttpService:JSONEncode(self:GetConfig())
end

function Config:DecodeConfig(json)
    self:LoadConfig(HttpService:JSONDecode(json))
end

function Config:ConfigChanged()
    if self.Storage and not self.RestoringConfig then
        self.ConfigDirty = true
    end
end

function Config:FlushConfig()
    if not self.Storage or not self.ConfigDirty then
        return
    end
    local ok, message = pcall(self.Storage.Write, self:EncodeConfig())
    if ok then
        self.ConfigDirty = false
    else
        Util.warn("Config save failed: " .. tostring(message))
    end
end

function Config:EnablePersistence(adapter)
    assert(
        type(adapter) == "table" and type(adapter.Read) == "function" and type(adapter.Write) == "function",
        "Persistence requires Read/Write functions"
    )
    self.Storage = adapter
    self.RestoringConfig = true
    local ok, json = pcall(adapter.Read)
    if ok and json and json ~= "" then
        local loaded, message = pcall(function()
            self:DecodeConfig(json)
        end)
        if not loaded then
            Util.warn("Ignored invalid config: " .. tostring(message))
        end
    end
    self.RestoringConfig = false

    if not self.PersistenceConnection then
        local elapsed = 0
        self.PersistenceConnection = self.Scope:Connect(RunService.Heartbeat, function(deltaTime)
            elapsed += deltaTime
            if elapsed >= SAVE_INTERVAL then
                elapsed = 0
                self:FlushConfig()
            end
        end)
    end
end

return Config
end

__factories["Window/Input"] = function()
local UserInputService = game:GetService("UserInputService")

local Util = __require("internal/Util")

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
end

__factories["Window/Notifications"] = function()
local Mount = __require("internal/Mount")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local WIDTH = 260
local PADDING = 10
local TITLE_HEIGHT = 18
local TIMER_HEIGHT = 2
local CLOSE_SIZE = 16
local SCREEN_MARGIN = 14
local GAP = 6
local MAX_VISIBLE = 5
local DEFAULT_DURATION = 4
local MIN_DURATION = 0.5
local ENTER_DURATION = 0.24
local EXIT_DURATION = 0.18
local OFFSCREEN = WIDTH + SCREEN_MARGIN * 2

local Notifications = {}

local function ensureScreen(window)
    if window.NotificationScreen then
        return window.NotificationHolder
    end
    local screen = Util.new("ScreenGui", {
        Name = window.Screen.Name .. "Notifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = window.Screen.DisplayOrder + 1,
    })
    Mount.core(screen, false)
    local holder = Util.frame(screen, {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -SCREEN_MARGIN, 1, -SCREEN_MARGIN),
        Size = UDim2.new(0, WIDTH, 1, -2 * SCREEN_MARGIN),
        BackgroundTransparency = 1,
    })
    local list = Util.list(holder, false, GAP)
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    window.NotificationScreen = screen
    window.NotificationHolder = holder
    window.Toasts = {}
    return holder
end

local function parse(window, options)
    if type(options) ~= "table" then
        options = { Text = options }
    end
    local duration = tonumber(options.Duration) or DEFAULT_DURATION
    return {
        Title = tostring(options.Title or window.Name),
        Text = options.Text ~= nil and tostring(options.Text) or "",
        Duration = math.max(MIN_DURATION, duration),
    }
end

local function release(window, toast)
    for _, object in ipairs({ toast.Card, toast.Slot, toast.Timer }) do
        local tween = window.Scope.Tweens[object]
        if tween then
            tween:Cancel()
            window.Scope.Tweens[object] = nil
        end
    end
    if toast.Slot.Parent then
        toast.Slot:Destroy()
    end
end

local function dismiss(window, toast)
    if toast.Closed then
        return
    end
    toast.Closed = true
    toast.Scope:Destroy()
    local index = table.find(window.Toasts, toast)
    if index then
        table.remove(window.Toasts, index)
    end

    if window.ReducedMotion or window.Dead then
        release(window, toast)
        return
    end
    window.Scope:Tween(toast.Card, EXIT_DURATION, { Position = UDim2.fromOffset(OFFSCREEN, 0) }, false)
    window.Scope:Tween(toast.Slot, EXIT_DURATION, { Size = UDim2.fromOffset(WIDTH, 0) }, false)
    task.delay(EXIT_DURATION, function()
        release(window, toast)
    end)
end

local function build(window, holder, message)
    local textWidth = WIDTH - 2 * PADDING
    local textHeight = 0
    if message.Text ~= "" then
        textHeight = math.ceil(Util.textSize(message.Text, Theme.SmallSize, textWidth).Y)
    end
    local height = PADDING + TITLE_HEIGHT + (textHeight > 0 and textHeight + 2 or 0) + PADDING + TIMER_HEIGHT

    local slot = Util.frame(holder, {
        Name = "Slot",
        Size = UDim2.fromOffset(WIDTH, 0),
        BackgroundTransparency = 1,
    })
    local card = Util.frame(slot, {
        Name = "Notification",
        Position = UDim2.fromOffset(OFFSCREEN, 0),
        Size = UDim2.fromOffset(WIDTH, height),
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
    })
    Util.frame(card, {
        Name = "Accent",
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = Theme.Color.Accent,
    })
    local title = Util.label(card, message.Title, {
        Name = "Title",
        Position = UDim2.fromOffset(PADDING, PADDING - 2),
        Size = UDim2.new(1, -(2 * PADDING + CLOSE_SIZE), 0, TITLE_HEIGHT),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local body = Util.label(card, message.Text, {
        Name = "Message",
        Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT),
        Size = UDim2.new(1, -2 * PADDING, 0, textHeight),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = textHeight > 0,
    })
    local close = Util.button(card, "×", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -4, 0, 4),
        Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.TextSize,
    })
    local track = Util.frame(card, {
        Name = "Timer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, TIMER_HEIGHT),
        BackgroundColor3 = Theme.Color.Hover,
    })
    local timer = Util.frame(track, {
        Name = "Fill",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })

    return {
        Slot = slot,
        Card = card,
        Title = title,
        Message = body,
        CloseButton = close,
        Timer = timer,
        Height = height,
        Duration = message.Duration,
        Closed = false,
        Scope = Util.scope(),
    }
end

function Notifications.show(window, options)
    if window.Dead or window.NotificationsEnabled == false then
        return nil
    end
    local message = parse(window, options)
    local holder = ensureScreen(window)
    while #window.Toasts >= MAX_VISIBLE do
        dismiss(window, window.Toasts[1])
    end

    local toast = build(window, holder, message)
    table.insert(window.Toasts, toast)

    local reduced = window.ReducedMotion
    window.Scope:Tween(toast.Slot, ENTER_DURATION, { Size = UDim2.fromOffset(WIDTH, toast.Height) }, reduced)
    window.Scope:Tween(toast.Card, ENTER_DURATION, { Position = UDim2.fromOffset(0, 0) }, reduced)
    window.Scope:Tween(toast.Timer, toast.Duration, { Size = UDim2.fromScale(0, 1) }, false, Enum.EasingStyle.Linear)

    toast.Scope:Connect(toast.CloseButton.Activated, function()
        dismiss(window, toast)
    end)
    task.delay(toast.Duration, function()
        if not window.Dead then
            dismiss(window, toast)
        end
    end)

    function toast.Close()
        dismiss(window, toast)
    end
    return toast
end

function Notifications.clear(window)
    if not window.Toasts then
        return
    end
    for _, toast in ipairs(table.clone(window.Toasts)) do
        toast.Closed = true
        toast.Scope:Destroy()
    end
    table.clear(window.Toasts)
end

function Notifications.destroy(window)
    Notifications.clear(window)
    if window.NotificationScreen then
        window.NotificationScreen:Destroy()
        window.NotificationScreen = nil
        window.NotificationHolder = nil
    end
end

return Notifications
end

__factories["Window/Page"] = function()
local Group = __require("Controls")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local NARROW_WIDTH = 520

local Background = __require("Window/Background")

local Page = {}
Page.__index = Page

local Subpage = {}
Subpage.__index = Subpage

local function build(window, name)
    local self = setmetatable({ Window = window, Name = name, Groups = {}, Subpages = {} }, Page)
    self.Frame = Util.frame(window.Body, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    })
    self.Title = Util.label(self.Frame, name, {
        Position = UDim2.fromOffset(8, 1),
        Size = UDim2.new(0.65, -8, 0, 23),
    })
    self.Mode = Util.label(self.Frame, "", {
        Position = UDim2.new(0.65, 0, 0, 1),
        Size = UDim2.new(0.35, -8, 0, 23),
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    self.Scroll = Util.new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 26),
        Size = UDim2.new(1, -16, 1, -32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Color.Outline,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, self.Frame)
    self.Left = Util.frame(self.Scroll, { BackgroundTransparency = 1 })
    self.Right = Util.frame(self.Scroll, { BackgroundTransparency = 1 })
    self.LeftList = Util.list(self.Left, false, Theme.Gap)
    self.RightList = Util.list(self.Right, false, Theme.Gap)

    local function relayout()
        self:Relayout()
    end
    window.Scope:Connect(self.LeftList:GetPropertyChangedSignal("AbsoluteContentSize"), relayout)
    window.Scope:Connect(self.RightList:GetPropertyChangedSignal("AbsoluteContentSize"), relayout)
    window.Scope:Connect(self.Scroll:GetPropertyChangedSignal("AbsoluteSize"), relayout)
    return self
end

function Page.hidden(window, name)
    local self = build(window, name)
    window:AddSearchEntry({ Kind = "Tab", Name = name, Page = self })
    return self
end

function Page.new(window, name)
    local self = build(window, name)
    self.Button = Util.button(window.Tabs, name, {
        Size = UDim2.fromOffset(Util.textWidth(name) + 18, 24),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextColor3 = Theme.Color.Muted,
    })
    self.Line = Util.frame(self.Button, {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Color.Accent,
        Visible = false,
    })
    window.Scope:Connect(self.Button.Activated, function()
        window:SelectTab(self)
    end)

    table.insert(window.Pages, self)
    window:AddSearchEntry({ Kind = "Tab", Name = name, Page = self })
    if #window.Pages == 1 then
        window:SelectTab(self)
    end
    return self
end

function Page:Relayout()
    local available = math.floor(self.Scroll.AbsoluteSize.X)
    local narrow = self.Scroll.AbsoluteSize.X < NARROW_WIDTH
    local leftHeight = self.LeftList.AbsoluteContentSize.Y
    local rightHeight = self.RightList.AbsoluteContentSize.Y

    if narrow then
        self.Left.Size = UDim2.fromOffset(available, leftHeight)
        self.Right.Size = UDim2.fromOffset(available, rightHeight)
        self.Right.Position = UDim2.fromOffset(0, leftHeight + Theme.Gap)
        self.Scroll.CanvasSize = UDim2.fromOffset(0, leftHeight + rightHeight + Theme.Gap)
    else
        local leftWidth = math.floor((available - Theme.Gap) / 2)
        self.Left.Size = UDim2.fromOffset(leftWidth, leftHeight)
        self.Right.Size = UDim2.fromOffset(available - leftWidth - Theme.Gap, rightHeight)
        self.Right.Position = UDim2.fromOffset(leftWidth + Theme.Gap, 0)
        self.Scroll.CanvasSize = UDim2.fromOffset(0, math.max(leftHeight, rightHeight))
    end
end

function Page:SetTitle(text)
    self.Title.Text = text
end

function Page:SetMode(text)
    text = text or ""
    if self.Mode.Text ~= text then
        self.Mode.Text = text
    end
end

function Page:Select()
    self.Window:SelectTab(self)
end

function Page:AddGroupbox(title, side)
    local frame = Util.frame(side == "Right" and self.Right or self.Left, {
        Name = title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
    })
    local header = Util.frame(frame, {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.Color.Panel,
    })
    Util.frame(header, {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Color.Accent,
    })
    Util.label(header, title, {
        Position = UDim2.fromOffset(6, 2),
        Size = UDim2.new(1, -12, 1, -2),
    })
    Background.surface(self.Window, frame)
    Background.surface(self.Window, header)
    local container = Util.frame(frame, {
        Position = UDim2.fromOffset(Theme.Padding, 27),
        Size = UDim2.new(1, -2 * Theme.Padding, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(container, false, Theme.ControlGap)
    Util.padding(container, 0)
    Util.new("UIPadding", { PaddingBottom = UDim.new(0, Theme.Padding) }, frame)

    local group = Group.new(self.Window, container, self, frame)
    group.Title = title
    table.insert(self.Groups, group)
    self.Window:AddSearchEntry({
        Kind = "Group",
        Name = title,
        Group = group,
        Self = true,
        Target = function()
            return frame
        end,
    })
    return group
end

function Page:AddSubTab(title)
    if not self.Subbar then
        self.Subbar = Util.frame(self.Frame, {
            Position = UDim2.fromOffset(8, 25),
            Size = UDim2.new(1, -16, 0, 24),
            BackgroundTransparency = 1,
        })
        Util.list(self.Subbar, true, 3)
        self.Scroll.Position = UDim2.fromOffset(8, 54)
        self.Scroll.Size = UDim2.new(1, -16, 1, -60)
    end
    return Subpage.new(self, title)
end

function Subpage.new(page, title)
    local self = setmetatable({ Page = page, Groups = {}, Title = title }, Subpage)
    self.Button = Util.button(page.Subbar, title, {
        Size = UDim2.fromOffset(Util.textWidth(title) + 16, 22),
    })
    table.insert(page.Subpages, self)
    page.Window:AddSearchEntry({ Kind = "Tab", Name = title, Subpage = self })
    page.Window.Scope:Connect(self.Button.Activated, function()
        self:Select()
    end)
    if #page.Subpages == 1 then
        self:Select()
        table.insert(page.Window.ThemeHooks, function()
            page:StyleSubtabs()
        end)
    end
    return self
end

function Page:StyleSubtabs()
    for _, item in ipairs(self.Subpages) do
        item.Button.BorderColor3 = item == self.ActiveSubpage and Theme.Accent or Theme.Outline
    end
end

function Subpage:Select()
    local page = self.Page
    page.Window:ClosePopup()
    page.ActiveSubpage = self
    for _, item in ipairs(page.Subpages) do
        for _, group in ipairs(item.Groups) do
            group.Frame.Visible = item == self
        end
    end
    page:StyleSubtabs()
    page:Relayout()
end

function Subpage:AddGroupbox(name, side)
    local group = self.Page:AddGroupbox(name, side)
    group.Subpage = self
    table.insert(self.Groups, group)
    group.Frame.Visible = self.Page.ActiveSubpage == self
    return group
end

Util.protect(Page, { "SetTitle", "SetMode", "AddSubTab", "AddGroupbox", "Select" })
Util.protect(Subpage, { "Select", "AddGroupbox" })

return Page
end

__factories["Window/Search"] = function()
local UserInputService = game:GetService("UserInputService")

local Icons = __require("internal/Icons")
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local BUTTON_SIZE = 20
local ICON_SIZE = 14
local BOX_WIDTH = 200
local BOX_HEIGHT = 22
local BOX_GAP = 4
local RESULTS_WIDTH = 280
local RESULT_HEIGHT = 34
local MAX_RESULTS = 25
local MAX_VISIBLE = 7
local OPEN_DURATION = 0.16
local FLASH_DURATION = 0.9
local SCROLL_MARGIN = 8
local SEPARATOR = " > "

local Search = {}

local function nameOf(entry)
    local name = entry.Name
    if type(name) == "function" then
        name = name()
    end
    return tostring(name or "")
end

local function rootOf(group)
    local labels, chain = {}, {}
    while group.Parent do
        table.insert(labels, 1, group.Label)
        table.insert(chain, 1, group)
        group = group.Parent
    end
    return group, labels, chain
end

local function locate(entry)
    if entry.Group then
        local root = rootOf(entry.Group)
        return root.Page, root.Subpage
    end
    if entry.Subpage then
        return entry.Subpage.Page, entry.Subpage
    end
    return entry.Page, nil
end

function Search.path(entry)
    if entry.Group then
        local root, labels = rootOf(entry.Group)
        local parts = { root.Page.Name }
        if root.Subpage then
            table.insert(parts, root.Subpage.Title)
        end
        table.insert(parts, root.Title)
        for _, label in ipairs(labels) do
            table.insert(parts, label)
        end
        if entry.Self then
            table.remove(parts)
        end
        return table.concat(parts, SEPARATOR)
    end
    if entry.Subpage then
        return entry.Subpage.Page.Name
    end
    return ""
end

local function hidden(entry)
    local target = entry.Target and entry.Target()
    return target ~= nil and target.Visible == false
end

function Search.query(window, text)
    local query = string.lower(tostring(text or "")):match("^%s*(.-)%s*$")
    if query == "" then
        return {}
    end
    local scored = {}
    for index, entry in ipairs(window.SearchIndex) do
        local name = string.lower(nameOf(entry))
        local score
        if name == query then
            score = 0
        elseif name:sub(1, #query) == query then
            score = 1
        elseif name:find(query, 1, true) then
            score = 2
        elseif string.lower(Search.path(entry)):find(query, 1, true) then
            score = 3
        end
        if score and not hidden(entry) then
            table.insert(scored, { Entry = entry, Score = score, Index = index })
        end
    end
    table.sort(scored, function(a, b)
        if a.Score ~= b.Score then
            return a.Score < b.Score
        end
        return a.Index < b.Index
    end)
    local results = {}
    for index = 1, math.min(#scored, MAX_RESULTS) do
        results[index] = scored[index].Entry
    end
    return results
end

function Search.focus(window, page, target)
    local scroll = page.Scroll
    local offset = target.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - SCROLL_MARGIN
    scroll.CanvasPosition = Vector2.new(0, math.max(0, offset))

    local flash = Util.frame(target, {
        Name = "SearchHighlight",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.7,
    })
    window.Scope:Tween(flash, FLASH_DURATION, { BackgroundTransparency = 1 }, false)
    task.delay(FLASH_DURATION, function()
        window.Scope.Tweens[flash] = nil
        if flash.Parent then
            flash:Destroy()
        end
    end)
end

function Search.reveal(window, entry)
    local page, subpage = locate(entry)
    if page == window.SettingsPage then
        window:OpenSettings()
    else
        window:SelectTab(page)
    end
    if subpage then
        subpage:Select()
    end
    if entry.Group then
        local _, _, chain = rootOf(entry.Group)
        for _, group in ipairs(chain) do
            group.Reveal()
        end
    end
    local target = entry.Target and entry.Target()
    if target then
        task.defer(function()
            if not window.Dead then
                Search.focus(window, page, target)
            end
        end)
    end
    return page
end

local function clearRows(state)
    if state.RowScope then
        state.RowScope:Destroy()
        state.RowScope = nil
    end
    for _, row in ipairs(state.Rows) do
        row:Destroy()
    end
    table.clear(state.Rows)
end

local function addRow(window, state, entry)
    local row = Util.button(state.Results, "", {
        Name = "Result",
        Size = UDim2.new(1, 0, 0, RESULT_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Color.Panel,
        ZIndex = 61,
    })
    Util.label(row, nameOf(entry), {
        Name = "Title",
        Position = UDim2.fromOffset(8, 3),
        Size = UDim2.new(1, -72, 0, 16),
        TextSize = Theme.TextSize - 1,
        ZIndex = 62,
    })
    Util.label(row, entry.Kind, {
        Name = "Kind",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 3),
        Size = UDim2.fromOffset(60, 16),
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 62,
    })
    local path = Search.path(entry)
    Util.label(row, path ~= "" and path or "Tab", {
        Name = "Path",
        Position = UDim2.fromOffset(8, 18),
        Size = UDim2.new(1, -16, 0, 13),
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 62,
    })
    state.RowScope:Connect(row.Activated, function()
        Search.go(window, entry)
    end)
    table.insert(state.Rows, row)
end

function Search.refresh(window)
    local state = window.Search
    clearRows(state)
    local text = state.Box.Text
    if not state.Open or text:match("^%s*$") then
        state.Matches = {}
        state.Results.Visible = false
        return
    end

    state.RowScope = Util.scope()
    state.Matches = Search.query(window, text)
    if #state.Matches == 0 then
        table.insert(
            state.Rows,
            Util.label(state.Results, "No results", {
                Size = UDim2.new(1, 0, 0, RESULT_HEIGHT),
                TextColor3 = Theme.Color.Muted,
                TextSize = Theme.SmallSize,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 61,
            })
        )
    end
    for _, entry in ipairs(state.Matches) do
        addRow(window, state, entry)
    end

    local count = math.max(1, #state.Matches)
    state.Results.CanvasSize = UDim2.fromOffset(0, count * RESULT_HEIGHT)
    state.Results.Size = UDim2.fromOffset(RESULTS_WIDTH, math.min(count, MAX_VISIBLE) * RESULT_HEIGHT)
    state.Results.Visible = true
end

local function paint(window)
    local state = window.Search
    state.Icon:SetColor(state.Open and Theme.Accent or Theme.Muted)
end

function Search.open(window)
    local state = window.Search
    if state.Open or window.Dead then
        return
    end
    state.Open = true
    state.Box.Text = ""
    state.Box.Visible = true
    window.Scope:Tween(
        state.Box,
        OPEN_DURATION,
        { Size = UDim2.fromOffset(BOX_WIDTH, BOX_HEIGHT) },
        window.ReducedMotion
    )
    paint(window)
    pcall(function()
        state.Box:CaptureFocus()
    end)

    state.Scope = Util.scope()
    state.Scope:Connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            Search.close(window)
            return
        end
        if not Util.isPointer(input) then
            return
        end
        local point = input.Position
        local inside = Util.contains(state.Box, point)
            or (state.Results.Visible and Util.contains(state.Results, point))
            or Util.contains(state.Button, point)
        if not inside then
            Search.close(window)
        end
    end)
    Search.refresh(window)
end

function Search.close(window)
    local state = window.Search
    if not state or not state.Open then
        return
    end
    state.Open = false
    if state.Scope then
        state.Scope:Destroy()
        state.Scope = nil
    end
    clearRows(state)
    pcall(function()
        state.Box:ReleaseFocus()
    end)
    window.Scope:Tween(state.Box, 0, { Size = UDim2.fromOffset(0, BOX_HEIGHT) }, true)
    state.Box.Visible = false
    state.Results.Visible = false
    state.Matches = {}
    paint(window)
end

function Search.go(window, entry)
    Search.close(window)
    return Search.reveal(window, entry)
end

function Search.build(window, headerHeight, rightOffset)
    local button = Util.button(window.Header, "", {
        Name = "SearchButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -rightOffset, 0.5, 0),
        Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local box = Util.textbox(window.Header, {
        Name = "SearchBox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(rightOffset + BUTTON_SIZE + BOX_GAP), 0.5, 0),
        Size = UDim2.fromOffset(0, BOX_HEIGHT),
        Text = "",
        PlaceholderText = "Search settings",
        PlaceholderColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClipsDescendants = true,
        Visible = false,
    })
    Util.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, box)
    local results = Util.new("ScrollingFrame", {
        Name = "SearchResults",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, headerHeight + 2),
        Size = UDim2.fromOffset(RESULTS_WIDTH, 0),
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Color.Outline,
        CanvasSize = UDim2.new(),
        ZIndex = 60,
        Visible = false,
    }, window.Root)
    Util.list(results, false, 0)

    window.Search = {
        Button = button,
        Icon = Icons.search(button, ICON_SIZE),
        Box = box,
        Results = results,
        Open = false,
        Rows = {},
        Matches = {},
    }

    window.Scope:Connect(button.Activated, function()
        if window.Search.Open then
            Search.close(window)
        else
            Search.open(window)
        end
    end)
    window.Scope:Connect(box:GetPropertyChangedSignal("Text"), function()
        if window.Search.Open then
            Search.refresh(window)
        end
    end)
    window.Scope:Connect(box.FocusLost, function(enterPressed)
        local first = window.Search.Matches[1]
        if enterPressed and window.Search.Open and first then
            Search.go(window, first)
        end
    end)
    table.insert(window.ThemeHooks, function()
        paint(window)
    end)
    return BUTTON_SIZE
end

return Search
end

__factories["Window/Settings"] = function()
local Page = __require("Window/Page")
local Theme = __require("internal/Theme")

local CUSTOM = "Custom"

local EDITABLE_COLORS = {
    { Key = "Accent", Text = "Accent" },
    { Key = "Background", Text = "Background" },
    { Key = "Panel", Text = "Panels" },
    { Key = "Outline", Text = "Outlines" },
    { Key = "Text", Text = "Text" },
    { Key = "Muted", Text = "Muted text" },
}

local COLOR_TOLERANCE = 0.5 / 255

local Settings = {}

local function sameColor(a, b)
    return math.abs(a.R - b.R) <= COLOR_TOLERANCE
        and math.abs(a.G - b.G) <= COLOR_TOLERANCE
        and math.abs(a.B - b.B) <= COLOR_TOLERANCE
end

local function presetOptions()
    local options = table.clone(Theme.PresetNames)
    table.insert(options, CUSTOM)
    return options
end

local function buildTheme(window, page)
    local group = page:AddGroupbox("Theme", "Left")
    local controls = {}

    controls.Preset = group:AddDropdown("UI.Theme", {
        Text = "Preset",
        Options = presetOptions(),
        Value = Theme.Preset,
        Callback = function(value)
            if value ~= CUSTOM then
                Theme.apply(value)
            end
        end,
    })

    controls.Colors = {}
    for _, entry in ipairs(EDITABLE_COLORS) do
        controls.Colors[entry.Key] = group:AddColorPicker("UI.Color." .. entry.Key, {
            Text = entry.Text,
            Value = Theme[entry.Key],
            Callback = function(value)
                if not sameColor(value, Theme[entry.Key]) then
                    Theme.apply({ [entry.Key] = value })
                end
            end,
        })
    end

    group:AddButton({
        Text = "Reset theme",
        Callback = function()
            Theme.apply("Dark")
        end,
    })

    return controls
end

local function buildWindow(window, page, options)
    local group = page:AddGroupbox("Window", "Right")
    local defaultSnap = math.max(1, options.SnapDistance or 8)

    group:AddKeybind("UI.MenuKey", {
        Text = "Menu key",
        Value = window.ToggleKey,
        Clearable = false,
        Callback = function(key)
            window:SetToggleKey(key)
        end,
    })

    group:AddToggle("UI.LockToScreen", {
        Text = "Lock to screen",
        Keybind = false,
        Value = not window.AllowOffscreen,
        Callback = function(value)
            window:SetLockToScreen(value)
        end,
    })
    group:AddToggle("UI.SnapToEdges", {
        Text = "Snap to edges",
        Keybind = false,
        Value = window.SnapDistance > 0,
        Callback = function(value)
            window.SnapDistance = value and defaultSnap or 0
        end,
    })
    group:AddLabel("Unlock to drag past screen edges.", true)
    page.LogoutGroup = group

    local look = page:AddGroupbox("Appearance", "Right")
    look:AddToggle("UI.Animations", {
        Text = "Animations",
        Keybind = false,
        Value = not window.ReducedMotion,
        Callback = function(value)
            window:SetReducedMotion(not value)
        end,
    })
    look:AddToggle("UI.Notifications", {
        Text = "Notifications",
        Keybind = false,
        Value = window.NotificationsEnabled,
        Callback = function(value)
            window.NotificationsEnabled = value
        end,
    })
    look:AddToggle("UI.RainbowAccent", {
        Text = "Rainbow accent line",
        Keybind = false,
        Value = window.RainbowAccent,
        Callback = function(value)
            window:SetRainbowAccent(value)
        end,
    })
end

function Settings.setLogout(window, callback)
    local page = window.SettingsPage
    if callback and not page.Controls.Logout then
        page.Controls.Logout = page.LogoutGroup:AddButton({
            Text = "Logout",
            Callback = function()
                if window.LogoutHandler then
                    window.LogoutHandler()
                end
            end,
        })
    end
    window.LogoutHandler = callback
    if page.Controls.Logout then
        page.Controls.Logout.Row.Visible = callback ~= nil
        page.Controls.Logout:SetEnabled(callback ~= nil)
    end
end

local function buildBackground(window, page)
    local group = page:AddGroupbox("Background", "Left")
    local defaults = window.BackgroundState.Options
    group:AddToggle("UI.Background.Enabled", {
        Text = "Enabled",
        Value = defaults.Enabled,
        Keybind = false,
        Callback = function(value)
            window:SetBackground({ Enabled = value })
        end,
    })
    group:AddTextbox("UI.Background.File", {
        Text = "File",
        Value = defaults.File,
        MaxLength = 1024,
        Callback = function(value)
            window:SetBackground({ File = value })
        end,
    })
    group:AddButtons({
        {
            Text = "Load",
            Callback = function()
                local file = window.Controls["UI.Background.File"]
                file:Set(file.Root.Text)
                window:SetBackground({ Enabled = true }, true)
            end,
        },
        {
            Text = "Clear",
            Callback = function()
                window:ClearBackground()
            end,
        },
    })
    for _, entry in ipairs({
        { Key = "Opacity", Text = "Image opacity", Min = 0, Max = 1 },
        { Key = "PanelOpacity", Text = "Panel opacity", Min = 0, Max = 1 },
        { Key = "Speed", Text = "Playback speed", Min = 0.1, Max = 4 },
    }) do
        group:AddSlider("UI.Background." .. entry.Key, {
            Text = entry.Text,
            Value = defaults[entry.Key],
            Min = entry.Min,
            Max = entry.Max,
            Step = 0.05,
            Callback = function(value)
                window:SetBackground({ [entry.Key] = value })
            end,
        })
    end
    group:AddDropdown("UI.Background.Fit", {
        Text = "Fit",
        Options = { "Cover", "Contain", "Stretch" },
        Value = defaults.Fit,
        Callback = function(value)
            window:SetBackground({ Fit = value })
        end,
    })
end

function Settings.build(window, options)
    local page = Page.hidden(window, "UI settings")
    page:SetTitle("UI settings")
    page:SetMode("Theme applies to every window")
    local controls = buildTheme(window, page)
    buildWindow(window, page, options)
    buildBackground(window, page)

    function controls.sync()
        controls.Preset:SetSilent(Theme.Preset)
        for key, picker in pairs(controls.Colors) do
            picker:SetSilent(Theme[key])
        end
    end

    page.Controls = controls
    return page
end

return Settings
end

__factories["Window"] = function()
local Cursor = __require("internal/Cursor")
local Fade = __require("internal/Fade")
local Mount = __require("internal/Mount")
local Theme = __require("internal/Theme")
local Tooltip = __require("internal/Tooltip")
local Util = __require("internal/Util")
local Background = __require("Window/Background")
local Chrome = __require("Window/Chrome")
local Config = __require("Window/Config")
local Input = __require("Window/Input")
local Notifications = __require("Window/Notifications")
local Page = __require("Window/Page")
local Search = __require("Window/Search")
local Settings = __require("Window/Settings")

local EDGE_MARGIN = 12
local FIT_MARGIN = 24
local OPEN_DURATION = 0.18
local CLOSE_DURATION = 0.15

local Window = {}
Window.__index = Window

for name, method in pairs(Config) do
    Window[name] = method
end

function Window.new(options, version)
    local self = setmetatable({}, Window)
    self.Scope = Util.scope()
    self.Name = options.Name or "Kinoue"
    self.Version = version
    self.Controls = {}
    self.Pages = {}
    self.Keybinds = {}
    self.Cleanup = {}
    self.ThemeHooks = {}
    self.SearchIndex = {}
    self.NotificationsEnabled = options.Notifications ~= false
    self.ReducedMotion = options.ReducedMotion == true
    self.RainbowAccent = options.RainbowAccent ~= false
    self.BindableToggles = options.BindableToggles == true
    self.SettingsOpen = false
    self.ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift
    self.Size = options.Size or Vector2.new(704, 470)
    self.MinSize = options.MinSize or Vector2.new(480, 360)
    self.Resizable = options.Resizable ~= false
    self.AllowOffscreen = options.AllowOffscreen == true
    self.SnapDistance = math.max(0, options.SnapDistance or 8)
    self.Open = true
    self.Dead = false
    self.VisibilityVersion = 0

    self.Screen = Util.new("ScreenGui", {
        Name = options.Id or "Kinoue",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.DisplayOrder or 100,
    })
    Mount.core(self.Screen, options.ReplaceExisting == true)
    self.Scope:Connect(self.Screen.Destroying, function()
        self:Destroy()
    end)
    Background.init(self, options.Background)
    Chrome.build(self, options)
    Background.mount(self)
    Search.build(self, Chrome.HEADER_HEIGHT, Chrome.SEARCH_OFFSET)

    self.Fade = Fade.new(self.Screen)
    self.Fade:Set(1)
    Cursor.set(self, true)

    Input.bindKeys(self)
    Input.bindPointer(self)

    self.SettingsPage = Settings.build(self, options)
    self.SettingsButton.Visible = options.ShowSettings ~= false
    self.Scope:Connect(self.SettingsButton.Activated, function()
        self:ToggleSettings()
    end)
    self.ThemeListener = Theme.onChanged(function()
        self:RefreshTheme()
    end)

    local function fit()
        self:Fit()
    end
    self.Scope:Connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:Relayout()
    end)
    self.Scope:Connect(self.Screen:GetPropertyChangedSignal("AbsoluteSize"), fit)
    local camera = workspace.CurrentCamera
    if camera then
        self.Scope:Connect(camera:GetPropertyChangedSignal("ViewportSize"), fit)
    end

    task.defer(function()
        if not self.Dead then
            fit()
        end
    end)
    task.defer(function()
        if not self.Dead and self.Open then
            self:SetVisible(true, true)
        end
    end)
    return self
end

function Window:Dispatch(callback, ...)
    if not callback or self.Dead then
        return
    end
    local ok, message = pcall(callback, ...)
    if not ok then
        if not self.Dead then
            self:SetStatus("Callback error")
        end
        Util.warn(message)
    end
end

function Window:UniqueId(base)
    if not self.Controls[base] then
        return base
    end
    local index = 2
    while self.Controls[base .. index] do
        index += 1
    end
    return base .. index
end

function Window:Register(id, control)
    assert(type(id) == "string", "Control IDs must be strings: " .. tostring(id))
    if self.Controls[id] then
        local unique = self:UniqueId(id)
        Util.warn('Duplicate control ID "' .. id .. '"; registered as "' .. unique .. '"')
        id = unique
    end
    self.Controls[id] = control
    control.Id = id
    return control
end

function Window:AddSearchEntry(entry)
    table.insert(self.SearchIndex, entry)
    return entry
end

function Window:OpenSearch()
    Search.open(self)
    return self
end

function Window:CloseSearch()
    Search.close(self)
    return self
end

function Window:SetBackground(options, reload)
    Background.set(self, options, reload)
    return self
end

function Window:ClearBackground()
    return self:SetBackground({ Enabled = false, File = "" })
end

function Window:GetBackgroundStatus()
    local state = self.BackgroundState
    local media = state.Media
    return {
        Loading = state.Loading == true,
        Error = state.Error,
        File = state.LoadedFile,
        Kind = media and media.Kind,
        Frames = media and #media.Frames or 0,
        Width = media and media.Width,
        Height = media and media.Height,
        Cached = media and media.Cached == true,
    }
end

function Window:Notify(options)
    return Notifications.show(self, options)
end

function Window:UpdateKeyConflicts()
    local byKey = {}
    for _, control in ipairs(self.Keybinds) do
        local key = control:Get()
        if control.Enabled and key ~= Enum.KeyCode.Unknown then
            byKey[key] = byKey[key] or {}
            table.insert(byKey[key], control)
        end
    end
    for _, control in ipairs(self.Keybinds) do
        local conflicts = {}
        local shared = control.Enabled and byKey[control:Get()]
        if shared and #shared > 1 then
            for _, other in ipairs(shared) do
                if other ~= control then
                    table.insert(conflicts, other)
                end
            end
        end
        control.Conflicts = conflicts
        if control.PaintConflict then
            control.PaintConflict()
        end
    end
end

function Window:SetStatus(text)
    if self.Dead then
        return
    end
    text = tostring(text or "")
    if self.Status.Text ~= text then
        self.Status.Text = text
    end
end

function Window:SetToggleKey(key)
    assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode, "ToggleKey requires Enum.KeyCode")
    self.ToggleKey = key
    local control = self.Controls["UI.MenuKey"]
    if control then
        control:SetSilent(key)
    end
end

function Window:ClosePopup()
    if self.PopupClose then
        local close = self.PopupClose
        self.PopupClose = nil
        close()
    end
end

function Window:SetVisible(value, initial)
    if self.Dead then
        return
    end
    if self.Open == value and not initial then
        return
    end
    self.Open = value
    Background.sync(self)
    self.VisibilityVersion += 1
    self.UpdateAccent()

    local version = self.VisibilityVersion
    self:ClosePopup()
    if not value then
        Search.close(self)
        Tooltip.hide(self)
    end
    self.Resizing = nil
    if self.Capturing then
        self.Capturing.Render(self.Capturing:Get())
        self.Capturing = nil
    end

    self.Root.Visible = true
    Cursor.set(self, value)
    local duration = value and OPEN_DURATION or CLOSE_DURATION
    self.Scope:Tween(self.Fade.Alpha, duration, { Value = value and 0 or 1 }, self.ReducedMotion)

    if not value then
        task.delay(self.ReducedMotion and 0 or CLOSE_DURATION, function()
            if not self.Dead and version == self.VisibilityVersion then
                self.Root.Visible = false
            end
        end)
    end
end

local function snapToEdge(value, edges, distance)
    for _, edge in ipairs(edges) do
        if math.abs(value - edge) <= distance then
            return edge
        end
    end
    return value
end

function Window:SnapPosition(snapEdges)
    local viewport, size, anchor = self.Screen.AbsoluteSize, self.Root.AbsoluteSize, self.Root.AnchorPoint
    local position = self.RestPosition
    local x = math.round(position.X.Scale * viewport.X + position.X.Offset - anchor.X * size.X)
    local y = math.round(position.Y.Scale * viewport.Y + position.Y.Offset - anchor.Y * size.Y)

    if not self.AllowOffscreen then
        x = math.clamp(x, EDGE_MARGIN, math.max(EDGE_MARGIN, viewport.X - size.X - EDGE_MARGIN))
        y = math.clamp(y, EDGE_MARGIN, math.max(EDGE_MARGIN, viewport.Y - size.Y - EDGE_MARGIN))
    elseif snapEdges then
        x = snapToEdge(x, { 0, viewport.X - size.X }, self.SnapDistance)
        y = snapToEdge(y, { 0, viewport.Y - size.Y }, self.SnapDistance)
    end

    self.RestPosition = UDim2.fromOffset(x + anchor.X * size.X, y + anchor.Y * size.Y)
    self.Root.Position = self.RestPosition
end

function Window:Fit()
    local viewport = self.Screen.AbsoluteSize
    local margin = self.AllowOffscreen and 0 or FIT_MARGIN
    local width = math.round(math.min(self.Size.X, math.max(1, viewport.X - margin)))
    local height = math.round(math.min(self.Size.Y, math.max(1, viewport.Y - margin)))
    self.Root.Size = UDim2.fromOffset(width, height)
    self:SnapPosition()
    self:Relayout()
end

function Window:GetPosition()
    local position, viewport = self.RestPosition, self.Screen.AbsoluteSize
    return Vector2.new(
        position.X.Scale * viewport.X + position.X.Offset,
        position.Y.Scale * viewport.Y + position.Y.Offset
    )
end

function Window:SetPosition(position, snapEdges)
    assert(typeof(position) == "Vector2", "SetPosition requires Vector2")
    self.RestPosition = UDim2.fromOffset(position.X, position.Y)
    self:SnapPosition(snapEdges)
    return self
end

function Window:SetSize(size, origin)
    assert(typeof(size) == "Vector2", "SetSize requires Vector2")
    local viewport = self.Screen.AbsoluteSize
    origin = origin or self:GetPosition()

    local maxX, maxY
    if self.AllowOffscreen then
        maxX = math.max(1, viewport.X)
        maxY = math.max(1, viewport.Y)
    else
        maxX = math.max(1, viewport.X - math.max(EDGE_MARGIN, origin.X) - EDGE_MARGIN)
        maxY = math.max(1, viewport.Y - math.max(EDGE_MARGIN, origin.Y) - EDGE_MARGIN)
    end

    local width = math.round(math.clamp(size.X, math.min(self.MinSize.X, maxX), maxX))
    local height = math.round(math.clamp(size.Y, math.min(self.MinSize.Y, maxY), maxY))
    self.Size = Vector2.new(width, height)
    self.Root.Size = UDim2.fromOffset(width, height)
    self.RestPosition = UDim2.fromOffset(origin.X, origin.Y)
    self.Root.Position = self.RestPosition
    self:Relayout()
end

function Window:Relayout()
    Chrome.layoutAccent(self)
    for _, page in ipairs(self.Pages) do
        page:Relayout()
    end
    if self.SettingsPage then
        self.SettingsPage:Relayout()
    end
end

function Window:AddTab(name)
    return Page.new(self, name)
end

function Window:StyleTabs()
    for _, item in ipairs(self.Pages) do
        local active = item == self.ActivePage
        item.Line.Visible = active
        item.Button.BackgroundTransparency = active and 0 or 1
        item.Button.TextColor3 = active and Theme.Text or Theme.Muted
    end
end

function Window:SelectTab(page)
    self:ClosePopup()
    local settings = self.SettingsPage
    self.SettingsOpen = settings ~= nil and page == settings
    if not self.SettingsOpen then
        self.LastPage = page
    end
    if settings then
        settings.Frame.Visible = self.SettingsOpen
    end
    for _, item in ipairs(self.Pages) do
        item.Frame.Visible = item == page
    end
    self.ActivePage = page
    self:StyleTabs()
    Chrome.paintSettingsButton(self)
    page:Relayout()
end

function Window:OpenSettings()
    if not self.SettingsOpen then
        self:SelectTab(self.SettingsPage)
    end
    return self
end

function Window:CloseSettings()
    if not self.SettingsOpen then
        return self
    end
    local page = self.LastPage or self.Pages[1]
    if page then
        self:SelectTab(page)
    else
        self:ClosePopup()
        self.SettingsOpen = false
        self.SettingsPage.Frame.Visible = false
        self.ActivePage = nil
        Chrome.paintSettingsButton(self)
    end
    return self
end

function Window:ToggleSettings()
    if self.SettingsOpen then
        return self:CloseSettings()
    end
    return self:OpenSettings()
end

function Window:SetLogoutHandler(callback)
    assert(callback == nil or type(callback) == "function", "Logout handler must be a function")
    Settings.setLogout(self, callback)
    return self
end

local function syncSetting(window, id, value)
    local control = window.Controls[id]
    if control then
        control:SetSilent(value)
    end
end

function Window:SetLockToScreen(locked)
    self.AllowOffscreen = locked ~= true
    syncSetting(self, "UI.LockToScreen", not self.AllowOffscreen)
    self:Fit()
    return self
end

function Window:SetReducedMotion(reduced)
    self.ReducedMotion = reduced == true
    Background.sync(self)
    syncSetting(self, "UI.Animations", not self.ReducedMotion)
    self.UpdateAccent()
    return self
end

function Window:SetRainbowAccent(enabled)
    self.RainbowAccent = enabled == true
    syncSetting(self, "UI.RainbowAccent", self.RainbowAccent)
    self.UpdateAccent()
    return self
end

function Window:RefreshTheme()
    if self.Dead then
        return
    end
    for _, control in pairs(self.Controls) do
        if control.Render and control ~= self.Capturing then
            control.Render(control:Get())
        end
    end
    self.SettingsPage.Controls.sync()
    for _, hook in ipairs(self.ThemeHooks) do
        hook()
    end
    self:StyleTabs()
    Chrome.paintSettingsButton(self)
    self.UpdateAccent()
end

function Window:OnDestroy(callback)
    assert(type(callback) == "function", "OnDestroy requires a function")
    if self.Dead then
        callback()
    else
        table.insert(self.Cleanup, callback)
    end
    return self
end

local function cleanupStep(name, fn)
    local ok, message = pcall(function()
        return Util.withContext(fn)
    end)
    if not ok then
        Util.warn(name .. " cleanup failed: " .. tostring(message))
    end
end

function Window:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    self.Open = false
    self.Capturing = nil
    self.Resizing = nil
    self.LogoutHandler = nil
    self.VisibilityVersion += 1

    cleanupStep("Visibility", function()
        self.Screen.Enabled = false
        self.Root.Visible = false
    end)
    cleanupStep("Config", function()
        self:FlushConfig()
    end)
    cleanupStep("Popup", function()
        self:ClosePopup()
    end)
    self.PopupOwner = nil
    cleanupStep("Search", function()
        Search.close(self)
    end)
    cleanupStep("Notifications", function()
        Notifications.destroy(self)
    end)
    cleanupStep("Cursor", function()
        Cursor.set(self, false)
    end)
    cleanupStep("Theme", function()
        if self.ThemeListener then
            self.ThemeListener()
            self.ThemeListener = nil
        end
    end)
    cleanupStep("Accent", function()
        if self.AccentScope then
            self.AccentScope:Destroy()
            self.AccentScope = nil
        end
    end)
    cleanupStep("Background", function()
        Background.destroy(self)
    end)
    cleanupStep("Signals", function()
        self.Scope:Destroy()
    end)
    cleanupStep("Fade", function()
        self.Fade:Destroy()
    end)
    cleanupStep("Screen", function()
        self.Screen:Destroy()
    end)

    for _, callback in ipairs(self.Cleanup) do
        local ok, message = pcall(callback)
        if not ok then
            Util.warn("Cleanup error: " .. tostring(message))
        end
    end
    table.clear(self.Cleanup)
    table.clear(self.Controls)
    table.clear(self.Keybinds)
end

local protected = {}
for name, method in pairs(Window) do
    if type(method) == "function" and name ~= "new" and name ~= "Destroy" and name ~= "Dispatch" then
        table.insert(protected, name)
    end
end
Util.protect(Window, protected)

return Window
end

__factories["init"] = function()
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")
local Window = __require("Window")
local KeySystem = __require("KeySystem")

local Library = {
    Version = "0.8.1",
    Theme = Theme,
    Themes = Theme.PresetNames,
}

function Library:CreateWindow(options)
    return Window.new(options or {}, Library.Version)
end

function Library:CreateKeySystem(options)
    return Util.withContext(KeySystem.new, self, options)
end

function Library:SetTheme(theme)
    Util.withContext(Theme.apply, theme)
end

function Library:GetTheme()
    return Theme.Preset
end

function Library.FileStorage(path)
    assert(
        type(readfile) == "function" and type(writefile) == "function",
        "File APIs unavailable; supply your own Read/Write adapter"
    )

    local function read()
        if isfile and not isfile(path) then
            return nil
        end
        return readfile(path)
    end

    local function write(json)
        local folder = path:match("^(.*)/[^/]+$")
        if folder and makefolder and (not isfolder or not isfolder(folder)) then
            makefolder(folder)
        end
        writefile(path, json)
    end

    return { Read = read, Write = write }
end

return Library
end

__factories["internal/Cursor"] = function()
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cursor = {}

local owners = {}
local overriding, previousIcon = false, nil
local binding = "Kinoue.Cursor." .. tostring(owners)

local function firstPerson()
    local camera = workspace.CurrentCamera
    if not camera or camera.CameraType == Enum.CameraType.Scriptable then
        return false
    end
    return (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
end

local function onScreen(owner)
    if owner.Dead or not owner.Open or not owner.Screen.Enabled or not owner.Root.Visible then
        return false
    end
    local position, size, viewport = owner.Root.AbsolutePosition, owner.Root.AbsoluteSize, owner.Screen.AbsoluteSize
    return position.X < viewport.X and position.Y < viewport.Y and position.X + size.X > 0 and position.Y + size.Y > 0
end

local function release(inFirstPerson)
    if not overriding then
        return
    end
    if inFirstPerson and UserInputService.MouseIconEnabled then
        UserInputService.MouseIconEnabled = previousIcon
    end
    overriding, previousIcon = false, nil
end

local function update()
    local visible = false
    for owner in pairs(owners) do
        if onScreen(owner) then
            visible = true
            break
        end
    end

    local inFirstPerson = firstPerson()
    if not (visible and inFirstPerson) then
        release(inFirstPerson)
        return
    end

    if not overriding then
        previousIcon = UserInputService.MouseIconEnabled
        overriding = true
    end
    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    if not UserInputService.MouseIconEnabled then
        UserInputService.MouseIconEnabled = true
    end
end

function Cursor.set(owner, open)
    if open then
        if owners[owner] then
            return
        end
        if not next(owners) then
            RunService:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, update)
        end
        owners[owner] = true
        update()
        return
    end

    owners[owner] = nil
    if next(owners) then
        update()
    else
        RunService:UnbindFromRenderStep(binding)
        release(firstPerson())
    end
end

return Cursor
end

__factories["internal/Fade"] = function()
local Util = __require("internal/Util")

local EPSILON = 0.000001

local Fade = {}
Fade.__index = Fade

local function fadedProperties(object)
    local properties = {}
    if object:IsA("GuiObject") then
        table.insert(properties, "BackgroundTransparency")
    end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        table.insert(properties, "TextTransparency")
        table.insert(properties, "TextStrokeTransparency")
    end
    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        table.insert(properties, "ImageTransparency")
    end
    if object:IsA("ScrollingFrame") then
        table.insert(properties, "ScrollBarImageTransparency")
    end
    if object:IsA("UIStroke") then
        table.insert(properties, "Transparency")
    end
    return properties
end

local function replaceBorder(object, entry)
    if not object:IsA("GuiObject") or object.BorderSizePixel <= 0 then
        return
    end
    local stroke = Util.new("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = object.BorderColor3,
        Thickness = object.BorderSizePixel,
        Transparency = 0,
    }, object)
    object.BorderSizePixel = 0
    entry.Scope:Connect(object:GetPropertyChangedSignal("BorderColor3"), function()
        stroke.Color = object.BorderColor3
    end)
end

function Fade.new(screen)
    local self = setmetatable({ Entries = {}, Active = {}, Scope = Util.scope(), Dead = false }, Fade)
    self.Alpha = Util.new("NumberValue", { Value = 0 })

    self.Scope:Connect(screen.DescendantAdded, function(object)
        self:Attach(object)
    end)
    self.Scope:Connect(screen.DescendantRemoving, function(object)
        self:Detach(object)
    end)
    for _, object in ipairs(screen:GetDescendants()) do
        self:Attach(object)
    end
    self.Scope:Connect(self.Alpha:GetPropertyChangedSignal("Value"), function()
        for object, entry in pairs(self.Active) do
            self:RenderObject(object, entry)
        end
    end)

    return self
end

function Fade:Attach(object)
    if self.Entries[object] then
        return
    end
    local properties = fadedProperties(object)
    if #properties == 0 then
        return
    end

    local entry = { Base = {}, Applied = {}, Scope = Util.scope() }
    self.Entries[object] = entry
    replaceBorder(object, entry)

    for _, property in ipairs(properties) do
        entry.Base[property] = object[property]
        entry.Scope:Connect(object:GetPropertyChangedSignal(property), function()
            local current = object[property]
            local applied = entry.Applied[property]
            if applied ~= nil and math.abs(current - applied) <= EPSILON then
                return
            end
            entry.Base[property] = current
            self:RenderObject(object, entry)
        end)
    end

    self:RenderObject(object, entry)
end

function Fade:Detach(object)
    local entry = self.Entries[object]
    if entry then
        entry.Scope:Destroy()
        self.Entries[object] = nil
        self.Active[object] = nil
    end
end

function Fade:RenderObject(object, entry)
    local alpha = self.Alpha.Value
    local active = false
    for property, base in pairs(entry.Base) do
        if base < 1 then
            active = true
            local value = base + (1 - base) * alpha
            entry.Applied[property] = value
            if math.abs(object[property] - value) > EPSILON then
                object[property] = value
            end
        else
            entry.Applied[property] = 1
        end
    end
    self.Active[object] = active and entry or nil
end

function Fade:Set(alpha)
    self.Alpha.Value = alpha
end

function Fade:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    self.Scope:Destroy()
    for _, entry in pairs(self.Entries) do
        entry.Scope:Destroy()
    end
    table.clear(self.Entries)
    table.clear(self.Active)
    self.Alpha:Destroy()
end

return Fade
end

__factories["internal/Gif"] = function()
local Gif = {}
local band, shift, left, bor = bit32.band, bit32.rshift, bit32.lshift, bit32.bor

function Gif.parse(data, checkpoint)
    assert(
        type(data) == "string" and #data >= 13 and (data:sub(1, 6) == "GIF89a" or data:sub(1, 6) == "GIF87a"),
        "Invalid GIF header"
    )
    assert(#data <= 32 * 1024 * 1024, "GIF exceeds the 32 MB file limit")
    local at = 7
    local function byte()
        assert(at <= #data, "Truncated GIF")
        local value = string.byte(data, at)
        at += 1
        return value
    end
    local function word()
        local low = byte()
        return low + byte() * 256
    end
    local function palette(size)
        local colors = table.create(size)
        for index = 1, size do
            local r, g, b = byte(), byte(), byte()
            colors[index] = r + g * 256 + b * 65536 + 0xFF000000
        end
        return colors
    end
    local function blocks()
        local values = {}
        while true do
            local size = byte()
            if size == 0 then
                break
            end
            assert(at + size - 1 <= #data, "Truncated GIF block")
            values[#values + 1] = data:sub(at, at + size - 1)
            at += size
        end
        if checkpoint then
            checkpoint()
        end
        return table.concat(values)
    end
    local width, height = word(), word()
    assert(width > 0 and height > 0 and width * height <= 4194304, "GIF canvas exceeds 4 million pixels")
    local packed, background = byte(), byte()
    byte()
    local global = band(packed, 128) ~= 0 and palette(2 ^ (band(packed, 7) + 1)) or nil
    local result = {
        Width = width,
        Height = height,
        Frames = {},
        Background = global and global[background + 1] or 0,
        Duration = 0,
    }
    local control = {}
    local work = 0
    while at <= #data do
        local marker = byte()
        if marker == 0x3B then
            break
        end
        if marker == 0x21 then
            local label = byte()
            if label == 0xF9 then
                assert(byte() == 4, "Invalid GIF control block")
                local flags, delay = byte(), word()
                local transparent = byte()
                assert(byte() == 0, "Invalid GIF control terminator")
                control = {
                    Disposal = band(shift(flags, 2), 7),
                    Transparent = band(flags, 1) ~= 0 and transparent or nil,
                    Delay = delay <= 1 and 0.1 or delay / 100,
                }
            else
                blocks()
                if label == 0x01 then
                    control = {}
                end
            end
        elseif marker == 0x2C then
            local frame = {
                Left = word(),
                Top = word(),
                Width = word(),
                Height = word(),
                Disposal = control.Disposal or 0,
                Transparent = control.Transparent,
                Delay = control.Delay or 0.1,
            }
            assert(
                frame.Width > 0 and frame.Height > 0 and frame.Width * frame.Height <= 4194304,
                "Invalid GIF frame dimensions"
            )
            work += frame.Width * frame.Height
            assert(work <= 200000000, "GIF exceeds the decoding work limit")
            local flags = byte()
            frame.Interlaced = band(flags, 64) ~= 0
            frame.Palette = band(flags, 128) ~= 0 and palette(2 ^ (band(flags, 7) + 1)) or global
            assert(frame.Palette, "GIF has no color table")
            frame.CodeSize = byte()
            assert(frame.CodeSize >= 1 and frame.CodeSize <= 8, "Invalid GIF LZW code size")
            frame.Data = blocks()
            result.Duration += frame.Delay
            frame.End = result.Duration
            result.Frames[#result.Frames + 1] = frame
            assert(#result.Frames <= 300, "GIF exceeds the 300 frame limit")
            control = {}
        else
            error("Invalid GIF block")
        end
    end
    assert(#result.Frames > 0, "GIF contains no frames")
    return result
end

local function decompress(frame, checkpoint)
    local data, at, bits, value = frame.Data, 1, 0, 0
    local size = frame.CodeSize + 1
    local clear = 2 ^ frame.CodeSize
    local ending, available = clear + 1, clear + 2
    local prefix, suffix = table.create(4096), table.create(4096)
    local stack, output = buffer.create(4097), buffer.create(frame.Width * frame.Height)
    local used, previous, first = 0, nil, nil
    local count = frame.Width * frame.Height
    local operations, lastYield = 0, 0
    local function code()
        while bits < size do
            if at > #data then
                return nil
            end
            value = bor(value, left(string.byte(data, at), bits))
            bits += 8
            at += 1
        end
        local result = band(value, 2 ^ size - 1)
        value = shift(value, size)
        bits -= size
        return result
    end
    while true do
        local current = code()
        if current == nil then
            assert(used == count, "Truncated GIF pixels")
            break
        end
        if current == ending then
            break
        end
        if current == clear then
            size, available, previous = frame.CodeSize + 1, clear + 2, nil
        elseif previous == nil then
            assert(current < clear and used < count, "Invalid GIF LZW stream")
            buffer.writeu8(output, used, current)
            used += 1
            previous, first = current, current
        else
            local original, length = current, 0
            if current == available then
                buffer.writeu8(stack, length, first)
                length += 1
                current = previous
            else
                assert(current < available, "Invalid GIF LZW code")
            end
            while current >= clear do
                assert(prefix[current] ~= nil and length < 4096, "Invalid GIF LZW dictionary")
                buffer.writeu8(stack, length, suffix[current])
                length += 1
                current = prefix[current]
            end
            first = current
            buffer.writeu8(stack, length, current)
            length += 1
            assert(used + length <= count, "GIF pixels exceed frame bounds")
            for index = length - 1, 0, -1 do
                buffer.writeu8(output, used, buffer.readu8(stack, index))
                used += 1
            end
            if available < 4096 then
                prefix[available], suffix[available] = previous, first
                available += 1
                if available == 2 ^ size and size < 12 then
                    size += 1
                end
            end
            previous = original
        end
        operations += 1
        if checkpoint and (operations % 2048 == 0 or used - lastYield >= 8192) then
            checkpoint()
            lastYield = used
        end
    end
    assert(used == count, "GIF frame has incomplete pixels")
    return output
end

function Gif.render(gif, width, height, emit, checkpoint)
    assert(width > 0 and height > 0 and width <= gif.Width and height <= gif.Height, "Invalid GIF output dimensions")
    local canvas = buffer.create(width * height * 4)
    local background = gif.Frames[1].Transparent ~= nil and 0 or gif.Background
    if background ~= 0 then
        for index = 0, width * height - 1 do
            buffer.writeu32(canvas, index * 4, background)
        end
    end
    local saved, previous
    local function bounds(frame)
        return math.max(0, math.ceil(frame.Left * width / gif.Width)),
            math.max(0, math.ceil(frame.Top * height / gif.Height)),
            math.min(width - 1, math.ceil((frame.Left + frame.Width) * width / gif.Width) - 1),
            math.min(height - 1, math.ceil((frame.Top + frame.Height) * height / gif.Height) - 1)
    end
    for index, frame in ipairs(gif.Frames) do
        if previous and previous.Disposal == 2 then
            local x0, y0, x1, y1 = bounds(previous)
            local color = previous.Transparent ~= nil and 0 or gif.Background
            for y = y0, y1 do
                for x = x0, x1 do
                    buffer.writeu32(canvas, (y * width + x) * 4, color)
                end
                if y % 16 == 0 and checkpoint then
                    checkpoint()
                end
            end
        elseif previous and previous.Disposal == 3 then
            buffer.copy(canvas, 0, saved)
        end
        if frame.Disposal == 3 then
            saved = saved or buffer.create(buffer.len(canvas))
            buffer.copy(saved, 0, canvas)
        end
        local pixels = decompress(frame, checkpoint)
        local rows = {}
        if frame.Interlaced then
            local row = 0
            for _, pass in ipairs({ { 0, 8 }, { 4, 8 }, { 2, 4 }, { 1, 2 } }) do
                for y = pass[1], frame.Height - 1, pass[2] do
                    rows[y] = row
                    row += 1
                end
            end
        end
        local x0, y0, x1, y1 = bounds(frame)
        for y = y0, y1 do
            local sourceY = math.floor(y * gif.Height / height) - frame.Top
            local row = frame.Interlaced and rows[sourceY] or sourceY
            for x = x0, x1 do
                local sourceX = math.floor(x * gif.Width / width) - frame.Left
                local color = buffer.readu8(pixels, row * frame.Width + sourceX)
                if color ~= frame.Transparent then
                    buffer.writeu32(
                        canvas,
                        (y * width + x) * 4,
                        assert(frame.Palette[color + 1], "Invalid GIF palette index")
                    )
                end
            end
            if y % 16 == 0 and checkpoint then
                checkpoint()
            end
        end
        emit(canvas, index)
        previous = frame
        if checkpoint then
            checkpoint()
        end
    end
end

return Gif
end

__factories["internal/Icons"] = function()
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local GEAR_TEETH = 8
local SPIN_DURATION = 0.2

local Icons = {}

local Icon = {}
Icon.__index = Icon

local function resolve(color)
    if Theme.isToken(color) then
        return Theme[color.Key]
    end
    return color
end

function Icon:SetColor(color)
    color = resolve(color)
    self.Color = color
    for _, part in ipairs(self.Fills) do
        part.BackgroundColor3 = color
    end
    for _, stroke in ipairs(self.Strokes) do
        stroke.Color = color
    end
    return self
end

function Icon:SetRotation(window, rotation, instant)
    window.Scope:Tween(self.Root, SPIN_DURATION, { Rotation = rotation }, instant or window.ReducedMotion)
    return self
end

local function newIcon(parent, size, props)
    local root = Util.frame(parent, {
        Name = props.Name or "Icon",
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        Position = props.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
        Rotation = 0,
        BackgroundTransparency = 1,
        ZIndex = props.ZIndex,
    })
    return setmetatable({ Root = root, Fills = {}, Strokes = {} }, Icon)
end

function Icons.gear(parent, size, props)
    props = props or {}
    local icon = newIcon(parent, size, props)
    local ringSize = math.max(4, math.floor(size * 0.5))
    local thickness = math.max(1, math.floor(size / 8))
    local ring = Util.frame(icon.Root, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(ringSize, ringSize),
        BackgroundTransparency = 1,
        ZIndex = props.ZIndex,
    })
    Util.new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    table.insert(
        icon.Strokes,
        Util.new("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = thickness,
        }, ring)
    )

    local radius = size * 0.4
    local toothWidth = math.max(2, math.floor(size * 0.19))
    local toothHeight = math.max(2, math.floor(size * 0.25))
    for index = 0, GEAR_TEETH - 1 do
        local angle = index * (360 / GEAR_TEETH)
        local radians = math.rad(angle)
        table.insert(
            icon.Fills,
            Util.frame(icon.Root, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, math.sin(radians) * radius, 0.5, -math.cos(radians) * radius),
                Size = UDim2.fromOffset(toothWidth, toothHeight),
                Rotation = angle,
                ZIndex = props.ZIndex,
            })
        )
    end

    return icon:SetColor(props.Color or Theme.Muted)
end

function Icons.chevron(parent, size, props)
    props = props or {}
    local icon = newIcon(parent, size, props)
    local length = math.max(3, math.floor(size * 0.6))
    local thickness = math.max(1, math.floor(size / 5))
    local offset = length * math.cos(math.rad(45)) / 2
    for _, entry in ipairs({ { -offset, 45 }, { offset, -45 } }) do
        table.insert(
            icon.Fills,
            Util.frame(icon.Root, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, entry[1]),
                Size = UDim2.fromOffset(length, thickness),
                Rotation = entry[2],
                ZIndex = props.ZIndex,
            })
        )
    end
    return icon:SetColor(props.Color or Theme.Muted)
end

function Icons.warning(parent, size, props)
    props = props or {}
    local icon = newIcon(parent, size, props)
    local side = size
    local height = side * math.sqrt(3) / 2
    local thickness = math.max(1, math.floor(size / 9))
    local edges = {
        { 0, height / 2, 0 },
        { -side / 4, 0, -60 },
        { side / 4, 0, 60 },
    }
    for _, edge in ipairs(edges) do
        table.insert(
            icon.Fills,
            Util.frame(icon.Root, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, edge[1], 0.5, edge[2]),
                Size = UDim2.fromOffset(side, thickness),
                Rotation = edge[3],
                ZIndex = props.ZIndex,
            })
        )
    end
    local mark = math.max(1, math.floor(size / 8))
    table.insert(
        icon.Fills,
        Util.frame(icon.Root, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, -height * 0.05),
            Size = UDim2.fromOffset(mark, math.max(2, math.floor(height * 0.35))),
            ZIndex = props.ZIndex,
        })
    )
    table.insert(
        icon.Fills,
        Util.frame(icon.Root, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, height * 0.3),
            Size = UDim2.fromOffset(mark, mark),
            ZIndex = props.ZIndex,
        })
    )
    return icon:SetColor(props.Color or Theme.Danger)
end

function Icons.search(parent, size, props)
    props = props or {}
    local icon = newIcon(parent, size, props)
    local lens = math.max(4, math.floor(size * 0.55))
    local thickness = math.max(1, math.floor(size / 8))
    local ring = Util.frame(icon.Root, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, -size * 0.1, 0.5, -size * 0.1),
        Size = UDim2.fromOffset(lens, lens),
        BackgroundTransparency = 1,
        ZIndex = props.ZIndex,
    })
    Util.new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    table.insert(
        icon.Strokes,
        Util.new("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = thickness,
        }, ring)
    )
    table.insert(
        icon.Fills,
        Util.frame(icon.Root, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, size * 0.25, 0.5, size * 0.25),
            Size = UDim2.fromOffset(math.max(3, math.floor(size * 0.35)), thickness + 1),
            Rotation = 45,
            ZIndex = props.ZIndex,
        })
    )
    return icon:SetColor(props.Color or Theme.Muted)
end

return Icons
end

__factories["internal/LocalMedia"] = function()
local HttpService = game:GetService("HttpService")
local Gif = __require("internal/Gif")
local Png = __require("internal/Png")

local Media = {}
local ROOT = "Kinoue/backgrounds"
local VERSION = 1
local PIXELS = 8388608

local function dimensions(data, png)
    local function word(at)
        assert(at + 1 <= #data, "Truncated image header")
        return string.byte(data, at) * 256 + string.byte(data, at + 1)
    end
    local width, height
    if png then
        assert(#data >= 33 and data:sub(13, 16) == "IHDR", "Invalid PNG header")
        width, height = word(17) * 65536 + word(19), word(21) * 65536 + word(23)
    else
        local at = 3
        while at <= #data do
            assert(string.byte(data, at) == 255, "Invalid JPEG header")
            while string.byte(data, at) == 255 do
                at += 1
            end
            local marker = string.byte(data, at)
            at += 1
            assert(marker and marker ~= 0xDA and marker ~= 0xD9, "JPEG has no dimensions")
            if marker ~= 0x01 and (marker < 0xD0 or marker > 0xD7) then
                local size = word(at)
                assert(size >= 2 and at + size - 1 <= #data, "Truncated JPEG segment")
                if marker >= 0xC0 and marker <= 0xCF and marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
                    assert(size >= 8, "Invalid JPEG frame")
                    height, width = word(at + 3), word(at + 5)
                    break
                end
                at += size
            end
        end
    end
    assert(
        width and height and width > 0 and height > 0 and width <= 4096 and height <= 4096,
        "Background images must be at most 4096 pixels per side"
    )
    return width, height
end

local function folder(path)
    if type(isfolder) == "function" and isfolder(path) then
        return
    end
    local ok, message = pcall(makefolder, path)
    if not ok and type(isfolder) == "function" and not isfolder(path) then
        error(message)
    end
end

local function valid(meta)
    if
        type(meta) ~= "table"
        or meta.Version ~= VERSION
        or type(meta.Frames) ~= "table"
        or type(meta.Pages) ~= "table"
    then
        return false
    end
    if
        type(meta.Width) ~= "number"
        or meta.Width < 1
        or meta.Width > 512
        or meta.Width % 1 ~= 0
        or type(meta.Height) ~= "number"
        or meta.Height < 1
        or meta.Height > 512
        or meta.Height % 1 ~= 0
    then
        return false
    end
    if
        #meta.Frames < 1
        or #meta.Frames > 300
        or #meta.Pages < 1
        or #meta.Pages > 32
        or meta.Width * meta.Height * #meta.Frames > PIXELS
    then
        return false
    end
    local previous = 0
    for _, page in ipairs(meta.Pages) do
        if
            type(page) ~= "table"
            or type(page.Width) ~= "number"
            or page.Width < 1
            or page.Width > 1024
            or page.Width % 1 ~= 0
            or type(page.Height) ~= "number"
            or page.Height < 1
            or page.Height > 1024
            or page.Height % 1 ~= 0
        then
            return false
        end
    end
    for _, frame in ipairs(meta.Frames) do
        if
            type(frame) ~= "table"
            or type(frame.Page) ~= "number"
            or frame.Page % 1 ~= 0
            or not meta.Pages[frame.Page]
            or type(frame.X) ~= "number"
            or type(frame.Y) ~= "number"
            or frame.X < 0
            or frame.Y < 0
            or frame.X % 1 ~= 0
            or frame.Y % 1 ~= 0
            or frame.X + meta.Width > meta.Pages[frame.Page].Width
            or frame.Y + meta.Height > meta.Pages[frame.Page].Height
            or type(frame.End) ~= "number"
            or frame.End ~= frame.End
            or frame.End <= previous
            or frame.End > 200000
        then
            return false
        end
        previous = frame.End
    end
    return true
end

local function register(meta, directory, asset, checkpoint)
    local images = {}
    for index in ipairs(meta.Pages) do
        if checkpoint then
            checkpoint()
        end
        local path = directory .. "/" .. index .. ".png"
        assert(type(isfile) ~= "function" or isfile(path), "Cached GIF page missing")
        images[index] = asset(path)
        assert(type(images[index]) == "string" and images[index] ~= "", "Executor did not register the GIF page")
    end
    local frames = {}
    for _, frame in ipairs(meta.Frames) do
        frames[#frames + 1] = {
            Image = images[frame.Page],
            X = frame.X,
            Y = frame.Y,
            Width = meta.Width,
            Height = meta.Height,
            End = frame.End,
        }
    end
    return {
        Kind = "GIF",
        Width = meta.Width,
        Height = meta.Height,
        Frames = frames,
        Pages = images,
        Duration = frames[#frames].End,
    }
end

function Media.load(path, checkpoint)
    local asset = type(getcustomasset) == "function" and getcustomasset or getsynasset
    assert(
        type(readfile) == "function" and type(asset) == "function",
        "Local backgrounds require executor readfile and getcustomasset functions"
    )
    assert(type(path) == "string" and path ~= "" and not path:find("%z"), "Enter a local image or GIF path")
    local read, data = pcall(readfile, path)
    assert(
        read and type(data) == "string",
        "Executor could not read this file. Use a path accessible to its workspace."
    )
    assert(#data > 0 and #data <= 33554432, "Background file must be between 1 byte and 32 MB")
    if checkpoint then
        checkpoint()
    end
    local gif = data:sub(1, 6) == "GIF89a" or data:sub(1, 6) == "GIF87a"
    local png = data:sub(1, 8) == "\137PNG\13\10\26\10"
    local jpeg = data:sub(1, 3) == "\255\216\255"
    assert(gif or png or jpeg, "Choose a PNG, JPEG, or GIF file")
    if not gif then
        local width, height = dimensions(data, png)
        local image
        if type(writefile) == "function" and type(makefolder) == "function" then
            folder("Kinoue")
            folder(ROOT)
            local cached = ROOT .. "/image-" .. Png.hash(data, checkpoint) .. (png and ".png" or ".jpg")
            if type(isfile) ~= "function" or not isfile(cached) then
                writefile(cached, data)
            end
            image = asset(cached)
        else
            image = asset(path)
        end
        assert(type(image) == "string" and image ~= "", "Executor did not register the image")
        return {
            Kind = "Image",
            Width = width,
            Height = height,
            Pages = { image },
            Frames = { { Image = image, X = 0, Y = 0, Width = 0, Height = 0, End = 0 } },
            Duration = 0,
        }
    end
    assert(
        type(writefile) == "function" and type(makefolder) == "function",
        "GIF backgrounds require executor writefile and makefolder functions"
    )
    folder("Kinoue")
    folder(ROOT)
    local directory = ROOT .. "/gif" .. VERSION .. "-" .. Png.hash(data, checkpoint)
    folder(directory)
    local manifest = directory .. "/frames.json"
    local cached, meta = pcall(function()
        local value = HttpService:JSONDecode(readfile(manifest))
        assert(valid(value), "Invalid GIF cache")
        return value
    end)
    if cached then
        local loaded, result = pcall(register, meta, directory, asset, checkpoint)
        if loaded then
            result.Cached = true
            return result
        end
        if checkpoint then
            checkpoint()
        end
    end
    local source = Gif.parse(data, checkpoint)
    local scale = math.min(
        1,
        512 / source.Width,
        512 / source.Height,
        math.sqrt(PIXELS / (#source.Frames * source.Width * source.Height))
    )
    local width, height = math.max(1, math.floor(source.Width * scale)), math.max(1, math.floor(source.Height * scale))
    local cellWidth, cellHeight = width + 2, height + 2
    local columns, rows = math.floor(1024 / cellWidth), math.floor(1024 / cellHeight)
    local perPage = columns * rows
    meta = { Version = VERSION, Width = width, Height = height, Pages = {}, Frames = {} }
    local raw, pageWidth, pageHeight, stride, page
    Gif.render(source, width, height, function(canvas, index)
        local slot = (index - 1) % perPage
        if slot == 0 then
            page = #meta.Pages + 1
            local remaining = math.min(perPage, #source.Frames - index + 1)
            pageWidth = math.min(columns, remaining) * cellWidth
            pageHeight = math.ceil(remaining / columns) * cellHeight
            stride = pageWidth * 4 + 1
            raw = buffer.create(stride * pageHeight)
            meta.Pages[page] = { Width = pageWidth, Height = pageHeight }
        end
        local x, y = slot % columns * cellWidth, math.floor(slot / columns) * cellHeight
        for row = 0, height - 1 do
            local destination = (y + row + 1) * stride + (x + 1) * 4 + 1
            buffer.copy(raw, destination, canvas, row * width * 4, width * 4)
            buffer.copy(raw, destination - 4, canvas, row * width * 4, 4)
            buffer.copy(raw, destination + width * 4, canvas, (row * width + width - 1) * 4, 4)
        end
        buffer.copy(raw, y * stride + x * 4 + 1, raw, (y + 1) * stride + x * 4 + 1, cellWidth * 4)
        buffer.copy(raw, (y + height + 1) * stride + x * 4 + 1, raw, (y + height) * stride + x * 4 + 1, cellWidth * 4)
        meta.Frames[index] = { Page = page, X = x + 1, Y = y + 1, End = source.Frames[index].End }
        if slot == perPage - 1 or index == #source.Frames then
            local encoded = Png.encode(pageWidth, pageHeight, raw, checkpoint)
            if checkpoint then
                checkpoint()
            end
            writefile(directory .. "/" .. page .. ".png", encoded)
            raw = nil
        end
    end, checkpoint)
    if checkpoint then
        checkpoint()
    end
    writefile(manifest, HttpService:JSONEncode(meta))
    return register(meta, directory, asset, checkpoint)
end

return Media
end

__factories["internal/Model"] = function()
local Model = {}

function Model.number(value, minimum, maximum, step)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then
        number = minimum
    end
    number = math.clamp(number, minimum, maximum)
    if step and step > 0 then
        number = minimum + math.round((number - minimum) / step) * step
    end
    return math.clamp(number, minimum, maximum)
end

function Model.options(values)
    local result, seen = {}, {}
    for _, value in ipairs(values) do
        local option = type(value) == "table" and value or { Value = value, Label = tostring(value) }
        assert(option.Value ~= nil, "Dropdown option requires Value")
        assert(not seen[option.Value], "Duplicate dropdown value: " .. tostring(option.Value))
        seen[option.Value] = true
        table.insert(result, {
            Value = option.Value,
            Label = option.Label or tostring(option.Value),
            Meta = option.Meta,
        })
    end
    return result
end

function Model.control(initial, normalize, callback)
    local control = { Value = normalize(initial), Callback = callback }

    function control:Get()
        return self.Value
    end

    function control:Set(value, silent)
        local nextValue = normalize(value)
        local changed = nextValue ~= self.Value
        self.Value = nextValue
        if self.Render and (changed or value ~= nextValue) then
            self.Render(nextValue)
        end
        if changed and not silent and self.Callback then
            self.Callback(nextValue)
        end
        return self
    end

    function control:SetSilent(value)
        return self:Set(value, true)
    end

    control.RawSet = control.SetSilent

    function control:SetCallback(fn)
        self.Callback = fn
        return self
    end

    return control
end

return Model
end

__factories["internal/Mount"] = function()
local CORE_IDENTITY = 8

local Mount = {}

local function protector()
    if type(protect_gui) == "function" then
        return protect_gui
    end
    if type(syn) == "table" and type(syn.protect_gui) == "function" then
        return syn.protect_gui
    end
    return nil
end

local function identityHelpers()
    local getIdentity = type(getthreadidentity) == "function" and getthreadidentity
        or (type(syn) == "table" and syn.get_thread_identity)
    local setIdentity = type(setthreadidentity) == "function" and setthreadidentity
        or (type(syn) == "table" and syn.set_thread_identity)
    if type(getIdentity) == "function" and type(setIdentity) == "function" then
        return getIdentity, setIdentity
    end
    return nil, nil
end

local function attach(screen, replaceExisting)
    local core = game:GetService("CoreGui")
    if replaceExisting then
        for _, existing in ipairs(core:GetChildren()) do
            if existing ~= screen and existing:IsA("ScreenGui") and existing.Name == screen.Name then
                existing:Destroy()
            end
        end
    end
    screen.Parent = core
end

function Mount.core(screen, replaceExisting)
    local protect = protector()
    if protect then
        pcall(protect, screen)
    end

    local ok, message = pcall(attach, screen, replaceExisting)
    if ok then
        return
    end

    local getIdentity, setIdentity = identityHelpers()
    if getIdentity then
        local read, identity = pcall(getIdentity)
        if read then
            if pcall(setIdentity, CORE_IDENTITY) then
                ok, message = pcall(attach, screen, replaceExisting)
            end
            local restored, restoreError = pcall(setIdentity, identity)
            if not restored then
                screen:Destroy()
                error("[Kinoue] Failed to restore thread identity: " .. tostring(restoreError), 2)
            end
            if ok then
                return
            end
        end
    end

    screen:Destroy()
    error("[Kinoue] CoreGui mount failed. This client must allow CoreGui access: " .. tostring(message), 2)
end

return Mount
end

__factories["internal/Png"] = function()
local Png = {}
local xor, shift, band = bit32.bxor, bit32.rshift, bit32.band
local crcTable = table.create(256)
for index = 0, 255 do
    local value = index
    for _ = 1, 8 do
        value = band(value, 1) == 1 and xor(shift(value, 1), 0xEDB88320) or shift(value, 1)
    end
    crcTable[index + 1] = value
end

local function big(value)
    return string.char(
        band(shift(value, 24), 255),
        band(shift(value, 16), 255),
        band(shift(value, 8), 255),
        band(value, 255)
    )
end

local function crc(data, value, checkpoint)
    value = value or 0xFFFFFFFF
    for first = 1, #data, 16384 do
        for index = first, math.min(#data, first + 16383) do
            value = xor(shift(value, 8), crcTable[xor(band(value, 255), string.byte(data, index)) + 1])
        end
        if checkpoint then
            checkpoint()
        end
    end
    return value
end

function Png.hash(data, checkpoint)
    local second = 2166136261
    for first = 1, #data, 16384 do
        for index = first, math.min(#data, first + 16383) do
            second = xor(second, string.byte(data, index))
            second = (second * 403 + bit32.lshift(second, 24)) % 4294967296
        end
        if checkpoint then
            checkpoint()
        end
    end
    return string.format("%08x%08x-%x", bit32.bnot(crc(data, nil, checkpoint)), second, #data)
end

local function chunk(kind, data, checkpoint)
    local checksum = bit32.bnot(crc(data, crc(kind), checkpoint))
    return big(#data) .. kind .. data .. big(checksum)
end

function Png.encode(width, height, raw, checkpoint)
    assert(width > 0 and height > 0 and buffer.len(raw) == (width * 4 + 1) * height, "Invalid PNG dimensions")
    local data = buffer.tostring(raw)
    local blocks = { string.char(0x78, 0x01) }
    local a, b = 1, 0
    for first = 1, #data, 5552 do
        for index = first, math.min(#data, first + 5551) do
            a += string.byte(data, index)
            b += a
        end
        a, b = a % 65521, b % 65521
        if checkpoint then
            checkpoint()
        end
    end
    for first = 1, #data, 65535 do
        local length = math.min(65535, #data - first + 1)
        local inverse = 65535 - length
        blocks[#blocks + 1] = string.char(
            first + length > #data and 1 or 0,
            length % 256,
            math.floor(length / 256),
            inverse % 256,
            math.floor(inverse / 256)
        ) .. string.sub(data, first, first + length - 1)
        if checkpoint then
            checkpoint()
        end
    end
    blocks[#blocks + 1] = big(b * 65536 + a)
    local header = big(width) .. big(height) .. string.char(8, 6, 0, 0, 0)
    return "\137PNG\13\10\26\10"
        .. chunk("IHDR", header)
        .. chunk("IDAT", table.concat(blocks), checkpoint)
        .. chunk("IEND", "")
end

return Png
end

__factories["internal/Theme"] = function()
local COLOR_KEYS =
    { "Background", "Panel", "Input", "Hover", "Outline", "Text", "Muted", "Accent", "Selected", "Danger" }

local Theme = {
    Font = Enum.Font.Code,
    TextSize = 14,
    SmallSize = 12,
    RowHeight = 23,
    Gap = 6,
    ControlGap = 2,
    Padding = 6,
    DisabledTransparency = 0.55,
    Preset = "Dark",
    ColorKeys = COLOR_KEYS,
}

Theme.Presets = {
    Dark = {
        Background = Color3.fromRGB(20, 20, 20),
        Panel = Color3.fromRGB(28, 28, 28),
        Input = Color3.fromRGB(28, 28, 28),
        Hover = Color3.fromRGB(38, 38, 38),
        Outline = Color3.fromRGB(50, 50, 50),
        Text = Color3.fromRGB(232, 232, 232),
        Muted = Color3.fromRGB(171, 171, 171),
        Accent = Color3.fromRGB(57, 128, 233),
        Selected = Color3.fromRGB(35, 50, 74),
        Danger = Color3.fromRGB(235, 87, 87),
    },
    Midnight = {
        Background = Color3.fromRGB(14, 16, 24),
        Panel = Color3.fromRGB(20, 23, 34),
        Input = Color3.fromRGB(20, 23, 34),
        Hover = Color3.fromRGB(30, 34, 48),
        Outline = Color3.fromRGB(42, 47, 66),
        Text = Color3.fromRGB(226, 230, 240),
        Muted = Color3.fromRGB(150, 158, 180),
        Accent = Color3.fromRGB(124, 92, 255),
        Selected = Color3.fromRGB(40, 34, 72),
        Danger = Color3.fromRGB(240, 92, 112),
    },
    Ocean = {
        Background = Color3.fromRGB(12, 22, 28),
        Panel = Color3.fromRGB(17, 30, 38),
        Input = Color3.fromRGB(17, 30, 38),
        Hover = Color3.fromRGB(26, 42, 52),
        Outline = Color3.fromRGB(36, 56, 68),
        Text = Color3.fromRGB(225, 238, 242),
        Muted = Color3.fromRGB(150, 175, 185),
        Accent = Color3.fromRGB(38, 190, 190),
        Selected = Color3.fromRGB(20, 60, 64),
        Danger = Color3.fromRGB(236, 98, 98),
    },
    Rose = {
        Background = Color3.fromRGB(24, 18, 22),
        Panel = Color3.fromRGB(33, 25, 30),
        Input = Color3.fromRGB(33, 25, 30),
        Hover = Color3.fromRGB(46, 35, 42),
        Outline = Color3.fromRGB(64, 48, 58),
        Text = Color3.fromRGB(242, 230, 236),
        Muted = Color3.fromRGB(185, 160, 172),
        Accent = Color3.fromRGB(233, 84, 128),
        Selected = Color3.fromRGB(70, 32, 46),
        Danger = Color3.fromRGB(245, 96, 96),
    },
    Forest = {
        Background = Color3.fromRGB(16, 22, 18),
        Panel = Color3.fromRGB(23, 31, 25),
        Input = Color3.fromRGB(23, 31, 25),
        Hover = Color3.fromRGB(33, 44, 36),
        Outline = Color3.fromRGB(46, 61, 50),
        Text = Color3.fromRGB(228, 240, 230),
        Muted = Color3.fromRGB(160, 180, 164),
        Accent = Color3.fromRGB(88, 190, 110),
        Selected = Color3.fromRGB(32, 62, 40),
        Danger = Color3.fromRGB(232, 96, 86),
    },
    Light = {
        Background = Color3.fromRGB(240, 240, 242),
        Panel = Color3.fromRGB(250, 250, 252),
        Input = Color3.fromRGB(255, 255, 255),
        Hover = Color3.fromRGB(228, 228, 232),
        Outline = Color3.fromRGB(205, 205, 210),
        Text = Color3.fromRGB(30, 30, 34),
        Muted = Color3.fromRGB(110, 110, 118),
        Accent = Color3.fromRGB(40, 110, 220),
        Selected = Color3.fromRGB(215, 228, 250),
        Danger = Color3.fromRGB(205, 45, 45),
    },
}

Theme.PresetNames = { "Dark", "Midnight", "Ocean", "Rose", "Forest", "Light" }

for _, key in ipairs(COLOR_KEYS) do
    Theme[key] = Theme.Presets.Dark[key]
end

local Token = {}
Token.__index = Token

Theme.Color = setmetatable({}, {
    __index = function(cache, key)
        assert(table.find(COLOR_KEYS, key), "Unknown theme color: " .. tostring(key))
        local token = setmetatable({ Key = key }, Token)
        rawset(cache, key, token)
        return token
    end,
})

local bindings = setmetatable({}, { __mode = "k" })
local listeners = {}

function Theme.isToken(value)
    return type(value) == "table" and getmetatable(value) == Token
end

function Theme.bind(object, property, key)
    local properties = bindings[object]
    if not properties then
        properties = {}
        bindings[object] = properties
    end
    properties[property] = key
end

function Theme.onChanged(listener)
    table.insert(listeners, listener)
    return function()
        local index = table.find(listeners, listener)
        if index then
            table.remove(listeners, index)
        end
    end
end

local function resolve(values)
    if type(values) == "string" then
        return assert(Theme.Presets[values], "Unknown theme preset: " .. values), values
    end
    assert(type(values) == "table", "SetTheme requires a preset name or a table of colors")
    return values, "Custom"
end

function Theme.apply(values)
    local colors, preset = resolve(values)
    local previous = {}
    for _, key in ipairs(COLOR_KEYS) do
        previous[key] = Theme[key]
        local color = colors[key]
        if color ~= nil then
            assert(typeof(color) == "Color3", "Theme color " .. key .. " requires Color3")
            Theme[key] = color
        end
    end
    Theme.Preset = preset

    for object, properties in pairs(bindings) do
        if object.Parent == nil then
            bindings[object] = nil
        else
            for property, key in pairs(properties) do
                if object[property] == previous[key] then
                    object[property] = Theme[key]
                end
            end
        end
    end

    for _, listener in ipairs(table.clone(listeners)) do
        listener()
    end
end

return Theme
end

__factories["internal/Tooltip"] = function()
local Theme = __require("internal/Theme")
local Util = __require("internal/Util")

local HEIGHT = 20
local PADDING = 6
local OFFSET = 4
local SCREEN_MARGIN = 8

local Tooltip = {}

local function build(window)
    local frame = Util.frame(window.Screen, {
        Name = "Tooltip",
        Size = UDim2.fromOffset(0, HEIGHT),
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ZIndex = 80,
        Visible = false,
    })
    local label = Util.label(frame, "", {
        Position = UDim2.fromOffset(PADDING, 0),
        Size = UDim2.new(1, -2 * PADDING, 1, 0),
        TextSize = Theme.SmallSize,
        ZIndex = 81,
    })
    window.TooltipFrame = frame
    window.TooltipLabel = label
    return frame
end

function Tooltip.show(window, text, anchor)
    if window.Dead or not text or text == "" then
        return
    end
    local frame = window.TooltipFrame or build(window)
    local width = Util.textWidth(text, Theme.SmallSize) + 2 * PADDING
    window.TooltipLabel.Text = text
    frame.Size = UDim2.fromOffset(width, HEIGHT)

    local screen = window.Screen.AbsoluteSize
    local origin, size = anchor.AbsolutePosition, anchor.AbsoluteSize
    local x = origin.X + size.X - width
    local y = origin.Y + size.Y + OFFSET
    if y + HEIGHT > screen.Y - SCREEN_MARGIN then
        y = origin.Y - HEIGHT - OFFSET
    end
    frame.Position = UDim2.fromOffset(
        math.clamp(x, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.X - width - SCREEN_MARGIN)),
        math.clamp(y, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.Y - HEIGHT - SCREEN_MARGIN))
    )
    frame.Visible = true
    window.TooltipOwner = anchor
end

function Tooltip.hide(window, anchor)
    if not window.TooltipFrame then
        return
    end
    if anchor == nil or window.TooltipOwner == anchor then
        window.TooltipFrame.Visible = false
        window.TooltipOwner = nil
    end
end

function Tooltip.bind(window, gui, getText)
    window.Scope:Connect(gui.MouseEnter, function()
        Tooltip.show(window, getText(), gui)
    end)
    window.Scope:Connect(gui.MouseLeave, function()
        Tooltip.hide(window, gui)
    end)
end

return Tooltip
end

__factories["internal/Util"] = function()
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Theme = __require("internal/Theme")

local Util = {}

local CORE_IDENTITY = 8
local WIDTH_CACHE_LIMIT = 512

local widths, widthCount = {}, 0

local function identityHelpers()
    local getIdentity = getthreadidentity or getidentity or (type(syn) == "table" and syn.get_thread_identity)
    local setIdentity = setthreadidentity or setidentity or (type(syn) == "table" and syn.set_thread_identity)
    if type(getIdentity) == "function" and type(setIdentity) == "function" then
        return getIdentity, setIdentity
    end
    return nil, nil
end

function Util.warn(message)
    warn("[Kinoue] " .. tostring(message))
end

function Util.withContext(fn, ...)
    local getIdentity, setIdentity = identityHelpers()
    if getIdentity then
        local read, identity = pcall(getIdentity)
        if read and type(identity) == "number" and identity < CORE_IDENTITY and pcall(setIdentity, CORE_IDENTITY) then
            local result = table.pack(pcall(fn, ...))
            local restored, message = pcall(setIdentity, identity)
            if not restored then
                error("[Kinoue] Failed to restore callback identity: " .. tostring(message), 0)
            end
            if not result[1] then
                error(result[2], 0)
            end
            return table.unpack(result, 2, result.n)
        end
    end
    return fn(...)
end

function Util.protect(object, names)
    for _, name in ipairs(names) do
        local fn = object[name]
        if type(fn) == "function" then
            object[name] = function(...)
                return Util.withContext(fn, ...)
            end
        end
    end
    return object
end

function Util.textSize(text, size, maxWidth)
    return TextService:GetTextSize(text, size or Theme.TextSize, Theme.Font, Vector2.new(maxWidth or 10000, 10000))
end

function Util.textWidth(text, size)
    size = size or Theme.TextSize
    local key = size .. "\0" .. text
    local width = widths[key]
    if width then
        return width
    end
    if widthCount >= WIDTH_CACHE_LIMIT then
        table.clear(widths)
        widthCount = 0
    end
    width = math.ceil(TextService:GetTextSize(text, size, Theme.Font, Vector2.new(10000, 1000)).X)
    widths[key] = width
    widthCount += 1
    return width
end

function Util.isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Util.sameInput(a, b)
    if a == b then
        return a ~= nil
    end
    return a ~= nil
        and b ~= nil
        and a.UserInputType == Enum.UserInputType.MouseButton1
        and b.UserInputType == Enum.UserInputType.MouseButton1
end

function Util.contains(gui, point)
    local position, size = gui.AbsolutePosition, gui.AbsoluteSize
    return point.X >= position.X
        and point.X <= position.X + size.X
        and point.Y >= position.Y
        and point.Y <= position.Y + size.Y
end

function Util.keyName(key)
    if key == nil or key == Enum.KeyCode.Unknown then
        return "Unbound"
    end
    return key.Name
end

local function merge(defaults, props)
    for key, value in pairs(props or {}) do
        defaults[key] = value
    end
    return defaults
end

function Util.new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        if Theme.isToken(value) then
            Theme.bind(object, key, value.Key)
            value = Theme[value.Key]
        end
        object[key] = value
    end
    object.Parent = parent
    return object
end

function Util.frame(parent, props)
    return Util.new(
        "Frame",
        merge({
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Color.Background,
        }, props),
        parent
    )
end

function Util.label(parent, text, props)
    return Util.new(
        "TextLabel",
        merge({
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Theme.Font,
            TextSize = Theme.TextSize,
            TextScaled = false,
            TextColor3 = Theme.Color.Text,
            Text = text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Size = UDim2.new(1, 0, 0, Theme.RowHeight),
        }, props),
        parent
    )
end

function Util.button(parent, text, props)
    return Util.new(
        "TextButton",
        merge({
            BackgroundColor3 = Theme.Color.Panel,
            BorderColor3 = Theme.Color.Outline,
            BorderSizePixel = 1,
            Font = Theme.Font,
            TextSize = Theme.TextSize,
            TextScaled = false,
            TextColor3 = Theme.Color.Text,
            Text = text,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, Theme.RowHeight),
        }, props),
        parent
    )
end

function Util.textbox(parent, props)
    return Util.new(
        "TextBox",
        merge({
            BackgroundColor3 = Theme.Color.Input,
            BorderSizePixel = 1,
            BorderColor3 = Theme.Color.Outline,
            Font = Theme.Font,
            TextSize = Theme.TextSize,
            TextScaled = false,
            TextColor3 = Theme.Color.Text,
            ClearTextOnFocus = false,
        }, props),
        parent
    )
end

function Util.list(parent, horizontal, gap)
    return Util.new("UIListLayout", {
        FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
    }, parent)
end

function Util.padding(parent, amount)
    return Util.new("UIPadding", {
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount),
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
    }, parent)
end

local Scope = {}
Scope.__index = Scope

function Util.scope()
    return setmetatable({ Connections = {}, Tweens = {}, Dead = false }, Scope)
end

function Scope:Connect(signal, fn)
    local connection = signal:Connect(function(...)
        if self.Dead then
            return
        end
        return Util.withContext(fn, ...)
    end)
    table.insert(self.Connections, connection)
    return connection
end

function Scope:Release(connection)
    if not connection then
        return
    end
    pcall(function()
        connection:Disconnect()
    end)
    local index = table.find(self.Connections, connection)
    if index then
        local last = #self.Connections
        self.Connections[index] = self.Connections[last]
        self.Connections[last] = nil
    end
end

function Scope:Tween(object, duration, props, reduced, style)
    local prior = self.Tweens[object]
    if prior then
        prior:Cancel()
    end
    if reduced or duration <= 0 then
        for key, value in pairs(props) do
            object[key] = value
        end
        self.Tweens[object] = nil
        return
    end
    local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(object, info, props)
    self.Tweens[object] = tween
    tween:Play()
    return tween
end

function Scope:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    for _, connection in ipairs(self.Connections) do
        local ok, message = pcall(function()
            connection:Disconnect()
        end)
        if not ok then
            Util.warn("Disconnect failed: " .. tostring(message))
        end
    end
    for _, tween in pairs(self.Tweens) do
        local ok, message = pcall(function()
            tween:Cancel()
        end)
        if not ok then
            Util.warn("Tween cleanup failed: " .. tostring(message))
        end
    end
    table.clear(self.Connections)
    table.clear(self.Tweens)
end

return Util
end

__require = function(name)
    if __cache[name] ~= nil then
        return __cache[name]
    end
    assert(not __loading[name], "Circular dependency: " .. name)
    local factory = assert(__factories[name], "Unknown module: " .. name)
    __loading[name] = true
    local value = factory()
    __loading[name] = nil
    __cache[name] = value
    return value
end

return __require("init")

end)()

local window = Library:CreateWindow({
    Name = "Kinoue",
    Footer = "Demo",
    ToggleKey = Enum.KeyCode.RightShift,
})

local pages = {}
for _, name in ipairs({ "Home", "Inputs", "Actions", "Preview", "Visuals", "Layout", "Settings" }) do
    pages[name] = window:AddTab(name)
end

local function status(text)
    window:SetStatus(text)
end

local function withKey(text, key)
    if key == Enum.KeyCode.Unknown then
        return text
    end
    return text .. " [" .. key.Name .. "]"
end

local function action(text)
    return function()
        status(text)
    end
end

local welcome = pages.Home:AddGroupbox("Welcome", "Left")
welcome:AddLabel("A compact UI library for Roblox.")
welcome:AddLabel("RightShift shows or hides the menu.", true)
welcome:AddLabel("Every control here is live.", true)

local quick = pages.Home:AddGroupbox("Quick settings", "Right")
local notifications = quick:AddToggle("Notifications", {
    Text = "Notifications",
    Value = true,
    SubToggle = true,
    Callback = function(value)
        window.Controls["UI.Notifications"]:Set(value)
    end,
})
notifications.Settings:AddSlider("NotifyDuration", { Text = "Duration", Min = 1, Max = 10, Value = 3, Suffix = "s" })
quick:AddToggle("Sounds", { Text = "Sounds", Notify = true })
quick:AddButton({
    Text = "Test notification",
    Callback = function()
        window:Notify({
            Title = "Kinoue",
            Text = "Notifications slide in here and close on their own.",
            Duration = window.Controls.NotifyDuration:Get(),
        })
    end,
})
quick:AddDropdown("Language", { Text = "Language", Options = { "English", "German", "Spanish", "French" } })

local toggles = pages.Inputs:AddGroupbox("Toggles", "Left")
toggles:AddToggle("AutoSave", { Text = "Auto save", Value = true, Notify = true })
toggles:AddToggle("ShowHints", { Text = "Show hints", Keybind = true })
toggles:AddToggle("CompactMode", { Text = "Compact mode", Notify = true, Keybind = { Value = Enum.KeyCode.C } })

local sliders = pages.Inputs:AddGroupbox("Sliders", "Left")
sliders:AddSlider("Speed", { Text = "Speed", Min = 1, Max = 24, Value = 16, Suffix = "studs/s" })
sliders:AddSlider("Volume", { Text = "Volume", Min = 0, Max = 100, Value = 80, Suffix = "%" })
sliders:AddSlider("Sensitivity", { Text = "Sensitivity", Min = 0.1, Max = 2, Step = 0.1, Value = 1, Format = "%.1f" })

local text = pages.Inputs:AddGroupbox("Text", "Right")
text:AddTextbox("DisplayName", { Text = "Display name", Placeholder = "Type here", MaxLength = 24 })

local choices = pages.Inputs:AddGroupbox("Choices", "Right")
choices:AddDropdown("Material", {
    Text = "Material",
    Options = {
        { Value = "Stone", Meta = 320 },
        { Value = "Wood", Meta = 180 },
        { Value = "Metal", Meta = 90 },
    },
})
choices:AddDropdown("Quality", { Text = "Quality", Options = { "Low", "Medium", "High" }, Value = "High" })

local shortcuts = pages.Actions:AddGroupbox("Shortcuts", "Left")
shortcuts:AddButton({
    Text = "Save",
    Primary = true,
    Keybind = { Id = "SaveKey", Value = Enum.KeyCode.K },
    Callback = action("Saved"),
})
shortcuts:AddButton({
    Text = "Reload",
    Keybind = { Id = "ReloadKey", Value = Enum.KeyCode.J },
    Callback = action("Reloaded"),
})
shortcuts:AddButton({ Text = "Locked", Disabled = true })

local buttonRow = pages.Actions:AddGroupbox("Button row", "Right")
buttonRow:AddButtons({
    { Text = "One", Callback = action("One") },
    { Text = "Two", Callback = action("Two") },
    { Text = "Three", Callback = action("Three") },
})
buttonRow:AddKeybind("HoldKey", {
    Text = "Hold action",
    Value = Enum.KeyCode.G,
    Pressed = action("Action held"),
    Released = action("Action released"),
})

local glyphs = {
    A = "010/101/111/101/101",
    B = "110/101/110/101/110",
    C = "011/100/100/100/011",
    D = "110/101/101/101/110",
    E = "111/100/110/100/111",
    F = "111/100/110/100/100",
    G = "011/100/101/101/011",
    H = "101/101/111/101/101",
    I = "111/010/010/010/111",
    J = "001/001/001/101/010",
    K = "101/101/110/101/101",
    L = "100/100/100/100/111",
    M = "101/111/111/101/101",
    N = "101/111/111/111/101",
    O = "010/101/101/101/010",
    P = "110/101/110/100/100",
    Q = "010/101/101/111/011",
    R = "110/101/110/101/101",
    S = "011/100/010/001/110",
    T = "111/010/010/010/010",
    U = "101/101/101/101/111",
    V = "101/101/101/101/010",
    W = "101/101/111/111/101",
    X = "101/101/010/101/101",
    Y = "101/101/010/010/010",
    Z = "111/001/010/100/111",
    [" "] = "000/000/000/000/000",
    ["?"] = "110/001/010/000/010",
}

local shapes = {
    Heart = {
        ".##...##.",
        "####.####",
        "#########",
        ".#######.",
        "..#####..",
        "...###...",
        "....#....",
    },
    Arrow = {
        "....#....",
        "...###...",
        "..#####..",
        ".#######.",
        "...###...",
        "...###...",
        "...###...",
    },
}

local shape, message, filled = "Heart", "KINOUE", 0
local preview, animate, messageBox, pulseButton, fillButtons

local function textPoints()
    local result = {}
    local upper = message:upper():sub(1, 32)
    for index = 1, #upper do
        local rows = string.split(glyphs[upper:sub(index, index)] or glyphs["?"], "/")
        for y, line in ipairs(rows) do
            for x = 1, #line do
                if line:sub(x, x) == "1" then
                    table.insert(result, Vector2.new((index - 1) * 4 + x - 1, y - 1))
                end
            end
        end
    end
    return result
end

local function shapePoints()
    local result = {}
    for y, line in ipairs(shapes[shape]) do
        for x = 1, #line do
            if line:sub(x, x) == "#" then
                table.insert(result, Vector2.new(x - 1, y - 1))
            end
        end
    end
    return result
end

local function points()
    if shape == "Text" then
        return textPoints()
    end
    return shapePoints()
end

local function refresh()
    pages.Preview:SetMode(shape)
    if messageBox then
        messageBox:SetVisible(shape == "Text")
    end
    if preview then
        local current = points()
        filled = math.min(filled, #current)
        preview:SetPoints(current)
        preview:SetCount(filled, #current)
    end
    if pulseButton and animate then
        pulseButton:SetEnabled(animate:Get())
    end
end

local function fill()
    filled = #points()
    refresh()
    status("Filled " .. filled .. " pixels")
end

local function step()
    filled = math.min(filled + 10, #points())
    refresh()
    status("Filled " .. filled .. " pixels")
end

local function clear()
    filled = 0
    refresh()
    status("Cleared")
end

local function pulse()
    if animate:Get() then
        preview:Recoil()
        status("Pulse")
    end
end

pages.Preview:SetTitle("Pixel preview")

local composition = pages.Preview:AddGroupbox("Composition", "Left")
composition:AddDropdown("Shape", {
    Text = "Shape",
    Options = { "Heart", "Arrow", "Text" },
    Value = shape,
    Callback = function(value)
        shape = value
        filled = 0
        refresh()
    end,
})
messageBox = composition:AddTextbox("Message", {
    Text = "Message",
    Value = message,
    MaxLength = 32,
    Callback = function(value)
        message = value
        filled = 0
        refresh()
    end,
})
composition:AddSlider("Scale", { Text = "Scale", Min = 1, Max = 20, Value = 10, Suffix = "px" })
composition:AddKeybind("FillKey", {
    Text = "Fill",
    Value = Enum.KeyCode.T,
    Pressed = fill,
    Callback = function(key)
        if fillButtons then
            fillButtons[2].Text = withKey("Fill", key)
        end
    end,
})

local effects = pages.Preview:AddGroupbox("Effects", "Left")
animate = effects:AddToggle("Animate", {
    Text = "Animate",
    Keybind = {
        Id = "PulseKey",
        Value = Enum.KeyCode.F,
        Pressed = pulse,
        Callback = function(key)
            pulseButton:SetText(withKey("Pulse", key))
        end,
    },
    Callback = refresh,
})
pulseButton = effects:AddButton({ Text = "Pulse [F]", Callback = pulse })

local viewer = pages.Preview:AddGroupbox("Preview", "Right")
preview = viewer:AddPreview({ Height = 148, Points = points() })
fillButtons = viewer:AddButtons({
    { Text = "Step", Callback = step },
    { Text = "Fill [T]", Primary = true, Callback = fill },
    { Text = "Clear", Callback = clear },
})
refresh()

local colors = pages.Visuals:AddSubTab("Colors")
local glowTab = pages.Visuals:AddSubTab("Glow")

local palette = colors:AddGroupbox("Palette", "Left")
palette:AddColorPicker("PrimaryColor", { Text = "Primary", Value = Color3.fromRGB(57, 128, 233) })
palette:AddColorPicker("SecondaryColor", { Text = "Secondary", Value = Color3.fromRGB(233, 57, 128) })
palette:AddColorPicker("BackgroundColor", { Text = "Background", Value = Color3.fromRGB(20, 20, 20) })

local opacity = colors:AddGroupbox("Opacity", "Right")
opacity:AddSlider("FillOpacity", { Text = "Fill opacity", Min = 0, Max = 100, Value = 85, Suffix = "%" })
opacity:AddSlider("OutlineOpacity", { Text = "Outline opacity", Min = 0, Max = 100, Value = 100, Suffix = "%" })

local glow = glowTab:AddGroupbox("Glow", "Left")
local glowToggle = glow:AddToggle("Glow", { Text = "Glow", SubToggle = true, Keybind = true })
glowToggle.Settings:AddSlider("GlowSize", { Text = "Size", Min = 1, Max = 16, Value = 4, Suffix = "px" })
glowToggle.Settings:AddSlider("GlowSpeed", { Text = "Speed", Min = 1, Max = 10, Value = 3 })
glowToggle.Settings:AddToggle("GlowPulse", { Text = "Pulse" })
local glowAdvanced = glow:AddDisclosure("Advanced")
glowAdvanced:AddDropdown("GlowStyle", { Text = "Style", Options = { "Soft", "Sharp", "Outline" } })

local blur = glowTab:AddGroupbox("Blur", "Right")
blur:AddToggle("Blur", { Text = "Background blur" })
blur:AddSlider("BlurSize", { Text = "Blur size", Min = 0, Max = 24, Value = 8, Suffix = "px" })

local navigation = pages.Layout:AddGroupbox("Navigation", "Left")
local movement = navigation:AddDisclosure("Movement keys")
for _, entry in ipairs({
    { "Forward", Enum.KeyCode.W },
    { "Backward", Enum.KeyCode.S },
    { "Left", Enum.KeyCode.A },
    { "Right", Enum.KeyCode.D },
    { "Up", Enum.KeyCode.Space },
    { "Down", Enum.KeyCode.LeftControl },
}) do
    movement:AddKeybind("Move" .. entry[1], { Text = entry[1], Value = entry[2] })
end

local columns = pages.Layout:AddGroupbox("Columns", "Right")
columns:AddLabel("Groupboxes stack in two columns.", true)
columns:AddLabel("Narrow windows use one column.", true)

local checklist = pages.Layout:AddGroupbox("Checklist", "Left")
for index, name in ipairs({ "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta" }) do
    checklist:AddToggle("Item" .. name, { Text = name, Value = index <= 3 })
end

local windowSettings = pages.Settings:AddGroupbox("Window", "Left")
windowSettings:AddKeybind("UnloadKey", {
    Text = "Unload interface",
    Value = Enum.KeyCode.End,
    Pressed = function()
        window:Destroy()
    end,
})

local saving = pages.Settings:AddGroupbox("Persistence", "Left")
local savedLabel = saving:AddLabel("Settings: session")

local session = pages.Settings:AddGroupbox("Session", "Right")
session:AddButton({
    Text = "Reset toggles",
    Callback = function()
        for id, control in pairs(window.Controls) do
            if not id:find("^UI%.") and type(control:Get()) == "boolean" then
                control:Set(false)
            end
        end
        status("Toggles reset")
    end,
})
session:AddButton({
    Text = "Unload UI",
    Callback = function()
        window:Destroy()
    end,
})

if type(readfile) == "function" and type(writefile) == "function" then
    window:EnablePersistence(Library.FileStorage("Kinoue/demo.json"))
    savedLabel:SetText("Settings: automatic")
end

pages.Preview:Select()
return window

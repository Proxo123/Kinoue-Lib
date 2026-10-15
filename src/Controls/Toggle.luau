local Collapsible = require(script.Parent.Collapsible)
local Control = require(script.Parent.Control)
local Keybind = require(script.Parent.Keybind)
local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local ROW_HEIGHT = 30
local ROW_PADDING = 8
local SWITCH_WIDTH = 34
local SWITCH_HEIGHT = 20
local KNOB_SIZE = 16
local KNOB_INSET = 2
local SWITCH_GAP = 8
local KEY_ESTIMATE = 70
local COG_SIZE = 18
local COG_ICON_SIZE = 14
local COG_GAP = 4
local SETTINGS_INDENT = 22
local GUIDE_OFFSET = 14
local ANIMATION = 0.16

local Toggle = {}

local function newRow(parent)
    local row = Util.frame(parent, {
        Name = "Toggle",
        Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
        BackgroundColor3 = Theme.Color.Input,
        BackgroundTransparency = 1,
    })
    Util.corner(row, Theme.Radius - 1)
    return row
end

local function buildRow(group, subToggle)
    if not subToggle then
        local row = newRow(group.Container)
        return row, row
    end
    local holder = Util.frame(group.Container, {
        Name = "SubToggle",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(holder, false, Theme.ControlGap)
    return holder, newRow(holder)
end

local function buildSwitch(row)
    local track = Util.frame(row, {
        Name = "Switch",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -ROW_PADDING + 2, 0.5, 0),
        Size = UDim2.fromOffset(SWITCH_WIDTH, SWITCH_HEIGHT),
        BackgroundColor3 = Theme.Hover,
    })
    Util.corner(track, SWITCH_HEIGHT / 2)
    local knob = Util.frame(track, {
        Name = "Knob",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, KNOB_INSET, 0.5, 0),
        Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
        BackgroundColor3 = Theme.Muted,
    })
    Util.corner(knob, KNOB_SIZE / 2)
    return track, knob
end

local function attachSettings(group, control, window, row, newGroup)
    local cog = Util.button(row, "", {
        Name = "SettingsButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(ROW_PADDING - 2 + SWITCH_WIDTH + SWITCH_GAP), 0.5, 0),
        Size = UDim2.fromOffset(COG_SIZE, COG_SIZE),
        BackgroundTransparency = 1,
        ZIndex = 2,
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

    local subToggle = info.SubToggle == true
    local rightInset = ROW_PADDING - 2 + SWITCH_WIDTH + SWITCH_GAP
    if subToggle then
        rightInset += COG_SIZE + COG_GAP
    end

    local hit = Util.button(row, "", {
        Name = "Hit",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    control.Root = hit
    if subToggle then
        attachSettings(group, control, window, row, newGroup)
    end
    local name = Util.label(hit, info.Text or id, {
        Name = "Label",
        Position = UDim2.fromOffset(ROW_PADDING, 0),
        Size = UDim2.new(1, -(ROW_PADDING + rightInset + (keybind and KEY_ESTIMATE or 0)), 1, 0),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local track, knob = buildSwitch(row)
    control.Switch = track
    control.Knob = knob

    control.Render = function(value)
        local reduced = window.ReducedMotion
        window.Scope:Tween(track, ANIMATION, { BackgroundColor3 = value and Theme.Accent or Theme.Hover }, reduced)
        window.Scope:Tween(knob, ANIMATION, {
            Position = UDim2.new(0, value and SWITCH_WIDTH - KNOB_SIZE - KNOB_INSET or KNOB_INSET, 0.5, 0),
            BackgroundColor3 = value and Color3.new(1, 1, 1) or Theme.Muted,
        }, reduced)
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        name.TextTransparency = transparency
        track.BackgroundTransparency = control.Enabled and 0 or 0.5
    end

    window.Scope:Connect(hit.Activated, function()
        if control.Enabled then
            control:Set(not control:Get())
        end
    end)
    Util.hover(window.Scope, hit, function(hovered)
        row.BackgroundTransparency = (hovered and control.Enabled) and 0 or 1
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

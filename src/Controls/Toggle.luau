local Collapsible = require(script.Parent.Collapsible)
local Control = require(script.Parent.Control)
local Keybind = require(script.Parent.Keybind)
local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

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

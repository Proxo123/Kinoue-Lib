local Control = require(script.Parent.Control)
local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Tooltip = require(script.Parent.Parent.internal.Tooltip)
local Util = require(script.Parent.Parent.internal.Util)

local LABEL_INSET = 110
local KEY_HEIGHT = 20
local KEY_PADDING = 14
local KEY_TEXT_SIZE = 12
local CLEAR_SIZE = 14
local WARNING_SIZE = 12
local ICON_GAP = 4

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
        Name = "Key",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -inset, 0.5, 0),
        Size = UDim2.fromOffset(LABEL_INSET, KEY_HEIGHT),
        BackgroundColor3 = Theme.Input,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Outline,
        Font = Theme.MonoFont,
        TextColor3 = Theme.Text,
        TextSize = KEY_TEXT_SIZE,
    })
    Util.corner(control.Root, Theme.SmallRadius)
    control.Clear = Util.button(row, "×", {
        Name = "Unbind",
        AnchorPoint = Vector2.new(1, 0.5),
        Size = UDim2.fromOffset(CLEAR_SIZE, CLEAR_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.TextSize,
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
        keyWidth = Util.textWidth(text, KEY_TEXT_SIZE, Theme.MonoFont) + KEY_PADDING
        control.Root.Text = text
        control.Root.Size = UDim2.fromOffset(keyWidth, KEY_HEIGHT)
        layout()
    end

    local function paint()
        local root = control.Root
        local conflicted = #control.Conflicts > 0
        local capturing = window.Capturing == control
        local bound = Keybind.isBound(control:Get())
        if conflicted then
            root.TextColor3 = Theme.Danger
            root.BorderColor3 = Theme.Danger
            root.BackgroundColor3 = Theme.Danger
            root.BackgroundTransparency = 0.85
        else
            root.TextColor3 = (bound or capturing) and Theme.Text or Theme.Muted
            root.BorderColor3 = capturing and Theme.Accent or Theme.Outline
            root.BackgroundColor3 = Theme.Input
            root.BackgroundTransparency = (bound or capturing) and 0 or 1
        end
        control.Warning:SetColor(Theme.Danger)
        control.Warning.Root.Visible = conflicted and not hidden
        layout()
    end
    control.PaintConflict = paint

    control.Render = function(value)
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        control.Root.TextTransparency = transparency
        control.Clear.TextTransparency = transparency
        control.Root.Visible = not hidden
        control.Clear.Visible = clearable and not hidden and Keybind.isBound(value)
        show(Util.keyName(value))
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
        local previous = window.Capturing
        window.Capturing = control
        if previous and previous ~= control then
            previous.Render(previous:Get())
        end
        show("Press a key")
        paint()
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

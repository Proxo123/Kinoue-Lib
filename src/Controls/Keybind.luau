local Control = require(script.Parent.Control)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local LABEL_INSET = 110
local KEY_HEIGHT = 20
local KEY_PADDING = 4
local CLEAR_SIZE = 14
local CLEAR_GAP = 2

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

function Keybind.attach(group, row, id, info, inline, inset)
    inset = inset or 0
    local clearable = info.Clearable ~= false
    local window = group.Window
    local control = Control.new(group, id, info.Value or Enum.KeyCode.Unknown, normalize, info.Callback)
    control.Pressed = info.Pressed
    control.Released = info.Released
    control.Row = row
    control.Root = Util.button(row, "", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -inset, 0.5, 0),
        Size = UDim2.fromOffset(LABEL_INSET, KEY_HEIGHT),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
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

    local hidden = false

    local function show(text)
        local width = Util.textWidth(text, Theme.SmallSize) + KEY_PADDING
        control.Root.Text = text
        control.Root.Size = UDim2.fromOffset(width, KEY_HEIGHT)
        control.Clear.Position = UDim2.new(1, -(inset + width + CLEAR_GAP), 0.5, 0)
    end

    control.Render = function(value)
        show("[" .. Util.keyName(value) .. "]")
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        control.Root.TextTransparency = transparency
        control.Clear.TextTransparency = transparency
        control.Root.Visible = not hidden
        control.Clear.Visible = clearable and not hidden and Keybind.isBound(value)
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

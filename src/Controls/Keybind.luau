local Control = require(script.Parent.Control)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local KEY_WIDTH = 110

local Keybind = {}

local function normalize(value)
    assert(typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode, "Keybind requires Enum.KeyCode")
    return value
end

function Keybind.attach(group, row, id, info, inline)
    local window = group.Window
    local control = Control.new(group, id, info.Value or Enum.KeyCode.Unknown, normalize, info.Callback)
    control.Pressed = info.Pressed
    control.Released = info.Released
    control.Row = row
    control.Root = Util.button(row, "", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(KEY_WIDTH, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    control.Render = function(value)
        control.Root.Text = "[" .. Util.keyName(value) .. "]"
        control.Root.TextTransparency = control.Enabled and 0 or Theme.DisabledTransparency
    end

    window.Scope:Connect(control.Root.Activated, function()
        if not control.Enabled then
            return
        end
        if window.Capturing then
            window.Capturing.Render(window.Capturing:Get())
        end
        window.Capturing = control
        control.Root.Text = "[Press a key]"
    end)

    if inline then
        function control:SetVisible(value)
            self.Root.Visible = value == true
            return self
        end
        Util.protect(control, { "SetVisible" })
    end

    table.insert(window.Keybinds, control)
    control.Render(control:Get())
    return control
end

function Keybind.add(group, id, info)
    info = info or {}
    local row = Control.row(group)
    Util.label(row, info.Text or id, { Size = UDim2.new(1, -KEY_WIDTH, 1, 0) })
    return Keybind.attach(group, row, id, info)
end

return Keybind

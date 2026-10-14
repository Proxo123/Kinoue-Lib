local Control = require(script.Parent.Control)
local Keybind = require(script.Parent.Keybind)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local Toggle = {}

function Toggle.add(group, id, info)
    info = info or {}
    local window = group.Window
    local control = Control.new(group, id, info.Value == true, function(value)
        return value == true
    end, info.Callback)

    control.Row = Control.row(group)
    local hit = Util.button(control.Row, "", {
        Size = UDim2.new(1, info.Keybind and -65 or 0, 1, 0),
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

    if info.Keybind then
        control.Keybind = Keybind.attach(group, control.Row, info.Keybind.Id or id .. "Key", info.Keybind, true)
    end

    control.Render(control:Get())
    return control
end

return Toggle

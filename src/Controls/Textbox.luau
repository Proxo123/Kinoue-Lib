local Control = require(script.Parent.Control)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local Textbox = {}

function Textbox.add(group, id, info)
    info = info or {}
    local maxLength = info.MaxLength or 256
    local control = Control.new(group, id, info.Value or "", function(value)
        return tostring(value or ""):sub(1, maxLength)
    end, info.Callback)

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

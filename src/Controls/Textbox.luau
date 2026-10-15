local Control = require(script.Parent.Control)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local ROW_HEIGHT = 52
local LABEL_HEIGHT = 18
local FIELD_HEIGHT = 30

local Textbox = {}

function Textbox.add(group, id, info)
    info = info or {}
    local maxLength = info.MaxLength or 256
    local control = Control.new(group, id, info.Value or "", function(value)
        return tostring(value or ""):sub(1, maxLength)
    end, info.Callback, info)

    control.Row = Control.row(group, ROW_HEIGHT)
    local label = Util.label(control.Row, info.Text or id, {
        Name = "Label",
        Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
    })
    control.Root = Util.textbox(control.Row, {
        Name = "Field",
        Position = UDim2.fromOffset(0, LABEL_HEIGHT + 2),
        Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
        BorderColor3 = Theme.Outline,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = control:Get(),
        PlaceholderText = info.Placeholder or "",
        PlaceholderColor3 = Theme.Color.Muted,
        ClipsDescendants = true,
    })
    Util.corner(control.Root, Theme.Radius)
    Util.new("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, control.Root)

    local focused = false
    local function paint()
        control.Root.BorderColor3 = focused and Theme.Accent or Theme.Outline
    end
    table.insert(group.Window.ThemeHooks, paint)

    control.Render = function(value)
        control.Root.Text = value
        control.Root.TextEditable = control.Enabled
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        control.Root.TextTransparency = transparency
        label.TextTransparency = transparency
    end

    group.Window.Scope:Connect(control.Root.Focused, function()
        focused = true
        paint()
    end)
    group.Window.Scope:Connect(control.Root.FocusLost, function()
        focused = false
        paint()
        if control.Enabled then
            control:Set(control.Root.Text)
        end
    end)

    return control
end

return Textbox

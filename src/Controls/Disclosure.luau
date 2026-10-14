local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local Disclosure = {}

function Disclosure.add(group, title, newGroup)
    local frame = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(frame, false, 0)

    local button = Util.button(frame, "▸ " .. title, {
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Muted,
        TextSize = Theme.SmallSize,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local container = Util.frame(frame, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    })
    Util.list(container, false, Theme.ControlGap)
    local child = newGroup(group.Window, container)

    group.Window.Scope:Connect(button.Activated, function()
        container.Visible = not container.Visible
        button.Text = (container.Visible and "▾ " or "▸ ") .. title
    end)

    return child
end

return Disclosure

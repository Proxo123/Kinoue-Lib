local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

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

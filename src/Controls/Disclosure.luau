local Collapsible = require(script.Parent.Collapsible)
local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local ICON_SIZE = 10
local TEXT_INSET = 16
local CONTENT_INDENT = 8

local Disclosure = {}

function Disclosure.add(group, title, newGroup, open)
    local window = group.Window
    local frame = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(frame, false, 0)

    local button = Util.button(frame, title, {
        Name = "Header",
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    Util.new("UIPadding", { PaddingLeft = UDim.new(0, TEXT_INSET) }, button)
    local icon = Icons.chevron(button, ICON_SIZE, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, -TEXT_INSET / 2, 0.5, 0),
        Color = Theme.Color.Muted,
    })

    local section = Collapsible.new(window, frame, CONTENT_INDENT)
    local child = newGroup(window, section.Container)
    child.Header = button
    child.Icon = icon
    child.Section = section

    local function paint()
        icon:SetColor(section.Open and Theme.Text or Theme.Muted)
        button.TextColor3 = section.Open and Theme.Text or Theme.Muted
    end

    section:OnChanged(function(isOpen, reduced)
        icon:SetRotation(window, isOpen and 90 or 0, reduced)
        paint()
    end)
    table.insert(window.ThemeHooks, paint)

    function child:SetOpen(value)
        section:SetOpen(value)
        return self
    end

    function child:IsOpen()
        return section.Open
    end

    Util.protect(child, { "SetOpen" })

    window.Scope:Connect(button.Activated, function()
        section:Toggle()
    end)

    if open then
        section:SetOpen(true, true)
    end
    return child
end

return Disclosure

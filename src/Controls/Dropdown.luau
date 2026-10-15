local RunService = game:GetService("RunService")

local Control = require(script.Parent.Control)
local Icons = require(script.Parent.Parent.internal.Icons)
local Model = require(script.Parent.Parent.internal.Model)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local OPTION_HEIGHT = 28
local MENU_PADDING = 4
local MENU_GAP = 4
local MAX_MENU_HEIGHT = 200
local SCREEN_MARGIN = 8
local ROW_HEIGHT = 52
local LABEL_HEIGHT = 18
local FIELD_HEIGHT = 32
local FIELD_PADDING = 10
local META_PADDING = 10

local Dropdown = {}

local function metaWidth(text)
    return Util.textWidth(text, Theme.SmallSize - 1, Theme.MonoFont) + META_PADDING
end

local function openMenu(window, control, options, onClose)
    local scope = Util.scope()
    local contentHeight = #options * OPTION_HEIGHT + 2 * MENU_PADDING
    local menu = Util.new("ScrollingFrame", {
        Name = "Dropdown",
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ZIndex = 50,
        CanvasSize = UDim2.fromOffset(0, contentHeight),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Color.Outline,
    }, window.Screen)
    Util.corner(menu, Theme.Radius + 1)
    Util.padding(menu, MENU_PADDING)
    Util.list(menu, false, 0)

    local function position()
        local screen = window.Screen.AbsoluteSize
        local size = control.Root.AbsoluteSize
        local origin = control.Root.AbsolutePosition
        local height = math.min(contentHeight, MAX_MENU_HEIGHT, screen.Y - 2 * SCREEN_MARGIN)
        local y = origin.Y + size.Y + MENU_GAP
        if y + height > screen.Y - SCREEN_MARGIN then
            y = math.max(SCREEN_MARGIN, origin.Y - height - MENU_GAP)
        end
        local x = math.clamp(origin.X, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.X - size.X - SCREEN_MARGIN))
        menu.Position = UDim2.fromOffset(x, y)
        menu.Size = UDim2.fromOffset(size.X, height)
    end
    position()

    for _, option in ipairs(options) do
        local selected = option.Value == control:Get()
        local entry = Util.button(menu, "", {
            Name = "Option",
            Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Color.Selected,
            BackgroundTransparency = 1,
            ZIndex = 51,
        })
        Util.corner(entry, Theme.Radius - 2)
        Util.label(entry, option.Label, {
            Position = UDim2.fromOffset(8, 0),
            Size = UDim2.new(1, -40, 1, 0),
            Font = selected and Theme.FontMedium or Theme.Font,
            TextColor3 = selected and Theme.Color.Text or Theme.Color.Muted,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 52,
        })
        if option.Meta ~= nil then
            local metaText = tostring(option.Meta)
            Util.label(entry, metaText, {
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, Util.textWidth(option.Label) + 16, 0.5, 0),
                Size = UDim2.fromOffset(metaWidth(metaText), 16),
                Font = Theme.MonoFont,
                TextColor3 = Theme.Color.Muted,
                TextSize = Theme.SmallSize - 1,
                TextXAlignment = Enum.TextXAlignment.Center,
                BackgroundColor3 = Theme.Color.Hover,
                BackgroundTransparency = 0,
                ZIndex = 52,
            })
        end
        if selected then
            Icons.check(entry, 12, {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                ZIndex = 53,
            })
        end
        Util.hover(scope, entry, function(hovered)
            entry.BackgroundTransparency = hovered and 0 or 1
        end)
        scope:Connect(entry.Activated, function()
            control:Set(option.Value)
            window:ClosePopup()
        end)
    end

    scope:Connect(RunService.RenderStepped, position)
    Control.dismissPopupOnOutsideInput(scope, window, menu, control.Root)

    window.PopupClose = function()
        scope:Destroy()
        menu:Destroy()
        window.PopupOwner = nil
        onClose()
    end
end

function Dropdown.add(group, id, info)
    info = info or {}
    local window = group.Window
    local options = Model.options(info.Options or {})

    local function find(value)
        for _, option in ipairs(options) do
            if option.Value == value then
                return option
            end
        end
        return nil
    end

    local initial = info.Value
    if initial == nil and options[1] then
        initial = options[1].Value
    end

    local control = Control.new(group, id, initial, function(value)
        assert(value == nil or find(value), "Unknown dropdown value: " .. tostring(value))
        return value
    end, info.Callback, info)
    control.Window = window

    control.Row = Control.row(group, ROW_HEIGHT)
    local label = Util.label(control.Row, info.Text or id, {
        Name = "Label",
        Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
    })
    control.Root = Util.button(control.Row, "", {
        Name = "Field",
        Position = UDim2.fromOffset(0, LABEL_HEIGHT + 2),
        Size = UDim2.new(1, 0, 0, FIELD_HEIGHT),
        BackgroundColor3 = Theme.Color.Input,
        BorderColor3 = Theme.Outline,
    })
    Util.corner(control.Root, Theme.Radius)
    local name = Util.label(control.Root, "", {
        Name = "Selection",
        Position = UDim2.fromOffset(FIELD_PADDING, 0),
        Size = UDim2.new(1, -(FIELD_PADDING + 28), 1, 0),
    })
    local meta = Util.label(control.Root, "", {
        Name = "Meta",
        AnchorPoint = Vector2.new(0, 0.5),
        Font = Theme.MonoFont,
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundColor3 = Theme.Color.Hover,
        Size = UDim2.fromOffset(0, 16),
    })
    Util.corner(meta, Theme.SmallRadius)
    local chevron = Icons.chevron(control.Root, 10, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -FIELD_PADDING, 0.5, 0),
    })
    chevron.Root.Rotation = 90

    local function paintField()
        local open = window.PopupOwner == control
        control.Root.BorderColor3 = open and Theme.Accent or Theme.Outline
        chevron:SetColor(Theme.Muted)
        chevron:SetRotation(window, open and -90 or 90)
    end
    table.insert(window.ThemeHooks, paintField)

    control.Render = function(value)
        local option = find(value)
        name.Text = option and option.Label or "None"
        local metaText = option and option.Meta and tostring(option.Meta) or ""
        meta.Text = metaText
        meta.BackgroundTransparency = metaText == "" and 1 or 0
        meta.Size = UDim2.fromOffset(metaText == "" and 0 or metaWidth(metaText), 16)
        meta.Position = UDim2.new(0, FIELD_PADDING + Util.textWidth(name.Text) + 8, 0.5, 0)
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        name.TextTransparency = transparency
        label.TextTransparency = transparency
        if not control.Enabled and window.PopupOwner == control then
            window:ClosePopup()
        end
    end

    Control.closePopupWhenHidden(control, window)

    function control:UpdateOptions(values)
        window:ClosePopup()
        options = Model.options(values)
        local current = self:Get()
        local selected = find(current) and current or (options[1] and options[1].Value)
        local unchanged = selected == current
        self:SetSilent(selected)
        if unchanged then
            self.Render(selected)
        end
    end
    Util.protect(control, { "UpdateOptions" })

    local function toggle()
        if not control.Enabled or #options == 0 then
            return
        end
        if window.PopupOwner == control then
            window:ClosePopup()
            return
        end
        window:ClosePopup()
        window.PopupOwner = control
        openMenu(window, control, options, paintField)
        paintField()
    end
    window.Scope:Connect(control.Root.Activated, toggle)

    control.Render(control:Get())
    return control
end

return Dropdown

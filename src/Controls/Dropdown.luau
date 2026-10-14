local RunService = game:GetService("RunService")

local Control = require(script.Parent.Control)
local Model = require(script.Parent.Parent.internal.Model)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local OPTION_HEIGHT = 23
local MAX_MENU_HEIGHT = 184
local SCREEN_MARGIN = 8

local Dropdown = {}

local function openMenu(window, control, options)
    local scope = Util.scope()
    local menu = Util.new("ScrollingFrame", {
        Name = "Dropdown",
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ZIndex = 50,
        CanvasSize = UDim2.fromOffset(0, #options * OPTION_HEIGHT),
        ScrollBarThickness = 3,
    }, window.Screen)
    Util.list(menu, false, 0)

    local function position()
        local screen = window.Screen.AbsoluteSize
        local size = control.Root.AbsoluteSize
        local origin = control.Root.AbsolutePosition
        local height = math.min(#options * OPTION_HEIGHT, MAX_MENU_HEIGHT, screen.Y - 2 * SCREEN_MARGIN)
        local y = origin.Y + size.Y
        if y + height > screen.Y - SCREEN_MARGIN then
            y = math.max(SCREEN_MARGIN, origin.Y - height)
        end
        local x = math.clamp(origin.X, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.X - size.X - SCREEN_MARGIN))
        menu.Position = UDim2.fromOffset(x, y)
        menu.Size = UDim2.fromOffset(size.X, height)
    end
    position()

    for _, option in ipairs(options) do
        local entry = Util.button(menu, "", {
            Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
            BorderSizePixel = 0,
            BackgroundColor3 = option.Value == control:Get() and Theme.Selected or Theme.Panel,
            ZIndex = 51,
        })
        Util.label(entry, option.Label, {
            Position = UDim2.fromOffset(5, 0),
            Size = UDim2.new(1, -60, 1, 0),
            ZIndex = 52,
        })
        if option.Meta ~= nil then
            Util.label(entry, tostring(option.Meta), {
                Position = UDim2.fromOffset(Util.textWidth(option.Label) + 12, 0),
                Size = UDim2.new(0, 48, 1, 0),
                TextColor3 = Theme.Color.Muted,
                TextSize = Theme.SmallSize,
                ZIndex = 52,
            })
        end
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
    end, info.Callback)
    control.Window = window

    control.Row = Control.row(group, 41)
    Util.label(control.Row, info.Text or id, { Size = UDim2.new(1, 0, 0, 18) })
    control.Root = Util.button(control.Row, "", {
        Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, Theme.RowHeight),
    })
    local name = Util.label(control.Root, "", {
        Position = UDim2.fromOffset(5, 0),
        Size = UDim2.new(1, -20, 1, 0),
    })
    local meta = Util.label(control.Root, "", {
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        Size = UDim2.new(0, 50, 1, 0),
    })
    Util.label(control.Root, "▾", {
        Position = UDim2.new(1, -16, 0, 0),
        Size = UDim2.new(0, 12, 1, 0),
        TextColor3 = Theme.Color.Muted,
    })

    control.Render = function(value)
        local option = find(value)
        name.Text = option and option.Label or "None"
        meta.Text = option and option.Meta and tostring(option.Meta) or ""
        meta.Position = UDim2.fromOffset(Util.textWidth(name.Text) + 12, 0)
        name.TextTransparency = control.Enabled and 0 or Theme.DisabledTransparency
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
        openMenu(window, control, options)
    end
    window.Scope:Connect(control.Root.Activated, toggle)

    control.Render(control:Get())
    return control
end

return Dropdown

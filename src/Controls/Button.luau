local Control = require(script.Parent.Control)
local Keybind = require(script.Parent.Keybind)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local BUTTON_HEIGHT = 30
local TEXT_PADDING = 24
local ROW_GAP = 8
local PRIMARY_HOVER_TRANSPARENCY = 0.12

local Button = {}

local function width(text, fixed)
    return fixed or (Util.textWidth(text, Theme.TextSize, Theme.FontMedium) + TEXT_PADDING)
end

local function create(parent, text, info)
    local button = Util.button(parent, text, {
        Name = "Button",
        Size = UDim2.fromOffset(width(text, info.Width), BUTTON_HEIGHT),
        Font = Theme.FontMedium,
        BorderSizePixel = 1,
    })
    Util.corner(button, Theme.Radius)
    return button
end

local function style(window, button, primary, isEnabled)
    local hovered = false
    local function paint()
        local enabled = isEnabled()
        if primary and enabled then
            button.BackgroundColor3 = Theme.Accent
            button.BorderColor3 = Theme.Accent
            button.TextColor3 = Color3.new(1, 1, 1)
            button.BackgroundTransparency = hovered and PRIMARY_HOVER_TRANSPARENCY or 0
        else
            button.BackgroundColor3 = (hovered and enabled) and Theme.Selected or Theme.Input
            button.BorderColor3 = Theme.Hover
            button.TextColor3 = enabled and Theme.Text or Theme.Muted
            button.BackgroundTransparency = 0
        end
        button.TextTransparency = 0
    end
    Util.hover(window.Scope, button, function(state)
        hovered = state
        paint()
    end)
    table.insert(window.ThemeHooks, paint)
    return paint
end

function Button.add(group, info)
    info = info or {}
    local window = group.Window
    local row = Control.row(group, BUTTON_HEIGHT)
    local baseText = info.Text or "Button"
    local button = create(row, baseText, info)
    local result = {
        Root = button,
        Row = row,
        Enabled = info.Disabled ~= true,
        DisplayName = baseText,
        Notify = info.Notify,
    }

    local paint = style(window, button, info.Primary == true, function()
        return result.Enabled
    end)

    local function activate()
        if result.Enabled then
            window:Dispatch(info.Callback)
            Control.notify(window, result, nil)
        end
    end

    function result:SetEnabled(value)
        value = value == true
        if self.Enabled == value and self.Rendered then
            return self
        end
        self.Enabled = value
        self.Rendered = true
        paint()
        return self
    end

    function result:SetText(value)
        baseText = tostring(value)
        result.DisplayName = baseText
        button.Text = baseText
        button.Size = UDim2.fromOffset(width(baseText, info.Width), BUTTON_HEIGHT)
    end

    window.Scope:Connect(button.Activated, activate)
    Control.searchable(group, function()
        return baseText
    end, function()
        return row
    end)

    local config = Keybind.options(info.Keybind)
    if config then
        config.Pressed = config.Pressed or activate
        config.Name = config.Name or baseText
        local keyId = config.Id or window:UniqueId(baseText .. "Key")
        result.Keybind = Keybind.attach(group, row, keyId, config, true)
    end

    result:SetEnabled(result.Enabled)
    return Util.protect(result, { "SetEnabled", "SetText" })
end

function Button.addRow(group, definitions)
    local window = group.Window
    local row = Control.row(group, BUTTON_HEIGHT)
    Util.list(row, true, ROW_GAP)
    local buttons = {}
    for _, info in ipairs(definitions) do
        local button = create(row, info.Text, info)
        style(window, button, info.Primary == true, function()
            return true
        end)()
        window.Scope:Connect(button.Activated, function()
            window:Dispatch(info.Callback)
        end)
        table.insert(buttons, button)
    end
    return buttons
end

return Button

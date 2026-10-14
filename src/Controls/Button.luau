local Control = require(script.Parent.Control)
local Keybind = require(script.Parent.Keybind)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local TEXT_PADDING = 14
local ROW_GAP = 4

local Button = {}

local function width(text, fixed)
    return fixed or (Util.textWidth(text) + TEXT_PADDING)
end

function Button.add(group, info)
    info = info or {}
    local window = group.Window
    local row = Control.row(group)
    local baseText = info.Text or "Button"
    local button = Util.button(row, baseText, {
        Size = UDim2.fromOffset(width(baseText, info.Width), Theme.RowHeight),
        BorderColor3 = info.Primary and Theme.Color.Accent or Theme.Color.Outline,
    })
    local result = { Root = button, Row = row, Enabled = info.Disabled ~= true }

    local function render()
        local shown = baseText
        if result.Keybind and Keybind.isBound(result.Keybind:Get()) then
            shown = shown .. " [" .. Util.keyName(result.Keybind:Get()) .. "]"
        end
        button.Text = shown
        button.Size = UDim2.fromOffset(width(shown, info.Width), Theme.RowHeight)
    end

    local function activate()
        if result.Enabled then
            window:Dispatch(info.Callback)
        end
    end

    local function paint()
        button.TextColor3 = result.Enabled and Theme.Text or Theme.Muted
        button.TextTransparency = 0
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
        render()
    end

    window.Scope:Connect(button.Activated, activate)

    local config = Keybind.options(info.Keybind)
    if config then
        local changed = config.Callback
        config.Pressed = config.Pressed or activate
        config.Callback = function(value)
            render()
            if changed then
                changed(value)
            end
        end
        result.Keybind = Keybind.attach(group, row, config.Id or baseText .. "Key", config, true)
        render()
    end

    result:SetEnabled(result.Enabled)
    table.insert(window.ThemeHooks, paint)
    return Util.protect(result, { "SetEnabled", "SetText" })
end

function Button.addRow(group, definitions)
    local window = group.Window
    local row = Control.row(group)
    Util.list(row, true, ROW_GAP)
    local buttons = {}
    for _, info in ipairs(definitions) do
        local button = Util.button(row, info.Text, {
            Size = UDim2.fromOffset(width(info.Text, info.Width), Theme.RowHeight),
            BorderColor3 = info.Primary and Theme.Color.Accent or Theme.Color.Outline,
        })
        window.Scope:Connect(button.Activated, function()
            window:Dispatch(info.Callback)
        end)
        table.insert(buttons, button)
    end
    return buttons
end

return Button

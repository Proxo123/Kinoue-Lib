local Page = require(script.Parent.Page)
local Theme = require(script.Parent.Parent.internal.Theme)

local CUSTOM = "Custom"

local EDITABLE_COLORS = {
    { Key = "Accent", Text = "Accent" },
    { Key = "Background", Text = "Background" },
    { Key = "Panel", Text = "Panels" },
    { Key = "Outline", Text = "Outlines" },
    { Key = "Text", Text = "Text" },
    { Key = "Muted", Text = "Muted text" },
}

local COLOR_TOLERANCE = 0.5 / 255

local Settings = {}

local function sameColor(a, b)
    return math.abs(a.R - b.R) <= COLOR_TOLERANCE
        and math.abs(a.G - b.G) <= COLOR_TOLERANCE
        and math.abs(a.B - b.B) <= COLOR_TOLERANCE
end

local function presetOptions()
    local options = table.clone(Theme.PresetNames)
    table.insert(options, CUSTOM)
    return options
end

local function buildTheme(window, page)
    local group = page:AddGroupbox("Theme", "Left")
    local controls = {}

    controls.Preset = group:AddDropdown("UI.Theme", {
        Text = "Preset",
        Options = presetOptions(),
        Value = Theme.Preset,
        Callback = function(value)
            if value ~= CUSTOM then
                Theme.apply(value)
            end
        end,
    })

    controls.Colors = {}
    for _, entry in ipairs(EDITABLE_COLORS) do
        controls.Colors[entry.Key] = group:AddColorPicker("UI.Color." .. entry.Key, {
            Text = entry.Text,
            Value = Theme[entry.Key],
            Callback = function(value)
                if not sameColor(value, Theme[entry.Key]) then
                    Theme.apply({ [entry.Key] = value })
                end
            end,
        })
    end

    group:AddButton({
        Text = "Reset theme",
        Callback = function()
            Theme.apply("Dark")
        end,
    })

    return controls
end

local function buildWindow(window, page, options)
    local group = page:AddGroupbox("Window", "Right")
    local defaultSnap = math.max(1, options.SnapDistance or 8)

    group:AddKeybind("UI.MenuKey", {
        Text = "Menu key",
        Value = window.ToggleKey,
        Clearable = false,
        Callback = function(key)
            window:SetToggleKey(key)
        end,
    })

    group:AddToggle("UI.LockToScreen", {
        Text = "Lock to screen",
        Keybind = false,
        Value = not window.AllowOffscreen,
        Callback = function(value)
            window:SetLockToScreen(value)
        end,
    })
    group:AddToggle("UI.SnapToEdges", {
        Text = "Snap to edges",
        Keybind = false,
        Value = window.SnapDistance > 0,
        Callback = function(value)
            window.SnapDistance = value and defaultSnap or 0
        end,
    })
    group:AddLabel("Unlock to drag past screen edges.", true)

    local look = page:AddGroupbox("Appearance", "Right")
    look:AddToggle("UI.Animations", {
        Text = "Animations",
        Keybind = false,
        Value = not window.ReducedMotion,
        Callback = function(value)
            window:SetReducedMotion(not value)
        end,
    })
    look:AddToggle("UI.RainbowAccent", {
        Text = "Rainbow accent line",
        Keybind = false,
        Value = window.RainbowAccent,
        Callback = function(value)
            window:SetRainbowAccent(value)
        end,
    })
end

function Settings.build(window, options)
    local page = Page.hidden(window, "Settings")
    page:SetTitle("UI settings")
    page:SetMode("Theme applies to every window")
    local controls = buildTheme(window, page)
    buildWindow(window, page, options)

    function controls.sync()
        controls.Preset:SetSilent(Theme.Preset)
        for key, picker in pairs(controls.Colors) do
            picker:SetSilent(Theme[key])
        end
    end

    page.Controls = controls
    return page
end

return Settings

local COLOR_KEYS = { "Background", "Panel", "Input", "Hover", "Outline", "Text", "Muted", "Accent", "Selected" }

local Theme = {
    Font = Enum.Font.Code,
    TextSize = 14,
    SmallSize = 12,
    RowHeight = 23,
    Gap = 6,
    ControlGap = 2,
    Padding = 6,
    DisabledTransparency = 0.55,
    Preset = "Dark",
    ColorKeys = COLOR_KEYS,
}

Theme.Presets = {
    Dark = {
        Background = Color3.fromRGB(20, 20, 20),
        Panel = Color3.fromRGB(28, 28, 28),
        Input = Color3.fromRGB(28, 28, 28),
        Hover = Color3.fromRGB(38, 38, 38),
        Outline = Color3.fromRGB(50, 50, 50),
        Text = Color3.fromRGB(232, 232, 232),
        Muted = Color3.fromRGB(171, 171, 171),
        Accent = Color3.fromRGB(57, 128, 233),
        Selected = Color3.fromRGB(35, 50, 74),
    },
    Midnight = {
        Background = Color3.fromRGB(14, 16, 24),
        Panel = Color3.fromRGB(20, 23, 34),
        Input = Color3.fromRGB(20, 23, 34),
        Hover = Color3.fromRGB(30, 34, 48),
        Outline = Color3.fromRGB(42, 47, 66),
        Text = Color3.fromRGB(226, 230, 240),
        Muted = Color3.fromRGB(150, 158, 180),
        Accent = Color3.fromRGB(124, 92, 255),
        Selected = Color3.fromRGB(40, 34, 72),
    },
    Ocean = {
        Background = Color3.fromRGB(12, 22, 28),
        Panel = Color3.fromRGB(17, 30, 38),
        Input = Color3.fromRGB(17, 30, 38),
        Hover = Color3.fromRGB(26, 42, 52),
        Outline = Color3.fromRGB(36, 56, 68),
        Text = Color3.fromRGB(225, 238, 242),
        Muted = Color3.fromRGB(150, 175, 185),
        Accent = Color3.fromRGB(38, 190, 190),
        Selected = Color3.fromRGB(20, 60, 64),
    },
    Rose = {
        Background = Color3.fromRGB(24, 18, 22),
        Panel = Color3.fromRGB(33, 25, 30),
        Input = Color3.fromRGB(33, 25, 30),
        Hover = Color3.fromRGB(46, 35, 42),
        Outline = Color3.fromRGB(64, 48, 58),
        Text = Color3.fromRGB(242, 230, 236),
        Muted = Color3.fromRGB(185, 160, 172),
        Accent = Color3.fromRGB(233, 84, 128),
        Selected = Color3.fromRGB(70, 32, 46),
    },
    Forest = {
        Background = Color3.fromRGB(16, 22, 18),
        Panel = Color3.fromRGB(23, 31, 25),
        Input = Color3.fromRGB(23, 31, 25),
        Hover = Color3.fromRGB(33, 44, 36),
        Outline = Color3.fromRGB(46, 61, 50),
        Text = Color3.fromRGB(228, 240, 230),
        Muted = Color3.fromRGB(160, 180, 164),
        Accent = Color3.fromRGB(88, 190, 110),
        Selected = Color3.fromRGB(32, 62, 40),
    },
    Light = {
        Background = Color3.fromRGB(240, 240, 242),
        Panel = Color3.fromRGB(250, 250, 252),
        Input = Color3.fromRGB(255, 255, 255),
        Hover = Color3.fromRGB(228, 228, 232),
        Outline = Color3.fromRGB(205, 205, 210),
        Text = Color3.fromRGB(30, 30, 34),
        Muted = Color3.fromRGB(110, 110, 118),
        Accent = Color3.fromRGB(40, 110, 220),
        Selected = Color3.fromRGB(215, 228, 250),
    },
}

Theme.PresetNames = { "Dark", "Midnight", "Ocean", "Rose", "Forest", "Light" }

for _, key in ipairs(COLOR_KEYS) do
    Theme[key] = Theme.Presets.Dark[key]
end

local Token = {}
Token.__index = Token

Theme.Color = setmetatable({}, {
    __index = function(cache, key)
        assert(table.find(COLOR_KEYS, key), "Unknown theme color: " .. tostring(key))
        local token = setmetatable({ Key = key }, Token)
        rawset(cache, key, token)
        return token
    end,
})

local bindings = setmetatable({}, { __mode = "k" })
local listeners = {}

function Theme.isToken(value)
    return type(value) == "table" and getmetatable(value) == Token
end

function Theme.bind(object, property, key)
    local properties = bindings[object]
    if not properties then
        properties = {}
        bindings[object] = properties
    end
    properties[property] = key
end

function Theme.onChanged(listener)
    table.insert(listeners, listener)
    return function()
        local index = table.find(listeners, listener)
        if index then
            table.remove(listeners, index)
        end
    end
end

local function resolve(values)
    if type(values) == "string" then
        return assert(Theme.Presets[values], "Unknown theme preset: " .. values), values
    end
    assert(type(values) == "table", "SetTheme requires a preset name or a table of colors")
    return values, "Custom"
end

function Theme.apply(values)
    local colors, preset = resolve(values)
    local previous = {}
    for _, key in ipairs(COLOR_KEYS) do
        previous[key] = Theme[key]
        local color = colors[key]
        if color ~= nil then
            assert(typeof(color) == "Color3", "Theme color " .. key .. " requires Color3")
            Theme[key] = color
        end
    end
    Theme.Preset = preset

    for object, properties in pairs(bindings) do
        if object.Parent == nil then
            bindings[object] = nil
        else
            for property, key in pairs(properties) do
                if object[property] == previous[key] then
                    object[property] = Theme[key]
                end
            end
        end
    end

    for _, listener in ipairs(table.clone(listeners)) do
        listener()
    end
end

return Theme

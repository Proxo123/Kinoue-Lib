local COLOR_KEYS = {
    "Background",
    "Panel",
    "Input",
    "Hover",
    "Outline",
    "Text",
    "Muted",
    "Accent",
    "Selected",
    "Danger",
    "Success",
}

local function font(name, fallback)
    local ok, value = pcall(function()
        return Enum.Font[name]
    end)
    return ok and value or fallback
end

local Theme = {
    Font = font("BuilderSans", Enum.Font.Gotham),
    FontMedium = font("BuilderSansMedium", Enum.Font.GothamMedium),
    FontBold = font("BuilderSansBold", Enum.Font.GothamBold),
    MonoFont = Enum.Font.Code,
    TextSize = 14,
    SmallSize = 13,
    TinySize = 11,
    TitleSize = 15,
    RowHeight = 28,
    Gap = 10,
    ControlGap = 2,
    Padding = 10,
    Radius = 7,
    SmallRadius = 4,
    CardRadius = 10,
    WindowRadius = 12,
    DisabledTransparency = 0.55,
    Preset = "Dark",
    ColorKeys = COLOR_KEYS,
}

Theme.Presets = {
    Dark = {
        Background = Color3.fromRGB(21, 21, 23),
        Panel = Color3.fromRGB(27, 27, 30),
        Input = Color3.fromRGB(36, 36, 40),
        Hover = Color3.fromRGB(54, 54, 59),
        Outline = Color3.fromRGB(40, 40, 44),
        Text = Color3.fromRGB(232, 232, 234),
        Muted = Color3.fromRGB(139, 139, 146),
        Accent = Color3.fromRGB(76, 125, 217),
        Selected = Color3.fromRGB(44, 44, 49),
        Danger = Color3.fromRGB(229, 114, 108),
        Success = Color3.fromRGB(79, 191, 116),
    },
    Midnight = {
        Background = Color3.fromRGB(13, 15, 22),
        Panel = Color3.fromRGB(18, 21, 31),
        Input = Color3.fromRGB(24, 27, 40),
        Hover = Color3.fromRGB(40, 44, 62),
        Outline = Color3.fromRGB(36, 40, 58),
        Text = Color3.fromRGB(226, 230, 240),
        Muted = Color3.fromRGB(140, 148, 172),
        Accent = Color3.fromRGB(124, 92, 255),
        Selected = Color3.fromRGB(38, 36, 64),
        Danger = Color3.fromRGB(240, 92, 112),
        Success = Color3.fromRGB(80, 200, 140),
    },
    Ocean = {
        Background = Color3.fromRGB(11, 20, 25),
        Panel = Color3.fromRGB(15, 27, 34),
        Input = Color3.fromRGB(20, 35, 44),
        Hover = Color3.fromRGB(34, 54, 66),
        Outline = Color3.fromRGB(32, 50, 61),
        Text = Color3.fromRGB(225, 238, 242),
        Muted = Color3.fromRGB(138, 165, 176),
        Accent = Color3.fromRGB(38, 190, 190),
        Selected = Color3.fromRGB(24, 58, 64),
        Danger = Color3.fromRGB(236, 98, 98),
        Success = Color3.fromRGB(80, 200, 140),
    },
    Rose = {
        Background = Color3.fromRGB(22, 16, 20),
        Panel = Color3.fromRGB(29, 22, 27),
        Input = Color3.fromRGB(37, 28, 34),
        Hover = Color3.fromRGB(58, 44, 53),
        Outline = Color3.fromRGB(54, 40, 49),
        Text = Color3.fromRGB(242, 230, 236),
        Muted = Color3.fromRGB(176, 150, 163),
        Accent = Color3.fromRGB(233, 84, 128),
        Selected = Color3.fromRGB(66, 32, 46),
        Danger = Color3.fromRGB(245, 96, 96),
        Success = Color3.fromRGB(90, 196, 128),
    },
    Forest = {
        Background = Color3.fromRGB(14, 20, 16),
        Panel = Color3.fromRGB(19, 27, 22),
        Input = Color3.fromRGB(25, 35, 28),
        Hover = Color3.fromRGB(41, 56, 45),
        Outline = Color3.fromRGB(38, 52, 42),
        Text = Color3.fromRGB(228, 240, 230),
        Muted = Color3.fromRGB(148, 170, 153),
        Accent = Color3.fromRGB(88, 190, 110),
        Selected = Color3.fromRGB(32, 60, 40),
        Danger = Color3.fromRGB(232, 96, 86),
        Success = Color3.fromRGB(88, 190, 110),
    },
    Light = {
        Background = Color3.fromRGB(246, 246, 248),
        Panel = Color3.fromRGB(255, 255, 255),
        Input = Color3.fromRGB(240, 240, 243),
        Hover = Color3.fromRGB(214, 214, 220),
        Outline = Color3.fromRGB(222, 222, 228),
        Text = Color3.fromRGB(28, 28, 32),
        Muted = Color3.fromRGB(108, 108, 118),
        Accent = Color3.fromRGB(40, 110, 220),
        Selected = Color3.fromRGB(226, 234, 250),
        Danger = Color3.fromRGB(205, 45, 45),
        Success = Color3.fromRGB(40, 150, 80),
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

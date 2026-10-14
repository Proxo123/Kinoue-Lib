local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("Kinoue"))

local window = Library:CreateWindow({
    Name = "Kinoue",
    Footer = "Demo",
    ToggleKey = Enum.KeyCode.RightShift,
})

local pages = {}
for _, name in ipairs({ "Home", "Inputs", "Actions", "Preview", "Visuals", "Layout", "Settings" }) do
    pages[name] = window:AddTab(name)
end

local function status(text)
    window:SetStatus(text)
end

local function action(text)
    return function()
        status(text)
    end
end

local welcome = pages.Home:AddGroupbox("Welcome", "Left")
welcome:AddLabel("A compact UI library for Roblox.")
welcome:AddLabel("RightShift shows or hides the menu.", true)
welcome:AddLabel("Every control here is live.", true)

local quick = pages.Home:AddGroupbox("Quick settings", "Right")
quick:AddToggle("Notifications", { Text = "Notifications", Value = true })
quick:AddToggle("Sounds", { Text = "Sounds" })
quick:AddDropdown("Language", { Text = "Language", Options = { "English", "German", "Spanish", "French" } })

local toggles = pages.Inputs:AddGroupbox("Toggles", "Left")
toggles:AddToggle("AutoSave", { Text = "Auto save", Value = true })
toggles:AddToggle("ShowHints", { Text = "Show hints" })
toggles:AddToggle("CompactMode", { Text = "Compact mode" })

local sliders = pages.Inputs:AddGroupbox("Sliders", "Left")
sliders:AddSlider("Speed", { Text = "Speed", Min = 1, Max = 24, Value = 16, Suffix = "studs/s" })
sliders:AddSlider("Volume", { Text = "Volume", Min = 0, Max = 100, Value = 80, Suffix = "%" })
sliders:AddSlider("Sensitivity", { Text = "Sensitivity", Min = 0.1, Max = 2, Step = 0.1, Value = 1, Format = "%.1f" })

local text = pages.Inputs:AddGroupbox("Text", "Right")
text:AddTextbox("DisplayName", { Text = "Display name", Placeholder = "Type here", MaxLength = 24 })

local choices = pages.Inputs:AddGroupbox("Choices", "Right")
choices:AddDropdown("Material", {
    Text = "Material",
    Options = {
        { Value = "Stone", Meta = 320 },
        { Value = "Wood", Meta = 180 },
        { Value = "Metal", Meta = 90 },
    },
})
choices:AddDropdown("Quality", { Text = "Quality", Options = { "Low", "Medium", "High" }, Value = "High" })

local shortcuts = pages.Actions:AddGroupbox("Shortcuts", "Left")
shortcuts:AddButton({
    Text = "Save",
    Primary = true,
    Keybind = { Id = "SaveKey", Value = Enum.KeyCode.K },
    Callback = action("Saved"),
})
shortcuts:AddButton({
    Text = "Reload",
    Keybind = { Id = "ReloadKey", Value = Enum.KeyCode.J },
    Callback = action("Reloaded"),
})
shortcuts:AddButton({ Text = "Locked", Disabled = true })

local buttonRow = pages.Actions:AddGroupbox("Button row", "Right")
buttonRow:AddButtons({
    { Text = "One", Callback = action("One") },
    { Text = "Two", Callback = action("Two") },
    { Text = "Three", Callback = action("Three") },
})
buttonRow:AddKeybind("HoldKey", {
    Text = "Hold action",
    Value = Enum.KeyCode.G,
    Pressed = action("Action held"),
    Released = action("Action released"),
})

local glyphs = {
    A = "010/101/111/101/101",
    B = "110/101/110/101/110",
    C = "011/100/100/100/011",
    D = "110/101/101/101/110",
    E = "111/100/110/100/111",
    F = "111/100/110/100/100",
    G = "011/100/101/101/011",
    H = "101/101/111/101/101",
    I = "111/010/010/010/111",
    J = "001/001/001/101/010",
    K = "101/101/110/101/101",
    L = "100/100/100/100/111",
    M = "101/111/111/101/101",
    N = "101/111/111/111/101",
    O = "010/101/101/101/010",
    P = "110/101/110/100/100",
    Q = "010/101/101/111/011",
    R = "110/101/110/101/101",
    S = "011/100/010/001/110",
    T = "111/010/010/010/010",
    U = "101/101/101/101/111",
    V = "101/101/101/101/010",
    W = "101/101/111/111/101",
    X = "101/101/010/101/101",
    Y = "101/101/010/010/010",
    Z = "111/001/010/100/111",
    [" "] = "000/000/000/000/000",
    ["?"] = "110/001/010/000/010",
}

local shapes = {
    Heart = {
        ".##...##.",
        "####.####",
        "#########",
        ".#######.",
        "..#####..",
        "...###...",
        "....#....",
    },
    Arrow = {
        "....#....",
        "...###...",
        "..#####..",
        ".#######.",
        "...###...",
        "...###...",
        "...###...",
    },
}

local shape, message, filled = "Heart", "KINOUE", 0
local preview, animate, messageBox, pulseButton, fillButtons

local function textPoints()
    local result = {}
    local upper = message:upper():sub(1, 32)
    for index = 1, #upper do
        local rows = string.split(glyphs[upper:sub(index, index)] or glyphs["?"], "/")
        for y, line in ipairs(rows) do
            for x = 1, #line do
                if line:sub(x, x) == "1" then
                    table.insert(result, Vector2.new((index - 1) * 4 + x - 1, y - 1))
                end
            end
        end
    end
    return result
end

local function shapePoints()
    local result = {}
    for y, line in ipairs(shapes[shape]) do
        for x = 1, #line do
            if line:sub(x, x) == "#" then
                table.insert(result, Vector2.new(x - 1, y - 1))
            end
        end
    end
    return result
end

local function points()
    if shape == "Text" then
        return textPoints()
    end
    return shapePoints()
end

local function refresh()
    pages.Preview:SetMode(shape)
    if messageBox then
        messageBox:SetVisible(shape == "Text")
    end
    if preview then
        local current = points()
        filled = math.min(filled, #current)
        preview:SetPoints(current)
        preview:SetCount(filled, #current)
    end
    if pulseButton and animate then
        pulseButton:SetEnabled(animate:Get())
    end
end

local function fill()
    filled = #points()
    refresh()
    status("Filled " .. filled .. " pixels")
end

local function step()
    filled = math.min(filled + 10, #points())
    refresh()
    status("Filled " .. filled .. " pixels")
end

local function clear()
    filled = 0
    refresh()
    status("Cleared")
end

local function pulse()
    if animate:Get() then
        preview:Recoil()
        status("Pulse")
    end
end

pages.Preview:SetTitle("Pixel preview")

local composition = pages.Preview:AddGroupbox("Composition", "Left")
composition:AddDropdown("Shape", {
    Text = "Shape",
    Options = { "Heart", "Arrow", "Text" },
    Value = shape,
    Callback = function(value)
        shape = value
        filled = 0
        refresh()
    end,
})
messageBox = composition:AddTextbox("Message", {
    Text = "Message",
    Value = message,
    MaxLength = 32,
    Callback = function(value)
        message = value
        filled = 0
        refresh()
    end,
})
composition:AddSlider("Scale", { Text = "Scale", Min = 1, Max = 20, Value = 10, Suffix = "px" })
composition:AddKeybind("FillKey", {
    Text = "Fill",
    Value = Enum.KeyCode.T,
    Pressed = fill,
    Callback = function(key)
        if fillButtons then
            fillButtons[2].Text = "Fill [" .. key.Name .. "]"
        end
    end,
})

local effects = pages.Preview:AddGroupbox("Effects", "Left")
animate = effects:AddToggle("Animate", {
    Text = "Animate",
    Keybind = {
        Id = "PulseKey",
        Value = Enum.KeyCode.F,
        Pressed = pulse,
        Callback = function(key)
            pulseButton:SetText("Pulse [" .. key.Name .. "]")
        end,
    },
    Callback = refresh,
})
pulseButton = effects:AddButton({ Text = "Pulse [F]", Callback = pulse })

local viewer = pages.Preview:AddGroupbox("Preview", "Right")
preview = viewer:AddPreview({ Height = 148, Points = points() })
fillButtons = viewer:AddButtons({
    { Text = "Step", Callback = step },
    { Text = "Fill [T]", Primary = true, Callback = fill },
    { Text = "Clear", Callback = clear },
})
refresh()

local colors = pages.Visuals:AddSubTab("Colors")
local glowTab = pages.Visuals:AddSubTab("Glow")

local palette = colors:AddGroupbox("Palette", "Left")
palette:AddColorPicker("PrimaryColor", { Text = "Primary", Value = Color3.fromRGB(57, 128, 233) })
palette:AddColorPicker("SecondaryColor", { Text = "Secondary", Value = Color3.fromRGB(233, 57, 128) })
palette:AddColorPicker("BackgroundColor", { Text = "Background", Value = Color3.fromRGB(20, 20, 20) })

local opacity = colors:AddGroupbox("Opacity", "Right")
opacity:AddSlider("FillOpacity", { Text = "Fill opacity", Min = 0, Max = 100, Value = 85, Suffix = "%" })
opacity:AddSlider("OutlineOpacity", { Text = "Outline opacity", Min = 0, Max = 100, Value = 100, Suffix = "%" })

local glow = glowTab:AddGroupbox("Glow", "Left")
glow:AddToggle("Glow", { Text = "Glow" })
local glowAdvanced = glow:AddDisclosure("Advanced")
glowAdvanced:AddSlider("GlowSize", { Text = "Size", Min = 1, Max = 16, Value = 4, Suffix = "px" })
glowAdvanced:AddSlider("GlowSpeed", { Text = "Speed", Min = 1, Max = 10, Value = 3 })
glowAdvanced:AddToggle("GlowPulse", { Text = "Pulse" })

local blur = glowTab:AddGroupbox("Blur", "Right")
blur:AddToggle("Blur", { Text = "Background blur" })
blur:AddSlider("BlurSize", { Text = "Blur size", Min = 0, Max = 24, Value = 8, Suffix = "px" })

local navigation = pages.Layout:AddGroupbox("Navigation", "Left")
local movement = navigation:AddDisclosure("Movement keys")
for _, entry in ipairs({
    { "Forward", Enum.KeyCode.W },
    { "Backward", Enum.KeyCode.S },
    { "Left", Enum.KeyCode.A },
    { "Right", Enum.KeyCode.D },
    { "Up", Enum.KeyCode.Space },
    { "Down", Enum.KeyCode.LeftControl },
}) do
    movement:AddKeybind("Move" .. entry[1], { Text = entry[1], Value = entry[2] })
end

local columns = pages.Layout:AddGroupbox("Columns", "Right")
columns:AddLabel("Groupboxes stack in two columns.", true)
columns:AddLabel("Narrow windows use one column.", true)

local checklist = pages.Layout:AddGroupbox("Checklist", "Left")
for index, name in ipairs({ "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta" }) do
    checklist:AddToggle("Item" .. name, { Text = name, Value = index <= 3 })
end

local windowSettings = pages.Settings:AddGroupbox("Window", "Left")
windowSettings:AddKeybind("MenuKey", {
    Text = "Show / hide menu",
    Value = Enum.KeyCode.RightShift,
    Callback = function(key)
        window:SetToggleKey(key)
    end,
})
windowSettings:AddKeybind("UnloadKey", {
    Text = "Unload interface",
    Value = Enum.KeyCode.End,
    Pressed = function()
        window:Destroy()
    end,
})

local saving = pages.Settings:AddGroupbox("Persistence", "Left")
local savedLabel = saving:AddLabel("Settings: session")

local session = pages.Settings:AddGroupbox("Session", "Right")
session:AddButton({
    Text = "Reset toggles",
    Callback = function()
        for _, control in pairs(window.Controls) do
            if type(control:Get()) == "boolean" then
                control:Set(false)
            end
        end
        status("Toggles reset")
    end,
})
session:AddButton({
    Text = "Unload UI",
    Callback = function()
        window:Destroy()
    end,
})

if type(readfile) == "function" and type(writefile) == "function" then
    window:EnablePersistence(Library.FileStorage("Kinoue/demo.json"))
    savedLabel:SetText("Settings: automatic")
end

pages.Preview:Select()
return window

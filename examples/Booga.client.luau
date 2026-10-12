local Library = require(game:GetService("ReplicatedStorage"):WaitForChild("BoogaUI"))
-- UI demonstration only. Callbacks update demo state; no game remotes or item manipulation.
local window = Library:CreateWindow({ Name = "BOOGA", Footer = "Preview", ToggleKey = Enum.KeyCode.RightShift })
local pages = {}
for _, name in ipairs({ "Items", "Formations", "Studio", "Movement", "Visuals", "Aim", "Settings" }) do pages[name] = window:AddTab(name) end
pages.Studio:SetTitle("Drawing studio")
local mode = "None"
local refresh
local function status(text) window:SetStatus(text) end
local function setMode(value)
    mode = value
    for _, page in pairs(pages) do page:SetMode(value == "None" and "No active formation" or value) end
    if refresh then refresh() end
end
setMode("None")
local function action(text) return function() status(text) end end

local pickup = pages.Items:AddGroupbox("Pickup", "Left")
pickup:AddButton({ Text = "Pickup all", Keybind = { Id = "PickupKey", Value = Enum.KeyCode.P }, Callback = action("Pickup requested") })
pickup:AddToggle("AutoPickup", { Text = "Auto pickup", Value = false })
pickup:AddSlider("PickupDistance", { Text = "Pickup distance", Min = 1, Max = 25, Value = 25, Suffix = "studs" })
local bring = pages.Items:AddGroupbox("Bring items", "Left")
bring:AddSlider("BringDistance", { Text = "Bring distance", Min = 1, Max = 100, Value = 20, Suffix = "studs" })
bring:AddButton({ Text = "Bring items", Primary = true, Callback = action("Bring requested") })
local throw = pages.Items:AddGroupbox("Throw", "Right")
throw:AddButton({ Text = "Hold / Throw", Keybind = { Id = "ThrowKey", Value = Enum.KeyCode.H }, Callback = action("Throw requested") })
throw:AddButton({ Text = "Fling all", Callback = action("Fling requested") })
pages.Items:AddGroupbox("Spawn", "Right"):AddButton({ Text = "Spawn at bed", Callback = action("Spawn requested") })

local formation = pages.Formations:AddGroupbox("Formation", "Left")
for _, entry in ipairs({ { "Orbit", "OrbitKey", Enum.KeyCode.R }, { "Player box", "PlayerBoxKey", Enum.KeyCode.Q } }) do
    local name = entry[1]
    formation:AddButton({ Text = name, Keybind = { Id = entry[2], Value = entry[3] }, Callback = function() setMode(name) end })
end
formation:AddLabel("35 studs", true)
formation:AddButton({ Text = "Self box", Keybind = { Id = "SelfBoxKey", Value = Enum.KeyCode.G }, Callback = function() setMode("Self box") end })
formation:AddDropdown("SelfBoxShape", { Text = "Self box shape", Options = { "Self box", "7x7x7 house", "20x20x20 house" } })
local active = pages.Formations:AddGroupbox("Active formation", "Right")
active:AddButton({ Text = "Stop formation", Primary = true, Callback = function() setMode("None") end })
active:AddButton({ Text = "Open Studio", Callback = function() pages.Studio:Select() end })

local font = {
    A="010/101/111/101/101",B="110/101/110/101/110",C="011/100/100/100/011",D="110/101/101/101/110",E="111/100/110/100/111",F="111/100/110/100/100",G="011/100/101/101/011",H="101/101/111/101/101",I="111/010/010/010/111",J="001/001/001/101/010",K="101/101/110/101/101",L="100/100/100/100/111",M="101/111/111/101/101",N="101/111/111/111/101",O="010/101/101/101/010",P="110/101/110/100/100",Q="010/101/101/111/011",R="110/101/110/101/101",S="011/100/010/001/110",T="111/010/010/010/010",U="101/101/101/101/111",V="101/101/101/101/010",W="101/101/111/111/101",X="101/101/010/101/101",Y="101/101/010/010/010",Z="111/001/010/100/111",[" "]="000/000/000/000/000",["?"]="110/001/010/000/010",
}
local ak = { ".......................#........", ".............###########........", "........###############.########", "##.....################.........", "#######.###########.............", "######..#..#..##................", "####....#..#...##...............", "##......###.....##..............", "........##.......##.............", ".......##.........##............", "..................###..........." }
local shape, text, prepared = "AK-47", "BOOGA", 0
local preview, shooting, textbox, shootButton, drawButtons
local function points()
    local result = {}
    if shape == "AK-47" then
        for y, line in ipairs(ak) do for x = 1, #line do if line:sub(x, x) == "#" then table.insert(result, Vector2.new(x - 1, y - 1)) end end end
    else
        local upper = text:upper():sub(1, 32)
        for letter = 1, #upper do
            local rows = string.split(font[upper:sub(letter, letter)] or font["?"], "/")
            for y, line in ipairs(rows) do for x = 1, #line do if line:sub(x, x) == "1" then table.insert(result, Vector2.new((letter - 1) * 4 + x - 1, y - 1)) end end end
        end
    end
    return result
end
refresh = function()
    if textbox then textbox:SetVisible(shape == "Text") end
    if preview then preview:SetPoints(points()); preview:SetCount(prepared, #points()) end
    if shootButton and shooting then shootButton:SetEnabled(shape == "AK-47" and shooting:Get() and mode == "Drawing") end
end
local function draw() setMode("Drawing"); refresh(); status("Drawing " .. shape) end
local function stop() setMode("None"); refresh(); status("Stopped") end
local function shoot()
    if shape == "AK-47" and shooting:Get() and mode == "Drawing" then preview:Recoil(); status("Shot preview") end
end
local composition = pages.Studio:AddGroupbox("Composition", "Left")
composition:AddDropdown("Drawing", { Text = "Create", Options = { "Text", "AK-47" }, Value = "AK-47", Callback = function(value) shape = value; prepared = 0; refresh() end })
textbox = composition:AddTextbox("SpellText", { Text = "Text", Value = "BOOGA", MaxLength = 32, Callback = function(value) text = value; prepared = 0; refresh() end })
composition:AddDropdown("Material", { Text = "Material", Options = { { Value = "Bluefruit", Meta = 320 }, { Value = "Leaves", Meta = 240 }, { Value = "Wood", Meta = 180 } }, Callback = function() prepared = 0; refresh() end })
composition:AddSlider("DrawingDistance", { Text = "Distance", Min = 1, Max = 20, Value = 10, Suffix = "studs" })
composition:AddKeybind("DrawKey", { Text = "Draw / hold", Value = Enum.KeyCode.T, Pressed = draw, Callback = function(key) if drawButtons then drawButtons[2].Text = "Draw [" .. key.Name .. "]" end end })
local effects = pages.Studio:AddGroupbox("Effects", "Left")
shooting = effects:AddToggle("Shooting", { Text = "Shooting", Keybind = { Id = "ShootKey", Value = Enum.KeyCode.F, Pressed = shoot, Callback = function(key) if shootButton then shootButton:SetText("Shoot [" .. key.Name .. "]") end end }, Callback = refresh })
shootButton = effects:AddButton({ Text = "Shoot [F]", Callback = shoot })
local viewer = pages.Studio:AddGroupbox("Preview", "Right")
preview = viewer:AddPreview({ Height = 148, Points = points() })
drawButtons = viewer:AddButtons({
    { Text = "Drop missing", Callback = function() prepared = #points(); window.Controls.AutoPickup:Set(false); preview:SetCount(prepared, #points()); status("Dropped " .. prepared) end },
    { Text = "Draw [T]", Primary = true, Callback = draw },
    { Text = "Stop", Callback = stop },
})
refresh()

local ground = pages.Movement:AddGroupbox("Ground movement", "Left")
ground:AddToggle("SpeedOverwrite", { Text = "Speed overwrite" })
ground:AddSlider("WalkSpeed", { Text = "Walk speed", Min = 1, Max = 24, Value = 16, Suffix = "studs/sec" })
pages.Movement:AddGroupbox("Water", "Left"):AddToggle("WaterWalker", { Text = "Water Walker", Value = true })
local flight = pages.Movement:AddGroupbox("Bullets Cape / Flight", "Right")
flight:AddButton({ Text = "Toggle cape", Keybind = { Id = "CapeKey", Value = Enum.KeyCode.E }, Callback = action("Cape toggled") })
local direction = flight:AddDisclosure("Flight keybinds")
for _, entry in ipairs({ { "Forward", Enum.KeyCode.W }, { "Backward", Enum.KeyCode.S }, { "Left", Enum.KeyCode.A }, { "Right", Enum.KeyCode.D }, { "Up", Enum.KeyCode.Space }, { "Down", Enum.KeyCode.LeftControl } }) do direction:AddKeybind("Flight" .. entry[1], { Text = entry[1], Value = entry[2] }) end

local players = pages.Visuals:AddSubTab("Players")
local resources = pages.Visuals:AddSubTab("Resources")
local style = pages.Visuals:AddSubTab("Style")
local esp = players:AddGroupbox("Player ESP", "Left")
esp:AddToggle("PlayerESP", { Text = "Player ESP" })
for _, entry in ipairs({ { "Boxes", true }, { "Names", true }, { "Health / HP", true }, { "Distance", true }, { "Tracers", false }, { "Highlight", false } }) do esp:AddToggle("ESP" .. entry[1], { Text = entry[1], Value = entry[2] }) end
local tribe = esp:AddDisclosure("Tribe & visibility")
for _, entry in ipairs({ { "Use tribe color", false }, { "Show tribe name", false }, { "Ignore own tribe", false }, { "Through walls", true } }) do tribe:AddToggle("Tribe" .. entry[1], { Text = entry[1], Value = entry[2] }) end
local appearance = players:AddGroupbox("Appearance", "Right")
appearance:AddDropdown("BoxStyle", { Text = "Box style", Options = { "Corners", "Full" } })
appearance:AddDropdown("TracerOrigin", { Text = "Tracer origin", Options = { "Bottom", "Center", "Cursor" } })
appearance:AddSlider("PlayerRange", { Text = "Maximum distance", Min = 50, Max = 10000, Value = 2500, Suffix = "studs" })
local advanced = appearance:AddDisclosure("Advanced styling & refresh")
advanced:AddColorPicker("PlayerColor", { Text = "Custom / no-tribe color", Value = Color3.new(1, 1, 1) })
advanced:AddSlider("ESPTextSize", { Text = "Text size", Min = 10, Max = 24, Value = 14, Suffix = "px" })
advanced:AddSlider("ESPThickness", { Text = "Line thickness", Min = 1, Max = 4, Value = 1, Suffix = "px" })
advanced:AddSlider("ESPFill", { Text = "Highlight transparency", Min = 0, Max = 100, Value = 85, Suffix = "%" })
advanced:AddSlider("ESPRefresh", { Text = "Refresh rate", Min = 5, Max = 60, Value = 30, Suffix = "Hz" })
advanced:AddToggle("DynamicRefresh", { Text = "Dynamic refresh rate" })
local ores = resources:AddGroupbox("Ore ESP", "Left")
ores:AddToggle("OreESP", { Text = "Ore ESP" })
for i, name in ipairs({ "Gold Ore", "Iron", "Coal", "Crystal", "Emerald", "Adurite", "Meteor", "Stone" }) do ores:AddToggle("Ore" .. name, { Text = name, Value = i <= 3 }) end
local oreOptions = resources:AddGroupbox("Resource options", "Right")
oreOptions:AddSlider("OreDistance", { Text = "Ore distance", Min = 50, Max = 10000, Value = 2500, Suffix = "studs" })
oreOptions:AddToggle("OreLabels", { Text = "Distance labels", Value = true })
oreOptions:AddToggle("OreHighlights", { Text = "Ore highlights" })
oreOptions:AddToggle("MarketESP", { Text = "Market ESP" })
style:AddGroupbox("Equip animations", "Left"):AddDropdown("EquipAnimation", { Text = "Rock equip animation", Options = { "Off", "Karambit", "Ghost Karambit" } })
pages.Aim:AddGroupbox("Silent aim", "Left"):AddToggle("SilentAim", { Text = "Silent Aim" })

local settings = pages.Settings:AddGroupbox("Window", "Left")
settings:AddKeybind("MenuKey", { Text = "Show / hide menu", Value = Enum.KeyCode.RightShift, Callback = function(key) window:SetToggleKey(key) end })
settings:AddKeybind("UnloadKey", { Text = "Unload interface", Value = Enum.KeyCode.End, Pressed = function() window:Destroy() end })
local saving = pages.Settings:AddGroupbox("Persistence", "Left")
local savedLabel = saving:AddLabel("Settings: session")
local session = pages.Settings:AddGroupbox("Session", "Right")
session:AddButton({ Text = "Panic mode", Callback = function()
    for _, c in pairs(window.Controls) do if type(c:Get()) == "boolean" then c:Set(false) end end
    window.Controls.EquipAnimation:Set("Off"); stop()
end })
session:AddButton({ Text = "Unload UI", Callback = function() window:Destroy() end })
if type(readfile) == "function" and type(writefile) == "function" then
    window:EnablePersistence(Library.FileStorage("BoogaUI/config.json"))
    savedLabel:SetText("Settings: automatic")
end
pages.Studio:Select()
return window

local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/booga-ui/v0.1.10/dist/BoogaUI.lua"))()

-- In Roblox Studio, replace the loader above with:
-- local UI = require(game.ReplicatedStorage:WaitForChild("BoogaUI"))

local environment = type(getgenv) == "function" and getgenv() or shared
if environment and environment.BoogaUIExample then
    environment.BoogaUIExample:Destroy()
end

local window = UI:CreateWindow({
    Name = "BOOGA",
    Id = "BoogaUIExample",
    Footer = "Example",
    ToggleKey = Enum.KeyCode.RightShift,
})
if environment then environment.BoogaUIExample = window end

local main = window:AddTab("Main")
local settings = window:AddTab("Settings")
local controls = main:AddGroupbox("Controls", "Left")
local actions = main:AddGroupbox("Actions", "Right")

local shooting = controls:AddToggle("Shooting", {
    Text = "Shooting",
    Value = false,
    Callback = function(enabled)
        window:SetStatus(enabled and "Shooting on" or "Shooting off")
        -- Put your feature logic here.
    end,
})

local distance = controls:AddSlider("Distance", {
    Text = "Distance",
    Min = 1,
    Max = 20,
    Value = 10,
    Step = 1,
    Suffix = "studs",
    Callback = function(value)
        window:SetStatus("Distance: " .. value)
    end,
})

local material = controls:AddDropdown("Material", {
    Text = "Material",
    Value = "Bluefruit",
    Options = {
        { Value = "Bluefruit", Label = "Bluefruit", Meta = 320 },
        { Value = "Wood", Label = "Wood", Meta = 180 },
        { Value = "Leaves", Label = "Leaves", Meta = 240 },
    },
    Callback = function(value)
        window:SetStatus("Material: " .. value)
    end,
})

local text = controls:AddTextbox("Text", {
    Text = "Text",
    Value = "BOOGA",
    MaxLength = 32,
    Callback = function(value)
        window:SetStatus(value)
    end,
})

actions:AddButton({
    Text = "Print values",
    Primary = true,
    Keybind = { Id = "PrintKey", Value = Enum.KeyCode.P },
    Callback = function()
        print("Shooting:", shooting:Get())
        print("Distance:", distance:Get())
        print("Material:", material:Get())
        print("Text:", text:Get())
        window:SetStatus("Values printed")
    end,
})

actions:AddButtons({
    { Text = "On", Callback = function() shooting:Set(true) end },
    { Text = "Off", Callback = function() shooting:Set(false) end },
})

local advanced = actions:AddDisclosure("Advanced")
advanced:AddColorPicker("Color", {
    Text = "Color",
    Value = Color3.fromRGB(57, 128, 233),
    Callback = function(value)
        print("Selected color:", value)
    end,
})

local binds = settings:AddGroupbox("Keybinds", "Left")
binds:AddKeybind("MenuKey", {
    Text = "Show / hide menu",
    Value = Enum.KeyCode.RightShift,
    Callback = function(key)
        window:SetToggleKey(key)
    end,
})

settings:AddGroupbox("Session", "Right"):AddButton({
    Text = "Unload UI",
    Callback = function()
        window:Destroy()
        if environment then environment.BoogaUIExample = nil end
    end,
})

-- Optional saving in environments with file APIs.
if type(readfile) == "function" and type(writefile) == "function" then
    window:EnablePersistence(UI.FileStorage("BoogaUI/example.json"))
end

main:Select()
return window

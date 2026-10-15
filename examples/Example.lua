local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Proxo123/Kinoue-Lib/main/dist/Kinoue.lua"))()

local environment = type(getgenv) == "function" and getgenv() or shared
if environment and environment.KinoueExample then
    environment.KinoueExample:Destroy()
end

local window = UI:CreateWindow({
    Name = "Kinoue",
    Id = "KinoueExample",
    Subtitle = "Example",
    ToggleKey = Enum.KeyCode.RightShift,
})
if environment then
    environment.KinoueExample = window
end

local main = window:AddTab("Main")
local settings = window:AddTab("Settings")
local controls = main:AddGroupbox("Controls", "Left")
local actions = main:AddGroupbox("Actions", "Right")

local enabled = controls:AddToggle("Enabled", {
    Text = "Enabled",
    Value = false,
    Callback = function(value)
        window:SetStatus(value and "Enabled" or "Disabled")
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
    Value = "Stone",
    Options = {
        { Value = "Stone", Label = "Stone", Meta = 320 },
        { Value = "Wood", Label = "Wood", Meta = 180 },
        { Value = "Metal", Label = "Metal", Meta = 90 },
    },
    Callback = function(value)
        window:SetStatus("Material: " .. value)
    end,
})

local text = controls:AddTextbox("Text", {
    Text = "Text",
    Value = "Kinoue",
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
        print("Enabled:", enabled:Get())
        print("Distance:", distance:Get())
        print("Material:", material:Get())
        print("Text:", text:Get())
        window:SetStatus("Values printed")
    end,
})

actions:AddButtons({
    {
        Text = "On",
        Callback = function()
            enabled:Set(true)
        end,
    },
    {
        Text = "Off",
        Callback = function()
            enabled:Set(false)
        end,
    },
})

local advanced = actions:AddDisclosure("Advanced")
advanced:AddColorPicker("Color", {
    Text = "Color",
    Value = Color3.fromRGB(57, 128, 233),
    Callback = function(value)
        print("Selected color:", value)
    end,
})

settings:AddGroupbox("Session", "Right"):AddButton({
    Text = "Unload UI",
    Callback = function()
        window:Destroy()
        if environment then
            environment.KinoueExample = nil
        end
    end,
})

if type(readfile) == "function" and type(writefile) == "function" then
    window:EnablePersistence(UI.FileStorage("Kinoue/example.json"))
end

main:Select()
return window

# Kinoue Lib

Compact Luau UI library for Roblox. Requires a client context with CoreGui access.

## Install

```lua
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Proxo123/Kinoue-Lib/main/dist/BoogaUI.lua"
))()
```

Or import `dist/BoogaUI.rbxmx` as a ModuleScript and `require` it.

## Usage

Every function in the library:

```lua
local window = UI:CreateWindow({
    Name = "Kinoue", Id = "Kinoue", Footer = "v" .. UI.Version,
    Size = Vector2.new(704, 470), MinSize = Vector2.new(480, 360),
    Position = UDim2.fromScale(0.5, 0.5), DisplayOrder = 100,
    Resizable = true, AllowOffscreen = true, SnapDistance = 8,
    ToggleKey = Enum.KeyCode.RightShift, ReducedMotion = false, ReplaceExisting = true,
})

-- Tabs and groupboxes
local main = window:AddTab("Main")
main:SetTitle("Main")
main:SetMode("Example")
local left = main:AddGroupbox("Controls", "Left")
local right = main:AddGroupbox("Actions", "Right")

-- Controls
local label = left:AddLabel("Hello")
left:AddLabel("Small muted text", true)

local toggle
toggle = left:AddToggle("Enabled", {
    Text = "Enabled", Value = false,
    Keybind = { Id = "EnabledKey", Value = Enum.KeyCode.E, Pressed = function() toggle:Set(not toggle:Get()) end },
    Callback = function(value) window:SetStatus("Enabled: " .. tostring(value)) end,
})

local slider = left:AddSlider("Speed", {
    Text = "Speed", Min = 0, Max = 50, Step = 0.5, Value = 16,
    Format = "%.1f", Suffix = "studs/s", Callback = print,
})

local textbox = left:AddTextbox("Name", { Text = "Name", Placeholder = "Type here", MaxLength = 24, Callback = print })

local dropdown = left:AddDropdown("Mode", {
    Text = "Mode", Value = "Normal",
    Options = { "Normal", { Value = "Fast", Label = "Fast", Meta = "x2" } },
    Callback = print,
})

local key = left:AddKeybind("ActionKey", {
    Text = "Action", Value = Enum.KeyCode.Q,
    Pressed = function() print("down") end,
    Released = function() print("up") end,
    Callback = function(newKey) print("Rebound to", newKey.Name) end,
})

local color = left:AddDisclosure("Advanced"):AddColorPicker("Color", {
    Text = "Color", Value = Color3.fromRGB(57, 128, 233), Callback = print,
})

-- Control methods (toggle, slider, textbox, dropdown, keybind, color picker)
slider:Set(20)        -- fires the callback
slider:SetSilent(10)  -- skips the callback
textbox:RawSet("Kinoue") -- same as SetSilent
slider:SetCallback(function(value) print("Speed", value) end)
key:SetEnabled(true)
color:SetVisible(true)
dropdown:UpdateOptions({ "Normal", "Fast", "Slow" })
label:SetText("Ready")
label:SetVisible(true)

-- Buttons
right:AddButton({
    Text = "Print", Primary = true,
    Keybind = { Id = "PrintKey", Value = Enum.KeyCode.P },
    Callback = function()
        print(toggle:Get(), slider:Get(), textbox:Get(), dropdown:Get(), key:Get(), color:Get())
    end,
})

local locked = right:AddButton({ Text = "Locked", Width = 80, Disabled = true, Callback = print })
locked:SetText("Unlocked")
locked:SetEnabled(true)

local row = right:AddButtons({
    { Text = "Open color", Callback = function() color:Open() end },
    { Text = "Close color", Callback = function() color:Close() end },
})
row[1].TextColor3 = UI.Theme.Accent -- AddButtons returns the TextButtons

-- Sub-tabs and preview
local layout = window:AddTab("Layout")
local shapes = layout:AddSubTab("Preview")
layout:AddSubTab("Other"):AddGroupbox("Empty", "Left")
shapes:Select()

local preview = shapes:AddGroupbox("Preview", "Left"):AddPreview({
    Points = { Vector2.new(0, 0), Vector2.new(1, 0) }, Height = 148,
})
preview:SetPoints({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1) })
preview:SetCount(1, 3)
preview:Recoil()

-- Window
main:Select()
window:SelectTab(main)
window:SetToggleKey(Enum.KeyCode.RightShift)
window:SetSize(Vector2.new(704, 470))
window:SetPosition(Vector2.new(100, 100), true) -- true snaps to nearby edges
print(window:GetPosition())
window:SetVisible(true)
window:ClosePopup()

-- Config
local json = window:EncodeConfig()
window:DecodeConfig(json)
window:LoadConfig(window:GetConfig())
window:EnablePersistence(UI.FileStorage("Kinoue/config.json")) -- or { Read = fn, Write = fn }
window:FlushConfig()

-- Cleanup
window:OnDestroy(function() print("Unloaded") end)
-- window:Destroy()
```

RightShift toggles the menu.

## Build

```powershell
python tools/build.py
python tools/test.py --luau path/to/luau --compiler path/to/luau-compile
```

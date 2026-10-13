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

```lua
local window = UI:CreateWindow({ Name = "Kinoue" })
local group = window:AddTab("Main"):AddGroupbox("Controls", "Left")

group:AddToggle("Enabled", { Text = "Enabled", Value = false, Callback = print })
group:AddSlider("Speed", { Text = "Speed", Min = 1, Max = 20, Value = 10 })
group:AddButton({ Text = "Run", Callback = function() end })
```

RightShift toggles the menu. See [examples](examples) for more.

## Build

```powershell
python tools/build.py
python tools/test.py --luau path/to/luau --compiler path/to/luau-compile
```

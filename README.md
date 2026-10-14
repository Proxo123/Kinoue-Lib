# Kinoue Lib

Compact Luau UI library for Roblox. Requires a client context with CoreGui access.

## Install

```lua
local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Proxo123/Kinoue-Lib/main/dist/Kinoue.lua"
))()
```

Or import `dist/Kinoue.rbxmx` as a ModuleScript and `require` it.

## Quick start

```lua
local window = UI:CreateWindow({ Name = "Kinoue", Footer = "v" .. UI.Version })
local main = window:AddTab("Main")
local group = main:AddGroupbox("Controls", "Left")

group:AddToggle("Enabled", {
    Text = "Enabled",
    Callback = function(value)
        window:SetStatus("Enabled: " .. tostring(value))
    end,
})
```

RightShift shows and hides the window.

## Window

```lua
local window = UI:CreateWindow({
    Name = "Kinoue",
    Id = "Kinoue",
    Footer = "v" .. UI.Version,
    Size = Vector2.new(704, 470),
    MinSize = Vector2.new(480, 360),
    Position = UDim2.fromScale(0.5, 0.5),
    DisplayOrder = 100,
    Resizable = true,
    AllowOffscreen = true,
    SnapDistance = 8,
    ToggleKey = Enum.KeyCode.RightShift,
    ReducedMotion = false,
    RainbowAccent = true,
    ShowSettings = true,
    ReplaceExisting = true,
})
```

`AllowOffscreen = false` (the default) locks the window to the screen: dragging stops at the edges. With `AllowOffscreen = true` the window can be dragged partly or fully off screen, and it snaps to edges within `SnapDistance` pixels.

| Method | Description |
| --- | --- |
| `window:AddTab(name)` | Adds a tab and returns its page. |
| `window:SelectTab(page)` | Shows a tab. |
| `window:SetStatus(text)` | Sets the footer status text. |
| `window:SetToggleKey(keyCode)` | Changes the show/hide key. |
| `window:SetVisible(open)` | Shows or hides the window. |
| `window:SetSize(Vector2)` | Resizes the window, keeping the top-left corner fixed. |
| `window:SetPosition(Vector2, snapEdges)` | Moves the window; `snapEdges` snaps to nearby screen edges. |
| `window:GetPosition()` | Returns the top-left corner as a `Vector2`. |
| `window:ClosePopup()` | Closes an open dropdown or color picker. |
| `window:OpenSettings()` / `window:CloseSettings()` / `window:ToggleSettings()` | Shows or hides the settings page. |
| `window:SetLockToScreen(locked)` | Keeps the window on screen, or lets it be dragged past the edges. |
| `window:SetReducedMotion(reduced)` | Turns animations off or on. |
| `window:SetRainbowAccent(enabled)` | Switches the header line between rainbow and the accent color. |
| `window:OnDestroy(callback)` | Runs `callback` after the window is removed. |
| `window:Destroy()` | Removes the window and disconnects everything. |

## Settings and themes

The gear button in the top-right corner of the header opens the settings page. Press it again to go back. The page has:

- **Theme:** a preset (Dark, Midnight, Ocean, Rose, Forest, Light), color pickers for the accent, background, panels, outlines, text and muted text, and a reset button.
- **Window:** Lock to screen and Snap to edges.
- **Appearance:** Animations and Rainbow accent line.

Settings are saved with the rest of the config under IDs that start with `UI.`. Themes apply to every window at once.

```lua
UI:SetTheme("Ocean")
UI:SetTheme({ Accent = Color3.fromRGB(255, 120, 0) })
print(UI:GetTheme(), UI.Themes)
```

Pass `ShowSettings = false` to `CreateWindow` to hide the gear button.

## Pages and groupboxes

```lua
local main = window:AddTab("Main")
main:SetTitle("Main")
main:SetMode("Example")
main:Select()

local left = main:AddGroupbox("Controls", "Left")
local right = main:AddGroupbox("Actions", "Right")

local layout = window:AddTab("Layout")
local preview = layout:AddSubTab("Preview")
preview:AddGroupbox("Preview", "Left")
preview:Select()

local advanced = left:AddDisclosure("Advanced")
```

A disclosure is a collapsible section. It supports the same `Add*` methods as a groupbox.

## Controls

Every control with an ID is registered in `window.Controls[id]` and saved with the config.

```lua
local label = left:AddLabel("Hello")
left:AddLabel("Small muted text", true)

local toggle = left:AddToggle("Enabled", {
    Text = "Enabled",
    Value = false,
    Keybind = { Id = "EnabledKey", Value = Enum.KeyCode.E },
    Callback = print,
})

left:AddToggle("Hints", { Text = "Hints", Keybind = true })

local slider = left:AddSlider("Speed", {
    Text = "Speed",
    Min = 0,
    Max = 50,
    Step = 0.5,
    Value = 16,
    Format = "%.1f",
    Suffix = "studs/s",
    Callback = print,
})

local textbox = left:AddTextbox("Name", {
    Text = "Name",
    Placeholder = "Type here",
    MaxLength = 24,
    Callback = print,
})

local dropdown = left:AddDropdown("Mode", {
    Text = "Mode",
    Value = "Normal",
    Options = { "Normal", { Value = "Fast", Label = "Fast", Meta = "x2" } },
    Callback = print,
})

local key = left:AddKeybind("ActionKey", {
    Text = "Action",
    Value = Enum.KeyCode.Q,
    Pressed = function()
        print("down")
    end,
    Released = function()
        print("up")
    end,
    Callback = function(newKey)
        print("Rebound to", newKey.Name)
    end,
})

local color = advanced:AddColorPicker("Color", {
    Text = "Color",
    Value = Color3.fromRGB(57, 128, 233),
    Callback = print,
})
```

Toggles, sliders, textboxes, dropdowns, keybinds and color pickers share these methods:

| Method | Description |
| --- | --- |
| `control:Get()` | Returns the current value. |
| `control:Set(value)` | Sets the value and fires the callback if it changed. |
| `control:SetSilent(value)` / `control:RawSet(value)` | Sets the value without firing the callback. |
| `control:SetCallback(fn)` | Replaces the callback. |
| `control:SetEnabled(enabled)` | Enables or disables input. |
| `control:SetVisible(visible)` | Shows or hides the control. |

Extra methods:

| Method | Description |
| --- | --- |
| `dropdown:UpdateOptions(options)` | Replaces the options, keeping the selection when it still exists. |
| `keybind:Unbind()` | Clears the key; the bind shows `[Unbound]`. |
| `color:Open()` / `color:Close()` | Opens or closes the picker popup. |
| `label:SetText(text)` / `label:SetVisible(visible)` | Updates a label. |

## Keybinds

Keybinds can sit on their own row (`AddKeybind`) or next to a toggle or button (`Keybind = {...}`).

- Click the key label, then press a key to rebind it. Escape cancels.
- Click the grey × left of the key to unbind it. Unbound keys show `[Unbound]`.
- `Keybind = true` adds an empty slot that starts unbound.
- A toggle's keybind flips the toggle unless you pass your own `Pressed`.
- Pass `BindableToggles = true` to `CreateWindow` to give every toggle a slot. Use `Keybind = false` to opt one out.

## Buttons

```lua
right:AddButton({
    Text = "Print",
    Primary = true,
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
row[1].TextColor3 = UI.Theme.Accent
```

`AddButtons` returns the underlying `TextButton` instances.

## Preview

```lua
local preview = group:AddPreview({
    Points = { Vector2.new(0, 0), Vector2.new(1, 0) },
    Height = 148,
})
preview:SetPoints({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1) })
preview:SetCount(1, 3)
preview:Recoil()
```

## Config

```lua
local json = window:EncodeConfig()
window:DecodeConfig(json)
window:LoadConfig(window:GetConfig())

window:EnablePersistence(UI.FileStorage("Kinoue/config.json"))
window:FlushConfig()
```

`EnablePersistence` also accepts any `{ Read = fn, Write = fn }` adapter. Changes are saved at most twice per second.

## Project layout

```text
src/
  init.luau            Library entry point
  Window/
    init.luau          Window class: visibility, position, size, tabs, teardown
    Chrome.luau        Header, accent, tab bar, footer and resize handle
    Input.luau         Keybinds, dragging and resizing
    Page.luau          Tabs, sub-tabs and groupboxes
    Settings.luau      Built-in settings page
    Config.luau        Config encoding, loading and persistence
  Controls/
    init.luau          Group class with the Add* methods
    Control.luau       Shared control behavior and popup helpers
    Button.luau, ColorPicker.luau, Disclosure.luau, Dropdown.luau, Keybind.luau,
    Label.luau, Preview.luau, Slider.luau, Textbox.luau, Toggle.luau
  internal/
    Cursor.luau, Fade.luau, Model.luau, Mount.luau, Theme.luau, Util.luau
examples/              Demo place script, minimal example and ESP example
tests/                 Headless behavior tests against a Roblox mock
tools/                 Bundler and test runner
dist/                  Generated bundle, model and demo place
```

## Development

```bash
python tools/build.py
python tools/test.py --luau path/to/luau --compiler path/to/luau-compile
stylua src tests examples
```

`dist/` is generated by `tools/build.py`. Edit `src/` and rebuild instead of editing `dist/` directly.

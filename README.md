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
local window = UI:CreateWindow({ Name = "Kinoue", Subtitle = "My script" })
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
    Subtitle = "My script",
    Size = Vector2.new(704, 470),
    MinSize = Vector2.new(480, 360),
    Position = UDim2.fromScale(0.5, 0.5),
    DisplayOrder = 100,
    Resizable = true,
    AllowOffscreen = true,
    SnapDistance = 8,
    ToggleKey = Enum.KeyCode.RightShift,
    ReducedMotion = false,
    RainbowAccent = false,
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
| `window:Notify(text or options)` | Shows a notification (see below). |
| `window:OpenSearch()` / `window:CloseSearch()` | Opens or closes the header search. |
| `window:OnDestroy(callback)` | Runs `callback` after the window is removed. |
| `window:Destroy()` | Removes the window and disconnects everything. |

## Settings and themes

The gear button in the top-right corner of the header opens the settings page. Press it again to go back. The page has:

- **Theme:** a preset (Dark, Midnight, Ocean, Rose, Forest, Light), color pickers for the accent, background, panels, outlines, text and muted text, and a reset button.
- **Window:** Menu key (RightShift by default), Lock to screen and Snap to edges.
- **Appearance:** Animations and Rainbow accent line (off by default).

Settings are saved with the rest of the config under IDs that start with `UI.`. Themes apply to every window at once.

```lua
UI:SetTheme("Ocean")
UI:SetTheme({ Accent = Color3.fromRGB(255, 120, 0) })
print(UI:GetTheme(), UI.Themes)
```

Pass `ShowSettings = false` to `CreateWindow` to hide the gear button.

`Subtitle` appears in small grey text next to the window name. `Footer` is still accepted as an older name for it. The footer shows a status line on the left and the library version on the right.

## Local backgrounds

Open the settings gear and use **Background** to enter an executor-accessible file path, then press **Load**. PNG, JPEG, and animated GIF files are supported. Controls include image opacity, panel opacity, Cover/Contain/Stretch, and playback speed. **Clear** removes the background. These settings persist under `UI.Background.*` with the existing config system.

`readfile` and `getcustomasset` (or `getsynasset`) are required. GIFs also require `writefile` and `makefolder`. Paths follow the executor's filesystem rules: a file anywhere on your PC only works if that executor permits reading it. Otherwise, copy it into the executor workspace and use a relative path. Files stay on your computer.

```lua
local window = UI:CreateWindow({
    Name = "Kinoue",
    Background = { Enabled = true, File = "backgrounds/rain.gif", Opacity = 0.6 },
})

window:SetBackground("backgrounds/wallpaper.png")
window:SetBackground({ PanelOpacity = 0.8, Fit = "Cover", Speed = 1 })
print(window:GetBackgroundStatus().Loading)
window:ClearBackground()
```

`SetBackground(path)` enables and loads a file asynchronously. The options table accepts `Enabled`, `File`, `Opacity` (0–1), `PanelOpacity` (0–1), `Fit` (Cover, Contain, Stretch), and `Speed` (0.1–4). Defaults are disabled, an empty path, 0.6 image opacity, 0.8 panel opacity, Cover, and normal speed. Pass `true` as a second argument to force a reload. Options can also be supplied through `CreateWindow.Background`.

`GetBackgroundStatus()` returns `Loading`, `Error`, the successfully loaded `File`, `Kind`, `Frames`, `Width`, `Height`, and `Cached`. A failed replacement keeps the previous background; errors appear as native notifications. Destroying the window cancels pending work and disconnects playback.

GIFs loop continuously using their frame delays (zero/one-centisecond delays use 100 ms). Playback follows rendered frames, skips overdue frames, and pauses while the window is hidden, image opacity is zero, or Animations is off. Static images have no playback connection. Files are limited to 32 MB; static images are limited to 4096 pixels per side. GIFs are limited to 300 frames, a 4-million-pixel source canvas/frame, and 200 million decoded source pixels. They are downscaled to at most 512 pixels per side and 8 million total output pixels, packed into 1024-pixel PNG pages with edge padding, and cached under `Kinoue/backgrounds`. Preparation yields between work chunks; later loads reuse cached pages. The cache can be deleted when the library is unloaded.

## Key systems

Kinoue includes a reusable key UI and client with `UI:CreateKeySystem`. Keys are redeemed by the [backend key service](backend/README.md), bound to the executor-provided HWID, and exchanged for a remembered session. Only an authorized session can download and run the configured script. Executors without a working HWID function report an unsupported-executor error and cannot continue.

The compact dialog contains only a key input, **Redeem**, and **Close**. Enter submits the key; Escape or Close cancels pending verification and removes the dialog. Progress and errors appear only when needed. Sessions are remembered automatically when file functions are available; set `Remember = false` to disable saving and restoring them.

```lua
return UI:CreateKeySystem({
    Name = "My script",
    Application = "my-script",
    Endpoint = "https://keys.example.com",
    CachePath = "MyScript/auth.json",
})
```

See [KeySystem.lua](examples/KeySystem.lua) and [backend setup, deployment, and limits](backend/README.md). The library does not contain a master key or a protected script's source.

Return the protected Kinoue window, or a script controller with `Window` and `Destroy()`, to get **Logout** in its built-in settings. Logout cleans up the script, clears the remembered login, revokes the current server session, and returns to the key dialog. UI settings stay saved. Custom integrations can use `gate:AttachWindow(window)` and `OnUnload(result)`.

The backend includes a Vercel-ready admin site with Postgres storage. Create and manage keys, view encrypted HWID records after signing in, reset or replace a device binding, revoke/delete access, and upload script payloads from `/admin/`.

Authenticated windows also get a **Session → License** section showing the key's remaining time. It uses the license deadline, rather than the remembered session token's lifetime, and accounts for the server clock. Existing Session tabs are reused. Custom integrations can call `window:SetSessionInfo({ ExpiresAt = unixTimestamp, ServerTime = serverTimestamp })`; omit `ExpiresAt` for a key without expiry, or pass `Known = false` when expiry is unavailable.

After a protected script starts successfully, the client reports its Roblox player ID, username, display name, place, and Kinoue version to the key service. The signed-in admin can view these starts under **Manage key → Executions**. Failed script loads are not reported as successful executions; recording failure does not interrupt an already loaded script.

## Search

The search field next to the gear filters every tab, sub-tab, groupbox, section and control, including those inside sub-toggle panels and the settings page. Each result shows where it lives, such as `Main > Combat > Aim assist`. Click a result, or press Enter for the first one, and the window jumps there: it opens the tab, sub-tab, section or sub-toggle panel, scrolls to the item and flashes it. Escape or a click outside clears and closes the search.

## Notifications

```lua
window:Notify("Saved")
window:Notify({ Title = "Hub", Text = "Config loaded", Duration = 5 })

left:AddToggle("Fly", { Text = "Fly", Notify = true })
left:AddSlider("Speed", { Text = "Speed", Min = 1, Max = 50, Notify = true })
left:AddButton({ Text = "Rejoin", Notify = "Rejoining..." })
left:AddToggle("God", {
    Text = "God mode",
    Notify = function(value)
        return value and "You are invincible" or "You can be hit again"
    end,
})
```

Notifications slide in at the bottom right, show a timer bar, and close on their own or with their × button. They stay visible while the menu is hidden, and up to five show at once.

The `Notify` option works on toggles, sliders, textboxes, dropdowns, color pickers, keybinds and buttons:

- `Notify = true` uses a default message, such as `Fly enabled`, `Speed: 16` or `Fly bound to F`.
- A string replaces that message.
- A function receives the new value and returns the message.

Only real changes notify. Silent sets and config loads stay quiet. Users can turn notifications off from the settings page, and `Notifications = false` in `CreateWindow` starts them off.

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

Pages start straight with their groupboxes. `SetTitle` or `SetMode` adds a title row above them.

A disclosure is a collapsible section with a chevron icon that rotates as it opens. It supports the same `Add*` methods as a groupbox. Pass `true` as the second argument to start it open, and use `advanced:SetOpen(open)` to open or close it from code.

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

local esp = left:AddToggle("ESP", { Text = "ESP", SubToggle = true })
esp.Settings:AddSlider("ESPRange", { Text = "Range", Min = 50, Max = 1000, Value = 300 })
esp.Settings:AddToggle("ESPNames", { Text = "Names" })

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
| `keybind:Unbind()` | Clears the key; the keycap shows `Unbound`. |
| `toggle:SetSettingsOpen(open)` / `toggle:IsSettingsOpen()` | Opens, closes or reads a sub-toggle's settings panel. |
| `color:Open()` / `color:Close()` | Opens or closes the picker popup. |
| `label:SetText(text)` / `label:SetVisible(visible)` | Updates a label. |

## Sub-toggles

`SubToggle = true` adds a cog on the right of a toggle. The cog opens an animated settings panel under the toggle, and `toggle.Settings` is a group for adding that panel's controls. Clicking the cog never flips the toggle itself. Sub settings are saved like any other control.

## Keybinds

Keybinds can sit on their own row (`AddKeybind`) or next to a toggle or button (`Keybind = {...}`).

- Click the key label, then press a key to rebind it. Escape cancels.
- Keys show as keycaps. Click the grey × left of a keycap to unbind it. Unbound keys show a faint `Unbound` keycap.
- `Keybind = true` adds an empty slot that starts unbound.
- A toggle's keybind flips the toggle unless you pass your own `Pressed`.
- `Clearable = false` hides the ×, as on the built-in menu key.
- When two enabled binds share a key, both key labels turn red and a warning icon appears. Hover either one to see what else uses that key. Both binds still fire.
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
```

`AddButtons` returns the underlying `TextButton` instances. `Primary = true` gives a button the filled accent style.

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
    Search.luau        Header search and navigation
    Notifications.luau Notification cards
    Config.luau        Config encoding, loading and persistence
  Controls/
    init.luau          Group class with the Add* methods
    Control.luau       Shared control behavior and popup helpers
    Collapsible.luau   Animated expand and collapse for sections and sub-toggles
    Button.luau, ColorPicker.luau, Disclosure.luau, Dropdown.luau, Keybind.luau,
    Label.luau, Preview.luau, Slider.luau, Textbox.luau, Toggle.luau
  internal/
    Cursor.luau, Fade.luau, Icons.luau, Model.luau, Mount.luau, Theme.luau, Tooltip.luau, Util.luau
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

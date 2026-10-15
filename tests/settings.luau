local V = Mock.Environment.Vector2.new
local Theme = UI.Theme
local window = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)

for _, child in ipairs(window.Header:GetChildren()) do
    assert(not (child.Text and child.Text:find("PlaceId")), "Header must not show the PlaceId watermark")
end
assert(window.SettingsButton and window.SettingsButton.Visible, "Header must show the settings button")

local page = window:AddTab("Main")
local group = page:AddGroupbox("Controls", "Left")
local toggle = group:AddToggle("Flag", { Text = "Flag" })
local box = toggle.Switch
for _, descendant in ipairs(toggle.Row:GetDescendants()) do
    assert(descendant.Text ~= "✓", "Toggles must not show a check mark")
end
assert(box.BackgroundColor3 == Theme.Hover and toggle.Knob.Position.X.Offset == 2, "Off switches sit left and grey")
toggle:Set(true)
assert(box.BackgroundColor3 == Theme.Accent, "Enabled toggles fill with the accent")
assert(toggle.Knob.Position.X.Offset > 2, "The knob slides right when enabled")
toggle.Root.MouseEnter:Fire()
assert(toggle.Row.BackgroundTransparency == 0, "Rows highlight on hover")
toggle.Root.MouseLeave:Fire()
assert(toggle.Row.BackgroundTransparency == 1)

window.SettingsButton.Activated:Fire()
assert(window.SettingsOpen and window.ActivePage == window.SettingsPage)
assert(window.SettingsPage.Frame.Visible and not page.Frame.Visible, "Settings replace the current page")
assert(
    window.SettingsIcon.Color == Theme.Accent and window.SettingsIcon.Root.Rotation == 90,
    "Open settings highlight the icon"
)
window.SettingsButton.Activated:Fire()
assert(not window.SettingsOpen and window.ActivePage == page and page.Frame.Visible, "Second press returns to the page")
assert(window.SettingsIcon.Color == Theme.Muted and window.SettingsIcon.Root.Rotation == 0)

local custom = group:AddLabel("Custom color")
custom.Root.TextColor3 = Mock.Environment.Color3.fromRGB(1, 2, 3)
local customColor = custom.Root.TextColor3

UI:SetTheme("Ocean")
local ocean = Theme.Presets.Ocean
assert(UI:GetTheme() == "Ocean")
assert(window.Root.BackgroundColor3 == ocean.Background, "Bound backgrounds follow the theme")
assert(window.TabStrip.BackgroundColor3 == ocean.Panel)
assert(page.Line.BackgroundColor3 == ocean.Accent)
assert(page.Button.TextColor3 == ocean.Text, "Active tab text follows the theme")
assert(box.BackgroundColor3 == ocean.Accent, "Enabled toggles repaint with the new accent")
assert(custom.Root.TextColor3 == customColor, "Manual colors survive theme changes")
assert(window.Controls["UI.Theme"]:Get() == "Ocean")
assert(window.Controls["UI.Color.Accent"]:Get() == ocean.Accent, "Settings pickers sync to the theme")

local red = Mock.Environment.Color3.fromRGB(255, 0, 0)
window.Controls["UI.Color.Accent"]:Set(red)
assert(Theme.Accent == red and Theme.Preset == "Custom")
assert(window.Controls["UI.Theme"]:Get() == "Custom", "Editing a color switches the preset to Custom")
assert(page.Line.BackgroundColor3 == red and box.BackgroundColor3 == red)

window.Controls["UI.Theme"]:Set("Dark")
assert(Theme.Accent == Theme.Presets.Dark.Accent and box.BackgroundColor3 == Theme.Presets.Dark.Accent)

local other = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
UI:SetTheme("Rose")
assert(other.Root.BackgroundColor3 == Theme.Presets.Rose.Background, "Theme applies to every window")
assert(other.Controls["UI.Theme"]:Get() == "Rose")
other:Destroy()

assert(window.Controls["UI.LockToScreen"]:Get() == true, "Windows start locked to the screen")
window:SetPosition(V(-500, -500))
assert(window:GetPosition().X == 12 and window:GetPosition().Y == 12, "Locked windows stay on screen")
window.Controls["UI.LockToScreen"]:Set(false)
assert(window.AllowOffscreen)
window:SetPosition(V(-80, -40))
assert(window:GetPosition().X == -80 and window:GetPosition().Y == -40, "Unlocked windows can leave the screen")
window:SetPosition(V(3, 4), true)
assert(window:GetPosition().X == 0 and window:GetPosition().Y == 0, "Unlocked windows snap to edges")
window.Controls["UI.SnapToEdges"]:Set(false)
window:SetPosition(V(3, 4), true)
assert(window:GetPosition().X == 3 and window:GetPosition().Y == 4, "Snapping can be turned off")
window:SetPosition(V(-80, -40))
window:SetLockToScreen(true)
assert(window.Controls["UI.LockToScreen"]:Get() == true and not window.AllowOffscreen)
assert(window:GetPosition().X == 12 and window:GetPosition().Y == 12, "Locking pulls the window back on screen")

window.Controls["UI.Animations"]:Set(true)
assert(not window.ReducedMotion and window.AccentScope ~= nil)
window.Controls["UI.RainbowAccent"]:Set(false)
assert(not window.RainbowAccent and window.AccentScope == nil, "A static accent line needs no animation")
window:SetRainbowAccent(true)
assert(window.Controls["UI.RainbowAccent"]:Get() == true and window.AccentScope ~= nil)
window:SetReducedMotion(true)
assert(window.Controls["UI.Animations"]:Get() == false and window.AccentScope == nil)

local config = window:GetConfig()
assert(config.Values["UI.Theme"] == "Rose" and config.Values["UI.LockToScreen"] == true)
UI:SetTheme("Light")
window:LoadConfig(config)
assert(Theme.Preset == "Rose", "Saved themes restore from config")

window:OpenSettings()
window:Destroy()
UI:SetTheme("Dark")
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
print(
    "PASS: blue toggles, settings button, live themes across windows, manual color overrides, lock to screen, edge snapping, appearance toggles, config restore"
)

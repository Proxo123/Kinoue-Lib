local KeyCode = Mock.Enum.KeyCode
local Theme = UI.Theme
local window = UI:CreateWindow({})
Mock:Advance(1)
local group = window:AddTab("Main"):AddGroupbox("Main", "Left")

local feature = group:AddToggle("Feature", { Text = "Feature", SubToggle = true })
assert(feature.SettingsButton and feature.SettingsIcon, "Sub-toggles show a cog")
assert(
    feature.SettingsButton.AnchorPoint.X == 1 and feature.SettingsButton.Position.X.Scale == 1,
    "The cog sits on the right"
)
assert(feature.SettingsButton.Position.X.Offset < -feature.Switch.Size.X.Offset, "The cog sits left of the switch")
local panel = feature.SettingsPanel
assert(not panel.Open and not panel.Clip.Visible and panel.Clip.Size.Y.Offset == 0, "Settings start closed")

local strength = feature.Settings:AddSlider("Strength", { Text = "Strength", Min = 0, Max = 10, Value = 5 })
feature.Settings:AddToggle("Extra", { Text = "Extra" })
assert(window.Controls.Strength == strength, "Sub settings register like normal controls")

feature.SettingsButton.Activated:Fire()
assert(panel.Open and panel.Clip.Visible, "The cog opens the settings")
assert(panel.Clip.Size.Y.Offset == panel.Container.AbsoluteSize.Y and panel.Clip.Size.Y.Offset > 0)
assert(
    feature.SettingsIcon.Root.Rotation == 90 and feature.SettingsIcon.Color == Theme.Accent,
    "The cog spins and lights up"
)
assert(feature:IsSettingsOpen())
assert(feature:Get() == false, "Opening settings does not flip the toggle")

feature.SettingsButton.Activated:Fire()
assert(not panel.Open and panel.Clip.Size.Y.Offset == 0 and panel.Clip.Visible, "Closing animates before hiding")
Mock:Advance(1)
assert(not panel.Clip.Visible)
assert(feature.SettingsIcon.Root.Rotation == 0 and feature.SettingsIcon.Color == Theme.Muted)

feature:SetSettingsOpen(true)
feature:SetSettingsOpen(false)
feature:SetSettingsOpen(true)
Mock:Advance(1)
assert(panel.Clip.Visible, "Reopening during the close animation keeps the panel visible")

feature:SetVisible(false)
assert(not feature.Row.Visible, "Hiding a sub-toggle hides its settings too")
feature:SetVisible(true)

local bound = group:AddToggle("Bound", { Text = "Bound", SubToggle = true, Keybind = { Value = KeyCode.H } })
assert(bound.Keybind.Root.Position.X.Offset < 0, "The keybind sits left of the cog")
assert(bound.Keybind.Clear.Position.X.Offset < bound.Keybind.Root.Position.X.Offset)
Mock:Key("H")
assert(bound:Get() == true)

local plain = group:AddToggle("Plain", { Text = "Plain" })
assert(plain.SettingsButton == nil and plain.Settings == nil)

local section = group:AddDisclosure("Advanced")
assert(section.Header.Text == "Advanced", "Sections use an icon instead of a text arrow")
assert(section.Icon and #section.Icon.Fills == 2 and section.Icon.Root.Rotation == 0)
section:AddLabel("Inside")
section.Header.Activated:Fire()
assert(section:IsOpen() and section.Section.Clip.Visible and section.Icon.Root.Rotation == 90)
assert(section.Section.Clip.Size.Y.Offset > 0, "Sections expand to their content")
section:SetOpen(false)
Mock:Advance(1)
assert(not section.Section.Clip.Visible and section.Icon.Root.Rotation == 0)
local opened = group:AddDisclosure("Open", true)
assert(opened:IsOpen() and opened.Icon.Root.Rotation == 90)

local menuKey = window.Controls["UI.MenuKey"]
assert(
    menuKey:Get() == KeyCode.RightShift and window.ToggleKey == KeyCode.RightShift,
    "The menu key defaults to RightShift"
)
assert(not menuKey.Clear.Visible, "The menu key cannot be cleared")
menuKey.Clear.Activated:Fire()
assert(menuKey:Get() == KeyCode.RightShift)
window:SetToggleKey(KeyCode.F3)
assert(menuKey:Get() == KeyCode.F3, "SetToggleKey updates the setting")
menuKey.Root.Activated:Fire()
Mock:Key("F4")
assert(window.ToggleKey == KeyCode.F4, "Rebinding the setting changes the menu key")

local custom = UI:CreateWindow({ ToggleKey = KeyCode.Insert })
Mock:Advance(1)
assert(custom.Controls["UI.MenuKey"]:Get() == KeyCode.Insert)
custom:Destroy()

UI:SetTheme("Ocean")
assert(feature.SettingsIcon.Color == Theme.Accent, "Open cogs follow the theme accent")
UI:SetTheme("Dark")

window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
print("PASS: sub-toggle cog and animated settings, keybind spacing, section icons and animation, RightShift menu key")

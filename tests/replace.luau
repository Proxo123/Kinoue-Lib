local KeyCode = Mock.Enum.KeyCode

local old = UI:CreateWindow({ Id = "Ghost", ReplaceExisting = true, ReducedMotion = true })
Mock:Advance(1)
local cleaned, presses = 0, 0
old:OnDestroy(function()
    cleaned += 1
end)
old:AddTab("A"):AddGroupbox("A", "Left"):AddKeybind("K", {
    Value = KeyCode.K,
    Pressed = function()
        presses += 1
    end,
})
old:Notify("Old toast")
local oldNotifications = old.NotificationScreen
Mock:Key("K")
assert(presses == 1)

local replacement = UI:CreateWindow({ Id = "Ghost", ReplaceExisting = true, ReducedMotion = true })
Mock:Advance(1)
assert(old.Dead and cleaned == 1, "Replacing a window shuts the old one down")
assert(oldNotifications.Destroyed, "The old window's notifications go too")
Mock:Key("K")
assert(presses == 1, "The old window's keybinds stop firing")
Mock:Key("RightShift")
assert(not replacement.Open and old.Open == false, "Only the new window toggles")
Mock:Key("RightShift")

replacement.Screen:Destroy()
assert(replacement.Dead, "Destroying the ScreenGui from outside cleans up the window")
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)

local window = UI:CreateWindow({ Footer = "Demo", ReducedMotion = true })
Mock:Advance(1)
local label = window.VersionLabel
assert(label and label.Text == "v" .. UI.Version and UI.Version == "0.9.0", "The footer shows the version")
assert(label.TextSize == 11 and label.TextColor3 == UI.Theme.Muted and label.AnchorPoint.X == 1)
assert(label.Parent == window.Footer)
window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print("PASS: replaced windows shut down, external ScreenGui removal, version watermark")

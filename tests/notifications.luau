local KeyCode = Mock.Enum.KeyCode
local window = UI:CreateWindow({ Name = "Hub" })
Mock:Advance(1)

local toast = window:Notify("Hello")
local screen = window.NotificationScreen
assert(screen and screen ~= window.Screen and screen.Parent == Mock.CoreGui, "Notifications have their own layer")
assert(toast.Title.Text == "Hub" and toast.Message.Text == "Hello", "The title defaults to the window name")
assert(toast.Card.Position.X.Offset == 0 and toast.Slot.Size.Y.Offset == toast.Height, "Cards slide in")
assert(toast.Timer.Size.X.Scale == 0, "The timer bar runs down")
assert(toast.CloseButton.Text == "×")
assert(#window.Toasts == 1)

window:SetVisible(false)
Mock:Advance(1)
local hidden = window:Notify({ Title = "Status", Text = "While hidden", Duration = 2 })
assert(hidden.Title.Text == "Status" and hidden.Card.BackgroundTransparency == 0, "Notifications show while hidden")
window:SetVisible(true)

toast.CloseButton.Activated:Fire()
assert(toast.Closed and #window.Toasts == 1, "The close button dismisses early")
assert(toast.Card.Position.X.Offset > 0, "Closing slides the card out")
Mock:Advance(1)
assert(toast.Slot.Destroyed)
Mock:Advance(2)
assert(hidden.Closed, "Notifications expire after their duration")
Mock:Advance(1)
assert(hidden.Slot.Destroyed)

local messages = {}
local notify = window.Notify
window.Notify = function(self, options)
    table.insert(messages, type(options) == "table" and options.Text or options)
    return notify(self, options)
end
local function last()
    return messages[#messages]
end

local group = window:AddTab("Main"):AddGroupbox("Main", "Left")
local flag = group:AddToggle("Flag", { Text = "Flag", Notify = true })
flag:Set(true)
assert(last() == "Flag enabled")
flag:Set(false)
assert(last() == "Flag disabled")
group:AddSlider("Speed", { Text = "Speed", Min = 0, Max = 10, Value = 1, Notify = true }):Set(5)
assert(last() == "Speed: 5")
group:AddDropdown("Mode", { Text = "Mode", Options = { "A", "B" }, Notify = true }):Set("B")
assert(last() == "Mode: B")
group:AddToggle("Custom", { Text = "Custom", Notify = "Custom message" }):Set(true)
assert(last() == "Custom message")
group
    :AddToggle("Fn", {
        Text = "Fn",
        Notify = function(value)
            return "Fn is " .. tostring(value)
        end,
    })
    :Set(true)
assert(last() == "Fn is true")
group:AddButton({ Text = "Run", Notify = true }).Root.Activated:Fire()
assert(last() == "Run")
group:AddButton({ Text = "Save", Notify = "Saved!" }).Root.Activated:Fire()
assert(last() == "Saved!")
local key = group:AddKeybind("Key", { Text = "Key", Value = KeyCode.Q, Notify = true })
key:Set(KeyCode.E)
assert(last() == "Key bound to E")
key:Unbind()
assert(last() == "Key unbound")
local bound = group:AddToggle("Bound", { Text = "Bound", Notify = true, Keybind = { Value = KeyCode.B } })
Mock:Key("B")
assert(bound:Get() and last() == "Bound enabled", "Keybind presses notify too")

local count = #messages
flag:SetSilent(true)
group:AddToggle("Quiet", { Text = "Quiet" }):Set(true)
window:LoadConfig({ Version = 1, Values = { Flag = false, Speed = 9 } })
assert(#messages == count and flag:Get() == false, "Silent changes, quiet controls and config loads do not notify")

Mock.Environment.warn = function() end
group
    :AddToggle("Broken", {
        Text = "Broken",
        Notify = function()
            error("bad")
        end,
    })
    :Set(true)
assert(window.Controls.Broken:Get() == true, "A failing message does not break the control")

for index = 1, 8 do
    window:Notify("Spam " .. index)
end
assert(#window.Toasts == 5, "At most five notifications stay on screen")

window.Controls["UI.Notifications"]:Set(false)
assert(window:Notify("Muted") == nil, "Notifications can be turned off in settings")
window.Controls["UI.Notifications"]:Set(true)

local reduced = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
local instant = reduced:Notify({ Text = "Instant", Duration = 1 })
instant.Close()
assert(instant.Slot.Destroyed, "Reduced motion closes instantly")
reduced:Destroy()

window:Destroy()
Mock:Advance(5)
assert(screen.Destroyed, "Destroying the window removes its notifications")
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
print(
    "PASS: notification layer, slide animation, close button, timer, expiry, per-control Notify, quiet loads, limits, settings toggle"
)

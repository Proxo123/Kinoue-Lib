local KeyCode = Mock.Enum.KeyCode
local window = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
local group = window:AddTab("Binds"):AddGroupbox("Binds", "Left")

local changes, released = {}, 0
local key = group:AddKeybind("Action", {
    Text = "Action",
    Value = KeyCode.Q,
    Released = function()
        released += 1
    end,
    Callback = function(value)
        table.insert(changes, value)
    end,
})
assert(
    key.Root.Text == "Q" and key.Root.BorderColor3 == UI.Theme.Hover and key.Clear.Visible,
    "Bound keys show a clear button"
)
assert(key.Clear.Text == "×" and key.Clear.TextColor3 == UI.Theme.Muted, "Clear button is a grey x")
assert(key.Clear.Position.X.Offset < -key.Root.Size.X.Offset, "Clear button sits left of the key")

Mock:Key("Q")
assert(key.Down)
key.Clear.Activated:Fire()
assert(key:Get() == KeyCode.Unknown and changes[#changes] == KeyCode.Unknown, "Clear button unbinds")
assert(released == 1 and not key.Down, "Unbinding a held key releases it")
assert(
    key.Root.Text == "Unbound" and key.Root.BorderColor3 == UI.Theme.Outline and not key.Clear.Visible,
    "Unbound keys say Unbound and hide the clear button"
)

key.Root.Activated:Fire()
assert(window.Capturing == key and key.Root.Text == "Press a key" and key.Root.BorderColor3 == UI.Theme.Accent)
Mock:Key("V")
assert(key:Get() == KeyCode.V and key.Clear.Visible, "Rebinding brings the clear button back")
key.Root.Activated:Fire()
key:Unbind()
assert(window.Capturing == nil and key.Root.Text == "Unbound", "Unbinding cancels key capture")

local toggle = group:AddToggle("Bindable", { Text = "Bindable", Keybind = true })
assert(toggle.Keybind and toggle.Keybind:Get() == KeyCode.Unknown, "Keybind = true creates an unbound slot")
assert(toggle.Keybind.Root.Text == "Unbound" and not toggle.Keybind.Clear.Visible)
assert(window.Controls.BindableKey == toggle.Keybind)
toggle.Keybind.Root.Activated:Fire()
Mock:Key("B")
Mock:Key("B")
assert(toggle:Get() == true, "A bound toggle flips when its key is pressed")
Mock:Key("B")
assert(toggle:Get() == false)
toggle.Keybind.Clear.Activated:Fire()
Mock:Key("B")
assert(toggle:Get() == false, "An unbound toggle ignores its old key")
toggle.Keybind:SetVisible(false)
assert(not toggle.Keybind.Root.Visible and not toggle.Keybind.Clear.Visible)
toggle.Keybind:SetVisible(true)

local custom = 0
local customToggle = group:AddToggle("Custom", {
    Keybind = {
        Value = KeyCode.N,
        Pressed = function()
            custom += 1
        end,
    },
})
Mock:Key("N")
assert(custom == 1 and customToggle:Get() == false, "Custom Pressed handlers replace the default flip")

toggle.Keybind:SetEnabled(false)
toggle.Keybind.Root.Activated:Fire()
assert(window.Capturing == nil)
toggle.Keybind:SetEnabled(true)
toggle.Keybind:Set(KeyCode.M)
toggle.Keybind:SetEnabled(false)
toggle.Keybind.Clear.Activated:Fire()
assert(toggle.Keybind:Get() == KeyCode.M, "Disabled keybinds cannot be cleared")
toggle.Keybind:SetEnabled(true)

local pressed = 0
local button = group:AddButton({
    Text = "Run",
    Keybind = true,
    Callback = function()
        pressed += 1
    end,
})
assert(button.Root.Text == "Run", "Unbound buttons show no key suffix")
button.Keybind:Set(KeyCode.R)
assert(button.Root.Text == "Run" and button.Keybind.Root.Text == "R", "Button keys show as a keycap")
Mock:Key("R")
assert(pressed == 1)
button.Keybind:Unbind()
assert(button.Root.Text == "Run")

local bindable = UI:CreateWindow({ ReducedMotion = true, BindableToggles = true })
Mock:Advance(1)
local auto = bindable:AddTab("Auto"):AddGroupbox("Auto", "Left"):AddToggle("Auto", { Text = "Auto" })
assert(auto.Keybind and auto.Keybind:Get() == KeyCode.Unknown, "BindableToggles gives every toggle a slot")
assert(bindable.Controls["UI.LockToScreen"].Keybind == nil, "Settings toggles stay unbindable")
local plain = bindable.Pages[1].Groups[1]:AddToggle("Plain", { Keybind = false })
assert(plain.Keybind == nil)
bindable:Destroy()

local hiddenPresses, hiddenReleases = 0, 0
local hiddenToggle = group:AddToggle("HiddenToggle", { Text = "Hidden", Keybind = { Value = KeyCode.Z } })
group:AddKeybind("HiddenHold", {
    Value = KeyCode.Y,
    Pressed = function()
        hiddenPresses += 1
    end,
    Released = function()
        hiddenReleases += 1
    end,
})
window:SetVisible(false)
Mock:Advance(1)
assert(not window.Open and not window.Root.Visible)
Mock:Key("Z")
assert(hiddenToggle:Get() == true, "Keybinds work while the menu is hidden")
local hold = Mock:Key("Y")
Mock.Input.InputEnded:Fire(hold)
assert(hiddenPresses == 1 and hiddenReleases == 1, "Pressed and Released fire while hidden")
Mock:Key("Z", true)
assert(hiddenToggle:Get() == true, "Keys the game already handled are ignored")
Mock.Input.Focused = {}
Mock:Key("Z")
Mock.Input.Focused = nil
assert(hiddenToggle:Get() == true, "Typing in a textbox does not fire keybinds")
assert(not window.Open, "Keybinds do not reopen the menu")
window:SetVisible(true)

window:SetToggleKey(KeyCode.Unknown)
Mock.Input.InputBegan:Fire({ KeyCode = KeyCode.Unknown, UserInputType = Mock.Enum.UserInputType.MouseButton1 }, false)
assert(window.Open, "An unbound menu key must not toggle on mouse clicks")

local config = window:GetConfig()
assert(config.Values.BindableKey.Name == "M")
toggle.Keybind:Unbind()
local saved = window:GetConfig()
toggle.Keybind:Set(KeyCode.X)
window:LoadConfig(saved)
assert(toggle.Keybind:Get() == KeyCode.Unknown, "Unbound keys restore from config")

window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print(
    "PASS: clear buttons, Unbound labels, unbound toggles, default toggle binds, button suffixes, BindableToggles, unbound menu key, config restore"
)

local KeyCode = Mock.Enum.KeyCode
local Theme = UI.Theme
local warnings = {}
Mock.Environment.warn = function(message)
    table.insert(warnings, message)
end

local window = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
local group = window:AddTab("Binds"):AddGroupbox("Binds", "Left")

local runA = group:AddButton({ Text = "Run", Keybind = { Value = KeyCode.R } })
local runB = group:AddButton({ Text = "Run", Keybind = { Value = KeyCode.U } })
assert(runA.Keybind.Id == "RunKey" and runB.Keybind.Id == "RunKey2", "Same-text button keybinds get unique IDs")
assert(#warnings == 0, "Generated IDs do not warn")

local first = group:AddToggle("Same", { Text = "First" })
local second = group:AddToggle("Same", { Text = "Second" })
assert(window.Controls.Same == first and window.Controls.Same2 == second, "Duplicate IDs no longer crash")
assert(#warnings == 1 and warnings[1]:find("Duplicate control ID", 1, true))

local fly = group:AddToggle("Fly", { Text = "Fly", Keybind = { Value = KeyCode.F } })
local fill = group:AddKeybind("Fill", { Text = "Fill", Value = KeyCode.Q })
assert(#fly.Keybind.Conflicts == 0 and fly.Keybind.Root.TextColor3 == Theme.Muted)
assert(not fly.Keybind.Warning.Root.Visible)

fill:Set(KeyCode.F)
assert(fly.Keybind.Root.TextColor3 == Theme.Danger and fill.Root.TextColor3 == Theme.Danger, "Shared keys turn red")
assert(fly.Keybind.Warning.Root.Visible and fill.Warning.Root.Visible, "Shared keys show a warning icon")
assert(fill.Warning.Root.Position.X.Offset < fill.Clear.Position.X.Offset, "The warning sits left of the clear button")
assert(fill.Clear.Position.X.Offset < -fill.Root.Size.X.Offset)

fly.Keybind.Root.MouseEnter:Fire()
assert(window.TooltipFrame.Visible and window.TooltipLabel.Text == "Also bound to: Fill", "Hover names the other bind")
fly.Keybind.Root.MouseLeave:Fire()
assert(not window.TooltipFrame.Visible)
fill.Warning.Root.MouseEnter:Fire()
assert(window.TooltipFrame.Visible and window.TooltipLabel.Text == "Also bound to: Fly")
fill.Warning.Root.MouseLeave:Fire()

local third = group:AddKeybind("Third", { Text = "Third", Value = KeyCode.F })
fly.Keybind.Root.MouseEnter:Fire()
assert(window.TooltipLabel.Text == "Also bound to: Fill, Third")
fly.Keybind.Root.MouseLeave:Fire()

local presses = 0
fly.Keybind.Pressed = function()
    presses += 1
end
fill.Pressed = function()
    presses += 1
end
Mock:Key("F")
assert(presses == 2, "Conflicting binds still all fire")

third:SetEnabled(false)
fill:Unbind()
assert(
    #fly.Keybind.Conflicts == 0 and fly.Keybind.Root.TextColor3 == Theme.Muted,
    "Clearing the clash restores the color"
)
assert(not fly.Keybind.Warning.Root.Visible and not fill.Warning.Root.Visible)
fly.Keybind.Root.MouseEnter:Fire()
assert(not window.TooltipFrame.Visible, "No tooltip without a conflict")
fly.Keybind.Root.MouseLeave:Fire()

local clash = group:AddKeybind("Clash", { Text = "Clash", Value = KeyCode.RightShift })
local menuKey = window.Controls["UI.MenuKey"]
assert(menuKey.Root.TextColor3 == Theme.Danger and clash.Root.TextColor3 == Theme.Danger, "The menu key counts too")
clash.Root.MouseEnter:Fire()
assert(window.TooltipLabel.Text == "Also bound to: Menu key")
clash.Root.MouseLeave:Fire()

UI:SetTheme("Ocean")
assert(clash.Root.TextColor3 == Theme.Presets.Ocean.Danger, "Conflict color follows the theme")
UI:SetTheme("Dark")

window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print("PASS: unique keybind IDs, duplicate ID recovery, red conflicts, warning icon, hover tooltip, menu key clashes")

local env = Mock.Environment
local warnings = 0
env.warn = function() warnings += 1 end
Mock.Identity = 8
env.getthreadidentity = function() return Mock.Identity end
env.setthreadidentity = function(value) Mock.Identity = value end
Mock.ProtectCoreDestroy = true
local window = UI:CreateWindow({ Id = "UnloadRegression" })
Mock:Advance(1)
local group = window:AddTab("Test"):AddGroupbox("Unload")
local value = group:AddToggle("SavedValue", { Value = true })
local first, second = 0, 0
window:OnDestroy(function()
    assert(window.Screen.Destroyed and not window.Screen.Enabled, "GUI must disappear before feature cleanup")
    assert(value:Get(), "Settings values must remain available during cleanup")
    first += 1
    window:Destroy()
    error("Deliberate feature cleanup failure")
end)
window:OnDestroy(function() second += 1 end)
local cancelled = 0
window.Scope.Tweens[{}] = { Cancel = function() cancelled += 1; error("Stale tween") end }
window.Scope.Tweens[{}] = { Cancel = function() cancelled += 1 end }
window.PopupClose = function() error("Stale popup") end
Mock.Identity = 2
window:Destroy(); window:Destroy()
Mock:Advance(1)
assert(Mock.Identity == 2, "Direct unload must restore caller identity")
assert(window.Screen.Destroyed and not window.Root.Visible and not window.Open)
assert(first == 1 and second == 1 and cancelled == 2, "Failures must not stop later cleanup")
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
assert(warnings >= 3)

Mock.Identity = 8
local viaButton = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
local button = viaButton:AddTab("Test"):AddGroupbox("Unload"):AddButton({ Text = "Unload", Callback = function()
    viaButton:Destroy()
    error("Error after removal")
end })
Mock.Identity = 2
button.Root.Activated:Fire()
Mock:Advance(1)
assert(Mock.Identity == 2 and viaButton.Screen.Destroyed and Mock:ConnectionCount() == 0)

Mock.Identity = 8
local orphan = env.Instance.new("ScreenGui"); orphan.Name = "ReplaceMe"; orphan.Parent = Mock.CoreGui
local other = env.Instance.new("ScreenGui"); other.Name = "Unrelated"; other.Parent = Mock.CoreGui
local replacement = UI:CreateWindow({ Id = "ReplaceMe", ReplaceExisting = true, ReducedMotion = true })
assert(orphan.Destroyed and not other.Destroyed, "Replacement must remove only matching windows")
replacement:Destroy(); other:Destroy(); Mock:Advance(1)
assert(Mock:ConnectionCount() == 0)
print("PASS: unload button, direct low-identity unload, stale tween/popup failures, feature errors, recursive cleanup, identity restoration, and orphan replacement")

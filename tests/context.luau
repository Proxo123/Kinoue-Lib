local window = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
Mock.Identity = 2
Mock.Environment.getthreadidentity = function()
    return Mock.Identity
end
Mock.Environment.setthreadidentity = function(value)
    Mock.Identity = value
end
local warnings = 0
Mock.Environment.warn = function()
    warnings += 1
end
local called = 0
local group = window:AddTab("Test"):AddGroupbox("Context", "Left")
local button = group:AddButton({
    Text = "Protected",
    Callback = function()
        assert(Mock.Identity == 8, "GUI callback must have CoreGui identity")
        called += 1
    end,
})
button.Root.Activated:Fire()
assert(called == 1 and Mock.Identity == 2, "Callback identity must be restored")
local toggle = group:AddToggle("ProtectedToggle", {
    Text = "Toggle",
    Callback = function()
        assert(Mock.Identity == 8)
        error("Deliberate callback failure")
    end,
})
toggle.Root.Activated:Fire()
assert(Mock.Identity == 2 and window.Status.Text == "Callback error", "Identity must restore after feature errors")
assert(warnings == 1)
local key = group:AddKeybind("ProtectedKey", {
    Text = "Key",
    Value = Mock.Enum.KeyCode.P,
    Callback = function()
        assert(Mock.Identity == 8)
    end,
})
key.Root.Activated:Fire()
Mock:Key("K")
assert(key:Get() == Mock.Enum.KeyCode.K and Mock.Identity == 2)
local restored = group:AddToggle("RestoredToggle", {
    Callback = function()
        assert(Mock.Identity == 8, "Direct Set must run with CoreGui identity")
    end,
})
restored:Set(true)
assert(restored:Get() and Mock.Identity == 2, "Direct Set must restore caller identity")
local label = group:AddLabel("Status")
label:SetText("Updated")
window:SetStatus("Direct")
assert(Mock.Identity == 2 and warnings == 1)
window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
print("PASS: low-identity GUI callbacks, key capture, error handling, identity restoration, and cleanup")

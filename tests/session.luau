local env = Mock.Environment
local clock = 2000000000
env.os = table.clone(os)
env.os.time = function()
    return clock
end
local window = UI:CreateWindow({ ReducedMotion = true })
local session = window:AddTab("Session")
window:SetSessionInfo({ ExpiresAt = 1900000000 + 90061, ServerTime = 1900000000 })
assert(#window.Pages == 1 and window.SessionPage == session, "Reuse the script's Session tab")
assert(
    window.SessionTime.Root.Text == "Time left: 1d 1h 1m 1s",
    "Use license expiry and server time, not the device clock"
)
clock += 62
Mock.Run.Heartbeat:Fire(2)
assert(window.SessionTime.Root.Text == "Time left: 1d 0h 59m 59s")
clock += 100000
Mock.Run.Heartbeat:Fire(2)
assert(window.SessionTime.Root.Text == "Time left: Expired")
window:SetSessionInfo({})
assert(window.SessionTime.Root.Text == "Time left: No expiry" and not window.SessionTick)
window:SetSessionInfo({ Known = false })
assert(window.SessionTime.Root.Text == "Time left: Unavailable")
assert(not pcall(function()
    window:SetSessionInfo({ ExpiresAt = math.huge })
end))
window:SetSessionInfo(nil)
assert(not window.SessionTime.Root.Visible and not window.SessionTick)
window:SetSessionInfo({ ExpiresAt = clock + 50 })
assert(#window.Pages == 1 and window.SessionTime.Root.Visible)
window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil, "Destroy releases the countdown listener")
print(
    "PASS: Session license countdown, server clock offset, expiry, unlimited/unknown keys, no duplicate tabs, cleanup"
)

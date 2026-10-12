-- Appended to the generated test harness by tools/test.py.
Mock:Advance(1)
assert(#window.Pages == 7 and window.ActivePage.Name == "Studio")
assert(window.ToggleKey == Mock.Enum.KeyCode.RightShift)
assert(window.Root.ClassName == "Frame", "Text must not be rendered through a CanvasGroup texture")
assert(window.Root.AnchorPoint.X == 0 and window.Root.AnchorPoint.Y == 0)
assert(window.ResizeHandle.BackgroundTransparency == 1 and window.ResizeHandle.Size.X.Offset == 18)
local V = Mock.Environment.Vector2.new
local before = window.Root.AbsolutePosition
local startSize = window.Root.AbsoluteSize
local resizeInput = { UserInputType = Mock.Enum.UserInputType.MouseButton1, Position = V(900, 600) }
window.Root.AbsolutePositionOverride = V(before.X - 50, before.Y - 50)
window.ResizeHandle.InputBegan:Fire(resizeInput)
Mock.Input.InputChanged:Fire({ UserInputType = Mock.Enum.UserInputType.MouseMovement, Position = V(1000, 640) })
window.Root.AbsolutePositionOverride = nil
assert(window.Size.X == startSize.X + 100 and window.Size.Y == startSize.Y + 40)
assert(window.Root.AbsolutePosition.X == before.X and window.Root.AbsolutePosition.Y == before.Y, "Resize must keep the top-left fixed")
Mock.Input.InputEnded:Fire(resizeInput)
assert(window.Resizing == nil)
-- Repeated pointer moves and repeated grabs must not accumulate position drift.
for grab = 1, 8 do
    local pointer = { UserInputType = Mock.Enum.UserInputType.MouseButton1, Position = V(900, 600) }
    window.ResizeHandle.InputBegan:Fire(pointer)
    for step = 1, 10 do
        Mock.Input.InputChanged:Fire({ UserInputType = Mock.Enum.UserInputType.MouseMovement, Position = V(900 + step, 600 + step) })
        assert(window.Root.Position.X.Offset == before.X and window.Root.Position.Y.Offset == before.Y)
    end
    Mock.Input.InputEnded:Fire(pointer)
end
-- Starting a resize during opening must not snap the window to the animation's destination.
window.Root.Position = Mock.Environment.UDim2.fromOffset(before.X, before.Y + 3.4)
local interrupted = { UserInputType = Mock.Enum.UserInputType.Touch, Position = V(900, 600) }
window.ResizeHandle.InputBegan:Fire(interrupted)
interrupted.Position = V(910, 610)
Mock.Input.InputChanged:Fire(interrupted)
assert(window.Root.Position.Y.Offset == before.Y + 3.4)
Mock.Input.InputEnded:Fire(interrupted)
window:SnapPosition()
window:SetSize(V(10, 10))
assert(window.Size.X == 480 and window.Size.Y == 360)
window:SetSize(V(10000, 10000))
local endPosition, endSize = window.Root.AbsolutePosition, window.Root.AbsoluteSize
assert(endPosition.X + endSize.X <= 1280 - 12 and endPosition.Y + endSize.Y <= 720 - 12)
window:SetSize(V(705, 471))
assert(window.Root.AbsolutePosition.X % 1 == 0 and window.Root.AbsolutePosition.Y % 1 == 0, "Settled window must align to whole pixels")
window:SetSize(V(704, 470))
local count = 0
for _ in pairs(window.Controls) do count += 1 end
assert(count >= 60, "Demo controls missing")
local shooting = window.Controls.Shooting
local called = 0
shooting:SetCallback(function() called += 1 end)
shooting:Set(true); shooting:Set(true); shooting:SetSilent(false)
assert(called == 1 and shooting:Get() == false)
window.Controls.DrawingDistance:Set(99)
assert(window.Controls.DrawingDistance:Get() == 20)
window.Controls.Material:Set("Wood")
assert(window.Controls.Material:Get() == "Wood")
window.Controls.Material:UpdateOptions({ { Value = "Wood", Meta = 179 }, "Stone" })
assert(window.Controls.Material:Get() == "Wood")
Mock:Key("LeftShift"); assert(window.Open)
Mock:Key("RightShift"); assert(not window.Open)
Mock:Key("RightShift"); assert(window.Open)
Mock:Advance(1); assert(window.Root.Visible, "Cancelled close must not hide a reopened window")
window.Controls.MenuKey.Root.Activated:Fire()
Mock:Key("F2"); assert(window.ToggleKey == Mock.Enum.KeyCode.F2 and window.Open)
Mock:Key("RightShift"); assert(window.Open)
Mock:Key("F2"); assert(not window.Open)
Mock:Advance(1); assert(not window.Root.Visible)
Mock:Key("F2"); assert(window.Open)
window.Controls.MenuKey.Root.Activated:Fire()
Mock:Key("Escape"); assert(window.ToggleKey == Mock.Enum.KeyCode.F2)
local config = window:GetConfig()
assert(config.Values.MenuKey.Name == "F2" and config.Values.Material == "Wood")
window.Controls.WalkSpeed:Set(10)
window:LoadConfig(config)
assert(window.Controls.WalkSpeed:Get() == config.Values.WalkSpeed)
local saves = 0
window:EnablePersistence({ Read = function() return nil end, Write = function() saves += 1 end })
window.Controls.WalkSpeed:Set(12); window.Controls.WalkSpeed:Set(13)
Mock.Run.Heartbeat:Fire(0.5); assert(saves == 1, "Config writes must coalesce")
window.Controls.Material.Root.Activated:Fire()
assert(window.PopupOwner == window.Controls.Material)
window:SetVisible(false); assert(window.PopupOwner == nil, "Hide must close dropdown portal")
window:SetVisible(true)
local connections = Mock:ConnectionCount()
assert(connections > 0)
window:Destroy(); window:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and window.Screen.Destroyed, "Destroy must disconnect everything")
print("PASS: complete demo, values, dropdown refresh, callback semantics, key capture, left/right modifiers, rebind, rapid reopen, config restore, coalesced saves, popup cleanup, idempotent destroy")

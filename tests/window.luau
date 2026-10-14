local V = Mock.Environment.Vector2.new
local loose = UI:CreateWindow({ AllowOffscreen = true, ReducedMotion = true })
Mock:Advance(1)
local size = loose.Root.AbsoluteSize
for _, corner in ipairs({
    V(3, 4),
    V(1280 - size.X - 3, 4),
    V(3, 720 - size.Y - 4),
    V(1280 - size.X - 3, 720 - size.Y - 4),
}) do
    loose:SetPosition(corner, true)
    local position = loose:GetPosition()
    assert(position.X == 0 or position.X == 1280 - size.X)
    assert(position.Y == 0 or position.Y == 720 - size.Y)
end
loose:SetPosition(V(-80, -40))
loose:Fit()
assert(loose:GetPosition().X == -80 and loose:GetPosition().Y == -40, "Fit must preserve offscreen positions")
local pointer = { UserInputType = Mock.Enum.UserInputType.MouseButton1, Position = V(0, 0) }
loose.Header.InputBegan:Fire(pointer)
Mock.Input.InputChanged:Fire({ UserInputType = Mock.Enum.UserInputType.MouseMovement, Position = V(-150, -100) })
Mock.Input.InputEnded:Fire(pointer)
assert(loose:GetPosition().X == -230 and loose:GetPosition().Y == -140, "Dragging must pass beyond screen edges")
local origin = loose:GetPosition()
loose:SetSize(V(760, 500))
assert(
    loose:GetPosition().X == origin.X and loose:GetPosition().Y == origin.Y,
    "Offscreen resize must not shift the window"
)
loose:SetPosition(V(1300, 740))
loose:Fit()
assert(loose:GetPosition().X == 1300 and loose:GetPosition().Y == 740)
Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCenter, "Fully offscreen UI must yield cursor control")
loose:SetPosition(V(0, 0))
Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)
loose:SetVisible(false)
loose:SetVisible(true)
assert(loose:GetPosition().X == 0 and loose:GetPosition().Y == 0, "Fade must keep the tucked position")
loose:Destroy()
local bounded = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1)
bounded:SetPosition(V(-500, 2000))
assert(bounded:GetPosition().X == 12 and bounded:GetPosition().Y == 720 - bounded.Root.AbsoluteSize.Y - 12)
bounded:Destroy()
Mock:Advance(1)
assert(Mock:ConnectionCount() == 0 and next(Mock.Run.Bindings) == nil)
print(
    "PASS: all four corners, offscreen dragging, resize/fade position, fully offscreen cursor release, and bounded default"
)

local window = UI:CreateWindow({ ReducedMotion = true })
Mock:Advance(1); Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default and Mock.Input.MouseIconEnabled)
assert(window.ResizeHandle.Modal ~= true, "Resize handle must not interfere with camera control")

-- Zooming out while the menu is open releases control immediately.
Mock:SetCameraDistance(8); Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default and Mock.Input.MouseIconEnabled)
Mock.CameraBehavior = Mock.Enum.MouseBehavior.LockCurrentPosition
Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCurrentPosition, "Third-person right-mouse camera control must be untouched")
window:SetVisible(false); Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCurrentPosition)
Mock.CameraBehavior = nil; Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)

-- Never reapply a lock captured before zooming out.
Mock:SetCameraDistance(0.5); Mock:Render()
window:SetVisible(true); Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)
Mock:SetCameraDistance(4); Mock:Render()
window:SetVisible(false)
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default and Mock.Input.MouseIconEnabled, "Close after zooming out must remain free")
Mock:Render(); assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)

-- In first person the game's camera resumes normal look control on the next frame.
Mock:SetCameraDistance(0.5); Mock:Render()
window:SetVisible(true); Mock:Render()
window:SetVisible(false)
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)
Mock:Render(); assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCenter)
Mock:SetCameraDistance(2); Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)

-- A zoomed-out camera, scriptable camera, or missing camera is never overridden.
window:SetVisible(true)
Mock:SetCameraDistance(1.01); Mock.CameraBehavior = Mock.Enum.MouseBehavior.LockCurrentPosition; Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCurrentPosition)
Mock.Camera.CameraType = Mock.Enum.CameraType.Scriptable
Mock:SetCameraDistance(0.5); Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCurrentPosition)
Mock.Environment.workspace.CurrentCamera = nil; Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCurrentPosition)
Mock.Environment.workspace.CurrentCamera = Mock.Camera
Mock.Camera.CameraType = Mock.Enum.CameraType.Custom; Mock.CameraBehavior = nil
Mock:Render(); assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)
window.Screen.Enabled = false; Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.LockCenter, "Disabled GUI must yield to the camera")
window.Screen.Enabled = true; Mock:Render()
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default)
Mock:SetCameraDistance(8); Mock:Render()
window:Destroy(); Mock:Advance(1)
assert(Mock.Input.MouseBehavior == Mock.Enum.MouseBehavior.Default and Mock.Input.MouseIconEnabled)
assert(next(Mock.Run.Bindings) == nil and Mock:ConnectionCount() == 0)
print("PASS: first/third-person transitions, third-person camera drag, close after zooming out, camera ownership, scriptable/missing camera, disabled GUI, and unload")

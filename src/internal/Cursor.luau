local Input = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Cursor = {}
local owners = {}
local overriding, previousIcon = false, nil
local binding = "BoogaUI.Cursor." .. tostring(owners)
local function firstPerson()
    local camera = workspace.CurrentCamera
    if not camera or camera.CameraType == Enum.CameraType.Scriptable then return false end
    return (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
end
local function release(inFirstPerson)
    if not overriding then return end
    -- The camera owns mouse behavior. Never restore a captured LockCenter state.
    -- In third person, leave the game's current cursor visibility alone too.
    if inFirstPerson and Input.MouseIconEnabled then Input.MouseIconEnabled = previousIcon end
    overriding, previousIcon = false, nil
end
local function update()
    local visible = false
    for owner in pairs(owners) do
        if not owner.Dead and owner.Open and owner.Screen.Enabled and owner.Root.Visible then visible = true; break end
    end
    local inFirstPerson = firstPerson()
    if visible and inFirstPerson then
        if not overriding then previousIcon = Input.MouseIconEnabled; overriding = true end
        Input.MouseBehavior = Enum.MouseBehavior.Default
        Input.MouseIconEnabled = true
    else
        release(inFirstPerson)
    end
end
function Cursor.set(owner, open)
    if open then
        if owners[owner] then return end
        if not next(owners) then
            Run:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, update)
        end
        owners[owner] = true
        update()
    else
        owners[owner] = nil
        if not next(owners) then
            Run:UnbindFromRenderStep(binding)
            release(firstPerson())
        else update() end
    end
end
return Cursor

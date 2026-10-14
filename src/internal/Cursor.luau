local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Cursor = {}

local owners = {}
local overriding, previousIcon = false, nil
local binding = "Kinoue.Cursor." .. tostring(owners)

local function firstPerson()
    local camera = workspace.CurrentCamera
    if not camera or camera.CameraType == Enum.CameraType.Scriptable then
        return false
    end
    return (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
end

local function onScreen(owner)
    if owner.Dead or not owner.Open or not owner.Screen.Enabled or not owner.Root.Visible then
        return false
    end
    local position, size, viewport = owner.Root.AbsolutePosition, owner.Root.AbsoluteSize, owner.Screen.AbsoluteSize
    return position.X < viewport.X and position.Y < viewport.Y and position.X + size.X > 0 and position.Y + size.Y > 0
end

local function release(inFirstPerson)
    if not overriding then
        return
    end
    if inFirstPerson and UserInputService.MouseIconEnabled then
        UserInputService.MouseIconEnabled = previousIcon
    end
    overriding, previousIcon = false, nil
end

local function update()
    local visible = false
    for owner in pairs(owners) do
        if onScreen(owner) then
            visible = true
            break
        end
    end

    local inFirstPerson = firstPerson()
    if not (visible and inFirstPerson) then
        release(inFirstPerson)
        return
    end

    if not overriding then
        previousIcon = UserInputService.MouseIconEnabled
        overriding = true
    end
    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    if not UserInputService.MouseIconEnabled then
        UserInputService.MouseIconEnabled = true
    end
end

function Cursor.set(owner, open)
    if open then
        if owners[owner] then
            return
        end
        if not next(owners) then
            RunService:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, update)
        end
        owners[owner] = true
        update()
        return
    end

    owners[owner] = nil
    if next(owners) then
        update()
    else
        RunService:UnbindFromRenderStep(binding)
        release(firstPerson())
    end
end

return Cursor

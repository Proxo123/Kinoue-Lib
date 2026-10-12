local Input = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Cursor = {}
local owners, saved = {}, nil
local binding = "BoogaUI.Cursor." .. tostring(owners)
local function unlock()
    Input.MouseBehavior = Enum.MouseBehavior.Default
    Input.MouseIconEnabled = true
end
function Cursor.set(owner, open)
    if open then
        if owners[owner] then return end
        if not next(owners) then
            saved = { Behavior = Input.MouseBehavior, Icon = Input.MouseIconEnabled }
            Run:BindToRenderStep(binding, Enum.RenderPriority.Camera.Value + 1, unlock)
        end
        owners[owner] = true
        unlock()
    else
        owners[owner] = nil
        if saved and not next(owners) then
            Run:UnbindFromRenderStep(binding)
            Input.MouseBehavior = saved.Behavior
            Input.MouseIconEnabled = saved.Icon
            saved = nil
        end
    end
end
return Cursor

local U = require(script.Parent.Util)
local Fade = {}
Fade.__index = Fade
function Fade.new(screen)
    local self = setmetatable({ Entries = {}, Active = {}, Scope = U.scope(), Dead = false }, Fade)
    self.Alpha = U.new("NumberValue", { Value = 0 })
    local function attach(object)
        if self.Entries[object] then return end
        local properties = {}
        if object:IsA("GuiObject") then table.insert(properties, "BackgroundTransparency") end
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            table.insert(properties, "TextTransparency"); table.insert(properties, "TextStrokeTransparency")
        end
        if object:IsA("ImageLabel") or object:IsA("ImageButton") then table.insert(properties, "ImageTransparency") end
        if object:IsA("ScrollingFrame") then table.insert(properties, "ScrollBarImageTransparency") end
        if object:IsA("UIStroke") then table.insert(properties, "Transparency") end
        if #properties == 0 then return end
        local entry = { Base = {}, Applied = {}, Scope = U.scope() }
        self.Entries[object] = entry
        -- Native borders have no transparency. Replace them with matching strokes.
        if object:IsA("GuiObject") and object.BorderSizePixel > 0 then
            local stroke = U.new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = object.BorderColor3, Thickness = object.BorderSizePixel, Transparency = 0 }, object)
            object.BorderSizePixel = 0
            entry.Scope:Connect(object:GetPropertyChangedSignal("BorderColor3"), function() stroke.Color = object.BorderColor3 end)
        end
        for _, property in ipairs(properties) do
            entry.Base[property] = object[property]
            entry.Scope:Connect(object:GetPropertyChangedSignal(property), function()
                local current = object[property]
                if current == entry.Applied[property] then return end
                entry.Base[property] = current
                self:RenderObject(object, entry)
            end)
        end
        self:RenderObject(object, entry)
    end
    self.Scope:Connect(screen.DescendantAdded, attach)
    self.Scope:Connect(screen.DescendantRemoving, function(object)
        local entry = self.Entries[object]
        if entry then entry.Scope:Destroy(); self.Entries[object] = nil; self.Active[object] = nil end
    end)
    for _, object in ipairs(screen:GetDescendants()) do attach(object) end
    self.Scope:Connect(self.Alpha:GetPropertyChangedSignal("Value"), function()
        for object, entry in pairs(self.Active) do self:RenderObject(object, entry) end
    end)
    return self
end
function Fade:RenderObject(object, entry)
    local alpha = self.Alpha.Value
    local active = false
    for property, base in pairs(entry.Base) do
        if base < 1 then
            active = true
            local value = base + (1 - base) * alpha
            entry.Applied[property] = value
            if object[property] ~= value then object[property] = value end
        else
            -- Fully transparent properties do not change throughout a fade.
            entry.Applied[property] = 1
        end
    end
    self.Active[object] = active and entry or nil
end
function Fade:Set(alpha) self.Alpha.Value = alpha end
function Fade:Destroy()
    if self.Dead then return end
    self.Dead = true; self.Scope:Destroy()
    for _, entry in pairs(self.Entries) do entry.Scope:Destroy() end
    table.clear(self.Entries); table.clear(self.Active); self.Alpha:Destroy()
end
return Fade

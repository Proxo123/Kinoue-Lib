local Util = require(script.Parent.Util)

local EPSILON = 0.000001

local Fade = {}
Fade.__index = Fade

local function fadedProperties(object)
    local properties = {}
    if object:IsA("GuiObject") then
        table.insert(properties, "BackgroundTransparency")
    end
    if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
        table.insert(properties, "TextTransparency")
        table.insert(properties, "TextStrokeTransparency")
    end
    if object:IsA("ImageLabel") or object:IsA("ImageButton") then
        table.insert(properties, "ImageTransparency")
    end
    if object:IsA("ScrollingFrame") then
        table.insert(properties, "ScrollBarImageTransparency")
    end
    if object:IsA("UIStroke") then
        table.insert(properties, "Transparency")
    end
    return properties
end

local function replaceBorder(object, entry)
    if not object:IsA("GuiObject") or object.BorderSizePixel <= 0 then
        return
    end
    local stroke = Util.new("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = object.BorderColor3,
        Thickness = object.BorderSizePixel,
        Transparency = 0,
    }, object)
    object.BorderSizePixel = 0
    entry.Scope:Connect(object:GetPropertyChangedSignal("BorderColor3"), function()
        stroke.Color = object.BorderColor3
    end)
end

function Fade.new(screen)
    local self = setmetatable({ Entries = {}, Active = {}, Scope = Util.scope(), Dead = false }, Fade)
    self.Alpha = Util.new("NumberValue", { Value = 0 })

    self.Scope:Connect(screen.DescendantAdded, function(object)
        self:Attach(object)
    end)
    self.Scope:Connect(screen.DescendantRemoving, function(object)
        self:Detach(object)
    end)
    for _, object in ipairs(screen:GetDescendants()) do
        self:Attach(object)
    end
    self.Scope:Connect(self.Alpha:GetPropertyChangedSignal("Value"), function()
        for object, entry in pairs(self.Active) do
            self:RenderObject(object, entry)
        end
    end)

    return self
end

function Fade:Attach(object)
    if self.Entries[object] then
        return
    end
    local properties = fadedProperties(object)
    if #properties == 0 then
        return
    end

    local entry = { Base = {}, Applied = {}, Scope = Util.scope() }
    self.Entries[object] = entry
    replaceBorder(object, entry)

    for _, property in ipairs(properties) do
        entry.Base[property] = object[property]
        entry.Scope:Connect(object:GetPropertyChangedSignal(property), function()
            local current = object[property]
            local applied = entry.Applied[property]
            if applied ~= nil and math.abs(current - applied) <= EPSILON then
                return
            end
            entry.Base[property] = current
            self:RenderObject(object, entry)
        end)
    end

    self:RenderObject(object, entry)
end

function Fade:Detach(object)
    local entry = self.Entries[object]
    if entry then
        entry.Scope:Destroy()
        self.Entries[object] = nil
        self.Active[object] = nil
    end
end

function Fade:RenderObject(object, entry)
    local alpha = self.Alpha.Value
    local active = false
    for property, base in pairs(entry.Base) do
        if base < 1 then
            active = true
            local value = base + (1 - base) * alpha
            entry.Applied[property] = value
            if math.abs(object[property] - value) > EPSILON then
                object[property] = value
            end
        else
            entry.Applied[property] = 1
        end
    end
    self.Active[object] = active and entry or nil
end

function Fade:Set(alpha)
    self.Alpha.Value = alpha
end

function Fade:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    self.Scope:Destroy()
    for _, entry in pairs(self.Entries) do
        entry.Scope:Destroy()
    end
    table.clear(self.Entries)
    table.clear(self.Active)
    self.Alpha:Destroy()
end

return Fade

local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local OPEN_DURATION = 0.18
local CLOSE_DURATION = 0.14

local Collapsible = {}
Collapsible.__index = Collapsible

function Collapsible.new(window, parent, indent)
    indent = indent or 0
    local clip = Util.frame(parent, {
        Name = "Collapsible",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
    })
    local container = Util.frame(clip, {
        Position = UDim2.fromOffset(indent, 0),
        Size = UDim2.new(1, -indent, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(container, false, Theme.ControlGap)

    local self = setmetatable({
        Window = window,
        Clip = clip,
        Container = container,
        Open = false,
        Version = 0,
        Listeners = {},
    }, Collapsible)

    window.Scope:Connect(container:GetPropertyChangedSignal("AbsoluteSize"), function()
        if self.Open then
            window.Scope:Tween(clip, 0, { Size = self:OpenSize() }, true)
        end
    end)

    return self
end

function Collapsible:OpenSize()
    return UDim2.new(1, 0, 0, self.Container.AbsoluteSize.Y)
end

function Collapsible:OnChanged(listener)
    table.insert(self.Listeners, listener)
end

function Collapsible:SetOpen(open, instant)
    open = open == true
    if self.Open == open then
        return self
    end
    self.Open = open
    self.Version += 1

    local window = self.Window
    local version = self.Version
    local reduced = instant or window.ReducedMotion
    if open then
        self.Clip.Visible = true
        window.Scope:Tween(self.Clip, OPEN_DURATION, { Size = self:OpenSize() }, reduced)
    else
        window.Scope:Tween(self.Clip, CLOSE_DURATION, { Size = UDim2.new(1, 0, 0, 0) }, reduced)
        if reduced then
            self.Clip.Visible = false
        else
            task.delay(CLOSE_DURATION, function()
                if not window.Dead and version == self.Version then
                    self.Clip.Visible = false
                end
            end)
        end
    end

    for _, listener in ipairs(self.Listeners) do
        listener(open, reduced)
    end
    return self
end

function Collapsible:Toggle()
    return self:SetOpen(not self.Open)
end

return Collapsible

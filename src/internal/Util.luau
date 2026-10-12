local Theme = require(script.Parent.Theme)
local TweenService = game:GetService("TweenService")
local Util = {}
function Util.new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do object[key] = value end
    object.Parent = parent
    return object
end
function Util.frame(parent, props)
    local defaults = { BorderSizePixel = 0, BackgroundColor3 = Theme.Background }
    for k, v in pairs(props or {}) do defaults[k] = v end
    return Util.new("Frame", defaults, parent)
end
function Util.label(parent, text, props)
    local defaults = {
        BackgroundTransparency = 1, BorderSizePixel = 0, Font = Theme.Font,
        TextSize = Theme.TextSize, TextColor3 = Theme.Text, Text = text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, Theme.RowHeight),
    }
    for k, v in pairs(props or {}) do defaults[k] = v end
    return Util.new("TextLabel", defaults, parent)
end
function Util.button(parent, text, props)
    local defaults = {
        BackgroundColor3 = Theme.Panel, BorderColor3 = Theme.Outline, BorderSizePixel = 1,
        Font = Theme.Font, TextSize = Theme.TextSize, TextColor3 = Theme.Text, Text = text,
        AutoButtonColor = false, Size = UDim2.new(1, 0, 0, Theme.RowHeight),
    }
    for k, v in pairs(props or {}) do defaults[k] = v end
    return Util.new("TextButton", defaults, parent)
end
function Util.list(parent, horizontal, gap)
    return Util.new("UIListLayout", {
        FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap or 0),
    }, parent)
end
function Util.padding(parent, amount)
    return Util.new("UIPadding", {
        PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
        PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount),
    }, parent)
end
function Util.scope()
    local scope = { Connections = {}, Tweens = {}, Dead = false }
    function scope:Connect(signal, fn)
        local connection = signal:Connect(fn)
        table.insert(self.Connections, connection)
        return connection
    end
    function scope:Tween(object, duration, props, reduced)
        local prior = self.Tweens[object]
        if prior then prior:Cancel() end
        if reduced or duration <= 0 then
            for k, v in pairs(props) do object[k] = v end
            self.Tweens[object] = nil
            return
        end
        local tween = TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
        self.Tweens[object] = tween
        tween:Play()
        return tween
    end
    function scope:Destroy()
        if self.Dead then return end
        self.Dead = true
        for _, connection in ipairs(self.Connections) do connection:Disconnect() end
        for _, tween in pairs(self.Tweens) do tween:Cancel() end
        table.clear(self.Connections); table.clear(self.Tweens)
    end
    return scope
end
function Util.keyName(key)
    return key and key.Name or "None"
end
return Util

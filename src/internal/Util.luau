local Theme = require(script.Parent.Theme)
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Util = {}
function Util.withContext(fn, ...)
    local getIdentity = getthreadidentity or getidentity or (type(syn) == "table" and syn.get_thread_identity)
    local setIdentity = setthreadidentity or setidentity or (type(syn) == "table" and syn.set_thread_identity)
    if type(getIdentity) == "function" and type(setIdentity) == "function" then
        local read, identity = pcall(getIdentity)
        if read and type(identity) == "number" and identity < 8 and pcall(setIdentity, 8) then
            local result = table.pack(pcall(fn, ...))
            local restored, message = pcall(setIdentity, identity)
            if not restored then error("[BoogaUI] Failed to restore callback identity: " .. tostring(message), 0) end
            if not result[1] then error(result[2], 0) end
            return table.unpack(result, 2, result.n)
        end
    end
    return fn(...)
end
-- Text measurement is an engine call; labels re-render with the same strings constantly.
local widths, widthCount = {}, 0
-- Public methods may be called from feature threads (task.defer, Heartbeat) that lack
-- CoreGui access. Run them in the same context the GUI was mounted with.
function Util.protect(object, names)
    for _, name in ipairs(names) do
        local fn = object[name]
        if type(fn) == "function" then
            object[name] = function(...) return Util.withContext(fn, ...) end
        end
    end
    return object
end
function Util.textWidth(text, size)
    size = size or Theme.TextSize
    local key = size .. "\0" .. text
    local width = widths[key]
    if width then return width end
    if widthCount >= 512 then table.clear(widths); widthCount = 0 end
    width = math.ceil(TextService:GetTextSize(text, size, Theme.Font, Vector2.new(10000, 1000)).X)
    widths[key] = width; widthCount += 1
    return width
end
-- Mouse button InputObjects are not guaranteed to be the same object across began/ended.
function Util.sameInput(a, b)
    if a == b then return a ~= nil end
    return a ~= nil and b ~= nil and a.UserInputType == Enum.UserInputType.MouseButton1 and b.UserInputType == Enum.UserInputType.MouseButton1
end
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
        TextSize = Theme.TextSize, TextScaled = false, TextColor3 = Theme.Text, Text = text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, Theme.RowHeight),
    }
    for k, v in pairs(props or {}) do defaults[k] = v end
    return Util.new("TextLabel", defaults, parent)
end
function Util.button(parent, text, props)
    local defaults = {
        BackgroundColor3 = Theme.Panel, BorderColor3 = Theme.Outline, BorderSizePixel = 1,
        Font = Theme.Font, TextSize = Theme.TextSize, TextScaled = false, TextColor3 = Theme.Text, Text = text,
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
        local connection = signal:Connect(function(...)
            if self.Dead then return end
            -- Roblox GUI signals may run below the identity used to mount CoreGui.
            return Util.withContext(fn, ...)
        end)
        table.insert(self.Connections, connection)
        return connection
    end
    -- Disconnects a short-lived connection (drags) without keeping it until Destroy.
    function scope:Release(connection)
        if not connection then return end
        pcall(function() connection:Disconnect() end)
        local index = table.find(self.Connections, connection)
        if index then
            local last = #self.Connections
            self.Connections[index] = self.Connections[last]
            self.Connections[last] = nil
        end
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
        for _, connection in ipairs(self.Connections) do
            local ok, message = pcall(function() connection:Disconnect() end)
            if not ok then warn("[BoogaUI] Disconnect failed: " .. tostring(message)) end
        end
        for _, tween in pairs(self.Tweens) do
            local ok, message = pcall(function() tween:Cancel() end)
            if not ok then warn("[BoogaUI] Tween cleanup failed: " .. tostring(message)) end
        end
        table.clear(self.Connections); table.clear(self.Tweens)
    end
    return scope
end
function Util.keyName(key)
    return key and key.Name or "None"
end
return Util

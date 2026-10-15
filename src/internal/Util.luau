local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

local CORE_IDENTITY = 8
local WIDTH_CACHE_LIMIT = 512

local widths, widthCount = {}, 0

local function identityHelpers()
    local getIdentity = getthreadidentity or getidentity or (type(syn) == "table" and syn.get_thread_identity)
    local setIdentity = setthreadidentity or setidentity or (type(syn) == "table" and syn.set_thread_identity)
    if type(getIdentity) == "function" and type(setIdentity) == "function" then
        return getIdentity, setIdentity
    end
    return nil, nil
end

function Util.warn(message)
    warn("[Kinoue] " .. tostring(message))
end

function Util.withContext(fn, ...)
    local getIdentity, setIdentity = identityHelpers()
    if getIdentity then
        local read, identity = pcall(getIdentity)
        if read and type(identity) == "number" and identity < CORE_IDENTITY and pcall(setIdentity, CORE_IDENTITY) then
            local result = table.pack(pcall(fn, ...))
            local restored, message = pcall(setIdentity, identity)
            if not restored then
                error("[Kinoue] Failed to restore callback identity: " .. tostring(message), 0)
            end
            if not result[1] then
                error(result[2], 0)
            end
            return table.unpack(result, 2, result.n)
        end
    end
    return fn(...)
end

function Util.protect(object, names)
    for _, name in ipairs(names) do
        local fn = object[name]
        if type(fn) == "function" then
            object[name] = function(...)
                return Util.withContext(fn, ...)
            end
        end
    end
    return object
end

function Util.textSize(text, size, maxWidth, font)
    return TextService:GetTextSize(
        text,
        size or Theme.TextSize,
        font or Theme.Font,
        Vector2.new(maxWidth or 10000, 10000)
    )
end

function Util.textWidth(text, size, font)
    size = size or Theme.TextSize
    font = font or Theme.Font
    local key = size .. "\0" .. font.Name .. "\0" .. text
    local width = widths[key]
    if width then
        return width
    end
    if widthCount >= WIDTH_CACHE_LIMIT then
        table.clear(widths)
        widthCount = 0
    end
    width = math.ceil(TextService:GetTextSize(text, size, font, Vector2.new(10000, 1000)).X)
    widths[key] = width
    widthCount += 1
    return width
end

function Util.isPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Util.sameInput(a, b)
    if a == b then
        return a ~= nil
    end
    return a ~= nil
        and b ~= nil
        and a.UserInputType == Enum.UserInputType.MouseButton1
        and b.UserInputType == Enum.UserInputType.MouseButton1
end

function Util.contains(gui, point)
    local position, size = gui.AbsolutePosition, gui.AbsoluteSize
    return point.X >= position.X
        and point.X <= position.X + size.X
        and point.Y >= position.Y
        and point.Y <= position.Y + size.Y
end

function Util.keyName(key)
    if key == nil or key == Enum.KeyCode.Unknown then
        return "Unbound"
    end
    return key.Name
end

local function merge(defaults, props)
    for key, value in pairs(props or {}) do
        defaults[key] = value
    end
    return defaults
end

function Util.new(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        if Theme.isToken(value) then
            Theme.bind(object, key, value.Key)
            value = Theme[value.Key]
        end
        object[key] = value
    end
    object.Parent = parent
    return object
end

function Util.frame(parent, props)
    return Util.new(
        "Frame",
        merge({
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Color.Background,
        }, props),
        parent
    )
end

function Util.label(parent, text, props)
    return Util.new(
        "TextLabel",
        merge({
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Theme.Font,
            TextSize = Theme.TextSize,
            TextScaled = false,
            TextColor3 = Theme.Color.Text,
            Text = text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Size = UDim2.new(1, 0, 0, Theme.RowHeight),
        }, props),
        parent
    )
end

function Util.button(parent, text, props)
    return Util.new(
        "TextButton",
        merge({
            BackgroundColor3 = Theme.Color.Panel,
            BorderColor3 = Theme.Color.Outline,
            BorderSizePixel = 1,
            Font = Theme.Font,
            TextSize = Theme.TextSize,
            TextScaled = false,
            TextColor3 = Theme.Color.Text,
            Text = text,
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, Theme.RowHeight),
        }, props),
        parent
    )
end

function Util.textbox(parent, props)
    return Util.new(
        "TextBox",
        merge({
            BackgroundColor3 = Theme.Color.Input,
            BorderSizePixel = 1,
            BorderColor3 = Theme.Color.Outline,
            Font = Theme.Font,
            TextSize = Theme.TextSize,
            TextScaled = false,
            TextColor3 = Theme.Color.Text,
            ClearTextOnFocus = false,
        }, props),
        parent
    )
end

function Util.list(parent, horizontal, gap)
    return Util.new("UIListLayout", {
        FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
    }, parent)
end

function Util.corner(parent, radius)
    return Util.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius) }, parent)
end

function Util.hover(scope, gui, callback)
    scope:Connect(gui.MouseEnter, function()
        callback(true)
    end)
    scope:Connect(gui.MouseLeave, function()
        callback(false)
    end)
end

function Util.padding(parent, amount)
    return Util.new("UIPadding", {
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount),
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
    }, parent)
end

local Scope = {}
Scope.__index = Scope

function Util.scope()
    return setmetatable({ Connections = {}, Tweens = {}, Dead = false }, Scope)
end

function Scope:Connect(signal, fn)
    local connection = signal:Connect(function(...)
        if self.Dead then
            return
        end
        return Util.withContext(fn, ...)
    end)
    table.insert(self.Connections, connection)
    return connection
end

function Scope:Release(connection)
    if not connection then
        return
    end
    pcall(function()
        connection:Disconnect()
    end)
    local index = table.find(self.Connections, connection)
    if index then
        local last = #self.Connections
        self.Connections[index] = self.Connections[last]
        self.Connections[last] = nil
    end
end

function Scope:Tween(object, duration, props, reduced, style)
    local prior = self.Tweens[object]
    if prior then
        prior:Cancel()
    end
    if reduced or duration <= 0 then
        for key, value in pairs(props) do
            object[key] = value
        end
        self.Tweens[object] = nil
        return
    end
    local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(object, info, props)
    self.Tweens[object] = tween
    tween:Play()
    return tween
end

function Scope:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    for _, connection in ipairs(self.Connections) do
        local ok, message = pcall(function()
            connection:Disconnect()
        end)
        if not ok then
            Util.warn("Disconnect failed: " .. tostring(message))
        end
    end
    for _, tween in pairs(self.Tweens) do
        local ok, message = pcall(function()
            tween:Cancel()
        end)
        if not ok then
            Util.warn("Tween cleanup failed: " .. tostring(message))
        end
    end
    table.clear(self.Connections)
    table.clear(self.Tweens)
end

return Util

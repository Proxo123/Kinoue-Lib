-- Headless behavior checks. This does not emulate Roblox rendering.
local Mock = { Events = {}, Delayed = {}, Time = 0, Instances = {} }
local function signal()
    local event = { Listeners = {} }
    function event:Connect(fn)
        local c = { Connected = true, Fn = fn }
        function c:Disconnect() self.Connected = false end
        table.insert(self.Listeners, c)
        return c
    end
    function event:Fire(...)
        local copy = table.clone(self.Listeners)
        for _, c in ipairs(copy) do if c.Connected then c.Fn(...) end end
    end
    table.insert(Mock.Events, event)
    return event
end
local function vec(x, y, z)
    local v = { X = x or 0, Y = y or 0, Z = z or 0, _type = z == nil and "Vector2" or "Vector3" }
    return setmetatable(v, { __sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end })
end
local function dim(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end
local function dimensions(xs, xo, ys, yo) return { X = dim(xs, xo), Y = dim(ys, yo), _type = "UDim2" } end
local enum = setmetatable({}, { __index = function(self, groupName)
    local group = setmetatable({}, { __index = function(groupSelf, name)
        local item = { Name = name, EnumType = groupSelf, Value = groupName == "RenderPriority" and 200 or 0, _type = "EnumItem" }
        rawset(groupSelf, name, item); return item
    end })
    rawset(self, groupName, group); return group
end })
local function color(r, g, b)
    local c = { R = r, G = g, B = b, _type = "Color3" }
    function c:ToHex() return string.format("%02X%02X%02X", math.round(self.R * 255), math.round(self.G * 255), math.round(self.B * 255)) end
    function c:ToHSV()
        local maximum, minimum = math.max(self.R, self.G, self.B), math.min(self.R, self.G, self.B)
        local difference, hue = maximum - minimum, 0
        if difference > 0 then
            if maximum == self.R then hue = ((self.G - self.B) / difference) % 6
            elseif maximum == self.G then hue = (self.B - self.R) / difference + 2
            else hue = (self.R - self.G) / difference + 4 end
        end
        return hue / 6, maximum == 0 and 0 or difference / maximum, maximum
    end
    return c
end
local colorAPI = { new = color, fromRGB = function(r, g, b) return color(r / 255, g / 255, b / 255) end }
function colorAPI.fromHSV(h, s, v)
    local sector = (h % 1) * 6
    local index, fraction = math.floor(sector), sector % 1
    local p, q, t = v * (1 - s), v * (1 - fraction * s), v * (1 - (1 - fraction) * s)
    if index == 0 then return color(v, t, p) elseif index == 1 then return color(q, v, p)
    elseif index == 2 then return color(p, v, t) elseif index == 3 then return color(p, q, v)
    elseif index == 4 then return color(t, p, v) else return color(v, p, q) end
end
function colorAPI.fromHex(hex) return color(tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255) end
local function children(instance)
    local list = {}
    for _, candidate in ipairs(Mock.Instances) do if candidate.Parent == instance and not candidate.Destroyed then table.insert(list, candidate) end end
    return list
end
local width, height
width = function(instance)
    if instance.ClassName == "ScreenGui" then return 1280 end
    local size = instance.Size or dimensions()
    if size.X.Scale == 0 then return size.X.Offset end
    return size.X.Offset + size.X.Scale * (instance.Parent and width(instance.Parent) or 0)
end
height = function(instance)
    if instance.ClassName == "ScreenGui" then return 720 end
    local size = instance.Size or dimensions()
    if instance.AutomaticSize == enum.AutomaticSize.Y then
        local list
        for _, child in ipairs(children(instance)) do if child.ClassName == "UIListLayout" then list = child end end
        local total, count = 0, 0
        for _, child in ipairs(children(instance)) do
            if child.ClassName ~= "UIListLayout" and child.ClassName ~= "UIPadding" and child.Visible ~= false then
                if list then total += height(child); count += 1 else total = math.max(total, (child.Position and child.Position.Y.Offset or 0) + height(child)) end
            end
        end
        return total + (list and math.max(0, count - 1) * (list.Padding and list.Padding.Offset or 0) or 0)
    end
    if size.Y.Scale == 0 then return size.Y.Offset end
    return size.Y.Offset + size.Y.Scale * (instance.Parent and height(instance.Parent) or 0)
end
local function create(className)
    local methods, events, props = {}, {}, { ClassName = className, Visible = true, Position = dimensions(), Size = dimensions(), BackgroundTransparency = 0, TextTransparency = 0, TextStrokeTransparency = 1, ImageTransparency = 0, ScrollBarImageTransparency = 0, BorderSizePixel = 0 }
    local object
    function methods:GetChildren() return children(self) end
    function methods:GetDescendants()
        local result = {}
        for _, child in ipairs(children(self)) do
            table.insert(result, child)
            for _, descendant in ipairs(child:GetDescendants()) do table.insert(result, descendant) end
        end
        return result
    end
    function methods:IsA(name)
        if name == self.ClassName then return true end
        if name == "GuiObject" then
            return self.ClassName == "Frame" or self.ClassName == "ScrollingFrame" or self.ClassName == "TextButton" or self.ClassName == "TextLabel" or self.ClassName == "TextBox" or self.ClassName == "ImageLabel" or self.ClassName == "ImageButton"
        end
        return false
    end
    function methods:GetPropertyChangedSignal(name) events[name] = events[name] or signal(); return events[name] end
    function methods:Destroy()
        for _, child in ipairs(children(self)) do child:Destroy() end
        self.Parent = nil; props.Destroyed = true
    end
    function methods:WaitForChild(name) for _, child in ipairs(children(self)) do if child.Name == name then return child end end error("Missing child " .. name) end
    object = setmetatable({}, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if key == "AbsoluteSize" then return vec(width(object), height(object)) end
            if key == "AbsolutePosition" then
                if props.AbsolutePositionOverride then return props.AbsolutePositionOverride end
                local p = props.Parent and props.Parent.AbsolutePosition or vec(0, 0)
                local parent = props.Parent and props.Parent.AbsoluteSize or vec(0, 0)
                local anchor = props.AnchorPoint or vec(0, 0)
                return vec(p.X + props.Position.X.Offset + props.Position.X.Scale * parent.X - anchor.X * width(object), p.Y + props.Position.Y.Offset + props.Position.Y.Scale * parent.Y - anchor.Y * height(object))
            end
            if key == "AbsoluteContentSize" and className == "UIListLayout" then
                local y, n = 0, 0
                for _, child in ipairs(children(props.Parent)) do
                    if child.ClassName ~= "UIListLayout" and child.ClassName ~= "UIPadding" and child.Visible ~= false then y += height(child); n += 1 end
                end
                return vec(0, y + math.max(0, n - 1) * (props.Padding and props.Padding.Offset or 0))
            end
            if key == "Activated" or key == "InputBegan" or key == "FocusLost" or key == "DescendantAdded" or key == "DescendantRemoving" then events[key] = events[key] or signal(); return events[key] end
            return props[key]
        end,
        __newindex = function(_, key, value)
            if key == "Parent" and value ~= props.Parent then
                if Mock.RejectCore and value == Mock.CoreGui and (not Mock.AllowElevated or Mock.Identity ~= 8) then error("CoreGui permission denied") end
                local descendants = { object }
                for _, descendant in ipairs(object:GetDescendants()) do table.insert(descendants, descendant) end
                local ancestor = props.Parent
                while ancestor do
                    for _, descendant in ipairs(descendants) do ancestor.DescendantRemoving:Fire(descendant) end
                    ancestor = ancestor.Parent
                end
                props.Parent = value
                ancestor = value
                while ancestor do
                    for _, descendant in ipairs(descendants) do ancestor.DescendantAdded:Fire(descendant) end
                    ancestor = ancestor.Parent
                end
                return
            end
            local previous = props[key]; props[key] = value
            if previous ~= value and events[key] then events[key]:Fire() end
        end,
    })
    table.insert(Mock.Instances, object)
    return object
end
local input = { InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), MouseBehavior = enum.MouseBehavior.LockCenter, MouseIconEnabled = false }
function input:GetFocusedTextBox() return self.Focused end
local run = { RenderStepped = signal(), Heartbeat = signal(), Bindings = {} }
function run:BindToRenderStep(name, priority, fn) self.Bindings[name] = { Priority = priority, Fn = fn } end
function run:UnbindFromRenderStep(name) self.Bindings[name] = nil end
function Mock:Render()
    for _, binding in pairs(run.Bindings) do binding.Fn() end
    run.RenderStepped:Fire()
end
local playerGui = create("ScreenGui")
local localPlayer = create("Player")
localPlayer.CharacterAdded = signal(); localPlayer.CharacterRemoving = signal()
function localPlayer:WaitForChild() return playerGui end
local localCharacter = create("Model")
localPlayer.Character = localCharacter
local players = { LocalPlayer = localPlayer, PlayerAdded = signal(), PlayerRemoving = signal(), List = { localPlayer } }
function players:GetPlayers() return table.clone(self.List) end
function Mock:AddPlayer(name)
    local player = create("Player")
    player.Name = name; player.CharacterAdded = signal(); player.CharacterRemoving = signal()
    player.Character = create("Model")
    table.insert(players.List, player); players.PlayerAdded:Fire(player)
    return player
end
function Mock:Respawn(player)
    player.CharacterRemoving:Fire(player.Character); player.Character:Destroy()
    player.Character = create("Model"); player.CharacterAdded:Fire(player.Character)
end
function Mock:RemovePlayer(player)
    players.PlayerRemoving:Fire(player)
    local index = table.find(players.List, player)
    if index then table.remove(players.List, index) end
end
Mock.Players = players
Mock.CoreGui = create("CoreGui")
local services = {
    UserInputService = input, RunService = run,
    CoreGui = Mock.CoreGui,
    Players = players,
    TweenService = { Create = function(_, object, _, goals)
        return { Play = function() for key, value in pairs(goals) do object[key] = value end end, Cancel = function() end }
    end },
    TextService = { GetTextSize = function(_, text, size, _, _) return vec(#text * 7 * size / 12, size) end },
    HttpService = { JSONEncode = function(_, value) return value end, JSONDecode = function(_, value) return value end },
}
Mock.Input = input; Mock.Run = run; Mock.Enum = enum
Mock.Environment = setmetatable({
    game = { PlaceId = 11729688377, GetService = function(_, name) return assert(services[name], name) end },
    workspace = { CurrentCamera = create("Camera") },
    Instance = { new = create }, Enum = enum,
    Color3 = colorAPI, Vector2 = { new = function(x, y) return vec(x, y) end },
    UDim = { new = dim }, UDim2 = { new = dimensions, fromOffset = function(x, y) return dimensions(0, x, 0, y) end, fromScale = function(x, y) return dimensions(x, 0, y, 0) end },
    ColorSequence = { new = function(value) return value end }, ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end },
    NumberSequence = { new = function(value) return value end }, NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end },
    TweenInfo = { new = function(...) return { ... } end },
    typeof = function(value) return type(value) == "table" and value._type or type(value) end,
    task = { defer = function(fn) table.insert(Mock.Delayed, { At = Mock.Time, Fn = fn }) end, delay = function(seconds, fn) table.insert(Mock.Delayed, { At = Mock.Time + seconds, Fn = fn }) end },
}, { __index = getfenv(0) })
function Mock:Advance(seconds)
    self.Time += seconds
    local old = self.Delayed; self.Delayed = {}
    for _, event in ipairs(old) do if event.At <= self.Time then event.Fn() else table.insert(self.Delayed, event) end end
end
function Mock:Key(name, processed)
    local key = { KeyCode = enum.KeyCode[name], UserInputType = enum.UserInputType.Keyboard }
    input.InputBegan:Fire(key, processed == true)
    return key
end
function Mock:ConnectionCount()
    local count = 0
    for _, event in ipairs(self.Events) do for _, c in ipairs(event.Listeners) do if c.Connected then count += 1 end end end
    return count
end
return Mock

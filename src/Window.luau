local U = require(script.Parent.internal.Util)
local T = require(script.Parent.internal.Theme)
local Controls = require(script.Parent.Controls)
local Mount = require(script.Parent.internal.Mount)
local Fade = require(script.Parent.internal.Fade)
local Cursor = require(script.Parent.internal.Cursor)
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Window = {}
Window.__index = Window

function Window.new(options)
    local self = setmetatable({}, Window)
    self.Scope = U.scope()
    self.Controls = {}; self.Pages = {}; self.Keybinds = {}
    self.ReducedMotion = options.ReducedMotion == true
    self.ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift
    self.Size = options.Size or Vector2.new(704, 470)
    self.MinSize = options.MinSize or Vector2.new(480, 360)
    self.Resizable = options.Resizable ~= false
    self.Open = true; self.Dead = false; self.VisibilityVersion = 0
    self.Screen = U.new("ScreenGui", {
        Name = options.Id or "BoogaUI", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = options.DisplayOrder or 100,
    })
    Mount.core(self.Screen)
    local initialPosition = options.Position or UDim2.fromScale(0.5, 0.5)
    self.Root = U.new("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(initialPosition.X.Scale, initialPosition.X.Offset - self.Size.X / 2, initialPosition.Y.Scale, initialPosition.Y.Offset - self.Size.Y / 2),
        Size = UDim2.fromOffset(self.Size.X, self.Size.Y), BackgroundColor3 = T.Background,
        BorderColor3 = T.Outline, BorderSizePixel = 1, ClipsDescendants = true,
    }, self.Screen)
    self.RestPosition = self.Root.Position
    self.Header = U.frame(self.Root, { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.Panel, Active = true })
    U.label(self.Header, options.Name or "BOOGA", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.45, -8, 1, 0), TextSize = T.TextSize + 1 })
    U.label(self.Header, "PlaceId: " .. tostring(options.PlaceId or game.PlaceId), {
        Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, -8, 1, 0),
        TextColor3 = T.Muted, TextSize = T.SmallSize, TextXAlignment = Enum.TextXAlignment.Right,
    })
    U.frame(self.Header, { Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Outline })
    local accent = U.frame(self.Root, { Name = "RainbowAccent", Position = UDim2.fromOffset(0, 31), Size = UDim2.fromOffset(364, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4 })
    self.Accent = accent
    local transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0), NumberSequenceKeypoint.new(0.88, 0), NumberSequenceKeypoint.new(1, 1) })
    local gradient = U.new("UIGradient", { Transparency = transparency }, accent)
    local hues, last = {}, -1
    self.Scope:Connect(RunService.RenderStepped, function()
        if not self.Open then return end
        local tick = self.ReducedMotion and 0 or math.floor(os.clock() * 30)
        if tick == last then return end
        last = tick
        local phase = self.ReducedMotion and 0 or (tick / 150) % 1
        for i = 0, 6 do
            hues[i + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6 + phase) % 1, 0.56, 0.93))
        end
        gradient.Color = ColorSequence.new(hues)
    end)
    self.Tabs = U.new("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 30), BorderSizePixel = 0, BackgroundColor3 = T.Background, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X }, self.Root)
    U.padding(self.Tabs, 4); U.list(self.Tabs, true, 0)
    self.Body = U.frame(self.Root, { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 1, -84) })
    self.Footer = U.frame(self.Root, { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = T.Panel })
    U.frame(self.Footer, { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Outline })
    self.Status = U.label(self.Footer, "Ready", { Position = UDim2.fromOffset(7, 0), Size = UDim2.new(0.7, -7, 1, 0), TextSize = T.SmallSize })
    U.label(self.Footer, options.Footer or "", { Position = UDim2.new(0.7, 0, 0, 0), Size = UDim2.new(0.3, -7, 1, 0), TextSize = T.SmallSize, TextColor3 = T.Muted, TextXAlignment = Enum.TextXAlignment.Right })
    self.ResizeHandle = U.button(self.Root, "", {
        Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, BorderSizePixel = 0,
        ZIndex = 100, Visible = self.Resizable,
    })
    self.ResizeHandle.Modal = true
    self.Fade = Fade.new(self.Screen)
    self.Fade:Set(1)
    Cursor.set(self, true)
    self.Scope:Connect(Input.InputBegan, function(input, processed)
        if self.Capturing then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local control = self.Capturing; self.Capturing = nil
            if input.KeyCode ~= Enum.KeyCode.Escape then control:Set(input.KeyCode) else control.Render(control:Get()) end
            return
        end
        if processed or Input:GetFocusedTextBox() then return end
        if input.KeyCode == self.ToggleKey then self:SetVisible(not self.Open) return end
        if not self.Open then return end
        for _, control in ipairs(self.Keybinds) do
            if control.Enabled and input.KeyCode == control:Get() and control.Pressed then self:Dispatch(control.Pressed, input) end
        end
    end)
    self.Scope:Connect(Input.InputEnded, function(input)
        for _, control in ipairs(self.Keybinds) do
            if input.KeyCode == control:Get() and control.Released then self:Dispatch(control.Released, input) end
        end
    end)
    local dragStart, dragPosition
    self.Scope:Connect(self.Header.InputBegan, function(input)
        if not self.Open then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.Root.Position = self.RestPosition
            dragStart = input.Position; dragPosition = self.Root.Position; self.DragInput = input
        end
    end)
    self.Scope:Connect(Input.InputChanged, function(input)
        if not self.Open then return end
        local resize = self.Resizing
        if resize and (input.UserInputType == Enum.UserInputType.MouseMovement or input == resize.Input) then
            local delta = input.Position - resize.Start
            self:SetSize(Vector2.new(resize.Size.X + delta.X, resize.Size.Y + delta.Y), resize.Origin)
            return
        end
        if not dragStart then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= self.DragInput then return end
        local delta = input.Position - dragStart
        self.RestPosition = UDim2.new(dragPosition.X.Scale, math.round(dragPosition.X.Offset + delta.X), dragPosition.Y.Scale, math.round(dragPosition.Y.Offset + delta.Y))
        self.Root.Position = self.RestPosition
        self:SnapPosition()
    end)
    self.Scope:Connect(Input.InputEnded, function(input)
        if input == self.DragInput then dragStart = nil; self.DragInput = nil end
        if self.Resizing and input == self.Resizing.Input then self.Resizing = nil end
    end)
    self.Scope:Connect(self.ResizeHandle.InputBegan, function(input)
        if not self.Open or not self.Resizable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self:ClosePopup()
            -- Keep the logical position while resizing.
            -- AbsolutePosition can lag after a tween/size change; don't use it as the resize anchor.
            self.RestPosition = self.Root.Position
            dragStart = nil; self.DragInput = nil
            self.Resizing = { Input = input, Start = input.Position, Size = Vector2.new(self.Root.Size.X.Offset, self.Root.Size.Y.Offset), Origin = self:GetPosition() }
        end
    end)
    self.Scope:Connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function() self:Relayout() end)
    local camera = workspace.CurrentCamera
    local function fit()
        self:Fit()
    end
    self.Scope:Connect(self.Screen:GetPropertyChangedSignal("AbsoluteSize"), fit)
    if camera then self.Scope:Connect(camera:GetPropertyChangedSignal("ViewportSize"), fit) end
    task.defer(function() if not self.Dead then fit() end end)
    task.defer(function() if not self.Dead and self.Open then self:SetVisible(true, true) end end)
    return self
end

function Window:Dispatch(callback, ...)
    if not callback or self.Dead then return end
    local ok, message = pcall(callback, ...)
    if not ok then self:SetStatus("Callback error"); warn("[BoogaUI] " .. tostring(message)) end
end
function Window:Register(id, control)
    assert(type(id) == "string" and not self.Controls[id], "Control IDs must be unique: " .. tostring(id))
    self.Controls[id] = control
    control.Id = id
    return control
end
function Window:SetStatus(text) self.Status.Text = tostring(text or "") end
function Window:SetToggleKey(key)
    assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode, "ToggleKey requires Enum.KeyCode")
    self.ToggleKey = key
end
function Window:ClosePopup()
    if self.PopupClose then local close = self.PopupClose; self.PopupClose = nil; close() end
end
function Window:SetVisible(value, initial)
    if self.Dead then return end
    if self.Open == value and not initial then return end
    self.Open = value; self.VisibilityVersion += 1
    local version = self.VisibilityVersion
    self:ClosePopup()
    self.Resizing = nil
    if self.Capturing then self.Capturing.Render(self.Capturing:Get()); self.Capturing = nil end
    self.Root.Visible = true
    self.ResizeHandle.Modal = value
    Cursor.set(self, value)
    self.Scope:Tween(self.Fade.Alpha, value and 0.18 or 0.15, { Value = value and 0 or 1 }, self.ReducedMotion)
    if not value then
        task.delay(self.ReducedMotion and 0 or 0.15, function()
            if not self.Dead and version == self.VisibilityVersion then self.Root.Visible = false end
        end)
    end
end
function Window:SnapPosition()
    local viewport, size, anchor = self.Screen.AbsoluteSize, self.Root.AbsoluteSize, self.Root.AnchorPoint
    local position = self.RestPosition
    local x = math.round(position.X.Scale * viewport.X + position.X.Offset - anchor.X * size.X)
    local y = math.round(position.Y.Scale * viewport.Y + position.Y.Offset - anchor.Y * size.Y)
    x = math.clamp(x, 12, math.max(12, viewport.X - size.X - 12))
    y = math.clamp(y, 12, math.max(12, viewport.Y - size.Y - 12))
    self.RestPosition = UDim2.fromOffset(x + anchor.X * size.X, y + anchor.Y * size.Y)
    self.Root.Position = self.RestPosition
end
function Window:Fit()
    local viewport = self.Screen.AbsoluteSize
    self.Root.Size = UDim2.fromOffset(math.round(math.min(self.Size.X, math.max(1, viewport.X - 24))), math.round(math.min(self.Size.Y, math.max(1, viewport.Y - 24))))
    self:SnapPosition(); self:Relayout()
end
function Window:GetPosition()
    local position, viewport = self.RestPosition, self.Screen.AbsoluteSize
    return Vector2.new(position.X.Scale * viewport.X + position.X.Offset, position.Y.Scale * viewport.Y + position.Y.Offset)
end
function Window:SetSize(size, origin)
    assert(typeof(size) == "Vector2", "SetSize requires Vector2")
    local viewport = self.Screen.AbsoluteSize
    origin = origin or self:GetPosition()
    local maxX = math.max(1, viewport.X - math.max(12, origin.X) - 12)
    local maxY = math.max(1, viewport.Y - math.max(12, origin.Y) - 12)
    local width = math.round(math.clamp(size.X, math.min(self.MinSize.X, maxX), maxX))
    local height = math.round(math.clamp(size.Y, math.min(self.MinSize.Y, maxY), maxY))
    self.Size = Vector2.new(width, height)
    self.Root.Size = UDim2.fromOffset(width, height)
    self.RestPosition = UDim2.fromOffset(origin.X, origin.Y)
    self.Root.Position = self.RestPosition
    self:Relayout()
end
function Window:Relayout()
    local width = self.Root.AbsoluteSize.X
    local accentWidth = math.floor(math.min(364, width * 0.546) / 2) * 2
    self.Accent.Size = UDim2.fromOffset(accentWidth, 1)
    self.Accent.Position = UDim2.new(0.5, -accentWidth / 2, 0, 31)
    for _, page in ipairs(self.Pages) do page:Relayout() end
end
function Window:AddTab(name)
    local page = { Window = self, Name = name, Groups = {}, Subpages = {} }
    local button = U.button(self.Tabs, name, { Size = UDim2.fromOffset(U.textWidth(name) + 18, 24), BorderSizePixel = 0, BackgroundTransparency = 1, TextColor3 = T.Muted })
    page.Button = button
    page.Line = U.frame(button, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = T.Accent, Visible = false })
    page.Frame = U.frame(self.Body, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
    page.Title = U.label(page.Frame, name, { Position = UDim2.fromOffset(8, 1), Size = UDim2.new(0.65, -8, 0, 23) })
    page.Mode = U.label(page.Frame, "", { Position = UDim2.new(0.65, 0, 0, 1), Size = UDim2.new(0.35, -8, 0, 23), TextColor3 = T.Muted, TextSize = T.SmallSize, TextXAlignment = Enum.TextXAlignment.Right })
    page.Scroll = U.new("ScrollingFrame", { Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 1, -32), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Outline, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y }, page.Frame)
    page.Left = U.frame(page.Scroll, { BackgroundTransparency = 1 })
    page.Right = U.frame(page.Scroll, { BackgroundTransparency = 1 })
    page.LeftList = U.list(page.Left, false, T.Gap); page.RightList = U.list(page.Right, false, T.Gap)
    function page:Relayout()
        local narrow = self.Scroll.AbsoluteSize.X < 520
        local leftHeight, rightHeight = self.LeftList.AbsoluteContentSize.Y, self.RightList.AbsoluteContentSize.Y
        local available = math.floor(self.Scroll.AbsoluteSize.X)
        local leftWidth = narrow and available or math.floor((available - T.Gap) / 2)
        self.Left.Size = UDim2.fromOffset(leftWidth, leftHeight)
        self.Right.Size = UDim2.fromOffset(narrow and available or available - leftWidth - T.Gap, rightHeight)
        self.Right.Position = narrow and UDim2.fromOffset(0, leftHeight + T.Gap) or UDim2.fromOffset(leftWidth + T.Gap, 0)
        self.Scroll.CanvasSize = UDim2.fromOffset(0, narrow and leftHeight + rightHeight + T.Gap or math.max(leftHeight, rightHeight))
    end
    function page:SetTitle(text) self.Title.Text = text end
    function page:SetMode(text) self.Mode.Text = text or "" end
    function page:AddSubTab(title)
        if not self.Subbar then
            self.Subbar = U.frame(self.Frame, { Position = UDim2.fromOffset(8, 25), Size = UDim2.new(1, -16, 0, 24), BackgroundTransparency = 1 })
            U.list(self.Subbar, true, 3)
            self.Scroll.Position = UDim2.fromOffset(8, 54)
            self.Scroll.Size = UDim2.new(1, -16, 1, -60)
        end
        local child = { Page = self, Groups = {} }
        child.Button = U.button(self.Subbar, title, { Size = UDim2.fromOffset(U.textWidth(title) + 16, 22) })
        function child:Select()
            self.Page.Window:ClosePopup()
            self.Page.ActiveSubpage = self
            for _, item in ipairs(self.Page.Subpages) do
                local active = item == self
                item.Button.BorderColor3 = active and T.Accent or T.Outline
                for _, group in ipairs(item.Groups) do group.Frame.Visible = active end
            end
            self.Page:Relayout()
        end
        function child:AddGroupbox(name, side)
            local group = self.Page:AddGroupbox(name, side)
            table.insert(self.Groups, group)
            group.Frame.Visible = self.Page.ActiveSubpage == self
            return group
        end
        table.insert(self.Subpages, child)
        self.Window.Scope:Connect(child.Button.Activated, function() child:Select() end)
        if #self.Subpages == 1 then child:Select() end
        return child
    end
    function page:AddGroupbox(title, side)
        local group = { Window = self.Window, Page = self }
        group.Frame = U.frame(side == "Right" and self.Right or self.Left, { Name = title, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 1, BorderColor3 = T.Outline })
        local header = U.frame(group.Frame, { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Panel })
        U.frame(header, { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = T.Accent })
        U.label(header, title, { Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 1, -2) })
        group.Container = U.frame(group.Frame, { Position = UDim2.fromOffset(T.Padding, 27), Size = UDim2.new(1, -2 * T.Padding, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
        U.list(group.Container, false, T.ControlGap)
        U.padding(group.Container, 0)
        U.new("UIPadding", { PaddingBottom = UDim.new(0, T.Padding) }, group.Frame)
        Controls.attach(group)
        table.insert(self.Groups, group)
        return group
    end
    function page:Select() self.Window:SelectTab(self) end
    self.Scope:Connect(button.Activated, function() self:SelectTab(page) end)
    self.Scope:Connect(page.LeftList:GetPropertyChangedSignal("AbsoluteContentSize"), function() page:Relayout() end)
    self.Scope:Connect(page.RightList:GetPropertyChangedSignal("AbsoluteContentSize"), function() page:Relayout() end)
    self.Scope:Connect(page.Scroll:GetPropertyChangedSignal("AbsoluteSize"), function() page:Relayout() end)
    table.insert(self.Pages, page)
    if #self.Pages == 1 then self:SelectTab(page) end
    return page
end
function Window:SelectTab(page)
    self:ClosePopup()
    for _, item in ipairs(self.Pages) do
        local active = item == page
        item.Frame.Visible = active; item.Line.Visible = active
        item.Button.BackgroundTransparency = active and 0 or 1
        item.Button.TextColor3 = active and T.Text or T.Muted
    end
    self.ActivePage = page
    page:Relayout()
end
function Window:GetConfig()
    local values = {}
    for id, control in pairs(self.Controls) do
        if control.Persist ~= false then
            local value = control:Get()
            if typeof(value) == "EnumItem" then value = { Type = "KeyCode", Name = value.Name } end
            if typeof(value) == "Color3" then value = { Type = "Color3", R = value.R, G = value.G, B = value.B } end
            values[id] = value
        end
    end
    return { Version = 1, Values = values }
end
function Window:LoadConfig(config)
    assert(type(config) == "table" and config.Version == 1 and type(config.Values) == "table", "Unsupported UI config")
    for id, value in pairs(config.Values) do
        local control = self.Controls[id]
        if control then
            if type(value) == "table" and value.Type == "KeyCode" then value = Enum.KeyCode[value.Name] end
            if type(value) == "table" and value.Type == "Color3" then value = Color3.new(value.R, value.G, value.B) end
            control:Set(value)
        end
    end
end
function Window:EncodeConfig() return Http:JSONEncode(self:GetConfig()) end
function Window:DecodeConfig(json) self:LoadConfig(Http:JSONDecode(json)) end
function Window:ConfigChanged()
    if self.Storage and not self.RestoringConfig then self.ConfigDirty = true end
end
function Window:FlushConfig()
    if not self.Storage or not self.ConfigDirty then return end
    local ok, message = pcall(self.Storage.Write, self:EncodeConfig())
    if ok then self.ConfigDirty = false else warn("[BoogaUI] Config save failed: " .. tostring(message)) end
end
function Window:EnablePersistence(adapter)
    assert(type(adapter) == "table" and type(adapter.Read) == "function" and type(adapter.Write) == "function", "Persistence requires Read/Write functions")
    self.Storage = adapter; self.RestoringConfig = true
    local ok, json = pcall(adapter.Read)
    if ok and json and json ~= "" then
        local loaded, message = pcall(function() self:DecodeConfig(json) end)
        if not loaded then warn("[BoogaUI] Ignored invalid config: " .. tostring(message)) end
    end
    self.RestoringConfig = false
    if not self.PersistenceConnection then
        local elapsed = 0
        self.PersistenceConnection = self.Scope:Connect(RunService.Heartbeat, function(dt)
            elapsed += dt
            if elapsed >= 0.5 then elapsed = 0; self:FlushConfig() end
        end)
    end
end
function Window:Destroy()
    if self.Dead then return end
    self:FlushConfig(); self:ClosePopup(); self.Dead = true; self.Capturing = nil
    Cursor.set(self, false)
    self.Scope:Destroy(); self.Fade:Destroy(); self.Screen:Destroy()
    table.clear(self.Controls); table.clear(self.Keybinds)
end
return Window

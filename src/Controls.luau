local U = require(script.Parent.internal.Util)
local T = require(script.Parent.internal.Theme)
local Model = require(script.Parent.internal.Model)
local ColorPicker = require(script.Parent.internal.ColorPicker)
local Input = game:GetService("UserInputService")
local Controls = {}

local function row(group, height)
    return U.frame(group.Container, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or T.RowHeight) })
end
local function control(group, id, initial, normalize, callback)
    local window = group.Window
    local c = Model.control(initial, normalize, function(value) window:Dispatch(callback, value); window:ConfigChanged() end)
    c.Enabled = true
    function c:SetCallback(fn)
        self.Callback = function(value) window:Dispatch(fn, value); window:ConfigChanged() end
        return self
    end
    function c:SetEnabled(value)
        value = value == true
        if self.Enabled == value then return self end
        self.Enabled = value
        if self.Root then self.Root.Active = self.Enabled end
        if self.Render then self.Render(self:Get()) end
        return self
    end
    function c:SetVisible(value) self.Row.Visible = value == true return self end
    return window:Register(id, c)
end
local function keyButton(group, parent, id, info)
    local window = group.Window
    local c = control(group, id, info.Value or Enum.KeyCode.Unknown, function(value)
        assert(typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode, "Keybind requires Enum.KeyCode")
        return value
    end, info.Callback)
    c.Pressed = info.Pressed; c.Released = info.Released
    c.Row = parent
    c.Root = U.button(parent, "", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(110, 20), BackgroundTransparency = 1, BorderSizePixel = 0, TextColor3 = T.Muted, TextSize = T.SmallSize, TextXAlignment = Enum.TextXAlignment.Right })
    c.Render = function(value)
        c.Root.Text = "[" .. U.keyName(value) .. "]"
        c.Root.TextTransparency = c.Enabled and 0 or 0.55
    end
    window.Scope:Connect(c.Root.Activated, function()
        if not c.Enabled then return end
        if window.Capturing then window.Capturing.Render(window.Capturing:Get()) end
        window.Capturing = c; c.Root.Text = "[Press a key]"
    end)
    table.insert(window.Keybinds, c)
    c.Render(c:Get())
    return c
end

function Controls.attach(group)
    function group:AddLabel(text, small)
        local label = U.label(self.Container, text, { TextSize = small and T.SmallSize or T.TextSize, TextColor3 = small and T.Muted or T.Text })
        local result = { Root = label }
        function result:SetText(value) label.Text = tostring(value) end
        function result:SetVisible(value) label.Visible = value end
        return result
    end
    function group:AddToggle(id, info)
        info = info or {}
        local c = control(self, id, info.Value == true, function(value) return value == true end, info.Callback)
        c.Row = row(self)
        local hit = U.button(c.Row, "", { Size = UDim2.new(1, info.Keybind and -65 or 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0 })
        c.Root = hit
        local box = U.frame(hit, { Position = UDim2.new(0, 0, 0.5, -6), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = T.Panel, BorderSizePixel = 1, BorderColor3 = T.Outline })
        local check = U.label(box, "✓", { Size = UDim2.fromScale(1, 1), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1 })
        local scale = U.new("UIScale", { Scale = 0.35 }, check)
        local name = U.label(hit, info.Text or id, { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0) })
        c.Render = function(value)
            self.Window.Scope:Tween(box, 0.16, { BackgroundColor3 = value and T.Accent or T.Panel, BorderColor3 = value and T.Accent or T.Outline }, self.Window.ReducedMotion)
            self.Window.Scope:Tween(check, 0.13, { TextTransparency = value and 0 or 1 }, self.Window.ReducedMotion)
            self.Window.Scope:Tween(scale, 0.18, { Scale = value and 1 or 0.35 }, self.Window.ReducedMotion)
            name.TextTransparency = c.Enabled and 0 or 0.55
        end
        self.Window.Scope:Connect(hit.Activated, function() if c.Enabled then c:Set(not c:Get()) end end)
        if info.Keybind then c.Keybind = keyButton(self, c.Row, info.Keybind.Id or id .. "Key", info.Keybind) end
        c.Render(c:Get())
        return c
    end
    function group:AddKeybind(id, info)
        info = info or {}
        local container = row(self)
        U.label(container, info.Text or id, { Size = UDim2.new(1, -110, 1, 0) })
        return keyButton(self, container, id, info)
    end
    function group:AddSlider(id, info)
        info = info or {}
        local minimum, maximum, step = info.Min or 0, info.Max or 100, info.Step or 1
        assert(maximum > minimum and step > 0, "Slider requires Max > Min and Step > 0")
        local c = control(self, id, info.Value or minimum, function(value) return Model.number(value, minimum, maximum, step) end, info.Callback)
        c.Row = row(self, 35)
        U.label(c.Row, info.Text or id, { Size = UDim2.new(0.65, 0, 0, 18) })
        local output = U.label(c.Row, "", { Position = UDim2.new(0.65, 0, 0, 0), Size = UDim2.new(0.35, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right })
        local track = U.button(c.Row, "", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 16) })
        c.Root = track
        local fill = U.frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent })
        local thumb = U.frame(track, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = T.Text })
        c.Render = function(value)
            local fraction = (value - minimum) / (maximum - minimum)
            fill.Size = UDim2.fromScale(fraction, 1); thumb.Position = UDim2.fromScale(fraction, 0)
            output.Text = string.format(info.Format or "%g", value) .. (info.Suffix and " " .. info.Suffix or "")
            output.TextTransparency = c.Enabled and 0 or 0.55
        end
        local dragging, touch
        local function update(x)
            if not c.Enabled then return end
            local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
            c:Set(minimum + fraction * (maximum - minimum))
        end
        self.Window.Scope:Connect(track.InputBegan, function(input)
            if not c.Enabled then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; touch = input; update(input.Position.X)
            end
        end)
        self.Window.Scope:Connect(Input.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == touch) then update(input.Position.X) end
        end)
        self.Window.Scope:Connect(Input.InputEnded, function(input) if input == touch then dragging = false; touch = nil end end)
        c.Render(c:Get())
        return c
    end
    function group:AddTextbox(id, info)
        info = info or {}
        local c = control(self, id, info.Value or "", function(value) return tostring(value or ""):sub(1, info.MaxLength or 256) end, info.Callback)
        c.Row = row(self, 41)
        U.label(c.Row, info.Text or id, { Size = UDim2.new(1, 0, 0, 18) })
        c.Root = U.new("TextBox", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, T.RowHeight), BackgroundColor3 = T.Input, BorderSizePixel = 1, BorderColor3 = T.Outline, Font = T.Font, TextSize = T.TextSize, TextScaled = false, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = c:Get(), PlaceholderText = info.Placeholder or "", ClearTextOnFocus = false }, c.Row)
        U.new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, c.Root)
        c.Render = function(value) c.Root.Text = value; c.Root.TextEditable = c.Enabled end
        self.Window.Scope:Connect(c.Root.FocusLost, function() if c.Enabled then c:Set(c.Root.Text) end end)
        return c
    end
    function group:AddDropdown(id, info)
        info = info or {}
        local options = Model.options(info.Options or {})
        local function find(value) for _, option in ipairs(options) do if option.Value == value then return option end end end
        local initial = info.Value
        if initial == nil and options[1] then initial = options[1].Value end
        local c = control(self, id, initial, function(value) assert(value == nil or find(value), "Unknown dropdown value: " .. tostring(value)) return value end, info.Callback)
        c.Row = row(self, 41)
        U.label(c.Row, info.Text or id, { Size = UDim2.new(1, 0, 0, 18) })
        c.Root = U.button(c.Row, "", { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, T.RowHeight) })
        local name = U.label(c.Root, "", { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(1, -20, 1, 0) })
        local meta = U.label(c.Root, "", { TextSize = T.SmallSize, TextColor3 = T.Muted, Size = UDim2.new(0, 50, 1, 0) })
        U.label(c.Root, "▾", { Position = UDim2.new(1, -16, 0, 0), Size = UDim2.new(0, 12, 1, 0), TextColor3 = T.Muted })
        c.Render = function(value)
            local option = find(value)
            name.Text = option and option.Label or "None"
            meta.Text = option and option.Meta and tostring(option.Meta) or ""
            local textWidth = U.textWidth(name.Text)
            meta.Position = UDim2.fromOffset(textWidth + 12, 0)
            name.TextTransparency = c.Enabled and 0 or 0.55
        end
        function c:UpdateOptions(values)
            self.Window:ClosePopup()
            options = Model.options(values)
            local selected = find(self:Get()) and self:Get() or (options[1] and options[1].Value)
            local unchanged = selected == self:Get()
            self:SetSilent(selected)
            if unchanged then self.Render(selected) end
        end
        c.Window = self.Window
        local function open()
            if not c.Enabled or #options == 0 then return end
            if self.Window.PopupOwner == c then self.Window:ClosePopup() return end
            self.Window:ClosePopup(); self.Window.PopupOwner = c
            local menuScope = U.scope()
            local menu = U.new("ScrollingFrame", { Name = "Dropdown", BackgroundColor3 = T.Panel, BorderSizePixel = 1, BorderColor3 = T.Outline, ZIndex = 50, CanvasSize = UDim2.fromOffset(0, #options * 23), ScrollBarThickness = 3 }, self.Window.Screen)
            U.list(menu, false, 0)
            local function position()
                local screen = self.Window.Screen.AbsoluteSize
                local size = c.Root.AbsoluteSize
                local origin = c.Root.AbsolutePosition
                local height = math.min(#options * 23, 184, screen.Y - 16)
                local y = origin.Y + size.Y
                if y + height > screen.Y - 8 then y = math.max(8, origin.Y - height) end
                menu.Position = UDim2.fromOffset(math.clamp(origin.X, 8, math.max(8, screen.X - size.X - 8)), y)
                menu.Size = UDim2.fromOffset(size.X, height)
            end
            position()
            for _, option in ipairs(options) do
                local entry = U.button(menu, "", { Size = UDim2.new(1, 0, 0, 23), BorderSizePixel = 0, BackgroundColor3 = option.Value == c:Get() and T.Selected or T.Panel, ZIndex = 51 })
                U.label(entry, option.Label, { Position = UDim2.fromOffset(5, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 52 })
                if option.Meta ~= nil then
                    local textWidth = U.textWidth(option.Label)
                    U.label(entry, tostring(option.Meta), { Position = UDim2.fromOffset(textWidth + 12, 0), Size = UDim2.new(0, 48, 1, 0), TextColor3 = T.Muted, TextSize = T.SmallSize, ZIndex = 52 })
                end
                menuScope:Connect(entry.Activated, function() c:Set(option.Value); self.Window:ClosePopup() end)
            end
            menuScope:Connect(game:GetService("RunService").RenderStepped, position)
            menuScope:Connect(Input.InputBegan, function(input)
                if input.KeyCode == Enum.KeyCode.Escape then self.Window:ClosePopup() return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local p = input.Position
                local function inside(gui) local a, b = gui.AbsolutePosition, gui.AbsoluteSize return p.X >= a.X and p.X <= a.X + b.X and p.Y >= a.Y and p.Y <= a.Y + b.Y end
                if not inside(menu) and not inside(c.Root) then self.Window:ClosePopup() end
            end)
            self.Window.PopupClose = function() menuScope:Destroy(); menu:Destroy(); self.Window.PopupOwner = nil end
        end
        self.Window.Scope:Connect(c.Root.Activated, open)
        c.Render(c:Get())
        return c
    end
    function group:AddButton(info)
        info = info or {}
        local container = row(self)
        local function setText(text)
            local width = info.Width or (U.textWidth(text) + 14)
            return text, UDim2.fromOffset(width, T.RowHeight)
        end
        local text, size = setText(info.Text or "Button")
        local button = U.button(container, text, { Size = size, BorderColor3 = info.Primary and T.Accent or T.Outline })
        local result = { Root = button, Row = container, Enabled = info.Disabled ~= true }
        function result:SetEnabled(value)
            value = value == true
            if self.Enabled == value and self.Rendered then return self end
            self.Enabled = value; self.Rendered = true
            button.TextTransparency = value and 0 or 0.55
            return self
        end
        function result:SetText(text) button.Text, button.Size = setText(text) end
        self.Window.Scope:Connect(button.Activated, function() if result.Enabled then self.Window:Dispatch(info.Callback) end end)
        if info.Keybind then
            local config = table.clone(info.Keybind)
            local changed = config.Callback
            config.Pressed = config.Pressed or function() if result.Enabled then self.Window:Dispatch(info.Callback) end end
            config.Callback = function(value) result:SetText((info.Text or "Button") .. " [" .. U.keyName(value) .. "]"); if changed then changed(value) end end
            result.Keybind = keyButton(self, container, config.Id, config)
            result:SetText((info.Text or "Button") .. " [" .. U.keyName(result.Keybind:Get()) .. "]")
        end
        result:SetEnabled(result.Enabled)
        return result
    end
    function group:AddButtons(definitions)
        local container = row(self)
        U.list(container, true, 4)
        local result = {}
        for _, info in ipairs(definitions) do
            local button = U.button(container, info.Text, { Size = UDim2.fromOffset(info.Width or U.textWidth(info.Text) + 14, T.RowHeight), BorderColor3 = info.Primary and T.Accent or T.Outline })
            self.Window.Scope:Connect(button.Activated, function() self.Window:Dispatch(info.Callback) end)
            table.insert(result, button)
        end
        return result
    end
    function group:AddDisclosure(title)
        local frame = U.frame(self.Container, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
        U.list(frame, false, 0)
        local button = U.button(frame, "▸ " .. title, { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Muted, TextSize = T.SmallSize, BackgroundTransparency = 1, BorderSizePixel = 0 })
        local child = { Window = self.Window, Container = U.frame(frame, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false }) }
        U.list(child.Container, false, T.ControlGap); Controls.attach(child)
        self.Window.Scope:Connect(button.Activated, function() child.Container.Visible = not child.Container.Visible; button.Text = (child.Container.Visible and "▾ " or "▸ ") .. title end)
        return child
    end
    function group:AddColorPicker(id, info)
        info = info or {}
        local c = control(self, id, info.Value or Color3.new(1, 1, 1), function(value) assert(typeof(value) == "Color3", "ColorPicker requires Color3") return value end, info.Callback)
        c.Row = row(self)
        U.label(c.Row, info.Text or id, { Size = UDim2.new(1, -85, 1, 0) })
        c.Root = U.button(c.Row, "", { Position = UDim2.new(1, -30, 0, 4), Size = UDim2.fromOffset(28, 15) })
        ColorPicker.attach(self, c, info)
        return c
    end
    function group:AddPreview(info)
        info = info or {}
        local preview = {}
        preview.Root = U.frame(self.Container, { Size = UDim2.new(1, 0, 0, info.Height or 148), BorderColor3 = T.Outline, BorderSizePixel = 1, ClipsDescendants = true })
        local grid = U.frame(preview.Root, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 })
        local gridDots = {}
        local gridColumns, gridRows = -1, -1
        local drawing = U.frame(preview.Root, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 })
        preview.Points = {}; preview.Parts = {}
        local count = self:AddLabel("0 / 0")
        local track = U.frame(self.Container, { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = T.Hover })
        local fill = U.frame(track, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent })
        local function layout()
            local bounds = preview.Root.AbsoluteSize
            local columns = math.max(0, math.floor((bounds.X - 16) / 10) + 1)
            local rows = math.max(0, math.floor((bounds.Y - 16) / 10) + 1)
            if columns ~= gridColumns or rows ~= gridRows then
                for key, dot in pairs(gridDots) do
                    if dot.Position.X.Offset > bounds.X - 8 or dot.Position.Y.Offset > bounds.Y - 8 then dot:Destroy(); gridDots[key] = nil end
                end
                for y = 8, bounds.Y - 8, 10 do for x = 8, bounds.X - 8, 10 do
                    local key = x .. ":" .. y
                    if not gridDots[key] then gridDots[key] = U.frame(grid, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(1, 1), BackgroundColor3 = T.Outline, BackgroundTransparency = 0.35 }) end
                end end
                gridColumns, gridRows = columns, rows
            end
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            for _, point in ipairs(preview.Points) do minX = math.min(minX, point.X); minY = math.min(minY, point.Y); maxX = math.max(maxX, point.X); maxY = math.max(maxY, point.Y) end
            if #preview.Points == 0 then return end
            local size = preview.Root.AbsoluteSize
            local cell = math.min((size.X - 24) / (maxX - minX + 1), (size.Y - 24) / (maxY - minY + 1))
            cell = math.max(1, cell)
            local ox, oy = (size.X - (maxX - minX + 1) * cell) / 2, (size.Y - (maxY - minY + 1) * cell) / 2
            for i, point in ipairs(preview.Points) do
                preview.Parts[i].Position = UDim2.fromOffset(ox + (point.X - minX) * cell, oy + (point.Y - minY) * cell)
                preview.Parts[i].Size = UDim2.fromOffset(cell * 0.84, cell * 0.84)
            end
        end
        function preview:SetPoints(points)
            local same = #points == #self.Points
            if same then for i, point in ipairs(points) do
                if point.X ~= self.Points[i].X or point.Y ~= self.Points[i].Y then same = false; break end
            end end
            if same then return self end
            for i = #self.Parts, #points + 1, -1 do self.Parts[i]:Destroy(); self.Parts[i] = nil end
            for i = #self.Parts + 1, #points do
                self.Parts[i] = U.frame(drawing, { BackgroundColor3 = T.Accent })
                U.new("UICorner", { CornerRadius = UDim.new(0, 1) }, self.Parts[i])
            end
            self.Points = table.clone(points)
            layout(); self:SetCount(0, #points)
            return self
        end
        function preview:SetCount(current, total)
            if self.Current == current and self.Total == total then return end
            self.Current, self.Total = current, total
            count:SetText(string.format("%d / %d", current, total))
            fill.Size = UDim2.fromScale(total > 0 and math.clamp(current / total, 0, 1) or 0, 1)
        end
        function preview:Recoil()
            if group.Window.ReducedMotion then return end
            group.Window.Scope:Tween(drawing, 0.06, { Position = UDim2.fromOffset(-3, -2) }, false)
            task.delay(0.06, function() if not group.Window.Dead then group.Window.Scope:Tween(drawing, 0.19, { Position = UDim2.fromOffset(0, 0) }, false) end end)
        end
        group.Window.Scope:Connect(preview.Root:GetPropertyChangedSignal("AbsoluteSize"), layout)
        preview:SetPoints(info.Points or {})
        return preview
    end
end
return Controls

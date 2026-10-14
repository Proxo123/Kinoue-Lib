local Cursor = require(script.Parent.internal.Cursor)
local Fade = require(script.Parent.internal.Fade)
local Mount = require(script.Parent.internal.Mount)
local Theme = require(script.Parent.internal.Theme)
local Util = require(script.Parent.internal.Util)
local Chrome = require(script.Chrome)
local Config = require(script.Config)
local Input = require(script.Input)
local Page = require(script.Page)
local Settings = require(script.Settings)

local EDGE_MARGIN = 12
local FIT_MARGIN = 24
local OPEN_DURATION = 0.18
local CLOSE_DURATION = 0.15

local Window = {}
Window.__index = Window

for name, method in pairs(Config) do
    Window[name] = method
end

function Window.new(options)
    local self = setmetatable({}, Window)
    self.Scope = Util.scope()
    self.Controls = {}
    self.Pages = {}
    self.Keybinds = {}
    self.Cleanup = {}
    self.ThemeHooks = {}
    self.ReducedMotion = options.ReducedMotion == true
    self.RainbowAccent = options.RainbowAccent ~= false
    self.SettingsOpen = false
    self.ToggleKey = options.ToggleKey or Enum.KeyCode.RightShift
    self.Size = options.Size or Vector2.new(704, 470)
    self.MinSize = options.MinSize or Vector2.new(480, 360)
    self.Resizable = options.Resizable ~= false
    self.AllowOffscreen = options.AllowOffscreen == true
    self.SnapDistance = math.max(0, options.SnapDistance or 8)
    self.Open = true
    self.Dead = false
    self.VisibilityVersion = 0

    self.Screen = Util.new("ScreenGui", {
        Name = options.Id or "Kinoue",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.DisplayOrder or 100,
    })
    Mount.core(self.Screen, options.ReplaceExisting == true)
    Chrome.build(self, options)

    self.Fade = Fade.new(self.Screen)
    self.Fade:Set(1)
    Cursor.set(self, true)

    Input.bindKeys(self)
    Input.bindPointer(self)

    self.SettingsPage = Settings.build(self, options)
    self.SettingsButton.Visible = options.ShowSettings ~= false
    self.Scope:Connect(self.SettingsButton.Activated, function()
        self:ToggleSettings()
    end)
    self.ThemeListener = Theme.onChanged(function()
        self:RefreshTheme()
    end)

    local function fit()
        self:Fit()
    end
    self.Scope:Connect(self.Root:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:Relayout()
    end)
    self.Scope:Connect(self.Screen:GetPropertyChangedSignal("AbsoluteSize"), fit)
    local camera = workspace.CurrentCamera
    if camera then
        self.Scope:Connect(camera:GetPropertyChangedSignal("ViewportSize"), fit)
    end

    task.defer(function()
        if not self.Dead then
            fit()
        end
    end)
    task.defer(function()
        if not self.Dead and self.Open then
            self:SetVisible(true, true)
        end
    end)
    return self
end

function Window:Dispatch(callback, ...)
    if not callback or self.Dead then
        return
    end
    local ok, message = pcall(callback, ...)
    if not ok then
        if not self.Dead then
            self:SetStatus("Callback error")
        end
        Util.warn(message)
    end
end

function Window:Register(id, control)
    assert(type(id) == "string" and not self.Controls[id], "Control IDs must be unique: " .. tostring(id))
    self.Controls[id] = control
    control.Id = id
    return control
end

function Window:SetStatus(text)
    if self.Dead then
        return
    end
    text = tostring(text or "")
    if self.Status.Text ~= text then
        self.Status.Text = text
    end
end

function Window:SetToggleKey(key)
    assert(typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode, "ToggleKey requires Enum.KeyCode")
    self.ToggleKey = key
end

function Window:ClosePopup()
    if self.PopupClose then
        local close = self.PopupClose
        self.PopupClose = nil
        close()
    end
end

function Window:SetVisible(value, initial)
    if self.Dead then
        return
    end
    if self.Open == value and not initial then
        return
    end
    self.Open = value
    self.VisibilityVersion += 1
    self.UpdateAccent()

    local version = self.VisibilityVersion
    self:ClosePopup()
    self.Resizing = nil
    if self.Capturing then
        self.Capturing.Render(self.Capturing:Get())
        self.Capturing = nil
    end

    self.Root.Visible = true
    Cursor.set(self, value)
    local duration = value and OPEN_DURATION or CLOSE_DURATION
    self.Scope:Tween(self.Fade.Alpha, duration, { Value = value and 0 or 1 }, self.ReducedMotion)

    if not value then
        task.delay(self.ReducedMotion and 0 or CLOSE_DURATION, function()
            if not self.Dead and version == self.VisibilityVersion then
                self.Root.Visible = false
            end
        end)
    end
end

local function snapToEdge(value, edges, distance)
    for _, edge in ipairs(edges) do
        if math.abs(value - edge) <= distance then
            return edge
        end
    end
    return value
end

function Window:SnapPosition(snapEdges)
    local viewport, size, anchor = self.Screen.AbsoluteSize, self.Root.AbsoluteSize, self.Root.AnchorPoint
    local position = self.RestPosition
    local x = math.round(position.X.Scale * viewport.X + position.X.Offset - anchor.X * size.X)
    local y = math.round(position.Y.Scale * viewport.Y + position.Y.Offset - anchor.Y * size.Y)

    if not self.AllowOffscreen then
        x = math.clamp(x, EDGE_MARGIN, math.max(EDGE_MARGIN, viewport.X - size.X - EDGE_MARGIN))
        y = math.clamp(y, EDGE_MARGIN, math.max(EDGE_MARGIN, viewport.Y - size.Y - EDGE_MARGIN))
    elseif snapEdges then
        x = snapToEdge(x, { 0, viewport.X - size.X }, self.SnapDistance)
        y = snapToEdge(y, { 0, viewport.Y - size.Y }, self.SnapDistance)
    end

    self.RestPosition = UDim2.fromOffset(x + anchor.X * size.X, y + anchor.Y * size.Y)
    self.Root.Position = self.RestPosition
end

function Window:Fit()
    local viewport = self.Screen.AbsoluteSize
    local margin = self.AllowOffscreen and 0 or FIT_MARGIN
    local width = math.round(math.min(self.Size.X, math.max(1, viewport.X - margin)))
    local height = math.round(math.min(self.Size.Y, math.max(1, viewport.Y - margin)))
    self.Root.Size = UDim2.fromOffset(width, height)
    self:SnapPosition()
    self:Relayout()
end

function Window:GetPosition()
    local position, viewport = self.RestPosition, self.Screen.AbsoluteSize
    return Vector2.new(
        position.X.Scale * viewport.X + position.X.Offset,
        position.Y.Scale * viewport.Y + position.Y.Offset
    )
end

function Window:SetPosition(position, snapEdges)
    assert(typeof(position) == "Vector2", "SetPosition requires Vector2")
    self.RestPosition = UDim2.fromOffset(position.X, position.Y)
    self:SnapPosition(snapEdges)
    return self
end

function Window:SetSize(size, origin)
    assert(typeof(size) == "Vector2", "SetSize requires Vector2")
    local viewport = self.Screen.AbsoluteSize
    origin = origin or self:GetPosition()

    local maxX, maxY
    if self.AllowOffscreen then
        maxX = math.max(1, viewport.X)
        maxY = math.max(1, viewport.Y)
    else
        maxX = math.max(1, viewport.X - math.max(EDGE_MARGIN, origin.X) - EDGE_MARGIN)
        maxY = math.max(1, viewport.Y - math.max(EDGE_MARGIN, origin.Y) - EDGE_MARGIN)
    end

    local width = math.round(math.clamp(size.X, math.min(self.MinSize.X, maxX), maxX))
    local height = math.round(math.clamp(size.Y, math.min(self.MinSize.Y, maxY), maxY))
    self.Size = Vector2.new(width, height)
    self.Root.Size = UDim2.fromOffset(width, height)
    self.RestPosition = UDim2.fromOffset(origin.X, origin.Y)
    self.Root.Position = self.RestPosition
    self:Relayout()
end

function Window:Relayout()
    Chrome.layoutAccent(self)
    for _, page in ipairs(self.Pages) do
        page:Relayout()
    end
    if self.SettingsPage then
        self.SettingsPage:Relayout()
    end
end

function Window:AddTab(name)
    return Page.new(self, name)
end

function Window:StyleTabs()
    for _, item in ipairs(self.Pages) do
        local active = item == self.ActivePage
        item.Line.Visible = active
        item.Button.BackgroundTransparency = active and 0 or 1
        item.Button.TextColor3 = active and Theme.Text or Theme.Muted
    end
end

function Window:SelectTab(page)
    self:ClosePopup()
    local settings = self.SettingsPage
    self.SettingsOpen = settings ~= nil and page == settings
    if not self.SettingsOpen then
        self.LastPage = page
    end
    if settings then
        settings.Frame.Visible = self.SettingsOpen
    end
    for _, item in ipairs(self.Pages) do
        item.Frame.Visible = item == page
    end
    self.ActivePage = page
    self:StyleTabs()
    Chrome.paintSettingsButton(self)
    page:Relayout()
end

function Window:OpenSettings()
    if not self.SettingsOpen then
        self:SelectTab(self.SettingsPage)
    end
    return self
end

function Window:CloseSettings()
    if not self.SettingsOpen then
        return self
    end
    local page = self.LastPage or self.Pages[1]
    if page then
        self:SelectTab(page)
    else
        self:ClosePopup()
        self.SettingsOpen = false
        self.SettingsPage.Frame.Visible = false
        self.ActivePage = nil
        Chrome.paintSettingsButton(self)
    end
    return self
end

function Window:ToggleSettings()
    if self.SettingsOpen then
        return self:CloseSettings()
    end
    return self:OpenSettings()
end

local function syncSetting(window, id, value)
    local control = window.Controls[id]
    if control then
        control:SetSilent(value)
    end
end

function Window:SetLockToScreen(locked)
    self.AllowOffscreen = locked ~= true
    syncSetting(self, "UI.LockToScreen", not self.AllowOffscreen)
    self:Fit()
    return self
end

function Window:SetReducedMotion(reduced)
    self.ReducedMotion = reduced == true
    syncSetting(self, "UI.Animations", not self.ReducedMotion)
    self.UpdateAccent()
    return self
end

function Window:SetRainbowAccent(enabled)
    self.RainbowAccent = enabled == true
    syncSetting(self, "UI.RainbowAccent", self.RainbowAccent)
    self.UpdateAccent()
    return self
end

function Window:RefreshTheme()
    if self.Dead then
        return
    end
    for _, control in pairs(self.Controls) do
        if control.Render and control ~= self.Capturing then
            control.Render(control:Get())
        end
    end
    self.SettingsPage.Controls.sync()
    for _, hook in ipairs(self.ThemeHooks) do
        hook()
    end
    self:StyleTabs()
    Chrome.paintSettingsButton(self)
    self.UpdateAccent()
end

function Window:OnDestroy(callback)
    assert(type(callback) == "function", "OnDestroy requires a function")
    if self.Dead then
        callback()
    else
        table.insert(self.Cleanup, callback)
    end
    return self
end

local function cleanupStep(name, fn)
    local ok, message = pcall(function()
        return Util.withContext(fn)
    end)
    if not ok then
        Util.warn(name .. " cleanup failed: " .. tostring(message))
    end
end

function Window:Destroy()
    if self.Dead then
        return
    end
    self.Dead = true
    self.Open = false
    self.Capturing = nil
    self.Resizing = nil
    self.VisibilityVersion += 1

    cleanupStep("Visibility", function()
        self.Screen.Enabled = false
        self.Root.Visible = false
    end)
    cleanupStep("Config", function()
        self:FlushConfig()
    end)
    cleanupStep("Popup", function()
        self:ClosePopup()
    end)
    self.PopupOwner = nil
    cleanupStep("Cursor", function()
        Cursor.set(self, false)
    end)
    cleanupStep("Theme", function()
        if self.ThemeListener then
            self.ThemeListener()
            self.ThemeListener = nil
        end
    end)
    cleanupStep("Accent", function()
        if self.AccentScope then
            self.AccentScope:Destroy()
            self.AccentScope = nil
        end
    end)
    cleanupStep("Signals", function()
        self.Scope:Destroy()
    end)
    cleanupStep("Fade", function()
        self.Fade:Destroy()
    end)
    cleanupStep("Screen", function()
        self.Screen:Destroy()
    end)

    for _, callback in ipairs(self.Cleanup) do
        local ok, message = pcall(callback)
        if not ok then
            Util.warn("Cleanup error: " .. tostring(message))
        end
    end
    table.clear(self.Cleanup)
    table.clear(self.Controls)
    table.clear(self.Keybinds)
end

local protected = {}
for name, method in pairs(Window) do
    if type(method) == "function" and name ~= "new" and name ~= "Destroy" and name ~= "Dispatch" then
        table.insert(protected, name)
    end
end
Util.protect(Window, protected)

return Window

local UserInputService = game:GetService("UserInputService")

local Cursor = require(script.Parent.Cursor)
local Mount = require(script.Parent.Mount)
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Dialog = {}
Dialog.__index = Dialog

local function button(dialog, text, position, primary)
    local control = { Enabled = true }
    control.Root = Util.button(dialog.Root, text, {
        Name = text,
        Position = position,
        Size = UDim2.new(0.5, -20, 0, 32),
        Font = Theme.FontMedium,
    })
    Util.corner(control.Root)
    local hovered = false
    local function paint()
        if dialog.Dead then
            return
        end
        local accent = primary and control.Enabled
        control.Root.Active = control.Enabled
        control.Root.BackgroundColor3 = accent and Theme.Accent
            or (hovered and control.Enabled and Theme.Hover or Theme.Input)
        control.Root.BorderColor3 = accent and Theme.Accent or Theme.Outline
        control.Root.TextColor3 = accent and Color3.new(1, 1, 1) or (control.Enabled and Theme.Text or Theme.Muted)
        control.Root.BackgroundTransparency = accent and hovered and 0.12 or 0
    end
    function control:SetEnabled(value)
        self.Enabled = value == true
        paint()
        return self
    end
    Util.hover(dialog.Scope, control.Root, function(value)
        hovered = value
        paint()
    end)
    table.insert(dialog.Painters, paint)
    paint()
    return Util.protect(control, { "SetEnabled" })
end

function Dialog.new(options)
    local self = setmetatable({
        Scope = Util.scope(),
        Cleanup = {},
        Painters = {},
        Dead = false,
        Open = true,
        Name = options.Name or "Kinoue",
    }, Dialog)
    self.Screen = Util.new("ScreenGui", {
        Name = options.Id,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })
    self.Root = Util.frame(self.Screen, {
        Name = "KeyDialog",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Color.Background,
        BorderColor3 = Theme.Color.Outline,
        BorderSizePixel = 1,
    })
    Util.corner(self.Root, Theme.WindowRadius)
    local field = Util.textbox(self.Root, {
        Name = "Key",
        Position = UDim2.fromOffset(16, 16),
        Size = UDim2.new(1, -32, 0, 36),
        Text = "",
        PlaceholderText = "Enter key",
        PlaceholderColor3 = Theme.Color.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClipsDescendants = true,
    })
    Util.corner(field)
    Util.new("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, field)
    local key = { Root = field, Enabled = true, Persist = false }
    local focused = false
    local function paintField()
        if self.Dead then
            return
        end
        field.BorderColor3 = focused and Theme.Accent or Theme.Outline
        field.TextColor3 = key.Enabled and Theme.Text or Theme.Muted
        field.TextEditable = key.Enabled
    end
    function key:SetEnabled(value)
        self.Enabled = value == true
        if not self.Enabled then
            field:ReleaseFocus()
        end
        paintField()
        return self
    end
    function key:SetSilent(value)
        if not self.Dialog.Dead then
            self.Root.Text = tostring(value or ""):sub(1, 256)
        end
        return self
    end
    function key:Get()
        return self.Root.Text
    end
    key.Dialog = self
    self.Key = Util.protect(key, { "SetEnabled", "SetSilent", "Get" })
    self.Scope:Connect(field.Focused, function()
        focused = true
        paintField()
    end)
    self.Scope:Connect(field.FocusLost, function()
        focused = false
        paintField()
    end)
    self.Scope:Connect(field:GetPropertyChangedSignal("Text"), function()
        if #field.Text > 256 then
            field.Text = field.Text:sub(1, 256)
        end
    end)
    table.insert(self.Painters, paintField)
    paintField()
    self.RedeemButton = button(self, "Redeem", UDim2.fromOffset(16, 64), true)
    self.CloseButton = button(self, "Close", UDim2.new(0.5, 4, 0, 64), false)
    self.Status = Util.label(self.Root, "", {
        Name = "Status",
        Position = UDim2.fromOffset(16, 104),
        Size = UDim2.new(1, -32, 0, 36),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        TextWrapped = true,
        Visible = false,
    })
    self.Scope:Connect(self.CloseButton.Root.Activated, function()
        self:Destroy()
    end)
    self.Scope:Connect(UserInputService.InputBegan, function(input)
        if self.Open and input.KeyCode == Enum.KeyCode.Escape then
            self:Destroy()
        end
    end)
    self.Scope:Connect(self.Screen.Destroying, function()
        self:Destroy()
    end)
    self.Scope:Connect(self.Screen:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:Fit()
    end)
    self.ThemeListener = Theme.onChanged(function()
        for _, paint in ipairs(self.Painters) do
            paint()
        end
    end)
    local mounted, message = pcall(Mount.core, self.Screen, true)
    if not mounted then
        self:Destroy()
        error(message, 0)
    end
    self:Fit()
    Cursor.set(self, true)
    return self
end

function Dialog:Fit()
    if not self.Dead then
        self.Size =
            Vector2.new(math.min(360, math.max(0, self.Screen.AbsoluteSize.X - 32)), self.Status.Visible and 152 or 112)
        self.Root.Size = UDim2.fromOffset(self.Size.X, self.Size.Y)
    end
end

function Dialog:SetStatus(text)
    if not self.Dead then
        self.Status.Text = tostring(text or "")
        self.Status.Visible = self.Status.Text ~= "" and self.Status.Text ~= "Enter key."
        self:Fit()
    end
end

function Dialog:SetVisible(value)
    if not self.Dead then
        self.Open = value == true
        self.Root.Visible = self.Open
        if not self.Open then
            self.Key.Root:ReleaseFocus()
        end
        Cursor.set(self, self.Open)
    end
end

function Dialog:Dispatch(callback, ...)
    if callback and not self.Dead then
        local ok, message = pcall(callback, ...)
        if not ok then
            self:SetStatus("Callback error")
            Util.warn(message)
        end
    end
end

function Dialog:OnDestroy(callback)
    assert(type(callback) == "function", "OnDestroy requires a function")
    if self.Dead then
        callback()
    else
        table.insert(self.Cleanup, callback)
    end
    return self
end

function Dialog:Destroy()
    if self.Dead then
        return
    end
    self.Dead, self.Open = true, false
    self.Screen.Enabled = false
    self.Key.Root:ReleaseFocus()
    Cursor.set(self, false)
    if self.ThemeListener then
        self.ThemeListener()
        self.ThemeListener = nil
    end
    self.Scope:Destroy()
    self.Screen:Destroy()
    for _, callback in ipairs(self.Cleanup) do
        local ok, message = pcall(callback)
        if not ok then
            Util.warn("Cleanup error: " .. tostring(message))
        end
    end
    table.clear(self.Cleanup)
    table.clear(self.Painters)
end

Util.protect(Dialog, { "Fit", "SetStatus", "SetVisible", "Dispatch", "OnDestroy", "Destroy" })
return Dialog

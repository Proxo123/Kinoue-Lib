local UserInputService = game:GetService("UserInputService")

local Model = require(script.Parent.Parent.internal.Model)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local Control = {}

function Control.row(group, height)
    return Util.frame(group.Container, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or Theme.RowHeight),
    })
end

local function describe(control, value)
    local notify = control.Notify
    if type(notify) == "function" then
        return notify(value)
    end
    if type(notify) == "string" then
        return notify
    end
    local name = control.DisplayName
    if type(value) == "boolean" then
        return name .. (value and " enabled" or " disabled")
    end
    if typeof(value) == "EnumItem" then
        if value == Enum.KeyCode.Unknown then
            return name .. " unbound"
        end
        return name .. " bound to " .. value.Name
    end
    if typeof(value) == "Color3" then
        return name .. " set to #" .. value:ToHex()
    end
    if type(value) == "number" then
        return name .. ": " .. string.format("%g", value)
    end
    if value == nil then
        return name
    end
    return name .. ": " .. tostring(value)
end

function Control.notify(window, control, value)
    if not control.Notify or window.SuppressNotify then
        return
    end
    local ok, message = pcall(describe, control, value)
    if not ok then
        Util.warn("Notification failed: " .. tostring(message))
    elseif message then
        window:Notify({ Text = message })
    end
end

function Control.searchable(group, name, target)
    group.Window:AddSearchEntry({
        Kind = "Setting",
        Name = name,
        Group = group,
        Target = target,
    })
end

function Control.new(group, id, initial, normalize, callback, info)
    info = info or {}
    local window = group.Window
    local control

    local function wrap(fn)
        return function(value)
            window:Dispatch(fn, value)
            window:ConfigChanged()
            Control.notify(window, control, value)
        end
    end

    control = Model.control(initial, normalize, wrap(callback))
    control.Enabled = true
    control.DisplayName = info.Name or info.Text or id
    control.Notify = info.Notify

    function control:SetCallback(fn)
        self.Callback = wrap(fn)
        return self
    end

    function control:SetEnabled(value)
        value = value == true
        if self.Enabled == value then
            return self
        end
        self.Enabled = value
        if not value and window.Capturing == self then
            window.Capturing = nil
        end
        if self.Root then
            self.Root.Active = self.Enabled
        end
        if self.Render then
            self.Render(self:Get())
        end
        return self
    end

    function control:SetVisible(value)
        self.Row.Visible = value == true
        return self
    end

    Util.protect(control, { "Set", "SetEnabled", "SetVisible" })
    window:Register(id, control)
    if not info.Inline and info.Searchable ~= false then
        Control.searchable(group, control.DisplayName, function()
            return control.Row
        end)
    end
    return control
end

function Control.closePopupWhenHidden(control, window)
    local setVisible = control.SetVisible
    function control:SetVisible(value)
        if not value and window.PopupOwner == self then
            window:ClosePopup()
        end
        return setVisible(self, value)
    end
end

function Control.dismissPopupOnOutsideInput(scope, window, popup, anchor)
    scope:Connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            window:ClosePopup()
            return
        end
        if not Util.isPointer(input) then
            return
        end
        if not Util.contains(popup, input.Position) and not Util.contains(anchor, input.Position) then
            window:ClosePopup()
        end
    end)
end

return Control

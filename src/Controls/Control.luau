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

function Control.new(group, id, initial, normalize, callback)
    local window = group.Window
    local control = Model.control(initial, normalize, function(value)
        window:Dispatch(callback, value)
        window:ConfigChanged()
    end)
    control.Enabled = true

    function control:SetCallback(fn)
        self.Callback = function(value)
            window:Dispatch(fn, value)
            window:ConfigChanged()
        end
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
    return window:Register(id, control)
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

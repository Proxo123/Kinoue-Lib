local UserInputService = game:GetService("UserInputService")

local Control = require(script.Parent.Control)
local Model = require(script.Parent.Parent.internal.Model)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local Slider = {}

function Slider.add(group, id, info)
    info = info or {}
    local window = group.Window
    local minimum, maximum, step = info.Min or 0, info.Max or 100, info.Step or 1
    assert(maximum > minimum and step > 0, "Slider requires Max > Min and Step > 0")

    local control = Control.new(group, id, info.Value or minimum, function(value)
        return Model.number(value, minimum, maximum, step)
    end, info.Callback, info)

    control.Row = Control.row(group, 35)
    Util.label(control.Row, info.Text or id, { Size = UDim2.new(0.65, 0, 0, 18) })
    local output = Util.label(control.Row, "", {
        Position = UDim2.new(0.65, 0, 0, 0),
        Size = UDim2.new(0.35, 0, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local track = Util.button(control.Row, "", {
        Position = UDim2.fromOffset(0, 18),
        Size = UDim2.new(1, 0, 0, 16),
    })
    control.Root = track
    local fill = Util.frame(track, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })
    local thumb = Util.frame(track, {
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 4, 1, 0),
        BackgroundColor3 = Theme.Color.Text,
    })

    local suffix = info.Suffix and " " .. info.Suffix or ""
    control.Render = function(value)
        local fraction = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(fraction, 1)
        thumb.Position = UDim2.fromScale(fraction, 0)
        output.Text = string.format(info.Format or "%g", value) .. suffix
        output.TextTransparency = control.Enabled and 0 or Theme.DisabledTransparency
    end

    local scope = window.Scope
    local dragging, moved, ended

    local function update(x)
        if not control.Enabled then
            return
        end
        local fraction = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        control:Set(minimum + fraction * (maximum - minimum))
    end

    local function stop()
        dragging = nil
        scope:Release(moved)
        scope:Release(ended)
        moved, ended = nil, nil
    end

    scope:Connect(track.InputBegan, function(input)
        if not control.Enabled or not Util.isPointer(input) then
            return
        end
        dragging = input
        if not moved then
            moved = scope:Connect(UserInputService.InputChanged, function(changed)
                if changed.UserInputType == Enum.UserInputType.MouseMovement or changed == dragging then
                    update(changed.Position.X)
                end
            end)
            ended = scope:Connect(UserInputService.InputEnded, function(released)
                if Util.sameInput(released, dragging) then
                    stop()
                end
            end)
        end
        update(input.Position.X)
    end)

    control.Render(control:Get())
    return control
end

return Slider

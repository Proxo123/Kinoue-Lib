local UserInputService = game:GetService("UserInputService")

local Control = require(script.Parent.Control)
local Model = require(script.Parent.Parent.internal.Model)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local ROW_HEIGHT = 44
local LABEL_HEIGHT = 18
local HIT_HEIGHT = 18
local TRACK_HEIGHT = 4
local KNOB_SIZE = 14

local Slider = {}

function Slider.add(group, id, info)
    info = info or {}
    local window = group.Window
    local minimum, maximum, step = info.Min or 0, info.Max or 100, info.Step or 1
    assert(maximum > minimum and step > 0, "Slider requires Max > Min and Step > 0")

    local control = Control.new(group, id, info.Value or minimum, function(value)
        return Model.number(value, minimum, maximum, step)
    end, info.Callback, info)

    control.Row = Control.row(group, ROW_HEIGHT)
    local label = Util.label(control.Row, info.Text or id, {
        Name = "Label",
        Size = UDim2.new(1, -96, 0, LABEL_HEIGHT),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local output = Util.label(control.Row, "", {
        Name = "Value",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(0, LABEL_HEIGHT),
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local hit = Util.button(control.Row, "", {
        Name = "Track",
        Position = UDim2.fromOffset(0, LABEL_HEIGHT + 4),
        Size = UDim2.new(1, 0, 0, HIT_HEIGHT),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    control.Root = hit
    local track = Util.frame(hit, {
        Name = "Rail",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
        BackgroundColor3 = Theme.Color.Hover,
    })
    Util.corner(track, TRACK_HEIGHT / 2)
    local fill = Util.frame(track, {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })
    Util.corner(fill, TRACK_HEIGHT / 2)
    local knob = Util.frame(hit, {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
        BackgroundColor3 = Color3.new(1, 1, 1),
    })
    Util.corner(knob, KNOB_SIZE / 2)

    local suffix = info.Suffix and " " .. info.Suffix or ""
    control.Render = function(value)
        local fraction = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(fraction, 1)
        knob.Position = UDim2.fromScale(fraction, 0.5)
        local text = string.format(info.Format or "%g", value) .. suffix
        output.Text = text
        output.Size = UDim2.fromOffset(Util.textWidth(text, Theme.SmallSize) + 2, LABEL_HEIGHT)
        local transparency = control.Enabled and 0 or Theme.DisabledTransparency
        output.TextTransparency = transparency
        label.TextTransparency = transparency
        knob.BackgroundTransparency = control.Enabled and 0 or 0.5
    end

    local scope = window.Scope
    local dragging, moved, ended

    local function update(x)
        if not control.Enabled then
            return
        end
        local fraction = math.clamp((x - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
        control:Set(minimum + fraction * (maximum - minimum))
    end

    local function stop()
        dragging = nil
        scope:Release(moved)
        scope:Release(ended)
        moved, ended = nil, nil
    end

    scope:Connect(hit.InputBegan, function(input)
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

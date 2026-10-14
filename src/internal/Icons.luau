local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local GEAR_TEETH = 8
local SPIN_DURATION = 0.2

local Icons = {}

local Icon = {}
Icon.__index = Icon

local function resolve(color)
    if Theme.isToken(color) then
        return Theme[color.Key]
    end
    return color
end

function Icon:SetColor(color)
    color = resolve(color)
    self.Color = color
    for _, part in ipairs(self.Fills) do
        part.BackgroundColor3 = color
    end
    for _, stroke in ipairs(self.Strokes) do
        stroke.Color = color
    end
    return self
end

function Icon:SetRotation(window, rotation, instant)
    window.Scope:Tween(self.Root, SPIN_DURATION, { Rotation = rotation }, instant or window.ReducedMotion)
    return self
end

local function newIcon(parent, size, props)
    local root = Util.frame(parent, {
        Name = props.Name or "Icon",
        AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
        Position = props.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size, size),
        Rotation = 0,
        BackgroundTransparency = 1,
        ZIndex = props.ZIndex,
    })
    return setmetatable({ Root = root, Fills = {}, Strokes = {} }, Icon)
end

function Icons.gear(parent, size, props)
    props = props or {}
    local icon = newIcon(parent, size, props)
    local ringSize = math.max(4, math.floor(size * 0.5))
    local thickness = math.max(1, math.floor(size / 8))
    local ring = Util.frame(icon.Root, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(ringSize, ringSize),
        BackgroundTransparency = 1,
        ZIndex = props.ZIndex,
    })
    Util.new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    table.insert(
        icon.Strokes,
        Util.new("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = thickness,
        }, ring)
    )

    local radius = size * 0.4
    local toothWidth = math.max(2, math.floor(size * 0.19))
    local toothHeight = math.max(2, math.floor(size * 0.25))
    for index = 0, GEAR_TEETH - 1 do
        local angle = index * (360 / GEAR_TEETH)
        local radians = math.rad(angle)
        table.insert(
            icon.Fills,
            Util.frame(icon.Root, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, math.sin(radians) * radius, 0.5, -math.cos(radians) * radius),
                Size = UDim2.fromOffset(toothWidth, toothHeight),
                Rotation = angle,
                ZIndex = props.ZIndex,
            })
        )
    end

    return icon:SetColor(props.Color or Theme.Muted)
end

function Icons.chevron(parent, size, props)
    props = props or {}
    local icon = newIcon(parent, size, props)
    local length = math.max(3, math.floor(size * 0.6))
    local thickness = math.max(1, math.floor(size / 5))
    local offset = length * math.cos(math.rad(45)) / 2
    for _, entry in ipairs({ { -offset, 45 }, { offset, -45 } }) do
        table.insert(
            icon.Fills,
            Util.frame(icon.Root, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, entry[1]),
                Size = UDim2.fromOffset(length, thickness),
                Rotation = entry[2],
                ZIndex = props.ZIndex,
            })
        )
    end
    return icon:SetColor(props.Color or Theme.Muted)
end

return Icons

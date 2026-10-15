local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local HEIGHT = 20
local PADDING = 6
local OFFSET = 4
local SCREEN_MARGIN = 8

local Tooltip = {}

local function build(window)
    local frame = Util.frame(window.Screen, {
        Name = "Tooltip",
        Size = UDim2.fromOffset(0, HEIGHT),
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ZIndex = 80,
        Visible = false,
    })
    local label = Util.label(frame, "", {
        Position = UDim2.fromOffset(PADDING, 0),
        Size = UDim2.new(1, -2 * PADDING, 1, 0),
        TextSize = Theme.SmallSize,
        ZIndex = 81,
    })
    window.TooltipFrame = frame
    window.TooltipLabel = label
    return frame
end

function Tooltip.show(window, text, anchor)
    if window.Dead or not text or text == "" then
        return
    end
    local frame = window.TooltipFrame or build(window)
    local width = Util.textWidth(text, Theme.SmallSize) + 2 * PADDING
    window.TooltipLabel.Text = text
    frame.Size = UDim2.fromOffset(width, HEIGHT)

    local screen = window.Screen.AbsoluteSize
    local origin, size = anchor.AbsolutePosition, anchor.AbsoluteSize
    local x = origin.X + size.X - width
    local y = origin.Y + size.Y + OFFSET
    if y + HEIGHT > screen.Y - SCREEN_MARGIN then
        y = origin.Y - HEIGHT - OFFSET
    end
    frame.Position = UDim2.fromOffset(
        math.clamp(x, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.X - width - SCREEN_MARGIN)),
        math.clamp(y, SCREEN_MARGIN, math.max(SCREEN_MARGIN, screen.Y - HEIGHT - SCREEN_MARGIN))
    )
    frame.Visible = true
    window.TooltipOwner = anchor
end

function Tooltip.hide(window, anchor)
    if not window.TooltipFrame then
        return
    end
    if anchor == nil or window.TooltipOwner == anchor then
        window.TooltipFrame.Visible = false
        window.TooltipOwner = nil
    end
end

function Tooltip.bind(window, gui, getText)
    window.Scope:Connect(gui.MouseEnter, function()
        Tooltip.show(window, getText(), gui)
    end)
    window.Scope:Connect(gui.MouseLeave, function()
        Tooltip.hide(window, gui)
    end)
end

return Tooltip

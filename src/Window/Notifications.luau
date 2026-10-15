local Icons = require(script.Parent.Parent.internal.Icons)
local Mount = require(script.Parent.Parent.internal.Mount)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local WIDTH = 280
local PADDING = 12
local ICON_SIZE = 26
local TEXT_LEFT = PADDING + ICON_SIZE + 10
local CLOSE_SIZE = 22
local SUBTITLE_HEIGHT = 16
local TIMER_HEIGHT = 2
local TIMER_SPACE = 8
local SCREEN_MARGIN = 14
local GAP = 8
local MAX_VISIBLE = 5
local DEFAULT_DURATION = 4
local MIN_DURATION = 0.5
local ENTER_DURATION = 0.24
local EXIT_DURATION = 0.18
local OFFSCREEN = WIDTH + SCREEN_MARGIN * 2

local Notifications = {}

local function ensureScreen(window)
    if window.NotificationScreen then
        return window.NotificationHolder
    end
    local screen = Util.new("ScreenGui", {
        Name = window.Screen.Name .. "Notifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = window.Screen.DisplayOrder + 1,
    })
    Mount.core(screen, false)
    local holder = Util.frame(screen, {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -SCREEN_MARGIN, 1, -SCREEN_MARGIN),
        Size = UDim2.new(0, WIDTH, 1, -2 * SCREEN_MARGIN),
        BackgroundTransparency = 1,
    })
    local list = Util.list(holder, false, GAP)
    list.VerticalAlignment = Enum.VerticalAlignment.Bottom
    window.NotificationScreen = screen
    window.NotificationHolder = holder
    window.Toasts = {}
    return holder
end

local function parse(window, options)
    if type(options) ~= "table" then
        options = { Text = options }
    end
    local duration = tonumber(options.Duration) or DEFAULT_DURATION
    return {
        Title = tostring(options.Title or window.Name),
        Text = options.Text ~= nil and tostring(options.Text) or "",
        Duration = math.max(MIN_DURATION, duration),
    }
end

local function release(window, toast)
    for _, object in ipairs({ toast.Card, toast.Slot, toast.Timer }) do
        local tween = window.Scope.Tweens[object]
        if tween then
            tween:Cancel()
            window.Scope.Tweens[object] = nil
        end
    end
    if toast.Slot.Parent then
        toast.Slot:Destroy()
    end
end

local function dismiss(window, toast)
    if toast.Closed then
        return
    end
    toast.Closed = true
    toast.Scope:Destroy()
    local index = table.find(window.Toasts, toast)
    if index then
        table.remove(window.Toasts, index)
    end

    if window.ReducedMotion or window.Dead then
        release(window, toast)
        return
    end
    window.Scope:Tween(toast.Card, EXIT_DURATION, { Position = UDim2.fromOffset(OFFSCREEN, 0) }, false)
    window.Scope:Tween(toast.Slot, EXIT_DURATION, { Size = UDim2.fromOffset(WIDTH, 0) }, false)
    task.delay(EXIT_DURATION, function()
        release(window, toast)
    end)
end

local function build(window, holder, message)
    local hasText = message.Text ~= ""
    local headline = hasText and message.Text or message.Title
    local textWidth = WIDTH - TEXT_LEFT - CLOSE_SIZE - PADDING
    local headlineHeight =
        math.max(16, math.ceil(Util.textSize(headline, Theme.TextSize, textWidth, Theme.FontMedium).Y))
    local blockHeight = headlineHeight + (hasText and SUBTITLE_HEIGHT + 2 or 0)
    local height = PADDING + math.max(ICON_SIZE, blockHeight) + PADDING + TIMER_SPACE

    local slot = Util.frame(holder, {
        Name = "Slot",
        Size = UDim2.fromOffset(WIDTH, 0),
        BackgroundTransparency = 1,
    })
    local card = Util.frame(slot, {
        Name = "Notification",
        Position = UDim2.fromOffset(OFFSCREEN, 0),
        Size = UDim2.fromOffset(WIDTH, height),
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
    })
    Util.corner(card, Theme.WindowRadius)

    local badge = Util.frame(card, {
        Name = "Badge",
        Position = UDim2.fromOffset(PADDING, PADDING),
        Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
        BackgroundColor3 = Theme.Color.Accent,
        BackgroundTransparency = 0.75,
    })
    Util.corner(badge, ICON_SIZE / 2)
    local icon = Icons.check(badge, 13)

    local body = Util.label(card, headline, {
        Name = "Message",
        Position = UDim2.fromOffset(TEXT_LEFT, PADDING),
        Size = UDim2.new(0, textWidth, 0, headlineHeight),
        Font = Theme.FontMedium,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
    })
    local title = Util.label(card, message.Title, {
        Name = "Title",
        Position = UDim2.fromOffset(TEXT_LEFT, PADDING + headlineHeight + 2),
        Size = UDim2.new(0, textWidth, 0, SUBTITLE_HEIGHT),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = hasText,
    })
    local close = Util.button(card, "×", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
        BackgroundColor3 = Theme.Color.Input,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.TitleSize + 2,
    })
    Util.corner(close, Theme.Radius - 1)
    local track = Util.frame(card, {
        Name = "Timer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, PADDING, 1, -6),
        Size = UDim2.new(1, -2 * PADDING, 0, TIMER_HEIGHT),
        BackgroundColor3 = Theme.Color.Hover,
    })
    Util.corner(track, 1)
    local timer = Util.frame(track, {
        Name = "Fill",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })
    Util.corner(timer, 1)

    local toast = {
        Slot = slot,
        Card = card,
        Title = title,
        Message = body,
        Icon = icon,
        CloseButton = close,
        Timer = timer,
        Height = height,
        Duration = message.Duration,
        Closed = false,
        Scope = Util.scope(),
    }
    Util.hover(toast.Scope, close, function(hovered)
        close.BackgroundTransparency = hovered and 0 or 1
    end)
    return toast
end

function Notifications.show(window, options)
    if window.Dead or window.NotificationsEnabled == false then
        return nil
    end
    local message = parse(window, options)
    local holder = ensureScreen(window)
    while #window.Toasts >= MAX_VISIBLE do
        dismiss(window, window.Toasts[1])
    end

    local toast = build(window, holder, message)
    table.insert(window.Toasts, toast)

    local reduced = window.ReducedMotion
    window.Scope:Tween(toast.Slot, ENTER_DURATION, { Size = UDim2.fromOffset(WIDTH, toast.Height) }, reduced)
    window.Scope:Tween(toast.Card, ENTER_DURATION, { Position = UDim2.fromOffset(0, 0) }, reduced)
    window.Scope:Tween(toast.Timer, toast.Duration, { Size = UDim2.fromScale(0, 1) }, false, Enum.EasingStyle.Linear)

    toast.Scope:Connect(toast.CloseButton.Activated, function()
        dismiss(window, toast)
    end)
    task.delay(toast.Duration, function()
        if not window.Dead then
            dismiss(window, toast)
        end
    end)

    function toast.Close()
        dismiss(window, toast)
    end
    return toast
end

function Notifications.clear(window)
    if not window.Toasts then
        return
    end
    for _, toast in ipairs(table.clone(window.Toasts)) do
        toast.Closed = true
        toast.Scope:Destroy()
    end
    table.clear(window.Toasts)
end

function Notifications.destroy(window)
    Notifications.clear(window)
    if window.NotificationScreen then
        window.NotificationScreen:Destroy()
        window.NotificationScreen = nil
        window.NotificationHolder = nil
    end
end

return Notifications

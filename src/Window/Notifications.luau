local Mount = require(script.Parent.Parent.internal.Mount)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local WIDTH = 260
local PADDING = 10
local TITLE_HEIGHT = 18
local TIMER_HEIGHT = 2
local CLOSE_SIZE = 16
local SCREEN_MARGIN = 14
local GAP = 6
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
    local textWidth = WIDTH - 2 * PADDING
    local textHeight = 0
    if message.Text ~= "" then
        textHeight = math.ceil(Util.textSize(message.Text, Theme.SmallSize, textWidth).Y)
    end
    local height = PADDING + TITLE_HEIGHT + (textHeight > 0 and textHeight + 2 or 0) + PADDING + TIMER_HEIGHT

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
    Util.frame(card, {
        Name = "Accent",
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = Theme.Color.Accent,
    })
    local title = Util.label(card, message.Title, {
        Name = "Title",
        Position = UDim2.fromOffset(PADDING, PADDING - 2),
        Size = UDim2.new(1, -(2 * PADDING + CLOSE_SIZE), 0, TITLE_HEIGHT),
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local body = Util.label(card, message.Text, {
        Name = "Message",
        Position = UDim2.fromOffset(PADDING, PADDING + TITLE_HEIGHT),
        Size = UDim2.new(1, -2 * PADDING, 0, textHeight),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        Visible = textHeight > 0,
    })
    local close = Util.button(card, "×", {
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -4, 0, 4),
        Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.TextSize,
    })
    local track = Util.frame(card, {
        Name = "Timer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, TIMER_HEIGHT),
        BackgroundColor3 = Theme.Color.Hover,
    })
    local timer = Util.frame(track, {
        Name = "Fill",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })

    return {
        Slot = slot,
        Card = card,
        Title = title,
        Message = body,
        CloseButton = close,
        Timer = timer,
        Height = height,
        Duration = message.Duration,
        Closed = false,
        Scope = Util.scope(),
    }
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

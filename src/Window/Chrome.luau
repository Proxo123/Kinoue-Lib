local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local HEADER_HEIGHT = 32
local TAB_BAR_HEIGHT = 30
local FOOTER_HEIGHT = 22
local ACCENT_WIDTH = 364
local ACCENT_FRAME_RATE = 30
local ACCENT_CYCLE_FRAMES = 150
local SETTINGS_BUTTON_SIZE = 20
local GEAR_TEETH = 8

local Chrome = {}

local function buildRoot(window, options)
    local position = options.Position or UDim2.fromScale(0.5, 0.5)
    window.Root = Util.new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.new(
            position.X.Scale,
            position.X.Offset - window.Size.X / 2,
            position.Y.Scale,
            position.Y.Offset - window.Size.Y / 2
        ),
        Size = UDim2.fromOffset(window.Size.X, window.Size.Y),
        BackgroundColor3 = Theme.Color.Background,
        BorderColor3 = Theme.Color.Outline,
        BorderSizePixel = 1,
        ClipsDescendants = true,
    }, window.Screen)
    window.RestPosition = window.Root.Position
end

local function buildHeader(window, options)
    window.Header = Util.frame(window.Root, {
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundColor3 = Theme.Color.Panel,
        Active = true,
    })
    Util.label(window.Header, options.Name or "Kinoue", {
        Position = UDim2.fromOffset(8, 0),
        Size = UDim2.new(1, -(SETTINGS_BUTTON_SIZE + 16), 1, 0),
        TextSize = Theme.TextSize + 1,
    })
    Util.frame(window.Header, {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Color.Outline,
    })
end

local function buildSettingsButton(window)
    local button = Util.button(window.Header, "", {
        Name = "SettingsButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(SETTINGS_BUTTON_SIZE, SETTINGS_BUTTON_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local parts = {}
    local center = UDim2.fromScale(0.5, 0.5)
    local disc = Util.frame(button, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = center,
        Size = UDim2.fromOffset(12, 12),
    })
    Util.new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
    table.insert(parts, disc)
    for index = 0, GEAR_TEETH - 1 do
        local angle = index * (360 / GEAR_TEETH)
        local radians = math.rad(angle)
        local tooth = Util.frame(button, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, math.sin(radians) * 6.5, 0.5, -math.cos(radians) * 6.5),
            Size = UDim2.fromOffset(3, 4),
            Rotation = angle,
        })
        table.insert(parts, tooth)
    end
    local hole = Util.frame(button, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = center,
        Size = UDim2.fromOffset(5, 5),
        BackgroundColor3 = Theme.Color.Panel,
        ZIndex = 2,
    })
    Util.new("UICorner", { CornerRadius = UDim.new(1, 0) }, hole)

    window.SettingsButton = button
    window.SettingsIcon = parts
end

function Chrome.paintSettingsButton(window)
    local color = window.SettingsOpen and Theme.Accent or Theme.Muted
    for _, part in ipairs(window.SettingsIcon) do
        part.BackgroundColor3 = color
    end
end

local function buildAccent(window)
    window.Accent = Util.frame(window.Root, {
        Name = "RainbowAccent",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT - 1),
        Size = UDim2.fromOffset(ACCENT_WIDTH, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 4,
    })
    local gradient = Util.new("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.12, 0),
            NumberSequenceKeypoint.new(0.88, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, window.Accent)

    local keypoints, lastFrame = {}, -1
    local function animate()
        if not window.RainbowAccent then
            gradient.Color = ColorSequence.new(Theme.Accent)
            return
        end
        local frame = window.ReducedMotion and 0 or math.floor(os.clock() * ACCENT_FRAME_RATE)
        if frame == lastFrame then
            return
        end
        lastFrame = frame
        local phase = window.ReducedMotion and 0 or (frame / ACCENT_CYCLE_FRAMES) % 1
        for index = 0, 6 do
            local hue = (index / 6 + phase) % 1
            keypoints[index + 1] = ColorSequenceKeypoint.new(index / 6, Color3.fromHSV(hue, 0.56, 0.93))
        end
        gradient.Color = ColorSequence.new(keypoints)
    end

    window.UpdateAccent = function()
        if window.AccentScope then
            window.AccentScope:Destroy()
            window.AccentScope = nil
        end
        if not window.Open then
            return
        end
        lastFrame = -1
        animate()
        if window.RainbowAccent and not window.ReducedMotion then
            window.AccentScope = Util.scope()
            window.AccentScope:Connect(RunService.RenderStepped, animate)
        end
    end
    window.UpdateAccent()
end

local function buildBody(window)
    window.Tabs = Util.new("ScrollingFrame", {
        Position = UDim2.fromOffset(0, HEADER_HEIGHT),
        Size = UDim2.new(1, 0, 0, TAB_BAR_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Color.Background,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.X,
    }, window.Root)
    Util.padding(window.Tabs, 4)
    Util.list(window.Tabs, true, 0)

    window.Body = Util.frame(window.Root, {
        Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_BAR_HEIGHT),
        Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_BAR_HEIGHT + FOOTER_HEIGHT)),
    })
end

local function buildFooter(window, options)
    window.Footer = Util.frame(window.Root, {
        Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT),
        Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
        BackgroundColor3 = Theme.Color.Panel,
    })
    Util.frame(window.Footer, {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Color.Outline,
    })
    window.Status = Util.label(window.Footer, "Ready", {
        Position = UDim2.fromOffset(7, 0),
        Size = UDim2.new(0.7, -7, 1, 0),
        TextSize = Theme.SmallSize,
    })
    Util.label(window.Footer, options.Footer or "", {
        Position = UDim2.new(0.7, 0, 0, 0),
        Size = UDim2.new(0.3, -7, 1, 0),
        TextSize = Theme.SmallSize,
        TextColor3 = Theme.Color.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
end

local function buildResizeHandle(window)
    window.ResizeHandle = Util.button(window.Root, "", {
        Name = "ResizeHandle",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 100,
        Visible = window.Resizable,
    })
end

function Chrome.build(window, options)
    buildRoot(window, options)
    buildHeader(window, options)
    buildSettingsButton(window)
    Chrome.paintSettingsButton(window)
    buildAccent(window)
    buildBody(window)
    buildFooter(window, options)
    buildResizeHandle(window)
end

function Chrome.layoutAccent(window)
    local width = window.Root.AbsoluteSize.X
    local accentWidth = math.floor(math.min(ACCENT_WIDTH, width * 0.546) / 2) * 2
    window.Accent.Size = UDim2.fromOffset(accentWidth, 1)
    window.Accent.Position = UDim2.new(0.5, -accentWidth / 2, 0, HEADER_HEIGHT - 1)
end

return Chrome

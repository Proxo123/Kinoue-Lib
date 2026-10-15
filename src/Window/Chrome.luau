local RunService = game:GetService("RunService")

local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local HEADER_HEIGHT = 32
local TAB_BAR_HEIGHT = 30
local FOOTER_HEIGHT = 22
local ACCENT_WIDTH = 364
local ACCENT_FRAME_RATE = 30
local ACCENT_CYCLE_FRAMES = 150
local SETTINGS_BUTTON_SIZE = 20
local SETTINGS_ICON_SIZE = 16
local HEADER_BUTTON_MARGIN = 6
local HEADER_BUTTON_GAP = 4
local VERSION_TEXT_SIZE = 11

local Background = require(script.Parent.Background)

local Chrome = {}
Chrome.HEADER_HEIGHT = HEADER_HEIGHT
Chrome.SEARCH_OFFSET = HEADER_BUTTON_MARGIN + SETTINGS_BUTTON_SIZE + HEADER_BUTTON_GAP

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
        Size = UDim2.new(1, -(Chrome.SEARCH_OFFSET + SETTINGS_BUTTON_SIZE + 8), 1, 0),
        TextSize = Theme.TextSize + 1,
    })
    Util.frame(window.Header, {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Color.Outline,
    })
end

local function buildSettingsButton(window)
    window.SettingsButton = Util.button(window.Header, "", {
        Name = "SettingsButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -HEADER_BUTTON_MARGIN, 0.5, 0),
        Size = UDim2.fromOffset(SETTINGS_BUTTON_SIZE, SETTINGS_BUTTON_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    window.SettingsIcon = Icons.gear(window.SettingsButton, SETTINGS_ICON_SIZE)
end

function Chrome.paintSettingsButton(window)
    window.SettingsIcon:SetColor(window.SettingsOpen and Theme.Accent or Theme.Muted)
    window.SettingsIcon:SetRotation(window, window.SettingsOpen and 90 or 0)
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
    local reserved = 7
    if window.Version then
        local text = "v" .. window.Version
        local width = Util.textWidth(text, VERSION_TEXT_SIZE)
        window.VersionLabel = Util.label(window.Footer, text, {
            Name = "Version",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -7, 0, 0),
            Size = UDim2.new(0, width, 1, 0),
            TextSize = VERSION_TEXT_SIZE,
            TextColor3 = Theme.Color.Muted,
            TextTransparency = 0.25,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        reserved += width + 8
    end
    Util.label(window.Footer, options.Footer or "", {
        Position = UDim2.new(0.7, 0, 0, 0),
        Size = UDim2.new(0.3, -reserved, 1, 0),
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
    Background.surface(window, window.Header)
    Background.surface(window, window.Tabs)
    Background.surface(window, window.Footer)
    buildResizeHandle(window)
end

function Chrome.layoutAccent(window)
    local width = window.Root.AbsoluteSize.X
    local accentWidth = math.floor(math.min(ACCENT_WIDTH, width * 0.546) / 2) * 2
    window.Accent.Size = UDim2.fromOffset(accentWidth, 1)
    window.Accent.Position = UDim2.new(0.5, -accentWidth / 2, 0, HEADER_HEIGHT - 1)
end

return Chrome

local RunService = game:GetService("RunService")

local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local HEADER_HEIGHT = 52
local TAB_BAR_HEIGHT = 44
local FOOTER_HEIGHT = 30
local EDGE = 18
local ACCENT_WIDTH = 364
local ACCENT_FRAME_RATE = 30
local ACCENT_CYCLE_FRAMES = 150
local SETTINGS_BUTTON_SIZE = 30
local SETTINGS_ICON_SIZE = 16
local HEADER_BUTTON_MARGIN = 10
local HEADER_BUTTON_GAP = 6
local SEARCH_WIDTH = 150
local VERSION_TEXT_SIZE = 11
local TAB_STRIP_PADDING = 3
local TAB_HEIGHT = 28
local TAB_STRIP_HEIGHT = TAB_HEIGHT + 2 * TAB_STRIP_PADDING
local TITLE_GAP = 8
local TABS_GAP = 16

local Background = require(script.Parent.Background)

local Chrome = {}
Chrome.HEADER_HEIGHT = HEADER_HEIGHT
Chrome.SEARCH_OFFSET = HEADER_BUTTON_MARGIN + SETTINGS_BUTTON_SIZE + HEADER_BUTTON_GAP
Chrome.SEARCH_WIDTH = SEARCH_WIDTH

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
    Util.corner(window.Root, Theme.WindowRadius)
    window.RestPosition = window.Root.Position
end

local function buildHeader(window, options)
    window.Header = Util.frame(window.Root, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BackgroundTransparency = 1,
        Active = true,
    })
    local title = options.Name or "Kinoue"
    local reserved = Chrome.SEARCH_OFFSET + SEARCH_WIDTH + EDGE
    local titleWidth = Util.textWidth(title, Theme.TitleSize, Theme.FontBold)
    window.TitleLabel = Util.label(window.Header, title, {
        Name = "Title",
        Position = UDim2.fromOffset(EDGE, 0),
        Size = UDim2.new(0, titleWidth, 1, 0),
        Font = Theme.FontBold,
        TextSize = Theme.TitleSize,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local subtitle = options.Subtitle or options.Footer or ""
    local subtitleWidth = subtitle ~= "" and Util.textWidth(subtitle, Theme.SmallSize - 1, Theme.FontMedium) or 0
    window.SubtitleLabel = Util.label(window.Header, subtitle, {
        Name = "Subtitle",
        Position = UDim2.fromOffset(EDGE + titleWidth + TITLE_GAP, 1),
        Size = UDim2.fromOffset(subtitleWidth, HEADER_HEIGHT),
        Font = Theme.FontMedium,
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    window.TabsLeft = EDGE + titleWidth + (subtitleWidth > 0 and TITLE_GAP + subtitleWidth or 0) + TABS_GAP
    window.TabsReserved = reserved
    Util.frame(window.Header, {
        Name = "Divider",
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
        BackgroundColor3 = Theme.Color.Input,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    Util.corner(window.SettingsButton, Theme.Radius + 1)
    window.SettingsIcon = Icons.gear(window.SettingsButton, SETTINGS_ICON_SIZE)
    Util.hover(window.Scope, window.SettingsButton, function(hovered)
        window.SettingsButton.BackgroundTransparency = hovered and 0 or 1
    end)
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
        window.Accent.Visible = window.RainbowAccent
        animate()
        if window.RainbowAccent and not window.ReducedMotion then
            window.AccentScope = Util.scope()
            window.AccentScope:Connect(RunService.RenderStepped, animate)
        end
    end
    window.UpdateAccent()
end

local function buildTabs(window)
    window.Tabs = Util.new("ScrollingFrame", {
        Name = "Tabs",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT),
        Size = UDim2.new(1, 0, 0, TAB_STRIP_HEIGHT),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.X,
    }, window.Root)
    window.TabStrip = Util.frame(window.Tabs, {
        Name = "TabStrip",
        Size = UDim2.fromOffset(0, TAB_STRIP_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        Visible = false,
    })
    Util.corner(window.TabStrip, Theme.Radius + 2)
    Util.padding(window.TabStrip, TAB_STRIP_PADDING)
    window.TabPill = Util.frame(window.TabStrip, {
        Name = "Pill",
        Size = UDim2.fromOffset(0, TAB_HEIGHT),
        BackgroundColor3 = Theme.Color.Selected,
        Visible = false,
    })
    Util.corner(window.TabPill, Theme.Radius - 1)
    window.TabButtons = Util.frame(window.TabStrip, {
        Name = "Buttons",
        Size = UDim2.fromOffset(0, TAB_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        ZIndex = 2,
    })
    Util.list(window.TabButtons, true, 0)
    window.Scope:Connect(window.TabStrip:GetPropertyChangedSignal("AbsoluteSize"), function()
        Chrome.layoutTabs(window)
    end)
end

function Chrome.layoutTabs(window)
    local available = window.Root.AbsoluteSize.X - window.TabsLeft - window.TabsReserved
    local stripWidth = window.TabStrip.Visible and window.TabStrip.AbsoluteSize.X or 0
    local inHeader = stripWidth <= available
    local bodyTop
    if inHeader then
        window.Tabs.Position = UDim2.fromOffset(window.TabsLeft, (HEADER_HEIGHT - TAB_STRIP_HEIGHT) / 2)
        window.Tabs.Size = UDim2.fromOffset(math.max(0, available), TAB_STRIP_HEIGHT)
        bodyTop = HEADER_HEIGHT
    else
        window.Tabs.Position = UDim2.fromOffset(EDGE, HEADER_HEIGHT + (TAB_BAR_HEIGHT - TAB_STRIP_HEIGHT) / 2)
        window.Tabs.Size = UDim2.new(1, -2 * EDGE, 0, TAB_STRIP_HEIGHT)
        bodyTop = HEADER_HEIGHT + TAB_BAR_HEIGHT
    end
    window.TabsInHeader = inHeader
    if window.Body then
        window.Body.Position = UDim2.fromOffset(0, bodyTop)
        window.Body.Size = UDim2.new(1, 0, 1, -(bodyTop + FOOTER_HEIGHT))
    end
end

local function buildBody(window)
    window.Body = Util.frame(window.Root, {
        Name = "Body",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT + TAB_BAR_HEIGHT),
        Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + TAB_BAR_HEIGHT + FOOTER_HEIGHT)),
        BackgroundTransparency = 1,
    })
end

local function buildFooter(window)
    window.Footer = Util.frame(window.Root, {
        Name = "Footer",
        Position = UDim2.new(0, 0, 1, -FOOTER_HEIGHT),
        Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
        BackgroundTransparency = 1,
    })
    Util.frame(window.Footer, {
        Name = "Divider",
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Color.Outline,
    })
    window.Status = Util.label(window.Footer, "Ready", {
        Name = "Status",
        Position = UDim2.fromOffset(EDGE, 0),
        Size = UDim2.new(0.7, -EDGE, 1, 0),
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    if window.Version then
        local text = "v" .. window.Version
        window.VersionLabel = Util.label(window.Footer, text, {
            Name = "Version",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -EDGE, 0, 0),
            Size = UDim2.new(0, Util.textWidth(text, VERSION_TEXT_SIZE), 1, 0),
            TextSize = VERSION_TEXT_SIZE,
            TextColor3 = Theme.Color.Muted,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
    end
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
    buildTabs(window)
    buildBody(window)
    buildFooter(window)
    Background.surface(window, window.TabStrip)
    buildResizeHandle(window)
    Chrome.layoutTabs(window)
end

function Chrome.paintTabs(window, instant)
    local active = window.ActivePage
    local pill = window.TabPill
    local offset, width = 0, nil
    for _, page in ipairs(window.Pages) do
        local size = page.Button.Size.X.Offset
        if page == active then
            width = size
            break
        end
        offset += size
    end
    if not width then
        pill.Visible = false
        return
    end
    local goal = {
        Position = UDim2.fromOffset(offset, 0),
        Size = UDim2.fromOffset(width, TAB_HEIGHT),
    }
    local reduced = instant or window.ReducedMotion or not pill.Visible
    pill.Visible = true
    window.Scope:Tween(pill, 0.26, goal, reduced, Enum.EasingStyle.Quint)
end

function Chrome.layoutAccent(window)
    local width = window.Root.AbsoluteSize.X
    local accentWidth = math.floor(math.min(ACCENT_WIDTH, width * 0.546) / 2) * 2
    window.Accent.Size = UDim2.fromOffset(accentWidth, 1)
    window.Accent.Position = UDim2.new(0.5, -accentWidth / 2, 0, HEADER_HEIGHT - 1)
end

return Chrome

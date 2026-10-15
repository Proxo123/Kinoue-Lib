local Group = require(script.Parent.Parent.Controls)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local NARROW_WIDTH = 520
local EDGE = 14
local TITLE_HEIGHT = 28
local TAB_HEIGHT = 24
local TAB_TEXT_SIZE = 12
local SUBBAR_HEIGHT = 26
local GROUP_HEADER_HEIGHT = 30

local Page = {}
Page.__index = Page

local Subpage = {}
Subpage.__index = Subpage

local function build(window, name)
    local self = setmetatable({ Window = window, Name = name, Groups = {}, Subpages = {} }, Page)
    self.Frame = Util.frame(window.Body, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    })
    self.Title = Util.label(self.Frame, name, {
        Position = UDim2.fromOffset(EDGE, 0),
        Size = UDim2.new(0.65, -EDGE, 0, TITLE_HEIGHT),
        Font = Theme.FontBold,
        TextSize = Theme.TextSize,
    })
    self.Mode = Util.label(self.Frame, "", {
        Position = UDim2.new(0.65, 0, 0, 0),
        Size = UDim2.new(0.35, -EDGE, 0, TITLE_HEIGHT),
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize - 1,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    self.Scroll = Util.new("ScrollingFrame", {
        Position = UDim2.fromOffset(EDGE, TITLE_HEIGHT),
        Size = UDim2.new(1, -2 * EDGE, 1, -(TITLE_HEIGHT + 8)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Color.Outline,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, self.Frame)
    self.Left = Util.frame(self.Scroll, { BackgroundTransparency = 1 })
    self.Right = Util.frame(self.Scroll, { BackgroundTransparency = 1 })
    self.LeftList = Util.list(self.Left, false, Theme.Gap)
    self.RightList = Util.list(self.Right, false, Theme.Gap)

    local function relayout()
        self:Relayout()
    end
    window.Scope:Connect(self.LeftList:GetPropertyChangedSignal("AbsoluteContentSize"), relayout)
    window.Scope:Connect(self.RightList:GetPropertyChangedSignal("AbsoluteContentSize"), relayout)
    window.Scope:Connect(self.Scroll:GetPropertyChangedSignal("AbsoluteSize"), relayout)
    return self
end

function Page.hidden(window, name)
    local self = build(window, name)
    window:AddSearchEntry({ Kind = "Tab", Name = name, Page = self })
    return self
end

function Page.new(window, name)
    local self = build(window, name)
    self.Button = Util.button(window.TabStrip, name, {
        Name = "Tab",
        Size = UDim2.fromOffset(Util.textWidth(name, TAB_TEXT_SIZE, Theme.FontMedium) + 20, TAB_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Color.Selected,
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        TextSize = TAB_TEXT_SIZE,
        TextColor3 = Theme.Color.Muted,
    })
    Util.corner(self.Button, Theme.Radius - 1)
    self.Line = Util.frame(self.Button, {
        Name = "Indicator",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -2),
        Size = UDim2.fromOffset(12, 2),
        BackgroundColor3 = Theme.Color.Accent,
        Visible = false,
    })
    Util.corner(self.Line, 1)
    window.TabStrip.Visible = true
    window.Scope:Connect(self.Button.Activated, function()
        window:SelectTab(self)
    end)
    Util.hover(window.Scope, self.Button, function(hovered)
        if window.ActivePage ~= self then
            self.Button.TextColor3 = hovered and Theme.Text or Theme.Muted
        end
    end)

    table.insert(window.Pages, self)
    window:AddSearchEntry({ Kind = "Tab", Name = name, Page = self })
    if #window.Pages == 1 then
        window:SelectTab(self)
    end
    return self
end

function Page:Relayout()
    local available = math.floor(self.Scroll.AbsoluteSize.X)
    local narrow = self.Scroll.AbsoluteSize.X < NARROW_WIDTH
    local leftHeight = self.LeftList.AbsoluteContentSize.Y
    local rightHeight = self.RightList.AbsoluteContentSize.Y

    if narrow then
        self.Left.Size = UDim2.fromOffset(available, leftHeight)
        self.Right.Size = UDim2.fromOffset(available, rightHeight)
        self.Right.Position = UDim2.fromOffset(0, leftHeight + Theme.Gap)
        self.Scroll.CanvasSize = UDim2.fromOffset(0, leftHeight + rightHeight + Theme.Gap)
    else
        local leftWidth = math.floor((available - Theme.Gap) / 2)
        self.Left.Size = UDim2.fromOffset(leftWidth, leftHeight)
        self.Right.Size = UDim2.fromOffset(available - leftWidth - Theme.Gap, rightHeight)
        self.Right.Position = UDim2.fromOffset(leftWidth + Theme.Gap, 0)
        self.Scroll.CanvasSize = UDim2.fromOffset(0, math.max(leftHeight, rightHeight))
    end
end

function Page:SetTitle(text)
    self.Title.Text = text
end

function Page:SetMode(text)
    text = text or ""
    if self.Mode.Text ~= text then
        self.Mode.Text = text
    end
end

function Page:Select()
    self.Window:SelectTab(self)
end

function Page:AddGroupbox(title, side)
    local frame = Util.frame(side == "Right" and self.Right or self.Left, {
        Name = title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
    })
    Util.corner(frame, Theme.CardRadius)
    Util.label(frame, string.upper(title), {
        Name = "Header",
        Position = UDim2.fromOffset(Theme.Padding + 2, 0),
        Size = UDim2.new(1, -2 * (Theme.Padding + 2), 0, GROUP_HEADER_HEIGHT),
        Font = Theme.FontBold,
        TextSize = Theme.TinySize,
        TextColor3 = Theme.Color.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local container = Util.frame(frame, {
        Position = UDim2.fromOffset(Theme.Padding, GROUP_HEADER_HEIGHT),
        Size = UDim2.new(1, -2 * Theme.Padding, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(container, false, Theme.ControlGap)
    Util.padding(container, 0)
    Util.new("UIPadding", { PaddingBottom = UDim.new(0, Theme.Padding) }, frame)

    local group = Group.new(self.Window, container, self, frame)
    group.Title = title
    table.insert(self.Groups, group)
    self.Window:AddSearchEntry({
        Kind = "Group",
        Name = title,
        Group = group,
        Self = true,
        Target = function()
            return frame
        end,
    })
    return group
end

function Page:AddSubTab(title)
    if not self.Subbar then
        self.Subbar = Util.frame(self.Frame, {
            Name = "SubTabs",
            Position = UDim2.fromOffset(EDGE, TITLE_HEIGHT),
            Size = UDim2.new(1, -2 * EDGE, 0, SUBBAR_HEIGHT),
            BackgroundTransparency = 1,
        })
        Util.list(self.Subbar, true, 4)
        self.Scroll.Position = UDim2.fromOffset(EDGE, TITLE_HEIGHT + SUBBAR_HEIGHT + 6)
        self.Scroll.Size = UDim2.new(1, -2 * EDGE, 1, -(TITLE_HEIGHT + SUBBAR_HEIGHT + 14))
    end
    return Subpage.new(self, title)
end

function Subpage.new(page, title)
    local self = setmetatable({ Page = page, Groups = {}, Title = title }, Subpage)
    self.Button = Util.button(page.Subbar, title, {
        Name = "SubTab",
        Size = UDim2.fromOffset(Util.textWidth(title, TAB_TEXT_SIZE, Theme.FontMedium) + 18, TAB_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Color.Selected,
        BackgroundTransparency = 1,
        Font = Theme.FontMedium,
        TextSize = TAB_TEXT_SIZE,
        TextColor3 = Theme.Color.Muted,
    })
    Util.corner(self.Button, Theme.Radius - 1)
    table.insert(page.Subpages, self)
    page.Window:AddSearchEntry({ Kind = "Tab", Name = title, Subpage = self })
    page.Window.Scope:Connect(self.Button.Activated, function()
        self:Select()
    end)
    if #page.Subpages == 1 then
        self:Select()
        table.insert(page.Window.ThemeHooks, function()
            page:StyleSubtabs()
        end)
    end
    return self
end

function Page:StyleSubtabs()
    for _, item in ipairs(self.Subpages) do
        local active = item == self.ActiveSubpage
        item.Button.BackgroundTransparency = active and 0 or 1
        item.Button.TextColor3 = active and Theme.Text or Theme.Muted
    end
end

function Subpage:Select()
    local page = self.Page
    page.Window:ClosePopup()
    page.ActiveSubpage = self
    for _, item in ipairs(page.Subpages) do
        for _, group in ipairs(item.Groups) do
            group.Frame.Visible = item == self
        end
    end
    page:StyleSubtabs()
    page:Relayout()
end

function Subpage:AddGroupbox(name, side)
    local group = self.Page:AddGroupbox(name, side)
    group.Subpage = self
    table.insert(self.Groups, group)
    group.Frame.Visible = self.Page.ActiveSubpage == self
    return group
end

Util.protect(Page, { "SetTitle", "SetMode", "AddSubTab", "AddGroupbox", "Select" })
Util.protect(Subpage, { "Select", "AddGroupbox" })

return Page

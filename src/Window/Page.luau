local Group = require(script.Parent.Parent.Controls)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local NARROW_WIDTH = 520

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
        Position = UDim2.fromOffset(8, 1),
        Size = UDim2.new(0.65, -8, 0, 23),
    })
    self.Mode = Util.label(self.Frame, "", {
        Position = UDim2.new(0.65, 0, 0, 1),
        Size = UDim2.new(0.35, -8, 0, 23),
        TextColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    self.Scroll = Util.new("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 26),
        Size = UDim2.new(1, -16, 1, -32),
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
    return build(window, name)
end

function Page.new(window, name)
    local self = build(window, name)
    self.Button = Util.button(window.Tabs, name, {
        Size = UDim2.fromOffset(Util.textWidth(name) + 18, 24),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        TextColor3 = Theme.Color.Muted,
    })
    self.Line = Util.frame(self.Button, {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Color.Accent,
        Visible = false,
    })
    window.Scope:Connect(self.Button.Activated, function()
        window:SelectTab(self)
    end)

    table.insert(window.Pages, self)
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
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
    })
    local header = Util.frame(frame, {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundColor3 = Theme.Color.Panel,
    })
    Util.frame(header, {
        Size = UDim2.new(1, 0, 0, 2),
        BackgroundColor3 = Theme.Color.Accent,
    })
    Util.label(header, title, {
        Position = UDim2.fromOffset(6, 2),
        Size = UDim2.new(1, -12, 1, -2),
    })
    local container = Util.frame(frame, {
        Position = UDim2.fromOffset(Theme.Padding, 27),
        Size = UDim2.new(1, -2 * Theme.Padding, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    })
    Util.list(container, false, Theme.ControlGap)
    Util.padding(container, 0)
    Util.new("UIPadding", { PaddingBottom = UDim.new(0, Theme.Padding) }, frame)

    local group = Group.new(self.Window, container, self, frame)
    table.insert(self.Groups, group)
    return group
end

function Page:AddSubTab(title)
    if not self.Subbar then
        self.Subbar = Util.frame(self.Frame, {
            Position = UDim2.fromOffset(8, 25),
            Size = UDim2.new(1, -16, 0, 24),
            BackgroundTransparency = 1,
        })
        Util.list(self.Subbar, true, 3)
        self.Scroll.Position = UDim2.fromOffset(8, 54)
        self.Scroll.Size = UDim2.new(1, -16, 1, -60)
    end
    return Subpage.new(self, title)
end

function Subpage.new(page, title)
    local self = setmetatable({ Page = page, Groups = {} }, Subpage)
    self.Button = Util.button(page.Subbar, title, {
        Size = UDim2.fromOffset(Util.textWidth(title) + 16, 22),
    })
    table.insert(page.Subpages, self)
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
        item.Button.BorderColor3 = item == self.ActiveSubpage and Theme.Accent or Theme.Outline
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
    table.insert(self.Groups, group)
    group.Frame.Visible = self.Page.ActiveSubpage == self
    return group
end

Util.protect(Page, { "SetTitle", "SetMode", "AddSubTab", "AddGroupbox", "Select" })
Util.protect(Subpage, { "Select", "AddGroupbox" })

return Page

local UserInputService = game:GetService("UserInputService")

local Icons = require(script.Parent.Parent.internal.Icons)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local BUTTON_SIZE = 20
local ICON_SIZE = 14
local BOX_WIDTH = 200
local BOX_HEIGHT = 22
local BOX_GAP = 4
local RESULTS_WIDTH = 280
local RESULT_HEIGHT = 34
local MAX_RESULTS = 25
local MAX_VISIBLE = 7
local OPEN_DURATION = 0.16
local FLASH_DURATION = 0.9
local SCROLL_MARGIN = 8
local SEPARATOR = " > "

local Search = {}

local function nameOf(entry)
    local name = entry.Name
    if type(name) == "function" then
        name = name()
    end
    return tostring(name or "")
end

local function rootOf(group)
    local labels, chain = {}, {}
    while group.Parent do
        table.insert(labels, 1, group.Label)
        table.insert(chain, 1, group)
        group = group.Parent
    end
    return group, labels, chain
end

local function locate(entry)
    if entry.Group then
        local root = rootOf(entry.Group)
        return root.Page, root.Subpage
    end
    if entry.Subpage then
        return entry.Subpage.Page, entry.Subpage
    end
    return entry.Page, nil
end

function Search.path(entry)
    if entry.Group then
        local root, labels = rootOf(entry.Group)
        local parts = { root.Page.Name }
        if root.Subpage then
            table.insert(parts, root.Subpage.Title)
        end
        table.insert(parts, root.Title)
        for _, label in ipairs(labels) do
            table.insert(parts, label)
        end
        if entry.Self then
            table.remove(parts)
        end
        return table.concat(parts, SEPARATOR)
    end
    if entry.Subpage then
        return entry.Subpage.Page.Name
    end
    return ""
end

local function hidden(entry)
    local target = entry.Target and entry.Target()
    return target ~= nil and target.Visible == false
end

function Search.query(window, text)
    local query = string.lower(tostring(text or "")):match("^%s*(.-)%s*$")
    if query == "" then
        return {}
    end
    local scored = {}
    for index, entry in ipairs(window.SearchIndex) do
        local name = string.lower(nameOf(entry))
        local score
        if name == query then
            score = 0
        elseif name:sub(1, #query) == query then
            score = 1
        elseif name:find(query, 1, true) then
            score = 2
        elseif string.lower(Search.path(entry)):find(query, 1, true) then
            score = 3
        end
        if score and not hidden(entry) then
            table.insert(scored, { Entry = entry, Score = score, Index = index })
        end
    end
    table.sort(scored, function(a, b)
        if a.Score ~= b.Score then
            return a.Score < b.Score
        end
        return a.Index < b.Index
    end)
    local results = {}
    for index = 1, math.min(#scored, MAX_RESULTS) do
        results[index] = scored[index].Entry
    end
    return results
end

function Search.focus(window, page, target)
    local scroll = page.Scroll
    local offset = target.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - SCROLL_MARGIN
    scroll.CanvasPosition = Vector2.new(0, math.max(0, offset))

    local flash = Util.frame(target, {
        Name = "SearchHighlight",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.7,
    })
    window.Scope:Tween(flash, FLASH_DURATION, { BackgroundTransparency = 1 }, false)
    task.delay(FLASH_DURATION, function()
        window.Scope.Tweens[flash] = nil
        if flash.Parent then
            flash:Destroy()
        end
    end)
end

function Search.reveal(window, entry)
    local page, subpage = locate(entry)
    if page == window.SettingsPage then
        window:OpenSettings()
    else
        window:SelectTab(page)
    end
    if subpage then
        subpage:Select()
    end
    if entry.Group then
        local _, _, chain = rootOf(entry.Group)
        for _, group in ipairs(chain) do
            group.Reveal()
        end
    end
    local target = entry.Target and entry.Target()
    if target then
        task.defer(function()
            if not window.Dead then
                Search.focus(window, page, target)
            end
        end)
    end
    return page
end

local function clearRows(state)
    if state.RowScope then
        state.RowScope:Destroy()
        state.RowScope = nil
    end
    for _, row in ipairs(state.Rows) do
        row:Destroy()
    end
    table.clear(state.Rows)
end

local function addRow(window, state, entry)
    local row = Util.button(state.Results, "", {
        Name = "Result",
        Size = UDim2.new(1, 0, 0, RESULT_HEIGHT),
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Color.Panel,
        ZIndex = 61,
    })
    Util.label(row, nameOf(entry), {
        Name = "Title",
        Position = UDim2.fromOffset(8, 3),
        Size = UDim2.new(1, -72, 0, 16),
        TextSize = Theme.TextSize - 1,
        ZIndex = 62,
    })
    Util.label(row, entry.Kind, {
        Name = "Kind",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 3),
        Size = UDim2.fromOffset(60, 16),
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 62,
    })
    local path = Search.path(entry)
    Util.label(row, path ~= "" and path or "Tab", {
        Name = "Path",
        Position = UDim2.fromOffset(8, 18),
        Size = UDim2.new(1, -16, 0, 13),
        TextSize = Theme.SmallSize - 1,
        TextColor3 = Theme.Color.Muted,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 62,
    })
    state.RowScope:Connect(row.Activated, function()
        Search.go(window, entry)
    end)
    table.insert(state.Rows, row)
end

function Search.refresh(window)
    local state = window.Search
    clearRows(state)
    local text = state.Box.Text
    if not state.Open or text:match("^%s*$") then
        state.Matches = {}
        state.Results.Visible = false
        return
    end

    state.RowScope = Util.scope()
    state.Matches = Search.query(window, text)
    if #state.Matches == 0 then
        table.insert(
            state.Rows,
            Util.label(state.Results, "No results", {
                Size = UDim2.new(1, 0, 0, RESULT_HEIGHT),
                TextColor3 = Theme.Color.Muted,
                TextSize = Theme.SmallSize,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 61,
            })
        )
    end
    for _, entry in ipairs(state.Matches) do
        addRow(window, state, entry)
    end

    local count = math.max(1, #state.Matches)
    state.Results.CanvasSize = UDim2.fromOffset(0, count * RESULT_HEIGHT)
    state.Results.Size = UDim2.fromOffset(RESULTS_WIDTH, math.min(count, MAX_VISIBLE) * RESULT_HEIGHT)
    state.Results.Visible = true
end

local function paint(window)
    local state = window.Search
    state.Icon:SetColor(state.Open and Theme.Accent or Theme.Muted)
end

function Search.open(window)
    local state = window.Search
    if state.Open or window.Dead then
        return
    end
    state.Open = true
    state.Box.Text = ""
    state.Box.Visible = true
    window.Scope:Tween(
        state.Box,
        OPEN_DURATION,
        { Size = UDim2.fromOffset(BOX_WIDTH, BOX_HEIGHT) },
        window.ReducedMotion
    )
    paint(window)
    pcall(function()
        state.Box:CaptureFocus()
    end)

    state.Scope = Util.scope()
    state.Scope:Connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == Enum.KeyCode.Escape then
            Search.close(window)
            return
        end
        if not Util.isPointer(input) then
            return
        end
        local point = input.Position
        local inside = Util.contains(state.Box, point)
            or (state.Results.Visible and Util.contains(state.Results, point))
            or Util.contains(state.Button, point)
        if not inside then
            Search.close(window)
        end
    end)
    Search.refresh(window)
end

function Search.close(window)
    local state = window.Search
    if not state or not state.Open then
        return
    end
    state.Open = false
    if state.Scope then
        state.Scope:Destroy()
        state.Scope = nil
    end
    clearRows(state)
    pcall(function()
        state.Box:ReleaseFocus()
    end)
    window.Scope:Tween(state.Box, 0, { Size = UDim2.fromOffset(0, BOX_HEIGHT) }, true)
    state.Box.Visible = false
    state.Results.Visible = false
    state.Matches = {}
    paint(window)
end

function Search.go(window, entry)
    Search.close(window)
    return Search.reveal(window, entry)
end

function Search.build(window, headerHeight, rightOffset)
    local button = Util.button(window.Header, "", {
        Name = "SearchButton",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -rightOffset, 0.5, 0),
        Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    })
    local box = Util.textbox(window.Header, {
        Name = "SearchBox",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(rightOffset + BUTTON_SIZE + BOX_GAP), 0.5, 0),
        Size = UDim2.fromOffset(0, BOX_HEIGHT),
        Text = "",
        PlaceholderText = "Search settings",
        PlaceholderColor3 = Theme.Color.Muted,
        TextSize = Theme.SmallSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClipsDescendants = true,
        Visible = false,
    })
    Util.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, box)
    local results = Util.new("ScrollingFrame", {
        Name = "SearchResults",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -6, 0, headerHeight + 2),
        Size = UDim2.fromOffset(RESULTS_WIDTH, 0),
        BackgroundColor3 = Theme.Color.Panel,
        BorderSizePixel = 1,
        BorderColor3 = Theme.Color.Outline,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Color.Outline,
        CanvasSize = UDim2.new(),
        ZIndex = 60,
        Visible = false,
    }, window.Root)
    Util.list(results, false, 0)

    window.Search = {
        Button = button,
        Icon = Icons.search(button, ICON_SIZE),
        Box = box,
        Results = results,
        Open = false,
        Rows = {},
        Matches = {},
    }

    window.Scope:Connect(button.Activated, function()
        if window.Search.Open then
            Search.close(window)
        else
            Search.open(window)
        end
    end)
    window.Scope:Connect(box:GetPropertyChangedSignal("Text"), function()
        if window.Search.Open then
            Search.refresh(window)
        end
    end)
    window.Scope:Connect(box.FocusLost, function(enterPressed)
        local first = window.Search.Matches[1]
        if enterPressed and window.Search.Open and first then
            Search.go(window, first)
        end
    end)
    table.insert(window.ThemeHooks, function()
        paint(window)
    end)
    return BUTTON_SIZE
end

return Search

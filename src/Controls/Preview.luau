local Label = require(script.Parent.Label)
local Theme = require(script.Parent.Parent.internal.Theme)
local Util = require(script.Parent.Parent.internal.Util)

local GRID_SPACING = 10
local GRID_INSET = 8
local CONTENT_INSET = 24
local PIXEL_FILL = 0.84

local Preview = {}

local function samePoints(a, b)
    if #a ~= #b then
        return false
    end
    for index, point in ipairs(a) do
        if point.X ~= b[index].X or point.Y ~= b[index].Y then
            return false
        end
    end
    return true
end

local function bounds(points)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    for _, point in ipairs(points) do
        minX = math.min(minX, point.X)
        minY = math.min(minY, point.Y)
        maxX = math.max(maxX, point.X)
        maxY = math.max(maxY, point.Y)
    end
    return minX, minY, maxX, maxY
end

function Preview.add(group, info)
    info = info or {}
    local window = group.Window
    local preview = { Points = {}, Parts = {} }

    preview.Root = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, info.Height or 148),
        BorderColor3 = Theme.Color.Outline,
        BorderSizePixel = 1,
        ClipsDescendants = true,
    })
    local grid = Util.frame(preview.Root, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 1,
    })
    local drawing = Util.frame(preview.Root, {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = 2,
    })
    local count = Label.add(group, "0 / 0")
    local track = Util.frame(group.Container, {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Theme.Color.Hover,
    })
    local fill = Util.frame(track, {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = Theme.Color.Accent,
    })

    local dots, columns, rows = {}, -1, -1

    local function layoutGrid(size)
        local nextColumns = math.max(0, math.floor((size.X - 2 * GRID_INSET) / GRID_SPACING) + 1)
        local nextRows = math.max(0, math.floor((size.Y - 2 * GRID_INSET) / GRID_SPACING) + 1)
        if nextColumns == columns and nextRows == rows then
            return
        end
        for key, dot in pairs(dots) do
            if dot.Position.X.Offset > size.X - GRID_INSET or dot.Position.Y.Offset > size.Y - GRID_INSET then
                dot:Destroy()
                dots[key] = nil
            end
        end
        for y = GRID_INSET, size.Y - GRID_INSET, GRID_SPACING do
            for x = GRID_INSET, size.X - GRID_INSET, GRID_SPACING do
                local key = x .. ":" .. y
                if not dots[key] then
                    dots[key] = Util.frame(grid, {
                        Position = UDim2.fromOffset(x, y),
                        Size = UDim2.fromOffset(1, 1),
                        BackgroundColor3 = Theme.Color.Outline,
                        BackgroundTransparency = 0.35,
                    })
                end
            end
        end
        columns, rows = nextColumns, nextRows
    end

    local function layoutPoints(size)
        local points = preview.Points
        if #points == 0 then
            return
        end
        local minX, minY, maxX, maxY = bounds(points)
        local spanX, spanY = maxX - minX + 1, maxY - minY + 1
        local cell = math.max(1, math.min((size.X - CONTENT_INSET) / spanX, (size.Y - CONTENT_INSET) / spanY))
        local offsetX, offsetY = (size.X - spanX * cell) / 2, (size.Y - spanY * cell) / 2
        for index, point in ipairs(points) do
            local part = preview.Parts[index]
            part.Position = UDim2.fromOffset(offsetX + (point.X - minX) * cell, offsetY + (point.Y - minY) * cell)
            part.Size = UDim2.fromOffset(cell * PIXEL_FILL, cell * PIXEL_FILL)
        end
    end

    local function layout()
        local size = preview.Root.AbsoluteSize
        layoutGrid(size)
        layoutPoints(size)
    end

    function preview:SetPoints(points)
        if samePoints(points, self.Points) then
            return self
        end
        for index = #self.Parts, #points + 1, -1 do
            self.Parts[index]:Destroy()
            self.Parts[index] = nil
        end
        for index = #self.Parts + 1, #points do
            self.Parts[index] = Util.frame(drawing, { BackgroundColor3 = Theme.Color.Accent })
            Util.new("UICorner", { CornerRadius = UDim.new(0, 1) }, self.Parts[index])
        end
        self.Points = table.clone(points)
        layout()
        self:SetCount(0, #points)
        return self
    end

    function preview:SetCount(current, total)
        if self.Current == current and self.Total == total then
            return
        end
        self.Current, self.Total = current, total
        count:SetText(string.format("%d / %d", current, total))
        fill.Size = UDim2.fromScale(total > 0 and math.clamp(current / total, 0, 1) or 0, 1)
    end

    function preview:Recoil()
        if window.ReducedMotion then
            return
        end
        window.Scope:Tween(drawing, 0.06, { Position = UDim2.fromOffset(-3, -2) }, false)
        task.delay(0.06, function()
            if not window.Dead then
                window.Scope:Tween(drawing, 0.19, { Position = UDim2.fromOffset(0, 0) }, false)
            end
        end)
    end

    window.Scope:Connect(preview.Root:GetPropertyChangedSignal("AbsoluteSize"), layout)
    preview:SetPoints(info.Points or {})
    return Util.protect(preview, { "SetPoints", "SetCount", "Recoil" })
end

return Preview

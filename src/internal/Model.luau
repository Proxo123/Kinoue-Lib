-- Pure value logic, usable in standalone Luau tests.
local Model = {}
function Model.number(value, minimum, maximum, step)
    local n = tonumber(value)
    if not n or n ~= n or math.abs(n) == math.huge then n = minimum end
    n = math.clamp(n, minimum, maximum)
    if step and step > 0 then n = minimum + math.round((n - minimum) / step) * step end
    return math.clamp(n, minimum, maximum)
end
function Model.options(values)
    local result, seen = {}, {}
    for _, value in ipairs(values) do
        local option = type(value) == "table" and value or { Value = value, Label = tostring(value) }
        assert(option.Value ~= nil, "Dropdown option requires Value")
        assert(not seen[option.Value], "Duplicate dropdown value: " .. tostring(option.Value))
        seen[option.Value] = true
        table.insert(result, { Value = option.Value, Label = option.Label or tostring(option.Value), Meta = option.Meta })
    end
    return result
end
function Model.control(initial, normalize, callback)
    local control = { Value = normalize(initial), Callback = callback }
    function control:Get() return self.Value end
    function control:Set(value, silent)
        local nextValue = normalize(value)
        local changed = nextValue ~= self.Value
        self.Value = nextValue
        if self.Render and (changed or value ~= nextValue) then self.Render(nextValue) end
        if changed and not silent and self.Callback then self.Callback(nextValue) end
        return self
    end
    function control:SetSilent(value) return self:Set(value, true) end
    control.RawSet = control.SetSilent
    function control:SetCallback(fn) self.Callback = fn return self end
    return control
end
return Model

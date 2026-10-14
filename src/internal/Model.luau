local Model = {}

function Model.number(value, minimum, maximum, step)
    local number = tonumber(value)
    if not number or number ~= number or math.abs(number) == math.huge then
        number = minimum
    end
    number = math.clamp(number, minimum, maximum)
    if step and step > 0 then
        number = minimum + math.round((number - minimum) / step) * step
    end
    return math.clamp(number, minimum, maximum)
end

function Model.options(values)
    local result, seen = {}, {}
    for _, value in ipairs(values) do
        local option = type(value) == "table" and value or { Value = value, Label = tostring(value) }
        assert(option.Value ~= nil, "Dropdown option requires Value")
        assert(not seen[option.Value], "Duplicate dropdown value: " .. tostring(option.Value))
        seen[option.Value] = true
        table.insert(result, {
            Value = option.Value,
            Label = option.Label or tostring(option.Value),
            Meta = option.Meta,
        })
    end
    return result
end

function Model.control(initial, normalize, callback)
    local control = { Value = normalize(initial), Callback = callback }

    function control:Get()
        return self.Value
    end

    function control:Set(value, silent)
        local nextValue = normalize(value)
        local changed = nextValue ~= self.Value
        self.Value = nextValue
        if self.Render and (changed or value ~= nextValue) then
            self.Render(nextValue)
        end
        if changed and not silent and self.Callback then
            self.Callback(nextValue)
        end
        return self
    end

    function control:SetSilent(value)
        return self:Set(value, true)
    end

    control.RawSet = control.SetSilent

    function control:SetCallback(fn)
        self.Callback = fn
        return self
    end

    return control
end

return Model

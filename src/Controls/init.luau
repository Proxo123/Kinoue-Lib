local Util = require(script.Parent.internal.Util)
local Button = require(script.Button)
local ColorPicker = require(script.ColorPicker)
local Disclosure = require(script.Disclosure)
local Dropdown = require(script.Dropdown)
local Keybind = require(script.Keybind)
local Label = require(script.Label)
local Preview = require(script.Preview)
local Slider = require(script.Slider)
local Textbox = require(script.Textbox)
local Toggle = require(script.Toggle)

local Group = {}
Group.__index = Group

function Group.new(window, container, page, frame)
    return setmetatable({
        Window = window,
        Page = page,
        Frame = frame,
        Container = container,
    }, Group)
end

function Group:AddLabel(text, small)
    return Label.add(self, text, small)
end

function Group:AddToggle(id, info)
    return Toggle.add(self, id, info, Group.new)
end

function Group:AddKeybind(id, info)
    return Keybind.add(self, id, info)
end

function Group:AddSlider(id, info)
    return Slider.add(self, id, info)
end

function Group:AddTextbox(id, info)
    return Textbox.add(self, id, info)
end

function Group:AddDropdown(id, info)
    return Dropdown.add(self, id, info)
end

function Group:AddButton(info)
    return Button.add(self, info)
end

function Group:AddButtons(definitions)
    return Button.addRow(self, definitions)
end

function Group:AddDisclosure(title, open)
    return Disclosure.add(self, title, Group.new, open)
end

function Group:AddColorPicker(id, info)
    return ColorPicker.add(self, id, info)
end

function Group:AddPreview(info)
    return Preview.add(self, info)
end

Util.protect(Group, {
    "AddLabel",
    "AddToggle",
    "AddKeybind",
    "AddSlider",
    "AddTextbox",
    "AddDropdown",
    "AddButton",
    "AddButtons",
    "AddDisclosure",
    "AddColorPicker",
    "AddPreview",
})

return Group

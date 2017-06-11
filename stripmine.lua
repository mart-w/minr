--[[
Minr - Automatic strip mining program for ComputerCraft turtles.

MIT License

Copyright (c) 2017 Martin W.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

-- Constants.
local DEFAULT_TUNNEL_DEPTH = 50
local DEFAULT_TUNNEL_HEIGHT = 3

-- Defines which materials get ignored while scanning.
IGNORED_MATERIALS = {
    "minecraft:stone",
    "minecraft:gravel",
    "minecraft:dirt",
    "minecraft:sand",
    "minecraft:cobblestone"
}

-- Variables.
local tunnel_depth = 0
local tunnel_height = 0

-- Functions.
local function prompt_user(prompt, default)
    --[[
    Prompts the user to enter a value. If a default value is given, that can be
    accepted by just pressing enter.

    @param prompt:  Message to the user describing what value is asked for.
    @param default: [optional] Default value to be offered to the user.

    @return         Value given by the user.
    --]]

    -- Compose message.
    local message = prompt

    if default then -- Add default value in parantheses if given.
        message = message.." ("..default..')'
    end

    message = message..": "

    -- Print the message to the screen and receive user input. Repeat if neither
    -- an input nor a default value is given.
    local output = nil
    local input = nil

    while not output do
        write(message)
        input = io.read()

        if input == "" then
            if default then output = default end
        else
            output = input
        end
    end

    return output
end

local function init()
    --[[
    Greets the user and sets up the global variables.
    --]]

    -- Clear terminal.
    term.clear()
    term.setCursorPos(1,1)

    -- Greet user.
    print([[
Welcome to Minr, the intelligent
strip mining program for ComputerCraft!
---------------------------------------]])

    -- Fetch information from user
    tunnel_depth = tonumber(prompt_user("Please enter the desired tunnel depth",
                                        DEFAULT_TUNNEL_DEPTH))
    tunnel_height = tonumber(prompt_user("Please enter the desired tunnel height",
                                        DEFAULT_TUNNEL_HEIGHT))
end

-- Main body.
init()

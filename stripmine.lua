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

-- Defines materials which drop items different from the block they originate
-- from.
BLOCK_DROPS = {
    ["minecraft:stone"] = "minecraft:cobblestone",
    ["minecraft:redstone_ore"] = "minecraft:redstone",
    ["minecraft:diamond_ore"] = "minecraft:diamond"
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

local function get_possible_slot(item, quantity)
    --[[
    Checks if the inventory offers space for a given item (and quantity).

    @param item         Item identifier of the item to be stored.
    @param quantity     [optional] Amount of items to be stored. If not given, 1
                        will be assumed.

    @return             Number of the first slot offering space for the desired
                        item and quantity, nil if there is none.
    --]]

    -- Scan inventory and compare its contents to the given item and quantity.
    local slot_item = nil

    for i = 1, 16 do
        slot_item = turtle.getItemDetail(i)
        if not slot_item then
            return i -- empty slot_item
        elseif slot_item.name == item then -- existing item stack found
            -- check for space in the stack
            local needed_space = 1
            if quantity then needed_space = quantity end

            if turtle.getItemSpace(i) >= needed_space then
                return i -- item can be stored in found stack
            end
        end
    end

    return nil -- no slot found
end

local function is_ignored_material(material)
    --[[
    Returns if a given material is one of the ignored materials defined in
    IGNORED_MATERIALS

    @param material     Identifier of the material to be looked up.

    @return             True if the material is ignored, false if not.
    --]]

    for index, ignored_material in pairs(IGNORED_MATERIALS) do
        if ignored_material == material then return true end
    end

    return false
end

local function get_block_drop(material)
    --[[
    Returns the identifier of the item a given block drops when mined.

    @param block    Identifier of the block to be looked up

    @return         Identifier of the dropped item
    --]]

    for block, drop in pairs(BLOCK_DROPS) do
        if material == block then
            return drop
        end
    end

    return material -- Dropped item equals mined material
end

local function return_to_ground(height)
    --[[
    Lets the turtle return to the ground from a given height.

    @param height   Height the turtle should return to the ground from.
    --]]

    while height > 1 do
        turtle.down()
        height = height - 1
    end
end

local function mine_block(direction)
    --[[
    Mines one block and stores it in the turtle's inventory. Checks for
    inventory space first, dropping items from the IGNORED_MATERIALS list if
    it is full.

    @param direction    [optional] Either "up" or "down", used to mine above or
                        below the turtle.

    @return             False if inventory is full and cannot be emptied,
                        otherwise true.
    --]]

    -- Store respective inspect and dig functions in a local variable according
    -- to direction parameter
    local inspect = nil
    local dig = nil

    if direction == "up" then
        inspect = turtle.inspectUp
        dig = turtle.digUp
    elseif direction == "down" then
        inspect = turtle.inspectDown
        dig = turtle.digDown
    else
        inspect = turtle.inspect
        dig = turtle.dig
    end

    -- Identify block to be mined
    is_block, block = inspect()

    -- Return true if there is no block to be mined
    if not is_block then return true end

    -- Check for inventory space and mine the block. If there is no space, try
    -- to drop one of the ignored materials and then mine the block.
    if get_possible_slot(get_block_drop(block.name)) then
        dig()
        return true -- Return true as the block has been mined
    else
        for i = 1, 16 do
            if is_ignored_material(turtle.getItemDetail(i).name) then
                turtle.select(i)
                turtle.drop()
                dig()
                return true -- Return true as the block has been mined
            end
        end
        return false -- No suitable slot could be found
    end
end

local function mine_row()
    --[[
    Mines a vertical row of blocks before the turtle. The height of the column
    is defined in tunnel_height.

    @return     True if all blocks were mined successfully, otherwise false.
    --]]
    local height = 1 -- ground level
    local successful = true

    while height < tunnel_height do
        if not mine_block() then
            successful = false
            break -- Mining unsuccessful, do not continue
        end
        turtle.up()
        height = height + 1
    end

    if successful then mine_block() end -- Mine topmost block

    return_to_ground(height)

    return successful
end

local function scan_block(direction)
    --[[
    Scans the block in front of the turtle and mines it if it isn't part of
    IGNORED_MATERIALS

    @param direction    [optional] Either "up" or "down", changes the direction
                        in which the turtle should scan and dig.

    @return             False if mine_block() fails, otherwise true.
    --]]

    -- Choose correct inspect function depending on the given direction
    local inspect = nil

    if direction == "up" then
        inspect = turtle.inspectUp
    elseif direction == "down" then
        inspect = turtle.inspectDown
    else
        inspect = turtle.inspect
    end

    is_block, block = inspect() -- Scan block in front of the turtle

    if is_block then
        if not is_ignored_material(block.name) then
            if not mine_block(direction) then
                return false
            end
        end
    end

    return true
end

local function scan_walls()
    --[[
    Scans the walls left and right of the turtle as well as the floor and
    ceiling for blocks not in IGNORED_MATERIALS and mines them.

    @return     False if scan_block() fails at any time, e.g. the inventory is
                full, otherwise true.
    --]]
    local height = 1 -- ground level

    -- floor
    if not scan_block("down") then
        return false -- Failed attempt at mining a block
    end

    turtle.turnLeft()

    -- way up
    while height < tunnel_height do
        if not scan_block() then
            turtle.turnRight()
            return_to_ground(height)
            return false -- Failed attempt at mining a block
        end

        turtle.up()
        height = height + 1
    end

    -- topmost left block
    if not scan_block() then
        turtle.turnRight()
        return_to_ground(height)
        return false -- Failed attempt at mining a block
    end

    turtle.turnRight()

    -- ceiling
    if not scan_block("up") then
        return_to_ground(height)
        return false -- Failed attempt at mining a block
    end

    turtle.turnRight()

    -- way back down
    while height > 1 do
        if not scan_block() then
            turtle.turnLeft()
            return_to_ground(height)
            return false -- Failed attempt at mining a block
        end

        turtle.down()
        height = height - 1
    end

    -- bottommost right block
    if not scan_block() then
        turtle.turnLeft()
        return false -- Failed attempt at mining a block
    end

    turtle.turnLeft()
    return true -- Scanning successful
end

local function go_to_position_in_strip(position, destination)
    --[[
    Moves to the given position inside a mined strip.

    @param position     The position the turtle is at inside the strip.
    @param destination  The position the turtle is supposed to go to
    --]]

    if destination > position then
        while destination > position do
            turtle.forward()
            position = position + 1
        end
    else
        while destination < position do
            turtle.back()
            position = position - 1
        end
    end
end

local function go_back_in_strip(position)
    --[[
    Moves back to the beginning of a mined strip.

    @param position     The position the turtle is at inside the strip.
    --]]

    go_to_position_in_strip(position, 0)
end

local function mine_strip(scanning_enabled)
    --[[
    Digs a tunnel with lenght tunnel_depth and height tunnel_height. If not
    told otherwise, scans the walls, floor and ceiling for materials not part of
    IGNORED_MATERIALS as well. If the path is blocked or the inventory is full,
    it will return to the starting position.

    @param scanning_enabled     [optional] If set to false, the turtle will not
                                scan the walls, floor and ceiling. If not set,
                                it will be assumed to be true.
    --]]

    local position = 0

    while position < tunnel_depth do
        if not mine_row() then
            go_back_in_strip(position) -- inventory is full
            position = 0
            break
        end

        if not turtle.forward() then
            go_back_in_strip(position) -- path is blocked
            position = 0
            break
        end
        position = position + 1

        if not scan_walls() then
            go_back_in_strip(position) -- inventory is full
            position = 0
            break
        end
    end

    go_back_in_strip()
end

local function greet()
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
greet()
mine_strip()

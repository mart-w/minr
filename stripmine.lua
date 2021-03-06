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
    ["minecraft:diamond_ore"] = "minecraft:diamond",
    ["minecraft:lapis_ore"] = "minecraft:dye",
    ["minecraft:coal_ore"] = "minecraft:coal"
}

-- Variables.
local tunnel_depth = 0
local tunnel_height = 0
local automatic_refuel = true

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

local function estimate_needed_fuel()
    --[[
    Estimates and returns the amount of fuel needed to dig the desired mines.

    @return     Estimated fuel consumption.
    --]]
    local estimate = 1

    estimate = estimate * tunnel_depth -- fuel needed to cover the length of the tunnel
    estimate = estimate * tunnel_height * 2 -- the turtle needs to go both up and down every row
    estimate = estimate + tunnel_depth -- way back
    estimate = estimate * 1.05 -- 5 per cent tolerance

    return estimate
end

local function refuel()
    --[[
    Looks for burnable items inside the turtle's inventory and uses one of them
    as fuel.

    @return     True if refuel was successful, false if not.
    --]]

    for i = 1, 16 do
        turtle.select(i)
        if turtle.refuel(1) then
            return true
        end
    end
    return false -- no fuel found
end

local function forward()
    --[[
    Moves the turtle one block forward. Automatically clears sand and gravel.

    @return     True if successful, false if the turtle cannot move.
    --]]

    if turtle.forward() then
        return true
    else
        is_block, block = turtle.inspect()

        if block.name == "minecraft:gravel" or block.name == "minecraft:sand" then
            while block.name == "minecraft:gravel" or block.name == "minecraft:sand" do
                turtle.dig()
                is_block, block = turtle.inspect()
            end
            if forward() then return true end
        else
            return false -- Turtle got stuck
        end
    end
end

local function back()
    --[[
    Moves the turtle on block backwards. Automatically clears sand and gravel.

    @return     True if successful, false if the turtle cannot move.
    --]]
    local successful = true

    if turtle.back() then
        return true
    else
        turtle.turnRight()
        turtle.turnRight()

        if not forward() then
            successful = false
        end

        turtle.turnRight()
        turtle.turnRight()

        return successful
    end
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
    it is full. If the inventory is full but the block in question is on the
    IGNORED_MATERIALS list, it is mined without being picked up.

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
        if is_ignored_material(block.name) then
            dig()
            return true -- Mined block was an ignored block, so it is omitted
        end
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
            forward()
            position = position + 1
        end
    else
        while destination < position do
            back()
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
        -- check for fuel
        while automatic_refuel and turtle.getFuelLevel() < 50 do
            refuel()
        end

        if not mine_row() then
            go_back_in_strip(position) -- inventory is full
            position = 0
            break
        end

        if not forward() then
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

    go_back_in_strip(position)
end

local function greet()
    --[[
    Greets the user.
    --]]

    -- Clear terminal.
    term.clear()
    term.setCursorPos(1,1)

    -- Greet user.
    print([[
Welcome to Minr, the intelligent
strip mining program for ComputerCraft!
---------------------------------------]])
end

-- Main body.
greet()

-- Fetch information from user
tunnel_depth = tonumber(prompt_user("Please enter the desired tunnel depth",
                                    DEFAULT_TUNNEL_DEPTH))
tunnel_height = tonumber(prompt_user("Please enter the desired tunnel height",
                                    DEFAULT_TUNNEL_HEIGHT))


local fuel = turtle.getFuelLevel()
local estimated_fuel_need = estimate_needed_fuel()
local fuel_okay = false

if fuel == "unlimited" then -- fuel need disabled
    fuel_okay = true
else -- fuel needed
    if fuel > estimated_fuel_need then
        fuel_okay = true
    else
        local fuel_answer = prompt_user("The turtle might not have enough fuel for that! Continue?", "N")
        if fuel_answer:lower() == "yes" or fuel_answer:lower() == "y" then
            fuel_okay = true
        end
    end

    local refuel_answer = prompt_user("Automatically refuel from gathered resources?", "Y")
    if refuel_answer:lower() == "no" or refuel_answer:lower() == "n" then
        automatic_refuel = false
    end
end

mine_strip()

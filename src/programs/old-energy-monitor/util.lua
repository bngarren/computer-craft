local util = {}

util.sides = {"left", "right", "top", "bottom", "front", "back"}

-- Function to write text in a specified color and then reset to the default color
function util.coloredWrite(text, color)
    if not term then return end
    local defaultColor = term.getTextColor()  -- Save the current text color
    term.setTextColor(color)                  -- Set the new text color
    write(text.."\n")                               -- Write the text
    term.setTextColor(defaultColor)           -- Reset the text color back to default
end

function util.ensureModuleExists(moduleName, action)
    local filePath = moduleName .. ".lua"

    if not fs.exists(filePath) then
        if action then
            local success = action(filePath)
            if success then
                return require(moduleName)
            else
                print("Module '" .. moduleName .. "' not found. Failed attempt to retrieve.")
            end
        end
        print("Module '" .. moduleName .. "' not found. Ensure .deps file includes " ..moduleName.." and re-run installer.")
    else
        return require(moduleName)
    end
end

--[[
Function to check and wrap specified peripherals

`peripheralsList` is a table where keys are the expected peripheral types or custom functions, and values are variables to store the wrapped peripheral or nil if not found.

Example: a key of 'monitor' will automatically find (and wrap) the first monitor it finds. A custom function should return the wrapped peripheral.
]]
function util.checkSpecifiedPeripherals(peripheralsList)
    local allFound = true
    for identifier, storageVar in pairs(peripheralsList) do
        local foundPeripheral = nil

        -- If the identifier is a function, call it to find the peripheral
        if type(identifier) == "function" then
            foundPeripheral = identifier()
        else
            -- Otherwise, use peripheral.find with the type string
            foundPeripheral = peripheral.find(identifier)
        end

        if foundPeripheral then
            _G[storageVar] = foundPeripheral  -- Store the wrapped peripheral in the specified global variable
        else
            util.coloredWrite("Missing required peripheral for: " .. storageVar, colors.yellow)
            _G[storageVar] = nil  -- Ensure the global variable is nil if the peripheral is not found
            allFound = false
        end
    end
    return allFound
end

--[[
    Finds (and wraps) a _wireless_ modem if present and returns it, otherwise returns nil
]]
function util.findWirelessModem()
    local m = peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end)
    return m or nil
end

--[[
    Opens the modem and hosts it on the specified protocol with the specified name

    'modem' is the wrapped peripheral
]]
function util.initNetwork(modem, protocol, name)
    local status, err = pcall(function() rednet.open(peripheral.getName(modem)) end)
    if not status then
        printError("Could not open modem connection: "..err)
        return false
    end
    rednet.host(protocol, name or os.getComputerLabel())
    util.coloredWrite("Modem opened for communication.", colors.cyan)
    return true
end

function util.formatNumber(num)
    if not num then return "0" end
    if num >= 1e12 then
        return string.format("%.1f T", num / 1e12)
    elseif num >= 1e9 then
        return string.format("%.1f B", num / 1e9)
    elseif num >= 1e6 then
        return string.format("%.1f M", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1f K", num / 1e3)
    else
        -- For numbers less than 1000, return them as integers
        -- No need for formatting with commas, and ensures no decimals
        return tostring(math.floor(num))
    end
end

function util.centerText(mon, text, yVal)
    local length = string.len(text)
    local monX, _ = mon.getSize() -- Get the width and ignore the height
    local minus = monX - length
    local x = math.floor(minus / 2)
    mon.setCursorPos(x + 1, yVal)
    mon.write(text)
end

function util.openModem()
    for _, side in pairs(util.sides) do
        if peripheral.isPresent(side) and peripheral.getType(side) == "modem" then
            rednet.open(side)
            print("Modem opened on " .. side)
            return true
        end
    end
    print("No modem found.")
    return false
end

function util.tableContains(table, element)
    for _, value in pairs(table) do
      if value == element then
        return true
      end
    end
    return false
  end

function util.sendData(receiverId, data, protocol)
    local serializedData = textutils.serialize(data)
    rednet.send(receiverId, serializedData, protocol)
end

return util
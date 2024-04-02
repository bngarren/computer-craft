local util = {}

util.sides = {"left", "right", "top", "bottom", "front", "back"}

function util.ensureModuleExists(moduleName, action)
    local filePath = moduleName .. ".lua"

    if not fs.exists(filePath) then
        if action then
            local success = action(moduleName)
            if success then
                return require(moduleName)
            end
        end
        print("Module '" .. moduleName .. "' not found. Consider re-running installer and ensure .deps file includes " ..moduleName)
    else
        return require(moduleName)
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
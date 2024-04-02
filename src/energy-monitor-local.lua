-- Attempt to load the modules
local util = require("util")

local function listenForData()
    while true do
        local senderId, message, protocol = rednet.receive("energy-monitor")

        local data = textutils.unserialize(message)
        -- Now `data` is a table, so you can access its contents
        if not data then
            basalt.debug("Could not deserialize data")
            return
        end
        if not data.type then
            basalt.debug("Received data is missing type")
            return
        end
    end
end


local function sendEnergyRate(receiverId, val)
    local data = {
        type = "energyRate",
        name = os.getComputerLabel(),
        energyType = settings.get("type") or "",
        payload = val
    }
    print("Sent energy rate to #" .. receiverId)
    util.sendData(receiverId, data, "energy-monitor")
end


-- Main logic
local function run()
    local modem, energyMeter
    -- Identify wireless modem
    local modems = { peripheral.find("modem", function(name, modem)
        return modem.isWireless() -- Check this modem is wireless.
    end) }
    if #modems == 0 then
        printError("Missing wireless modem")
        return
    else
        modem = modems[1] -- pick the first
        print("Using wireless modem on side: " .. peripheral.getName(modem))
    end

    -- Identify energy meter (required)
    local meters = { peripheral.find("energymeter") }
    if #meters == 0 then
        printError("Missing Energy Meter")
        return
    else
        energyMeter = meters[1] -- pick the first
        print("Using Energy Meter on side: " .. peripheral.getName(energyMeter))
        -- textutils.tabulate(peripheral.getMethods(peripheral.getName(energyMeter)))
    end

    -- Ensure Energy Meter is configured correctly
    if not energyMeter.hasInput() or not energyMeter.hasOutput() or energyMeter.getStatus() == "DISCONNECTED" then
        printError("Energy Meter is not properly configured!")
        return
    end

    -- Ensure computer is labeled
    local currentLabel = os.getComputerLabel()
    local typeSetting = settings.get("type")

    if not currentLabel then
        print("Enter a new label for the computer. It cannot be 'master' or empty.")
        local isValid = false
        while not isValid do
            write("Label: ")
            local newName = read()
            if #newName > 0 and newName ~= "master" then
                os.setComputerLabel(newName)
                print("Computer is now named: " .. os.getComputerLabel())
                isValid = true
            else
                print("Invalid name. Please try again.")
            end
        end
    else
        print("Computer is already named: " .. os.getComputerLabel())
    end

    -- Ensure computer has a "type" (from settings)
    -- e.g. Producer or Consumer
    if not typeSetting then
        local isValid = false
        while not isValid do
            print("Choose the type: 1) Producer 2) Consumer")
            local input = read()
            if input == "1" then
                typeSetting = "Producer"
                isValid = true
            elseif input == "2" then
                typeSetting = "Consumer"
                isValid = true
            else
                print("Invalid input. Please enter 1 for Producer or 2 for Consumer.")
            end
        end
        settings.set("type", typeSetting)
        settings.save()
        print("Type set to: " .. typeSetting)
    else
        print("Type: " .. typeSetting)
    end

    -- Identify network and master computer
    rednet.open(peripheral.getName(modem))
    rednet.host("energy-monitor", os.getComputerLabel())

    local master = rednet.lookup("energy-monitor", "master")
    if master then
        print("Found 'master' at computer #" .. master)
    else
        printError("Cannot find 'master' on network")
    end


    local function updateMaster()
        while true do
            local rate = energyMeter.getTransferRate()
            sendEnergyRate(master, rate)
            sleep(5)
        end
    end

    -- Start
    parallel.waitForAny(listenForData, updateMaster)
end

run()

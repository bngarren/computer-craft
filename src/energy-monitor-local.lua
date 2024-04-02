-- Attempt to load the modules
local util = require("util")

local function listenForData()
    while true do
        local senderId, message, protocol = rednet.receive("energy-monitor")

        local data = textutils.unserialize(message)
        -- Now `data` is a table, so you can access its contents
        if not data then
            basalt.debug("Could not deserialize data")
        end
        if not data.type then
            basalt.debug("Received data is missing type")
        end

        -- Process received data here...
    end
end


local function sendEnergyRate(receiverId, val)
    local data = {
        type = "energyRate",
        name = os.getComputerLabel(),
        energyType = settings.get("type") or "",
        payload = val
    }
    print("Sent energy rate to 'master' on computer #" .. receiverId)
    util.sendData(receiverId, data, "energy-monitor")
end

local requiredPeripherals = {
    [util.findWirelessModem] = "modem",
    ["energymeter"] = "energyMeter",
}
local shouldUpdate = false

local function checkPeripherals()
    print("Checking peripherals")
    -- Use the utility function to check for and wrap required peripherals
    local peripheralsReady = util.checkSpecifiedPeripherals(requiredPeripherals)

    if peripheralsReady then
        print("All required peripherals are present. Continuing operations...")
        return true
    else
        print("One or more required peripherals are missing. Paused operations.")
        if monitor then
            monitor.clear()
        end
        return false
    end
end

local function pollPeripherals()
    while true do
        if not checkPeripherals() then
            shouldUpdate = false
        else
            shouldUpdate = true
        end
        sleep(5)
    end
end


-- Main logic
local function run()
    term.clear()
    print("\n")
    util.coloredWrite("Energy Monitor Local - this is computer id #" .. os.getComputerID(), colors.blue)
    print("\n")

    -- Initial peripherals check
    if not checkPeripherals() then
        return
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
        util.coloredWrite("Enter a new label for the computer. It cannot be 'master' or empty.", colors.orange)
        print("\n")
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
        print("Computer is named: " .. os.getComputerLabel())
        print("\n")
    end

    -- Ensure computer has a "type" (from settings)
    -- e.g. Producer or Consumer
    if not typeSetting then
        local isValid = false
        while not isValid do
            util.coloredWrite("Choose the type: 1) Producer 2) Consumer", colors.orange)
            print("\n")
            local input = read()
            if input == "1" then
                typeSetting = "Producer"
                isValid = true
            elseif input == "2" then
                typeSetting = "Consumer"
                isValid = true
            else
                util.coloredWrite("Invalid input. Please enter 1 for Producer or 2 for Consumer.", colors.red)
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

    local master
    local function findMaster()
        local attempt = 0
        local maxAttempts = 5
        while attempt < maxAttempts do
            master = rednet.lookup("energy-monitor", "master")
            if master then
                print("Found 'master' on computer #" .. master)
                return master
            else
                attempt = attempt + 1
                print("Retrying to find 'master'... Attempt " .. attempt)
                sleep(2) -- Wait a bit before retrying
            end
        end
        printError("Cannot find 'master' on network after " .. maxAttempts .. " attempts.")
    end

    local function updateMaster()
        while true do
            if shouldUpdate then
                if not master or not rednet.isOpen(peripheral.getName(modem)) then
                    findMaster()
                end
                if master then
                    local rate = energyMeter.getTransferRate()
                    sendEnergyRate(master, rate)
                else
                    print("Master not found. Skipping update.")
                end
            else
                print("Peripherals not ready. Skipping update.")
            end
            sleep(5)
        end
    end

    -- Start
    parallel.waitForAny(pollPeripherals, listenForData, updateMaster)
end

run()

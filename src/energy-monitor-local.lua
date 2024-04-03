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
        --ensure modem is open for rednet and on protocol
        if not rednet.isOpen(peripheral.getName(modem)) then
            rednet.open(peripheral.getName(modem))
            rednet.host("energy-monitor", os.getComputerLabel())
            util.coloredWrite("Modem opened for communication.\n", colors.cyan)
        end
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
            util.coloredWrite("Choose the type:\n 1) Producer\n 2) Consumer\n", colors.orange)
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

    local master
    local function findMaster()
        local attempt = 0
        local maxAttempts = 2
        while attempt < maxAttempts do
            master = rednet.lookup("energy-monitor", "master")
            if master then
                print("Found 'master' on computer #" .. master)
                return master
            else
                attempt = attempt + 1
                util.coloredWrite("Retrying to find 'master'... Attempt " .. attempt.."\n", colors.yellow)
                sleep(0.5) -- Wait a bit before retrying
            end
        end
        printError("Cannot find 'master' on network after " .. maxAttempts .. " attempts.")
    end

    local function updateMaster()
        local lastMasterCheckTime = 0
        local masterCheckInterval = 5 -- Check if the master is still on the network every 5 seconds

        while true do
            local currentTime = os.epoch("utc") / 1000 -- Get current time in seconds

            -- Periodically check if the master is present, regardless of the current update status
            if currentTime - lastMasterCheckTime >= masterCheckInterval then
                local foundMaster = findMaster()
                if not foundMaster then
                    print("Master not found during periodic check.")
                    master = nil -- Clear the master variable if the master is not found
                end
                lastMasterCheckTime = currentTime
            end

            if shouldUpdate and master then
                -- Proceed with sending data to the master only if it's found and updates are enabled
                local rate = energyMeter.getTransferRate()
                if rate then -- Ensure rate is not nil before attempting to send
                    sendEnergyRate(master, rate)
                else
                    util.coloredWrite("Failed to obtain energy transfer rate. Couldn't send data.\n", colors.yellow)
                end
            else
                if not shouldUpdate then
                    util.coloredWrite("Updates are paused. Skipping data send.\n", colors.yellow)
                end
                if not master then
                    util.coloredWrite("Master not defined. Skipping data send.\n", colors.yellow)
                end
            end
            sleep(2)
        end
    end

     -- Initial peripherals check
    if not checkPeripherals() then
        return
    end

    -- Start
    parallel.waitForAny(pollPeripherals, listenForData, updateMaster)
end

run()

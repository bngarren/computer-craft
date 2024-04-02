-- How long until a local monitor is removed if no updates
local EXPIRATION_TIME = 15000 -- 15 seconds

-- Attempt to load the modules
local util = require("util")

local basalt = util.ensureModuleExists("basalt", function(...)
    -- Command to download from Pastebin
    return shell.run("wget", "run", "https://basalt.madefor.cc/install.lua", "release", "latest.lua", ...)
end
)

local function logToFile(message)
    local logFile = fs.open("log.txt", "a")                            -- Open the log file in append mode
    if logFile then
        local timestamp = textutils.formatTime(os.time("local"), true) -- Get a simple timestamp
        logFile.writeLine("[" .. timestamp .. "] " .. message)         -- Write the message with a timestamp
        logFile.close()                                                -- Make sure to close the file
    else
        print("Failed to open log file.")
    end
end

local localEnergyMonitors = {}
local function refreshLocalEnergyMonitors()
    while true do
        local numberOfMonitors = 0
        local currentTime = os.epoch("utc")
        for name, data in pairs(localEnergyMonitors) do
            if (currentTime - data.time) > EXPIRATION_TIME then
                -- Monitor hasn't sent an update in over the expiration time
                localEnergyMonitors[name] = nil -- Remove expired monitor
                -- logToFile("Removed expired monitor: " .. name)
            else
                numberOfMonitors = numberOfMonitors + 1
            end
        end

        util.coloredWrite("Tracking " .. numberOfMonitors .. " local energy monitors.\n", colors.lightGray)
        -- logToFile(textutils.serialize(localEnergyMonitors) .. " - " .. os.time())
        sleep(5)
    end
end

local function listenForData()
    while true do
        local senderId, message, protocol = rednet.receive("energy-monitor")

        local data = textutils.unserialize(message)
        -- Now `data` is a table, so you can access its contents
        if not data then
            -- logToFile("Could not deserialize data")
            return
        end
        if not data.type then
            -- logToFile("Received data is missing type")
            return
        end

        if data.type == "energyRate" then
            -- Process the data
            -- print("Received 'energyRate' from #" .. senderId .. " (" .. data.name .. ") with payload: " .. data.payload)
            localEnergyMonitors[data.name] = {
                energyType = data.energyType,
                rate = data.payload,
                time = os.epoch("utc")
            }
        end
    end
end

local requiredPeripherals = {
    [util.findWirelessModem] = "modem", -- Expecting a modem, will store in global `modem` variable
    ["monitor"] = "monitor",            -- Expecting a monitor, will store in global `monitor` variable
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
        util.coloredWrite("One or more required peripherals are missing. Paused operations.\n", colors.yellow)
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
    util.coloredWrite("Energy Monitor Master - this is computer id #" .. os.getComputerID(), colors.yellow)
    print("\n")

    -- Initial peripherals check
    if not checkPeripherals() then
        printError("Couldn't start")
        return
    end

    -- Ensure computer is labeled
    os.setComputerLabel("master")

    -- GUI
    local monitorFrame
    local mainGuiFrame, pausedFrame
    local energyMonitorLabels = {}

    monitor.setTextScale(0.5)
    monitorFrame = basalt.addMonitor():setMonitor(peripheral.getName(monitor))

    local monitorX, monitorY = monitorFrame.getSize()

    mainGuiFrame = monitorFrame:addFrame():setSize(monitorX, monitorY)
    pausedFrame = monitorFrame:addFrame():setSize(monitorX, monitorY):hide()

    local function addMonitorLabel(name, data, yPos, textColor)
        local label = mainGuiFrame:addLabel()
            :setText(name .. ": " .. tostring(data.rate) .. " FE/t")
            :setPosition(1, yPos)
            :setSize("parent.w", 1)
            :setBackground(colors.gray)
            :setForeground(textColor)

        table.insert(energyMonitorLabels, label)
        return yPos + 1 -- Return the next position for a label
    end

    local function updateGui()
        mainGuiFrame
            :setBackground(colors.black)

        mainGuiFrame
            :addLabel()
            :setText("Energy Monitors")
            :setPosition(1, 1)
            :setSize("parent.w", 1)
            :setBackground(colors.black)
            :setForeground(colors.blue)

        pausedFrame
            :setBackground(colors.gray)
        pausedFrame
            :addLabel()
            :setText("OFFLINE")
            :setForeground(colors.red)
            :setTextAlign("right")

        while true do
            if not shouldUpdate then
                pausedFrame:show()
            else
                pausedFrame:hide()
                -- Remove existing labels
                for _, label in ipairs(energyMonitorLabels) do
                    label:remove()
                end
                energyMonitorLabels = {} -- Reset the table for the next iteration

                local yPos = 3           -- Start position for the first monitor label
                local totalProducerRate = 0
                local totalConsumerRate = 0

                -- Heading for Producers
                local producerHeading = mainGuiFrame:addLabel()
                    :setText("Producers")
                    :setPosition(1, yPos)
                    :setSize("parent.w", 1)
                    :setBackground(colors.blue)
                    :setForeground(colors.white)
                table.insert(energyMonitorLabels, producerHeading)
                yPos = yPos + 1

                -- Add Producer labels
                for name, data in pairs(localEnergyMonitors) do
                    if data.energyType == "Producer" then
                        yPos = addMonitorLabel(name, data, yPos, colors.lime)
                        totalProducerRate = totalProducerRate + data.rate
                    end
                end

                -- Total for Producers
                local producerTotalLabel = mainGuiFrame:addLabel()
                    :setText("Total: " .. tostring(totalProducerRate) .. " FE/t")
                    :setPosition(1, yPos)
                    :setSize("parent.w", 1)
                    :setTextAlign("right")
                    :setBackground(colors.black)
                    :setForeground(colors.green)
                table.insert(energyMonitorLabels, producerTotalLabel)
                yPos = yPos + 2 -- Space before Consumer heading


                -- Heading for Consumers
                local consumerHeading = mainGuiFrame:addLabel()
                    :setText("Consumers")
                    :setPosition(1, yPos)
                    :setSize("parent.w", 1)
                    :setBackground(colors.blue)
                    :setForeground(colors.white)
                table.insert(energyMonitorLabels, consumerHeading)
                yPos = yPos + 1

                -- Add Consumer labels
                for name, data in pairs(localEnergyMonitors) do
                    if data.energyType == "Consumer" then
                        yPos = addMonitorLabel(name, data, yPos, colors.red)
                        totalConsumerRate = totalConsumerRate + data.rate
                    end
                end

                -- Total for Consumers
                local consumerTotalLabel = mainGuiFrame:addLabel()
                    :setText("Total: " .. tostring(totalConsumerRate) .. " FE/t")
                    :setPosition(1, yPos)
                    :setSize("parent.w", 1)
                    :setTextAlign("right")
                    :setBackground(colors.black)
                    :setForeground(colors.red)
                table.insert(energyMonitorLabels, consumerTotalLabel)
            end

            sleep(2) -- Refresh the GUI every 5 seconds
        end
    end

    local peripheralPollingThread = monitorFrame:addThread()
    peripheralPollingThread:start(pollPeripherals)

    local incomingThread = monitorFrame:addThread()
    incomingThread:start(listenForData)

    local refreshLocalEnergyMonitorsThread = monitorFrame:addThread()
    refreshLocalEnergyMonitorsThread:start(refreshLocalEnergyMonitors)

    local updateGuiThread = monitorFrame:addThread()
    updateGuiThread:start(updateGui)

    basalt.autoUpdate()
end

run()

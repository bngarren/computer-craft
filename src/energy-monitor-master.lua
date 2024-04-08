-- Attempt to load the modules
local util = require("util")

local basalt = util.ensureModuleExists("basalt", function(...)
    -- Command to download from Pastebin
    return shell.run("wget", "run", "https://basalt.madefor.cc/install.lua", "release", "latest.lua", ...)
end
)
-- Gui updates
local UPDATE_INTERVAL = 2                 -- seconds
-- How long until a local monitor is removed if no updates
local EXPIRATION_TIME = 15000             -- 15 seconds
local REFRESH_LOCAL_MONITORS_INTERVAL = 5 --seconds
local POLL_PERIPHERALS_INTERVAL = 5       -- seconds
local NETWORK_PROTOCOL = "energy-monitor"

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

        util.coloredWrite("Tracking " .. numberOfMonitors .. " local energy monitors.", colors.lightGray)
        -- logToFile(textutils.serialize(localEnergyMonitors) .. " - " .. os.time())
        sleep(REFRESH_LOCAL_MONITORS_INTERVAL)
    end
end

local function listenForData()
    while true do
        local senderId, message, protocol = rednet.receive(NETWORK_PROTOCOL)

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
    -- print("Checking peripherals")
    -- Use the utility function to check for and wrap required peripherals
    local peripheralsReady = util.checkSpecifiedPeripherals(requiredPeripherals)

    if peripheralsReady then
        -- print("All required peripherals are present. Continuing operations...")

        --ensure modem is open for rednet and on protocol
        if not rednet.isOpen(peripheral.getName(modem)) then
            util.initNetwork(modem, NETWORK_PROTOCOL, os.getComputerLabel())
        end
        return true
    else
        util.coloredWrite("One or more required peripherals are missing. Paused operations.", colors.yellow)
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
        sleep(POLL_PERIPHERALS_INTERVAL)
    end
end


-- Main logic
local function run()
    term.clear()
    print("\n")
    util.coloredWrite("Energy Monitor Master - this is computer id #" .. os.getComputerID(), colors.blue)
    print("\n")

    -- Initial peripherals check
    if not checkPeripherals() then
        printError("Couldn't start")
        return
    end

    -- Ensure computer is labeled
    os.setComputerLabel("master")

    -- Initialize network (modem open and rednet host on protocol)
    util.initNetwork(modem, NETWORK_PROTOCOL, os.getComputerLabel())

    -- GUI Setup
    local monitorFrame = basalt.addMonitor():setMonitor(peripheral.getName(monitor))
    monitorFrame.setTextScale(0.5)
    local mainGuiFrame, pausedFrame = monitorFrame:addFrame(), monitorFrame:addFrame():hide()
    local energyMonitorLabels = {}

    local monitorX, monitorY = monitorFrame.getSize()

    mainGuiFrame = monitorFrame:addFrame():setSize(monitorX, monitorY)
    pausedFrame = monitorFrame:addFrame():setSize(monitorX, monitorY):hide()


    -- Define helper functions for GUI updates
    local function addSectionHeading(yPos, text, backgroundColor, textColor)
        local label = mainGuiFrame:addLabel()
            :setText(text)
            :setPosition(1, yPos)
            :setSize("parent.w", 1)
            :setBackground(backgroundColor)
            :setForeground(textColor)
        table.insert(energyMonitorLabels, label)
        return yPos + 1
    end

    local function addTotalLabel(yPos, text, textColor)
        local label = mainGuiFrame:addLabel()
            :setText(text)
            :setPosition(1, yPos)
            :setSize("parent.w", 1)
            :setForeground(textColor)
            :setTextAlign("right")
        table.insert(energyMonitorLabels, label)
        return yPos + 1
    end

    local function addMonitorLabel(yPos, name, rate, textColor)
        local text = name .. ": " .. util.formatNumber(rate) .. " FE/t"
        local label = mainGuiFrame:addLabel()
            :setText(text)
            :setPosition(1, yPos)
            :setSize("parent.w", 1)
            :setForeground(textColor)
        table.insert(energyMonitorLabels, label)
        return yPos + 1
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
                energyMonitorLabels = {}     -- Reset the table for the next iteration

                local yPos = 3               -- Start position for the first label
                local totalProducerRate, totalConsumerRate = 0, 0

                -- Separate and sort the producers and consumers
                local producers, consumers = {}, {}
                for name, data in pairs(localEnergyMonitors) do
                    if data.energyType == "Producer" then
                        table.insert(producers, { name = name, rate = data.rate })
                        totalProducerRate = totalProducerRate + data.rate
                    elseif data.energyType == "Consumer" then
                        table.insert(consumers, { name = name, rate = data.rate })
                        totalConsumerRate = totalConsumerRate + data.rate
                    end
                end
                table.sort(producers, function(a, b) return a.name < b.name end)
                table.sort(consumers, function(a, b) return a.name < b.name end)

                -- Add labels for producers
                yPos = addSectionHeading(yPos, "Producers", colors.blue, colors.white)
                for _, p in ipairs(producers) do
                    yPos = addMonitorLabel(yPos, p.name, p.rate, colors.lime)
                end
                yPos = addTotalLabel(yPos, "Total: " .. util.formatNumber(totalProducerRate) .. " FE/t", colors.green)

                -- Add labels for consumers
                yPos = yPos + 1     -- Optional: Add a space between sections
                yPos = addSectionHeading(yPos, "Consumers", colors.blue, colors.white)
                for _, c in ipairs(consumers) do
                    yPos = addMonitorLabel(yPos, c.name, c.rate, colors.red)
                end
                yPos = addTotalLabel(yPos, "Total: " .. util.formatNumber(totalConsumerRate) .. " FE/t", colors.red)

                sleep(UPDATE_INTERVAL)     -- Refresh the GUI periodically
            end
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

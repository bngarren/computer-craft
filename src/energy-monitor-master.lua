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

local EXPIRATION_TIME = 15000 -- 15 seconds in milliseconds for this example
local localEnergyMonitors = {}
local function refreshLocalEnergyMonitors()
    while true do
        local currentTime = os.epoch("utc")
        for name, data in pairs(localEnergyMonitors) do
            if (currentTime - data.time) > EXPIRATION_TIME then
                -- Monitor hasn't sent an update in over the expiration time
                localEnergyMonitors[name] = nil -- Remove expired monitor
                -- logToFile("Removed expired monitor: " .. name)
            end
        end

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
            -- basalt.debug("Received 'energyRate' from #" .. senderId .. " with name: " .. data.name .. "and payload: " ..data.payload)
            localEnergyMonitors[data.name] = {
                energyType = data.energyType,
                rate = data.payload,
                time = os.epoch("utc")
            }
        end
    end
end


-- Main logic
local function run()
    local modem, monitor
    -- Identify wireless modem
    local modems = { peripheral.find("modem", function(name, modem)
        return modem.isWireless() -- Check this modem is wireless.
    end) }
    if #modems == 0 then
        error("Missing wireless modem")
    else
        modem = modems[1] -- pick the first
        print("Using wireless modem on side: " .. peripheral.getName(modem))
    end

    -- Identify monitor (required)
    local monitors = { peripheral.find("monitor") }
    if #monitors ~= 0 then
        monitor = monitors[1]
        print("Using Monitor on side: " .. peripheral.getName(monitor))
    else
        error("Missing monitor")
    end

    -- Ensure computer is labeled
    os.setComputerLabel("master")

    -- Identify network and master computer
    rednet.open(peripheral.getName(modem))
    rednet.host("energy-monitor", os.getComputerLabel())

    -- GUI
    local main = basalt.createFrame()
    local monitorFrame
    local energyMonitorLabels = {}

    monitor.setTextScale(0.5)
    monitorFrame = basalt.addMonitor():setMonitor(peripheral.getName(monitor))

    monitorFrame
        :setBackground(colors.black)

    local titleLabel = monitorFrame
        :addLabel()
        :setText("Energy Monitors")
        :setPosition(1, 1)
        :setSize("parent.w", 1)
        :setBackground(colors.black)
        :setForeground(colors.blue)

    local function addMonitorLabel(name, data, yPos, textColor)
        local label = monitorFrame:addLabel()
            :setText(name .. ": " .. tostring(data.rate) .. " FE/t")
            :setPosition(1, yPos)
            :setSize("parent.w", 1)
            :setBackground(colors.gray)
            :setForeground(textColor)

        table.insert(energyMonitorLabels, label)
        return yPos + 1 -- Return the next position for a label
    end

    local function updateGui()
        while true do
            -- Remove existing labels
            for _, label in ipairs(energyMonitorLabels) do
                label:remove()
            end
            energyMonitorLabels = {} -- Reset the table for the next iteration

            local yPos = 3           -- Start position for the first monitor label
            local totalProducerRate = 0
            local totalConsumerRate = 0

            -- Heading for Producers
            local producerHeading = monitorFrame:addLabel()
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
            local producerTotalLabel = monitorFrame:addLabel()
                :setText("Total: " .. tostring(totalProducerRate) .. " FE/t")
                :setPosition(1, yPos)
                :setSize("parent.w", 1)
                :setTextAlign("right")
                :setBackground(colors.black)
                :setForeground(colors.green)
            table.insert(energyMonitorLabels, producerTotalLabel)
            yPos = yPos + 2 -- Space before Consumer heading


            -- Heading for Consumers
            local consumerHeading = monitorFrame:addLabel()
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
            local consumerTotalLabel = monitorFrame:addLabel()
                :setText("Total: " .. tostring(totalConsumerRate) .. " FE/t")
                :setPosition(1, yPos)
                :setSize("parent.w", 1)
                :setTextAlign("right")
                :setBackground(colors.black)
                :setForeground(colors.red)
            table.insert(energyMonitorLabels, consumerTotalLabel)

            sleep(2) -- Refresh the GUI every 5 seconds
        end
    end

    -- START
    local incomingThread = main:addThread()
    incomingThread:start(listenForData)

    local refreshLocalEnergyMonitorsThread = main:addThread()
    refreshLocalEnergyMonitorsThread:start(refreshLocalEnergyMonitors)

    local updateGuiThread = main:addThread()
    updateGuiThread:start(updateGui)

    basalt.autoUpdate()
end

run()

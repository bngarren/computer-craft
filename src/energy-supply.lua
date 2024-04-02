local ENERGY_CHANGE_THRESHOLD = 0.5
local ENERGY_LEVEL_RED = 20    -- percent
local ENERGY_LEVEL_ORANGE = 50 -- percent
local ENERGY_LEVEL_YELLOW = 70 -- percent


-- Attempt to load the modules
local util = require("util")

local basalt = util.ensureModuleExists("basalt", function(...)
    -- Command to download from Pastebin
    shell.run("wget", "run", "https://basalt.madefor.cc/install.lua", "release", "latest.lua", ...)
end
)

local function isEnergyStorage(peripheralName)
    local methods = peripheral.getMethods(peripheralName) or {}

    -- Debug: Print all methods for a specific peripheral
    -- if peripheralName == "energyCell_0" then
    --     print(peripheralName .. " methods:")
    --     for _, method in ipairs(methods) do
    --         print("- " .. method)
    --     end
    -- end

    local requiredMethods = { "getEnergy", "getMaxEnergy" }
    for _, requiredMethod in ipairs(requiredMethods) do
        if not util.tableContains(methods, requiredMethod) then
            return false
        end
    end
    return true
end


local function formatNumber(num)
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

local function getPercentColor(val)
    if val < ENERGY_LEVEL_RED then
        return colors.red
    elseif val < ENERGY_LEVEL_ORANGE then
        return colors.orange
    elseif val < ENERGY_LEVEL_YELLOW then
        return colors.yellow
    else
        return colors.green
    end
end

local function setEnergyChangeLabel(label, val)
    if val < -ENERGY_CHANGE_THRESHOLD then
        label:setForeground(colors.red)
        label:setText("--")
    elseif val < 0 then
        label:setForeground(colors.red)
        label:setText("-")
    elseif math.abs(val) <= 0.0000005 then
        label:setText("")
    elseif val < ENERGY_CHANGE_THRESHOLD then
        label:setForeground(colors.lime)
        label:setText("+")
    elseif val >= ENERGY_CHANGE_THRESHOLD then
        label:setForeground(colors.lime)
        label:setText("++")
    else
        label:setText("")
    end
end


local oldEnergyStored = 0

local lastTime = os.epoch("utc") -- Initialize with the current time
local function getEnergyChange(oldEnergy, newEnergy)
    local currentTime = os.epoch("utc")
    local interval = (currentTime - lastTime) / 1000 -- Convert milliseconds to seconds
    lastTime = currentTime                           -- Update lastTime for the next iteration

    if interval > 0 then
        local deltaRate = (newEnergy - oldEnergy) / interval
        return deltaRate
    else
        return 0
    end
end

local modem, monitor, energyStorage
local shouldUpdate = false

local function checkPeripherals()
    local checkModem = nil
    local checkMonitor = nil
    local checkEnergyStorage = nil

    print("Checking peripherals...")
    checkModem = peripheral.find("modem")
    checkMonitor = peripheral.find("monitor")

    local peripheralNames = peripheral.getNames()
    for _, name in ipairs(peripheralNames) do
        -- print(name)
        if isEnergyStorage(name) then
            checkEnergyStorage = peripheral.wrap(name)
        end
    end

    local currentStatus = checkModem ~= nil and checkMonitor ~= nil and checkEnergyStorage ~= nil

    -- Only print messages if the status changed
    if currentStatus then
        print("All essential peripherals are present. Resuming updates.")
        shouldUpdate = true
        modem = checkModem
        monitor = checkMonitor
        energyStorage = checkEnergyStorage
    else
        print("Missing essential peripherals. Updates paused.")
        shouldUpdate = false
        monitor.clear()
    end
    return currentStatus
end

local function pollPeripherals()
    while true do
        sleep(5)
        checkPeripherals()
    end
end

local function getMaxEnergyCapacity(energyStorage)
    if not energyStorage or not energyStorage.getMaxEnergy then
        print("Error: Energy storage peripheral is not available or lacks the getMaxEnergy method.")
        return 0 -- Return a default value indicating failure or unavailability
    end

    local status, result = pcall(energyStorage.getMaxEnergy)
    if not status then
        print("Error calling getMaxEnergy:", result)
        return 0
    end

    return result or 0
end

local function getCurrentEnergyStored(energyStorage)
    if not energyStorage or not energyStorage.getEnergy then
        print("Error: Energy storage peripheral is not available or lacks the getEnergy method.")
        return 0 -- Return a default value indicating failure or unavailability
    end

    local status, result = pcall(energyStorage.getEnergy)
    if not status then
        print("Error calling getEnergy:", result)
        return 0
    end

    return result or 0
end


local function run()
    local monitorFrame = basalt.addMonitor()
    local pausedFrame = monitorFrame
        :addFrame()
        :setPosition(1, 1)
        :setBackground(colors.black)
        :setZIndex(100)
        :hide()
    local pausedLabel = pausedFrame
        :addLabel()
        :setPosition(1, 1)
        :setForeground(colors.red)
        :setText("Offline")

    -- gui
    local energyStoredLabel, energyCapacityLabel, energyPercentLabel, energyChangeLabel, energyProgressbar, energyChangePerTickLabel



    local function update()
        while true do -- Infinite loop to keep updating
            if shouldUpdate and energyStorage then
                pausedFrame:hide()
                -- Fetch current energy and capacity
                local energyCapacity = getMaxEnergyCapacity(energyStorage)
                local energyStored = getCurrentEnergyStored(energyStorage)

                -- Calculate the change in energy
                local rawEnergyChange = getEnergyChange(oldEnergyStored, energyStored)

                oldEnergyStored = energyStored -- Update the old energy level for the next iteration

                local energyPercent = 0
                local energyChangePercent = 0
                if energyCapacity > 0 then
                    energyPercent = math.floor((energyStored / energyCapacity) * 100 + 0.5)
                    energyChangePercent = rawEnergyChange / energyCapacity * 100.0
                end

                energyStoredLabel:setText(formatNumber(energyStored))

                energyCapacityLabel:setText("/" .. formatNumber(energyCapacity))
                energyPercentLabel:setText(string.format("%d%%  ", energyPercent or 1)):setForeground(
                    getPercentColor(
                        energyPercent))

                setEnergyChangeLabel(energyChangeLabel, energyChangePercent)

                energyProgressbar:setProgress(energyPercent)
                if energyPercent <= ENERGY_LEVEL_RED then
                    energyProgressbar:setProgressBar(colors.red, "-", colors.yellow)
                else
                    energyProgressbar:setProgressBar(colors.green, "-", colors.yellow)
                end

                local energyChangePerTick = rawEnergyChange / 20
                energyChangePerTickLabel:setText(formatNumber(math.abs(energyChangePerTick)) .. " FE/t")
            else
                print("Update paused")
                pausedFrame:setSize(monitorFrame.getSize()):show()
            end

            sleep(1)
        end
    end

    local function initializeGui()
        if monitor then
            -- monitor.clear()
            monitorFrame:setMonitor(peripheral.getName(monitor))
            monitor.setTextScale(1)

            monitorFrame
                :setBackground(colors.black)
                :setForeground(colors.white)

            local w, h = monitorFrame:getSize()

            local energyStoredFlexbox = monitorFrame
                :addFlexbox()
                :setSize("parent.w", 1)
                :setBackground(colors.black)
                :setForeground(colors.white)
                :setPosition(1, 1)
                :setSpacing(0)
                :setJustifyContent("space-around")

            -- Energy stored
            energyStoredLabel = energyStoredFlexbox
                :addLabel()
                :setText("")
                :setSize("parent.w/2 - 1", 1)
                -- :setPosition(1, "parent.y")
                -- :setFlexGrow(1)
                :setTextAlign("right")

            -- Energy capacity
            energyCapacityLabel = energyStoredFlexbox
                :addLabel()
                :setText("")
                :setForeground(colors.gray)
                :setSize("parent.w/2 - 1", 1)
            -- :setPosition(5, "parent.y")

            local batteryFlexBox = monitorFrame
                :addFlexbox()
                :setBackground(colors.black)
                :setSize("parent.w-1", 1)
                :setPosition(2, 3)
                :setSpacing(1)
                :setJustifyContent("center")

            -- Energy progress bar
            energyProgressbar = batteryFlexBox
                :addProgressbar()
                :setBackground(colors.lightGray)
                :setSize("parent.w -5", 1)
                -- :setFlexBasis(10)
                :setProgress(0)
                :setDirection(0)
                :setProgressBar(colors.green, "-", colors.yellow)

            -- Energy percentage
            energyPercentLabel = batteryFlexBox
                :addLabel()
                :setText("")
                :setSize(5, 1)
            -- :setFlexBasis(5)

            local energyChangeFlexbox = monitorFrame
                :addFlexbox()
                :setBackground(colors.black)
                :setForeground(colors.white)
                :setSize("parent.w-2", 1)
                :setPosition(1, 5)
                :setSpacing(1)
                :setJustifyContent("center")

            -- Energy change symbol
            energyChangeLabel = energyChangeFlexbox
                :addLabel()
                :setText("")
                :setSize("parent.w/2 - 5", 1)
                :setTextAlign("right")

            -- Energy change per tick
            energyChangePerTickLabel = energyChangeFlexbox
                :addLabel()
                :setText("")
                :setSize("parent.w/2 + 4", 1)
            -- :setFlexGrow(1)

            print("GUI initialized.")
        end
    end

    if checkPeripherals() then
        initializeGui()

        local updateThread = monitorFrame:addThread()
        updateThread:start(update)

        local peripheralPollingThread = monitorFrame:addThread()
        peripheralPollingThread:start(pollPeripherals)
    else
        print("Failed to start, missing essential peripherals.")
    end

    basalt.autoUpdate()
end

run()

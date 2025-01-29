-- main.lua
-- Main script to monitor an energy cube

local core = dofile("bng/common/bng-cc-core/init.lua")

local ppm = core.ppm
local util = core.util

local config = require("config")
local coloredWrite = util.coloredWrite


local args = {...}
if #args > 0 and args[1] == "--version" then
    local installManifestPath = shell.dir() .. "/install_manifest.json"
    if fs.exists(installManifestPath) then
        local file = fs.open(installManifestPath, "r")
        local data = textutils.unserializeJSON(file.readAll())
        file.close()
        coloredWrite("Installed Program: " .. (data.program or "Unknown"), colors.white)
        coloredWrite("Installed Version: " .. (data.version or "Unknown"), colors.lightBlue)
        coloredWrite("Installation Date: " .. (data.date or "Unknown"), colors.lightGray)
    else
        coloredWrite("No installation manifest found.", colors.red)
    end
    return 0
end

-- Mount peripherals
ppm.mount_all()

local thresholdSignal = false

-- Function to monitor energy levels
local function monitor_energy()
    while true do
        local energyStorageMain = config.peripherals.ENERGY_STORAGE_MAIN
        local energyStoragePeripheral = ppm.get(config.peripherals.ENERGY_STORAGE_MAIN.side)

        if energyStoragePeripheral and energyStoragePeripheral.getEnergy and energyStoragePeripheral.getEnergyCapacity then
            local currentEnergy = energyStoragePeripheral.getEnergy()
            local maxEnergy = energyStoragePeripheral.getEnergyCapacity()

            local percentFill = util.round(currentEnergy / maxEnergy * 100, -2)

            print(energyStorageMain.name .. " has energy level: " .. currentEnergy .. " / " .. maxEnergy)
            print(percentFill .. "%")

            -- Redstone control logic
            if percentFill >= config.threshold_high then
                redstone.setOutput(config.threshold_signal_side, true)
                thresholdSignal = true
            elseif percentFill < config.threshold_low and thresholdSignal then
                redstone.setOutput(config.threshold_signal_side, false)
                thresholdSignal = false
            end
        else
            print("'" .. energyStorageMain.name .. "'" .. " not found or disconnected!")
        end


        os.sleep(config.sample_rate) -- Refresh every x seconds
    end
end


monitor_energy()

-- startup.lua
-- Monitor an energy storage

-- Load bng-cc-core and init the package env -- *Must come before any other lib requires*
local core = require("/bng.lib.bng-cc-core.bng-cc-core")
-- Fixes package.path to allow easier requiring of lib modules
core.initenv.run()

-- Build logger singleton
local log = core.log.Builder.new()
    :with_level("trace")
    :with_monitor_output("top")
    :build()

-- Load libs
local ppm = core.ppm
local util = core.util

-- Program files
local config = require("base-energy-monitor.config") 

log:info("startup.lua initialized!")



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

            log:info("%s has energy level: %s/%s (%s%%)", energyStorageMain.name, currentEnergy, maxEnergy, percentFill)

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

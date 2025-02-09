-- config.lua
-- Peripheral configuration file


local config = {
    sample_rate = 4,
    threshold_low = 60,
    threshold_high = 90,
    threshold_signal_side = "back",
    peripherals = {
        ENERGY_STORAGE_MAIN = { side = "right", name = "Energy - Main" },
        MONITOR = { side = "left", name = "Primary Monitor" },
    }
}

return config
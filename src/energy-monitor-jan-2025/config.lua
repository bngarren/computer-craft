-- config.lua
-- Peripheral configuration file


local config = {
    sample_rate = 5,
    threshold_low = 60,
    threshold_high = 90,
    threshold_signal_side = "back",
    peripherals = {
        ENERGY_STORAGE_MAIN = { side = "left", name = "Energy - Main" },
        MONITOR = { side = "top", name = "Primary Monitor" },
    }
}

return config
-- startup.lua
-- This script runs main.lua at startup

local function run_main()
    if fs.exists("main.lua") then
        shell.run("main.lua")
    else
        print("Error: main.lua not found!")
    end
end

run_main()
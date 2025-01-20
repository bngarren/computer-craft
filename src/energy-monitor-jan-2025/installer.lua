--[[
    GitHub Repository Script Installer for ComputerCraft
    Author: Ben Garren
    Repository URL: https://github.com/bngarren/computer-craft
    Last Updated: 01/20/2025

    Purpose:
    This script automates the process of installing Lua scripts from my GitHub repository into ComputerCraft computers. 
    It supports automatic dependency resolution via .deps files, ensuring all required scripts are downloaded and available for execution.
]]

-- Define the base URL for raw user content on GitHub.
local baseURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/energy-monitor-jan-2025"

-- Manifest of files in the remote directory (manual listing required, no API for this)
local files = {
    "startup.lua",
    "main.lua",
    "config.lua",
    "ppm.lua",
    "util.lua"
}

-- -- -- implementation -- -- --

local newFiles = {}
local updatedFiles = {}
local removedFiles = {}
local localFiles = fs.list("/")
local localLuaFiles = {}

local function coloredWrite(text, color)
    if not term then return end
    local defaultColor = term.getTextColor()  -- Save the current text color
    term.setTextColor(color)                  -- Set the new text color
    write(text.."\n")                               -- Write the text
    term.setTextColor(defaultColor)           -- Reset the text color back to default
end



-- Identify local Lua files
for _, file in ipairs(localFiles) do
    if file:match("%.lua$") then
        localLuaFiles[file] = true
    end
end

-- Download and update files
for _, filename in ipairs(files) do
    local fileURL = baseURL .. filename
    local exists = fs.exists(filename)
    if exists then
        table.insert(updatedFiles, filename)
        fs.delete(filename)
    else
        table.insert(newFiles, filename)
    end
    shell.run("wget", fileURL, filename)
end

-- Identify removed files
for file in pairs(localLuaFiles) do
    if not table.contains(files, file) then
        table.insert(removedFiles, file)
        fs.delete(file)
    end
end

-- Print summary
coloredWrite("Installation Summary:", colors.lime)
coloredWrite("New Files:", colors.yellow)
for _, file in ipairs(newFiles) do print("  " .. file) end
coloredWrite("Updated Files:", colors.cyan)
for _, file in ipairs(updatedFiles) do print("  " .. file) end
coloredWrite("Removed Files:", colors.red)
for _, file in ipairs(removedFiles) do print("  " .. file) end

coloredWrite("Installation complete.", colors.lime)

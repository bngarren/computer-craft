-- GitHub Repository Script Installer for ComputerCraft
-- Author: Ben Garren
-- Repository URL: https://github.com/bngarren/computer-craft
-- Last Updated: 01/20/2025

-- Purpose:
-- This script automates the process of installing Lua scripts from my GitHub repository into ComputerCraft computers.
-- It downloads and overwrites all .lua files in the specified base URL and provides a summary of changes.

local function coloredWrite(text, color)
    if term and term.isColor() then
        local defaultColor = term.getTextColor()
        term.setTextColor(color)
        print(text)
        term.setTextColor(defaultColor)
    else
        print(text)
    end
end

-- Get command line argument for subdirectory
local args = {...}
if #args < 1 then
    coloredWrite("Usage: installer <subdirectory> | installer status", colors.red)
    return
end

local subdirectory = args[1]
local baseURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/" .. subdirectory .. "/"
local installManifestFile = "install_manifest.json"

-- Function to download a file with retries
local function downloadFile(url, filename, attempts)
    attempts = attempts or 3
    for i = 1, attempts do
        if shell.run("wget", url, filename) then return true end
        coloredWrite("Download failed, retrying... (" .. i .. "/" .. attempts .. ")", colors.red)
        os.sleep(2)
    end
    return false
end

-- Handle status command
if subdirectory == "status" then
    if fs.exists(installManifestFile) then
        local file = fs.open(installManifestFile, "r")
        local data = textutils.unserializeJSON(file.readAll())
        file.close()
        coloredWrite("Installed Program: " .. (data.program or "Unknown"), colors.white)
        coloredWrite("Installed Version: " .. (data.version or "Unknown"), colors.lightBlue)
        coloredWrite("Installation Date: " .. (data.date or "Unknown"), colors.lightGray)
    else
        coloredWrite("No installation manifest found.", colors.red)
    end
    return
end

-- Download manifest.json
local manifestURL = baseURL .. "manifest.json"
local manifestFile = "manifest.json"
if not downloadFile(manifestURL, manifestFile) then
    coloredWrite("Error: No manifest.json found in " .. baseURL, colors.red)
    return
end

-- Read manifest.json
local file = fs.open(manifestFile, "r")
local content = file.readAll()
file.close()
fs.delete(manifestFile)

local manifest = textutils.unserializeJSON(content)
if not manifest or not manifest.files then
    coloredWrite("Error: Invalid manifest.json structure", colors.red)
    return
end

local files = manifest.files
coloredWrite("Manifest found, containing " .. #files .. " files.", colors.white)

local newFiles = {}
local updatedFiles = {}
local removedFiles = {}
local localFiles = fs.list("/")
local localLuaFiles = {}

-- Utility function to check if a table contains a value
local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

-- Identify local Lua files
for _, file in ipairs(localFiles) do
    if file:match("%.lua$") and file ~= "installer.lua" then
        localLuaFiles[file] = true
    end
end

-- Download and update files
for _, filename in ipairs(files) do
    local fileURL = baseURL .. filename
    if filename == "config.lua" and fs.exists(filename) then
        coloredWrite("Skipping " .. filename .. " to preserve user settings.", colors.yellow)
    else
        local exists = fs.exists(filename)
        if exists then
            table.insert(updatedFiles, filename)
            fs.delete(filename)
        else
            table.insert(newFiles, filename)
        end
        downloadFile(fileURL, filename)
    end
end

-- Identify removed files
for file in pairs(localLuaFiles) do
    if not tableContains(files, file) then
        table.insert(removedFiles, file)
        fs.delete(file)
    end
end

-- Write installation manifest
local installManifest = {
    program = subdirectory,
    version = manifest.version,
    date = os.date("%Y-%m-%d %H:%M:%S")
}
local imFile = fs.open(installManifestFile, "w")
imFile.write(textutils.serializeJSON(installManifest))
imFile.close()

-- Print summary
coloredWrite("\nInstallation Summary:", colors.lime)
coloredWrite("Repo: " .. baseURL, colors.white)
coloredWrite("Program: " .. subdirectory, colors.white)

if manifest.version then
    coloredWrite("Version: " .. manifest.version, colors.lightBlue)
end
if manifest.description then
    coloredWrite("Description: " .. manifest.description, colors.lightGray)
end

coloredWrite("New Files:", colors.yellow)
if #newFiles == 0 then print("  none") end
for _, file in ipairs(newFiles) do print("  + " .. file) end

coloredWrite("Updated Files:", colors.cyan)
if #updatedFiles == 0 then print("  none") end
for _, file in ipairs(updatedFiles) do print("  * " .. file) end

coloredWrite("Removed Files:", colors.red)
if #removedFiles == 0 then print("  none") end
for _, file in ipairs(removedFiles) do print("  - " .. file) end

coloredWrite("Installation complete.", colors.lime)

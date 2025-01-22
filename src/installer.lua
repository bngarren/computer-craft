-- GitHub Repository Script Installer for ComputerCraft
-- Author: Ben Garren
-- Repository URL: https://github.com/bngarren/computer-craft
-- Last Updated: 01/20/2025

local installRootDir = "/bng"

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
local installDir = installRootDir .. "/" .. subdirectory .. "/"
local baseURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/" .. subdirectory .. "/"
local installManifestFile = installDir .. "install_manifest.json"

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

-- Ensure install directory exists
if not fs.exists(installDir) then fs.makeDir(installDir) end

-- Download manifest.json
local manifestURL = baseURL .. "manifest.json"
local manifestFile = installDir .. "manifest.json"
if not downloadFile(manifestURL, manifestFile) then
    coloredWrite("Error: No manifest.json found in " .. baseURL, colors.red)
    return
end

-- Read manifest.json
local file = fs.open(manifestFile, "r")
local content = file.readAll()
file.close()

local manifest = textutils.unserializeJSON(content)
if not manifest or not manifest.files then
    coloredWrite("Error: Invalid manifest.json structure", colors.red)
    return
end

local files = manifest.files
coloredWrite("Manifest found, containing " .. #files .. " files.", colors.white)

local newFiles, updatedFiles = {}, {}

-- Download and update files
for _, filename in ipairs(files) do
    local fileURL = baseURL .. filename
    local filePath = installDir .. filename

    if filename == "config.lua" and fs.exists(filePath) then
        coloredWrite("Skipping " .. filename .. " to preserve user settings.", colors.yellow)
    else
        local exists = fs.exists(filePath)
        if exists then
            table.insert(updatedFiles, filePath)
            fs.delete(filePath)
        else
            table.insert(newFiles, filePath)
        end
        downloadFile(fileURL, filePath)
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

-- Generate a startup.lua in the program directory
local startupContent = [[
local manifestPath = "]] .. installDir .. [[manifest.json"
local baseURL = "]] .. baseURL .. [["
local manifestURL = baseURL .. "manifest.json"
local mainScript = "]] .. installDir .. [[main.lua"

-- Function to check for updates
local function checkForUpdates()
    if not http then return end
    if not fs.exists(manifestPath) then return end

    local file = fs.open(manifestPath, "r")
    local localManifest = textutils.unserializeJSON(file.readAll())
    file.close()

    local request = http.get(manifestURL)
    if not request then return end
    local remoteManifest = textutils.unserializeJSON(request.readAll())
    request.close()

    if remoteManifest.version ~= localManifest.version then
        print("A new version (" .. remoteManifest.version .. ") is available.")
        print("Do you want to update? (y/n)")
        local choice = read()
        if choice:lower() == "y" then
            shell.run("installer.lua", "]] .. subdirectory .. [[")
            os.reboot()
        end
    else
        print("Up to date. v" .. localManifest.version)
    end
end

-- Run update check, then start the program
checkForUpdates()
shell.run(mainScript)
]]

local startupFile = fs.open(installDir .. "startup.lua", "w")
startupFile.write(startupContent)
startupFile.close()
coloredWrite("Generated startup.lua with update checker.", colors.lime)

-- Prompt user to overwrite global startup.lua
local globalStartupPath = "/startup.lua"
local programStartupPath = installDir .. "startup.lua"

if fs.exists(globalStartupPath) then
    coloredWrite("A startup.lua script already exists.", colors.yellow)
    coloredWrite("Do you want to overwrite it to launch this program at startup? (y/n)", colors.orange)
    local choice = read()
    if choice:lower() == "y" then
        fs.delete(globalStartupPath)
        fs.copy(programStartupPath, globalStartupPath)
        coloredWrite("startup.lua has been updated to run this program on startup.", colors.lime)
    else
        coloredWrite("Keeping existing startup.lua. You can run this program manually:", colors.white)
        coloredWrite("cd " .. installDir .. " && startup.lua", colors.lightBlue)
    end
else
    fs.copy(programStartupPath, globalStartupPath)
    coloredWrite("Created new startup.lua to launch the program at startup.", colors.lime)
end

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

coloredWrite("Installation complete.", colors.lime)

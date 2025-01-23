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

-- Get command line arguments
local args = {...}
if #args < 1 then
    coloredWrite("Usage: installer <programName> [--version]", colors.red)
    return
end

local programName = args[1]
local installDir = installRootDir .. "/" .. programName .. "/"
local baseURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/" .. programName .. "/"
local manifestURL = baseURL .. "manifest.json"
local installManifestFile = installDir .. "install_manifest.json"

-- Function to fetch remote manifest.json
local function fetchRemoteManifest()
    if not http then
        coloredWrite("HTTP API is disabled. Cannot fetch remote manifest.", colors.red)
        return nil
    end
    
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local request = http.get({ url = manifestURL, headers = headers })
    if not request then
        coloredWrite("Failed to retrieve remote manifest.json.", colors.red)
        return nil
    end

    local content = request.readAll()
    request.close()

    local manifest = textutils.unserializeJSON(content)
    if not manifest or not manifest.files or not manifest.version then
        coloredWrite("Invalid remote manifest.json structure.", colors.red)
        return nil
    end

    return manifest
end

-- Check for the --version flag
if #args > 1 and args[2] == "--version" then
    if fs.exists(installManifestFile) then
        local file = fs.open(installManifestFile, "r")
        local data = textutils.unserializeJSON(file.readAll())
        file.close()
        coloredWrite("Installed Program: " .. (data.program or "Unknown"), colors.white)
        coloredWrite("Installed Version: " .. (data.version or "Unknown"), colors.lightBlue)
        coloredWrite("Installation Date: " .. (data.date or "Unknown"), colors.lightGray)
    else
        coloredWrite("No installation manifest found for '" .. programName .. "'.", colors.red)
    end
    return
end

-- Fetch remote manifest
local manifest = fetchRemoteManifest()
if not manifest then return end

local files = manifest.files

-- Ensure install directory exists
if not fs.exists(installDir) then fs.makeDir(installDir) end

local newFiles, updatedFiles = {}, {}

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

-- Download and update files based on remote manifest
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
    program = programName,
    version = manifest.version,
    date = os.date("%Y-%m-%d %H:%M:%S")
}
local imFile = fs.open(installManifestFile, "w")
imFile.write(textutils.serializeJSON(installManifest))
imFile.close()

-- Generate a startup.lua in the program directory with update checking
local startupContent = [[
local manifestPath = "]] .. installManifestFile .. [["
local baseURL = "]] .. baseURL .. [["
local manifestURL = baseURL .. "manifest.json"
local mainScript = "]] .. installDir .. [[main.lua"

local function fetchRemoteVersion()
    if not http then return nil end
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local request = http.get({ url = manifestURL, headers = headers })
    if not request then return nil end
    local content = request.readAll()
    request.close()
    local manifest = textutils.unserializeJSON(content)
    return manifest and manifest.version or nil
end

local function fetchLocalVersion()
    if not fs.exists(manifestPath) then return nil end
    local file = fs.open(manifestPath, "r")
    local manifest = textutils.unserializeJSON(file.readAll())
    file.close()
    return manifest and manifest.version or nil
end

local function checkForUpdates()
    local localVersion = fetchLocalVersion()
    local remoteVersion = fetchRemoteVersion()

    print("Local version: " .. localVersion)
    print("Remote version: " .. remoteVersion)

    if not localVersion or not remoteVersion then return end

    if remoteVersion ~= localVersion then
        print("A new version (" .. remoteVersion .. ") is available.")
        print("Do you want to update? (y/n)")
        local choice = read()
        if choice:lower() == "y" then
            shell.run("installer.lua", "]] .. programName .. [[")
            os.reboot()
        end
    end
end

-- Run update check before launching program
checkForUpdates()

if fs.exists(mainScript) then
    shell.run(mainScript)
else
    print("Error: main.lua not found in " .. mainScript)
end
]]

local startupFile = fs.open(installDir .. "startup.lua", "w")
startupFile.write(startupContent)
startupFile.close()
coloredWrite("Generated startup.lua with update checker.", colors.lime)

-- Prompt user before overwriting global startup.lua
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
    end
else
    fs.copy(programStartupPath, globalStartupPath)
    coloredWrite("Created new startup.lua to launch the program at startup.", colors.lime)
end

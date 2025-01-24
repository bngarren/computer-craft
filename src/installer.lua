-- GitHub Repository Script Installer for ComputerCraft
-- Author: Ben Garren
-- Last Updated: 01/23/2025

-- Define repository URLs
local repo_url_base = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src"
local repo_url_common = repo_url_base .. "/common"
local installRootPath = "/bng"
local installCommonPath = installRootPath .. "/common"
local installProgramsPath = installRootPath .. "/programs"

-- Ensure common modules path exists
if not fs.exists(installCommonPath) then fs.makeDir(installCommonPath) end
package.path = installCommonPath .. "/?.lua;" .. package.path

-- Require common modules
local moduleManager = require("module_manager")
local updater = require("updater")

-- Function to download a file
local function downloadFile(url, filePath)
    local response = http.get(url)
    if not response then
        print("Error downloading:", filePath)
        return false
    end
    local file = fs.open(filePath, "w")
    file.write(response.readAll())
    file.close()
    return true
end

-- Function to fetch and parse remote JSON manifests
local function fetchRemoteJSON(url)
    local response = http.get(url)
    if not response then return nil end
    local content = response.readAll()
    response.close()
    return textutils.unserializeJSON(content)
end

-- Get command line arguments
local args = {...}
if #args < 1 then
    print("Usage: installer <programName> [--version]")
    return
end

local programName = args[1]
local installDir = installProgramsPath .. "/" .. programName .. "/"
local programURL = repo_url_base .. "/programs/" .. programName .. "/"
local manifestURL = programURL .. "manifest.json"
local installManifestFile = installDir .. "install_manifest.json"

-- Fetch remote program manifest
local remoteManifest = fetchRemoteJSON(manifestURL)
if not remoteManifest then
    print("Failed to retrieve manifest for:", programName)
    return
end

-- **✅ Handling Dependencies (Common Modules)**
if remoteManifest.dependencies then
    moduleManager.ensureModules(remoteManifest.dependencies)
end

-- **✅ Handling Program Files (Main Program & Configs)**
if not fs.exists(installDir) then fs.makeDir(installDir) end

for _, filename in ipairs(remoteManifest.files) do
    local fileURL = programURL .. filename
    local filePath = installDir .. filename

    -- **Skip config.lua if it already exists (preserve user settings)**
    if filename == "config.lua" and fs.exists(filePath) then
        print("Skipping", filename, "(preserving user settings)")
    else
        downloadFile(fileURL, filePath)
    end
end

-- **✅ Store Installation Info**
local installManifest = {
    program = programName,
    version = remoteManifest.version,
    date = os.date("%Y-%m-%d %H:%M:%S")
}
local file = fs.open(installManifestFile, "w")
file.write(textutils.serializeJSON(installManifest))
file.close()

print("Installed '" .. programName .. "' successfully.")

-- **✅ Generate `startup.lua` with auto-update checker**
updater.generateStartup(installDir, programName, programURL, installManifestFile)

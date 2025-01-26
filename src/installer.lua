-- GitHub Repository Script Installer for ComputerCraft
-- Author: Ben Garren
-- Last Updated: 01/23/2025

-- installer.lua

-- Define repository URLs
local repo_url_base = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src"
local repo_url_common = repo_url_base .. "/common"
local installRootPath = "/bng"
local installCommonPath = installRootPath .. "/common"
local installProgramsPath = installRootPath .. "/programs"
local localManifestFile = installCommonPath .. "/common_manifest.json"

-- Ensure common modules directory exists
if not fs.exists(installCommonPath) then fs.makeDir(installCommonPath) end

-- Add `/bng/common/` to package path so Lua can find required modules
package.path = installCommonPath .. "/?.lua;" .. package.path

-- Function to download a file
local function downloadFile(url, filePath)
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local response = http.get({ url = url, headers = headers })
    if not response then
        print("Installer: Error downloading:", url)
        return false
    end

    local file = fs.open(filePath, "w")
    file.write(response.readAll())
    file.close()
    return true
end

-- Function to fetch and parse remote JSON files, e.g. manifests
local function fetchRemoteJSON(url)
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local response = http.get({ url = url, headers = headers })
    if not response then 
        print("Installer: Error downloading JSON file:", url)
        return nil 
    end
    local content = response.readAll()
    response.close()
    return textutils.unserializeJSON(content)
end

-- Function to update local `common_manifest.json`
-- i.e. When this installer manually installs required modules that are needed for this installer
-- Otherwise, common modules used by individual programs should be installed/updated by module_manager
local function updateLocalManifest(moduleName, version)
    local localManifest = {}
    if fs.exists(localManifestFile) then
        local handle = fs.open(localManifestFile, "r")
        local contents = handle.readAll()
        handle.close()
        localManifest = textutils.unserializeJSON(contents) or {}
    end
    localManifest[moduleName] = version

    local file = fs.open(localManifestFile, "w")
    file.write(textutils.serializeJSON(localManifest))
    file.close()
end

local isForceUpdate = false
local args = {...}

-- Check if --force flag is present
for _, arg in ipairs(args) do
    if arg == "--force" then
        isForceUpdate = true
        print("Installer: Force update mode enabled. All common modules will be overwritten.")
    end
end

-- Function to download a module if missing or out-of-date
-- Ensure `common_manifest.json` is up to date when downloading modules
local function ensureModuleExists(moduleName, remoteCommonManifest)
    local modulePath = installCommonPath .. "/" .. moduleName .. ".lua"
    local remoteVersion = remoteCommonManifest[moduleName]

    local localVersion
    if fs.exists(localManifestFile) then
        local f = fs.open(localManifestFile, "r")
        local manifestData = f.readAll()
        f.close()
        local localManifest = textutils.unserializeJSON(manifestData) or {}
        localVersion = localManifest[moduleName]
    end

    if not remoteVersion then
        print("Installer: Error - No version info for", moduleName)
        return false
    end

    if not fs.exists(modulePath) then
        print("Installer: Installing module:", moduleName, " v" .. remoteVersion)
    elseif localVersion == remoteVersion then
        print("Installer: Module is up-to-date:", moduleName, " v" .. remoteVersion)
        return true
    else
        print("Installer: Updating module:", moduleName, " v" .. tostring(localVersion) .. " → v" .. remoteVersion)
    end

    local url = repo_url_common .. "/" .. moduleName .. ".lua"
    if not downloadFile(url, modulePath) then
        print("Installer: ERROR downloading module:", moduleName)
        return false
    end

    print("Installer: Successfully installed module:", moduleName)
    updateLocalManifest(moduleName, remoteVersion)
    return true
end

-- Fetch latest remote common manifest before bootstrapping
local remoteCommonManifest = fetchRemoteJSON(repo_url_common .. "/common_manifest.json")
if not remoteCommonManifest then
    print("Installer: Failed to retrieve remote common manifest.")
    return false
end

-- Ensure core modules are installed
if not ensureModuleExists("module_manager", remoteCommonManifest) or
   not ensureModuleExists("updater", remoteCommonManifest) then
    print("Installer: FATAL - Required core modules missing. Installation cannot proceed.")
    return false
end

-- Optional modules
if not ensureModuleExists("status", remoteCommonManifest) then
    print("Installer: WARNING - Could not install status.lua")
end

-- Require installed modules
local moduleManager = require("module_manager")
local updater = require("updater")

-- Get command line arguments (re-fetching, ignoring the earlier 'args' in scope)
local args = {...}
if #args < 1 then
    print("Usage: installer <programName> [--version]")
    return
end

local programName = args[1]
local installDir = installProgramsPath .. "/" .. programName .. "/"
local programURL = repo_url_base .. "/programs/" .. programName .. "/"
local programManifestURL = programURL .. "manifest.json"
local installManifestFile = installDir .. "install_manifest.json"

-- Fetch remote program manifest
local remoteProgramManifest = fetchRemoteJSON(programManifestURL)
if not remoteProgramManifest then
    print("Installer: Failed to retrieve manifest for:", programName)
    return
end

-- Install Dependencies (Pass `isForceUpdate` to moduleManager)
if remoteProgramManifest.dependencies then
    local result = moduleManager.ensureModules(remoteProgramManifest.dependencies, isForceUpdate)
    if not result then return 1 end
end

-- Install Program Files
if not fs.exists(installDir) then fs.makeDir(installDir) end

for _, filename in ipairs(remoteProgramManifest.files) do
    local fileURL = programURL .. filename
    local filePath = installDir .. filename

    -- Preserve existing config
    if filename == "config.lua" and fs.exists(filePath) then
        print("Installer: Skipping", filename, "(preserving user settings)")
    else
        downloadFile(fileURL, filePath)
    end
end

-- Store Installation Info
local installManifest = {
    program = programName,
    version = remoteProgramManifest.version,
    files = remoteProgramManifest.files,
    dependencies = remoteProgramManifest.dependencies,
    date = os.date("%Y-%m-%d %H:%M:%S")
}

local file = fs.open(installManifestFile, "w")
file.write(textutils.serializeJSON(installManifest))
file.close()

print("Installer: Installed '" .. programName .. "' successfully.")

-- Generate `startup.lua` with auto-update checker
updater.generateStartup(installDir, programName, programURL, installManifestFile)


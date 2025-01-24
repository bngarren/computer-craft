-- GitHub Repository Script Installer for ComputerCraft
-- Author: Ben Garren
-- Last Updated: 01/23/2025

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

-- Fetch remote common manifest
local function fetchRemoteCommonManifest()
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local request = http.get({ url = repo_url_common .. "/common_manifest.json", headers = headers })
    if not request then
        print("Installer: Failed to retrieve remote common manifest.")
        return nil
    end
    local content = request.readAll()
    request.close()
    return textutils.unserializeJSON(content)
end

-- Function to download a module if missing or out-of-date
-- Ensure `common_manifest.json` is up to date when downloading modules
local function ensureModuleExists(moduleName, remoteCommonManifest)
    local modulePath = installCommonPath .. "/" .. moduleName .. ".lua"
    local remoteVersion = remoteCommonManifest[moduleName]
    local localManifest = fs.exists(localManifestFile) and textutils.unserializeJSON(fs.open(localManifestFile, "r").readAll()) or {}

    if not remoteVersion then
        print("Installer: Error - No version info for", moduleName)
        return
    end

    if not fs.exists(modulePath) then
        print("Installer: Downloading missing module:", moduleName, " v" .. remoteVersion)
    else
        if localManifest then
            local localVersion = localManifest[moduleName]
            if localVersion ~= remoteVersion then
                print("Installer: Updating module:", moduleName, " v" .. localVersion .. " to v" .. remoteVersion)
            else
                print("Installer: Module is up-to-date:", moduleName, " v" .. remoteVersion)
                return
            end
        else
            print("Installer: Error - can't find local common_manifest.json file!")
            return
        end
        
    end

    local url = repo_url_common .. "/" .. moduleName .. ".lua"
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local response = http.get({ url = url, headers = headers })

    if response then
        local file = fs.open(modulePath, "w")
        file.write(response.readAll())
        file.close()
        print("Installer: Successfully installed module:", moduleName)

        -- **✅ Update local `common_manifest.json`**
        local localManifest = fs.exists(localManifestFile) and textutils.unserializeJSON(fs.open(localManifestFile, "r").readAll()) or {}
        localManifest[moduleName] = remoteVersion
        local file = fs.open(localManifestFile, "w")
        file.write(textutils.serializeJSON(localManifest))
        file.close()
    else
        print("Installer: Error downloading module:", moduleName)
    end
end

-- Fetch latest remote common manifest before bootstrapping
local remoteCommonManifest = fetchRemoteCommonManifest()
if remoteCommonManifest then
    ensureModuleExists("module_manager", remoteCommonManifest)
    ensureModuleExists("updater", remoteCommonManifest)
end

-- Require installed modules
local moduleManager = require("module_manager")
local updater = require("updater")

-- Function to download a file
local function downloadFile(url, filePath)
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local response = http.get({ url = url, headers = headers })
    if not response then
        print("Installer: Error downloading:", filePath)
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
    print("Installer: Downloaded JSON file:", url)
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
    print("Installer: Failed to retrieve manifest for:", programName)
    return
end

-- Install Dependencies
if remoteManifest.dependencies then
    moduleManager.ensureModules(remoteManifest.dependencies)
end

-- Install Program Files
if not fs.exists(installDir) then fs.makeDir(installDir) end

for _, filename in ipairs(remoteManifest.files) do
    local fileURL = programURL .. filename
    local filePath = installDir .. filename

    if filename == "config.lua" and fs.exists(filePath) then
        print("Installer: Skipping", filename, "(preserving user settings)")
    else
        downloadFile(fileURL, filePath)
    end
end

-- Store Installation Info
local installManifest = {
    program = programName,
    version = remoteManifest.version,
    files = remoteManifest.files,
    dependencies = remoteManifest.dependencies,
    date = os.date("%Y-%m-%d %H:%M:%S")
}
local file = fs.open(installManifestFile, "w")
file.write(textutils.serializeJSON(installManifest))
file.close()

print("Installer: Installed '" .. programName .. "' successfully.")

-- Generate `startup.lua` with auto-update checker
updater.generateStartup(installDir, programName, programURL, installManifestFile)

-- GitHub Repository Script Installer for ComputerCraft
-- Author: Ben Garren
-- Last Updated: 01/23/2025

-- Define repository URLs
local repo_url_base = "https://raw.githubusercontent.com/bngarren/computer-craft/src"
local repo_url_common = repo_url_base .. "/common"
local installRootPath = "/bng"
local installCommonPath = installRootPath .. "/common"
local installProgramsPath = installRootPath .. "/programs"
local commonManifestFile = installCommonPath .. "/common_manifest.json"

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

-- Ensure common directory exists
if not fs.exists(installCommonPath) then fs.makeDir(installCommonPath) end

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
local manifest = fetchRemoteJSON(manifestURL)
if not manifest then
    print("Failed to retrieve manifest for:", programName)
    return
end

-- **✅ Handling Dependencies (Common Modules)**
local function installDependencies(dependencies)
    -- Fetch remote common manifest
    local remoteCommonManifest = fetchRemoteJSON(repo_url_common .. "/common_manifest.json")
    if not remoteCommonManifest then
        print("Failed to retrieve common module manifest.")
        return
    end

    -- Fetch local common manifest (if exists)
    local localCommonManifest = {}
    if fs.exists(commonManifestFile) then
        local file = fs.open(commonManifestFile, "r")
        localCommonManifest = textutils.unserializeJSON(file.readAll())
        file.close()
    end

    for moduleName, moduleInfo in pairs(dependencies) do
        local modulePath = installCommonPath .. "/" .. moduleName .. ".lua"
        local remoteVersion = moduleInfo.version
        local localVersion = localCommonManifest[moduleName]

        if not fs.exists(modulePath) or (localVersion ~= remoteVersion) then
            print("Updating module:", moduleName, "(v" .. remoteVersion .. ")")
            local moduleURL = repo_url_common .. "/" .. moduleName .. ".lua"
            if downloadFile(moduleURL, modulePath) then
                localCommonManifest[moduleName] = remoteVersion
            end
        end
    end

    -- Save updated local common manifest
    local file = fs.open(commonManifestFile, "w")
    file.write(textutils.serializeJSON(localCommonManifest))
    file.close()
end

-- Install dependencies first
if manifest.dependencies then
    installDependencies(manifest.dependencies)
end

-- **✅ Handling Program Files (Main Program & Configs)**
if not fs.exists(installDir) then fs.makeDir(installDir) end

for _, filename in ipairs(manifest.files) do
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
    version = manifest.version,
    date = os.date("%Y-%m-%d %H:%M:%S")
}
local file = fs.open(installManifestFile, "w")
file.write(textutils.serializeJSON(installManifest))
file.close()

print("Installed '" .. programName .. "' successfully.")

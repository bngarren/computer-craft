-- Utility functions
local util = {}

-- Define repository URL
local programs_repo_url = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src"
local bng_cc_core_repo_url = "https://raw.githubusercontent.com/bngarren/bng-cc-core"

-- Define installation paths
local installRootPath = "/bng"
local installCommonPath = installRootPath .. "/common"
local installCorePath = installCommonPath .. "/bng-cc-core"
local installProgramsPath = installRootPath .. "/programs"

-- Safely read JSON files
local function readJSON(filePath)
    if fs.exists(filePath) then
        local file = fs.open(filePath, "r")
        local content = textutils.unserializeJSON(file.readAll())
        file.close()
        return content or {}
    end
    return {}
end

-- Update installed.json in bng-cc-core
local function updateCoreManifest(version, modules)
    local data = { version = version, modules = modules }
    local file = fs.open(installCorePath .. "/installed.json", "w")
    file.write(textutils.serializeJSON(data))
    file.close()
end

-- Fetch remote JSON data (e.g., manifests)
local function fetchRemoteJSON(url)
    local response = http.get({ url = url, headers = { ["Cache-Control"] = "no-cache" } })
    if type(response) == "string" then
        print(response)
        return nil
    end
    if not response then 
        print("Installer: Error - unknown error attempting to GET " .. url)
        return nil
        end
    local content = response.readAll()
    response.close()
    return textutils.unserializeJSON(content)
end

-- Download a file from a URL
local function downloadFile(url, filePath)
    local response = http.get({ url = url, headers = { ["Cache-Control"] = "no-cache" } })
    if not response then return false end
    local file = fs.open(filePath, "w")
    file.write(response.readAll())
    file.close()
    return true
end

local function getCoreModuleURL(version, moduleName)
    return bng_cc_core_repo_url .. "/refs/tags/v" .. version .. "/src/" .. moduleName .. ".lua"
end

-- Retrieve currently installed bng-cc-core modules
local function getCurrentCoreModules()
    local currentModules = {}
    local debugFile = fs.open("/debug_log.txt", "w")

    if not fs.exists(installCorePath) then
        debugFile.write("Debug: installCorePath does not exist.\n")
        debugFile.close()
        return currentModules
    end

    local files = fs.list(installCorePath)

    if type(files) ~= "table" then
        debugFile.write("Debug: fs.list() did not return a table! Type: " .. type(files) .. "\n")
        debugFile.close()
        return currentModules
    end

    for index, file in ipairs(files) do
        local filePath = fs.combine(installCorePath, file)
        debugFile.write("Debug: Checking file: " .. file .. " | Index: " .. tostring(index) .. "\n")

        -- **🔹 Ensure we only process .lua files and ignore installed.json**
        if fs.exists(filePath) and not fs.isDir(filePath) and file:match("%.lua$") then
            local moduleName = file:gsub("%.lua$", "")
            table.insert(currentModules, moduleName)
            debugFile.write("Debug: Added module: " .. moduleName .. "\n")
        end
    end

    debugFile.write("Debug: Final module list: " .. textutils.serialize(currentModules) .. "\n")
    debugFile.close()

    return currentModules
end

-- Fully install `bng-cc-core` with required modules
local function fullInstallCore(version, requiredModules)
    print("Installer: Installing `bng-cc-core` v" .. version .. "...")
    
    -- Create a temporary directory for the new installation
    local tempPath = installCommonPath .. "/_bng-cc-core"
    if fs.exists(tempPath) then fs.delete(tempPath) end
    fs.makeDir(tempPath)
    
    -- Attempt to download all modules first
    for _, module in ipairs(requiredModules) do
        local url = getCoreModuleURL(version, module)
        local filePath = tempPath .. "/" .. module .. ".lua"
        if not downloadFile(url, filePath) then
            print("Installer: Failed to download `bng-cc-core` module: " .. module)
            fs.delete(tempPath)
            return false
        end
    end
    
    -- If all downloads succeeded, remove the old installation and move the new one into place
    if fs.exists(installCorePath) then fs.delete(installCorePath) end
    fs.move(tempPath, installCorePath)
    updateCoreManifest(version, requiredModules)
    print("Installer: Installed `bng-cc-core` v" .. version .. " with modules: " .. table.concat(requiredModules, ", "))
    return true
end

-- Main installer function
local function main(args)
    if #args < 1 then return print("Usage: installer <programName>") end
    local programName = args[1]
    local installDir = installProgramsPath .. "/" .. programName .. "/"
    local programURL = programs_repo_url .. "/programs/" .. programName .. "/"
    local programManifestURL = programURL .. "manifest.json"

    local remoteProgramManifest = fetchRemoteJSON(programManifestURL)
    if not remoteProgramManifest then return print("Installer: Failed to retrieve manifest for:", programName) end

    -- Handle `bng-cc-core` installation
    if remoteProgramManifest["bng-cc-core"] then
        local requiredCore = remoteProgramManifest["bng-cc-core"]
        local requiredCoreVersion = requiredCore.version
        local requiredModules = requiredCore.modules or {}
        local installedCore = readJSON(installCorePath .. "/installed.json")
        local installedCoreVersion = installedCore.version
        
        local currentCoreModules = getCurrentCoreModules()
        local allModules = {}
        for _, module in ipairs(currentCoreModules) do allModules[module] = true end
        for _, module in ipairs(requiredModules) do allModules[module] = true end
        local moduleList = {}
        for module, _ in pairs(allModules) do table.insert(moduleList, module) end

        -- If no previous installation of bng-cc-core, then do full install 
        if not installedCoreVersion then
            if not fullInstallCore(requiredCoreVersion, moduleList) then return print("Installer: Failed to install `bng-cc-core`.") end
        -- Else, do a version comparison to determine how to proceed
        else 
            local versionComparison = util.compare_versions(installedCoreVersion, requiredCoreVersion)
            if versionComparison == 0 then
                print("Installer: bng-cc-core v" .. requiredCoreVersion .. " is required and present.")
            else
                print("Warning: This program requires `bng-cc-core` v" .. requiredCoreVersion .. ", but v" .. installedCoreVersion .. " is installed.")
                print("Would you like to " .. (versionComparison == -1 and "update" or "downgrade") .. " `bng-cc-core` to v" .. requiredCoreVersion .. "? (y/n)")
                if io.read() ~= "y" then return print("Installer: Aborting due to version mismatch.") end
                if not fullInstallCore(requiredCoreVersion, moduleList) then return print("Installer: Failed to install `bng-cc-core`.") end
            end
        end

        
    end
end

-- Version comparison function
function util.compare_versions(versionA, versionB)
    local function parse_version(version) return version:match("^(%d+)%.(%d+)%.(%d+)$") end
    local a1, a2, a3 = parse_version(versionA)
    local b1, b2, b3 = parse_version(versionB)
    if a1 ~= b1 then return a1 > b1 and 1 or -1 end
    if a2 ~= b2 then return a2 > b2 and 1 or -1 end
    if a3 ~= b3 then return a3 > b3 and 1 or -1 end
    return 0
end

main({ ... })

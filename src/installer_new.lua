
local programs_repo_url = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src"

-- Define paths
-- We install everything within this root
local installRootPath = "/bng"
-- Common (non-program files) modules are stored here
local installCommonPath = installRootPath .. "/common"
-- My specific core library is installed here
local installCorePath = installCommonPath .. "/bng-cc-core"
-- Programs are stored here
local installProgramsPath = installRootPath .. "/programs"

-- Ensure directories exist
if not fs.exists(installCommonPath) then fs.makeDir(installCommonPath) end
if not fs.exists(installCorePath) then fs.makeDir(installCorePath) end

-- Function to read JSON files safely
local function readJSON(filePath)
    if fs.exists(filePath) then
        local file = fs.open(filePath, "r")
        local content = textutils.unserializeJSON(file.readAll())
        file.close()
        return content or {}
    end
    return {}
end

-- Function to update installed.json in bng-cc-core
local function updateCoreManifest(version, modules)
    local data = { version = version, modules = modules }
    local file = fs.open(installCorePath .. "/installed.json", "w")
    file.write(textutils.serializeJSON(data))
    file.close()
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

-- Get the command line arguments
local args = {...}
if #args < 1 then
    print("Usage: installer <programName> [--version]")
    return
end

local programName = args[1]
local installDir = installProgramsPath .. "/" .. programName .. "/"
local programURL = programs_repo_url .. "/programs/" .. programName .. "/"
local programManifestURL = programURL .. "manifest.json"
local installedManifestFile = installDir .. "installed.json"

-- Fetch program manifest
local remoteProgramManifest = fetchRemoteJSON(programManifestURL)
if not remoteProgramManifest then
    print("Installer: Failed to retrieve manifest for:", programName)
    return
end

-- **🔹 Check and Install `bng-cc-core`**
if remoteProgramManifest["bng-cc-core"] then
    local requiredCore = remoteProgramManifest["bng-cc-core"]
    local requiredCoreVersion = requiredCore.version
    local requiredModules = requiredCore.modules

    local installedCore = readJSON(installCorePath .. "/installed.json")
    local installedCoreVersion = installedCore.version

    -- **Prompt for version mismatch**
    if installedCoreVersion and installedCoreVersion ~= requiredCoreVersion then
        print("Warning: This program requires `bng-cc-core` v" .. requiredCoreVersion .. 
              ", but v" .. installedCoreVersion .. " is installed.")

        print("Would you like to update `bng-cc-core` to v" .. requiredCoreVersion .. "? (y/n)")
        local response = io.read()
        if response ~= "y" then
            print("Installer: Aborting due to version mismatch.")
            return
        end
    end

    -- **Download only required modules**
    print("Installer: Installing `bng-cc-core` v" .. requiredCoreVersion .. "...")
    for _, module in ipairs(requiredModules) do
        local url = "https://raw.githubusercontent.com/bngarren/bng-cc-core/" 
                    .. requiredCoreVersion .. "/src/" .. module .. ".lua"
        local filePath = installCorePath .. "/" .. module .. ".lua"
        if not downloadFile(url, filePath) then
            print("Installer: Failed to install bng-cc-core module:", module)
            return
        end
    end
    updateCoreManifest(requiredCoreVersion, requiredModules)
    print("Installer: Installed `bng-cc-core` v" .. requiredCoreVersion .. " with modules: " .. table.concat(requiredModules, ", "))
end

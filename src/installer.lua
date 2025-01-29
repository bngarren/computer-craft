local debug = true

-- Utility functions
local util = {}
local log = {}

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
        log.error(response)
        return nil
    end
    if not response then
        util.println_c("ERROR: Unknown error attempting to GET " .. url, colors.red)
        log.error("Unknown error attempting to GET " .. url)
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

    if not fs.exists(installCorePath) then
        return currentModules
    end

    local files = fs.list(installCorePath)

    log.debug("Getting current installed modules in bng-cc-core")

    for index, file in ipairs(files) do
        local filePath = fs.combine(installCorePath, file)
        log.debug("Checking file: " .. file)

        -- **🔹 Ensure we only process .lua files and ignore installed.json**
        if fs.exists(filePath) and not fs.isDir(filePath) and file:match("%.lua$") then
            local moduleName = file:gsub("%.lua$", "")
            table.insert(currentModules, moduleName)
            log.debug("Debug: Added module: " .. moduleName)
        end
    end

    log.debug("Final module list: " .. textutils.serialize(currentModules))

    return currentModules
end

-- Fully install `bng-cc-core` with required modules
local function fullInstallCore(version, requiredModules)
    log.debug("Installing `bng-cc-core` v" .. version .. "...")

    -- Create a temporary directory for the new installation
    local tempPath = installCommonPath .. "/_bng-cc-core"
    if fs.exists(tempPath) then fs.delete(tempPath) end
    fs.makeDir(tempPath)

    local success

    -- Attempt to download all modules first
    for _, module in ipairs(requiredModules) do
        local url = getCoreModuleURL(version, module)
        local filePath = tempPath .. "/" .. module .. ".lua"
        if not downloadFile(url, filePath) then
            util.println_c("Could not download `bng-cc-core` module: " .. module, colors.red)
            log.error("Failed to download `bng-cc-core` module: " .. module)
            success = false
        else
            success = true
        end
    end

    -- Attemp to download the initenv.lua file
    local module = "initenv"
    local url = getCoreModuleURL(version, module)
    if success and not downloadFile(url, tempPath .. "/" .. module .. ".lua") then
        util.println_c("Could not download `bng-cc-core` module: " .. module, colors.red)
        log.error("Failed to download `bng-cc-core` module: " .. module)
        success = false
    else
        success = true
    end

    if not success then
        fs.delete(tempPath)
        return false
    end

    -- If all downloads succeeded, remove the old installation and move the new one into place
    if fs.exists(installCorePath) then fs.delete(installCorePath) end
    fs.move(tempPath, installCorePath)
    updateCoreManifest(version, requiredModules)
    util.println_c(
    "Successfully installed `bng-cc-core` v" .. version .. " with modules: " .. table.concat(requiredModules, ", "),
        colors.lightGray)
    return true
end

-- Install program files based on program's manifest.json
local function installProgramFiles(programName, remoteProgramManifest, force)
    local installDir = installProgramsPath .. "/" .. programName .. "/"
    local installedManifestFile = installDir .. "installed.json"
    local installedManifest = readJSON(installedManifestFile)

    if not fs.exists(installDir) then fs.makeDir(installDir) end

    for _, file in ipairs(remoteProgramManifest.files) do
        local fileURL = programs_repo_url .. "/programs/" .. programName .. "/" .. file
        local filePath = installDir .. file

        if force or not fs.exists(filePath) or installedManifest.version ~= remoteProgramManifest.version then
            log.info("Downloading: " .. file)
            if not downloadFile(fileURL, filePath) then
                util.println_c("Could not download " .. file, colors.red)
                log.error("Failed to download " .. file)
                return false
            end
        else
            log.debug("Program file: " .. file .. " is up-to-date.")
        end
    end

    -- Update installed.json
    local file = fs.open(installedManifestFile, "w")
    file.write(textutils.serializeJSON({ version = remoteProgramManifest.version, files = remoteProgramManifest.files }))
    file.close()

    return true
end

-- ** ** ** ** Main installer function ** ** ** **
local function main(args)
    -- init log
    log.init("installer_log.txt", true)

    term.clear()

    -- handle command line args (program name and flags)
    if #args < 1 then return print("Usage: installer <programName> [--force]") end
    local programName = args[1]
    local force = args[2] == "--force"

    util.println_c("### bng-cc installer", colors.purple)
    log.info("bng-cc installer - begin")

    local programURL = programs_repo_url .. "/programs/" .. programName .. "/"
    local programManifestURL = programURL .. "manifest.json"

    local remoteProgramManifest = fetchRemoteJSON(programManifestURL)
    if not remoteProgramManifest then
        util.println_c("ERROR: Could not retrieve remote manifest for program: " .. programName, colors.red)
        log.error("Failed to retrieve manifest for: " .. programName)
        return
    end

    local programVersion = remoteProgramManifest.version
    util.println_c("target: " .. programName .. " " .. (programVersion or "") .. "\n", colors.white)
    log.info("target: " .. programName .. " " .. (programVersion or ""))

    util.println_c("flags: " .. "--force=" .. tostring(force) .. "\n", colors.white)
    log.info("flags: " .. "--force=" .. tostring(force))

    local success = true

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
            if not fullInstallCore(requiredCoreVersion, moduleList) then
                util.println_c("ERROR: Could not complete install of `bng-cc-core`", colors.red)
                log.error("Failed to install `bng-cc-core`.")
                success = false
            end
            -- If force flag present, do full install regardless of versions
        elseif force == true then
            util.println_c("INFO: Forcing re-install of `bng-cc-core`", colors.white)
            log.info("Forcing re-install of `bng-cc-core`")
            if not fullInstallCore(requiredCoreVersion, moduleList) then
                util.println_c("ERROR: Could not install `bng-cc-core`.", colors.red)
                log.error("Could not install `bng-cc-core`")
                success = false
            end
            -- Else, do a version comparison to determine how to proceed
        else
            local versionComparison = util.compare_versions(installedCoreVersion, requiredCoreVersion)
            if versionComparison == 0 then
                util.println_c("bng-cc-core v" .. requiredCoreVersion .. " is required and present.", colors.lightGray)
                log.info("bng-cc-core v" .. requiredCoreVersion .. " is required and present.")
            else
                log.warn("bng-cc-core version mismatch: " ..
                installedCoreVersion .. " (installed), " .. requiredCoreVersion .. " (required)")
                util.println_c("WARNING: This program requires `bng-cc-core` v" ..
                    requiredCoreVersion .. ", but v" .. installedCoreVersion .. " is installed.", colors.yellow)
                util.println_c("Would you like to " ..
                    (versionComparison == -1 and "update" or "downgrade") ..
                    " `bng-cc-core` to v" .. requiredCoreVersion .. "? (y/n)", colors.cyan)
                if io.read() ~= "y" then
                    util.println_c("Installation aborted due to version mismatch.", colors.white)
                    log.warn("Installation of " .. programName .. " was aborted due to bng-cc-core version mismatch")
                    return
                else
                    log.info("Attemping to " ..
                    (versionComparison == -1 and "update" or "downgrade") .. " bng-cc-core to v" .. requiredCoreVersion)
                end
                if not fullInstallCore(requiredCoreVersion, moduleList) then
                    util.println_c("ERROR: Could not install `bng-cc-core`.", colors.red)
                    log.error("Could not install `bng-cc-core`")
                    success = false
                end
            end
        end
    end

    -- Handle program files installation
    if not installProgramFiles(programName, remoteProgramManifest, force) then success = false end

    if success == true then
        util.println_c("\n\nProgram `" .. programName .. "` installed successfully.", colors.green)
        log.info("Program `" .. programName .. "` installed successfully")
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

-- Printing
function util.println(msg) print(tostring(msg)) end

function util.println_c(msg, color) util.print_c(tostring(msg), color) end

function util.print_c(msg, color)
    if term and term.isColor() then
        local defaultColor = term.getTextColor()
        term.setTextColor(color or defaultColor)
        print(msg)
        term.setTextColor(defaultColor)
    else
        print(msg)
    end
end

--- Prints the message only if debug = true
function util.print_debug(msg)
    if debug then
        util.println(msg)
    end
end

-- File log

function log.init(path, debug_mode)
    log.path = path
    log.debug_mode = debug_mode or false
    log.file = fs.open(log.path, "w+")
end

-- Log message with timestamp
local function _log(level, msg)
    local timestamp = os.date("[%H:%M:%S] ")
    local formatted = timestamp .. "[" .. level .. "] " .. msg

    -- Write to log file
    if log.file then
        log.file.writeLine(formatted)
        log.file.flush()
    end
end

-- Log methods
function log.info(msg) _log("INFO", msg) end

function log.warn(msg) _log("WARN", msg) end

function log.error(msg) _log("ERROR", msg) end

function log.debug(msg)
    if log.debug_mode then _log("DEBUG", msg) end
end

main({ ... })

local updater = {}

-- Generate startup.lua with auto-update check
function updater.generateStartup(installDir, programName, baseURL, installManifestFile)
    local startupContent = [[
local manifestPath = "]] .. installManifestFile .. [["
local baseURL = "]] .. baseURL .. [["
local mainScript = "]] .. installDir .. [[main.lua"

local function fetchRemoteManifest()
    local request = http.get(baseURL .. "manifest.json")
    if not request then return nil end
    local content = request.readAll()
    request.close()
    return textutils.unserializeJSON(content)
end

local function fetchLocalManifest()
    if not fs.exists(manifestPath) then return nil end
    local file = fs.open(manifestPath, "r")
    local manifest = textutils.unserializeJSON(file.readAll())
    file.close()
    return manifest
end

local function checkForUpdates()
    local localManifest = fetchLocalManifest()
    local remoteManifest = fetchRemoteManifest()

    if remoteManifest and localManifest and remoteManifest.version ~= localManifest.version then
        print("A new version is available. Updating...")
        shell.run("installer.lua", "]] .. programName .. [[")
        os.reboot()
    end
end

checkForUpdates()
shell.run(mainScript)
]]

    local startupFile = fs.open(installDir .. "startup.lua", "w")
    startupFile.write(startupContent)
    startupFile.close()
end

return updater

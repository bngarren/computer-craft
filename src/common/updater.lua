local updater = {}

-- Generate startup.lua
function updater.generateStartup(installDir, programName, baseURL, installManifestFile)
    local startupContent = [[
package.path = "/bng/common/?.lua;" .. package.path
local http = require("http")

local function fetchRemoteManifest(url)
    local response = http.get(url)
    if not response then return nil end
    local content = response.readAll()
    response.close()
    return textutils.unserializeJSON(content)
end

local function fetchLocalManifest(path)
    if not fs.exists(path) then return nil end
    local file = fs.open(path, "r")
    local manifest = textutils.unserializeJSON(file.readAll())
    file.close()
    return manifest
end

local function checkForUpdates()
    local remoteManifest = fetchRemoteManifest("]] .. baseURL .. [[manifest.json")
    local localManifest = fetchLocalManifest("]] .. installManifestFile .. [[")

    if remoteManifest and localManifest and remoteManifest.version ~= localManifest.version then
        print("A new version is available. Updating...")
        shell.run("installer.lua", "]] .. programName .. [[")
        os.reboot()
    end
end

checkForUpdates()
shell.run("]] .. installDir .. [[main.lua")
]]

    local startupFile = fs.open("/startup.lua", "w")
    startupFile.write(startupContent)
    startupFile.close()
end

return updater

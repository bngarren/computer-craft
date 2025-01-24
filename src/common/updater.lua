local updater = {}

-- Generate startup.lua
function updater.generateStartup(installDir, programName, baseURL, installManifestFile)
    local startupContent = [[
package.path = "/bng/common/?.lua;" .. package.path
local updater = require("updater")

local manifestPath = "]] .. installManifestFile .. [["
local baseURL = "]] .. baseURL .. [["
local mainScript = "]] .. installDir .. [[main.lua"

local function checkForUpdates()
    local remoteVersion = fetchRemoteManifest()
    local localVersion = fetchLocalManifest()

    if remoteVersion and localVersion and remoteVersion ~= localVersion then
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

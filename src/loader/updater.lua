local updater = {}

-- Generate startup.lua with auto-update check
function updater.generateStartup(installDir, programName, baseURL, installManifestFile)
    local startupContent = [[
local manifestPath = "]] .. installManifestFile .. [["
local baseURL = "]] .. baseURL .. [["
local mainScript = "]] .. installDir .. [[main.lua"

local function checkForUpdates()
    local remoteVersion = fetchRemoteVersion()
    local localVersion = fetchLocalVersion()

    if remoteVersion and localVersion and remoteVersion ~= localVersion then
        print("A new version is available. Update? (y/n)")
        local choice = read()
        if choice:lower() == "y" then
            shell.run("installer.lua", "]] .. programName .. [[")
            os.reboot()
        end
    end
end

checkForUpdates()
shell.run(mainScript)
]]

    local startupFile = fs.open(installDir .. "startup.lua", "w")
    startupFile.write(startupContent)
    startupFile.close()
end

-- Prompt to overwrite global startup.lua
function updater.promptStartupOverwrite(installDir)
    local globalStartupPath = "/startup.lua"
    if fs.exists(globalStartupPath) then
        print("Overwrite global startup.lua? (y/n)")
        local choice = read()
        if choice:lower() == "y" then
            fs.delete(globalStartupPath)
            fs.copy(installDir .. "startup.lua", globalStartupPath)
        end
    else
        fs.copy(installDir .. "startup.lua", globalStartupPath)
    end
end

return updater

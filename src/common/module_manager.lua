local moduleManager = {}

local remoteCommonURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/common/"
local remoteCommonManifestURL = remoteCommonURL .. "common_manifest.json"
local installPath = "/bng/common/"
local localManifestFile = installPath .. "common_manifest.json"

-- Fetch remote common manifest
local function fetchCommonManifest()
    local request = http.get(remoteCommonManifestURL)
    if not request then
        print("Error: Failed to retrieve common manifest.")
        return nil
    end
    local content = request.readAll()
    request.close()
    return textutils.unserializeJSON(content)
end

-- Install or update modules
function moduleManager.ensureModules(dependencies)
    if not fs.exists(installPath) then fs.makeDir(installPath) end

    local remoteManifest = fetchCommonManifest()
    if not remoteManifest then return end

    local localManifest = {}
    if fs.exists(localManifestFile) then
        local file = fs.open(localManifestFile, "r")
        localManifest = textutils.unserializeJSON(file.readAll())
        file.close()
    end

    for moduleName, moduleInfo in pairs(dependencies) do
        local modulePath = installPath .. moduleName .. ".lua"
        local remoteVersion = moduleInfo.version
        local localVersion = localManifest[moduleName]

        if not fs.exists(modulePath) or localVersion ~= remoteVersion then
            print("Updating module:", moduleName, "to v" .. remoteVersion)
            local moduleURL = remoteCommonURL .. moduleName .. ".lua"
            local request = http.get(moduleURL)

            if request then
                local content = request.readAll()
                request.close()
                local file = fs.open(modulePath, "w")
                file.write(content)
                file.close()
                localManifest[moduleName] = remoteVersion
            else
                print("Error: Failed to download module:", moduleName)
            end
        end
    end

    local file = fs.open(localManifestFile, "w")
    file.write(textutils.serializeJSON(localManifest))
    file.close()
end

return moduleManager

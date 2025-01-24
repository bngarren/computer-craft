local moduleManager = {}

local commonManifestURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/common/common_manifest.json"
local installPath = "/bng/common/"
local localManifestFile = installPath .. "common_manifest.json"

-- Function to fetch remote common manifest
local function fetchCommonManifest()
    local request = http.get({ url = commonManifestURL, headers = { ["Cache-Control"] = "no-cache" } })
    if not request then return nil end
    local content = request.readAll()
    request.close()
    return textutils.unserializeJSON(content)
end

-- Install or update common modules
function moduleManager.ensureModules(dependencies)
    if not fs.exists(installPath) then fs.makeDir(installPath) end

    -- Fetch remote and local manifests
    local remoteManifest = fetchCommonManifest()
    if not remoteManifest then
        print("Failed to retrieve common module manifest.")
        return
    end

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

        if not fs.exists(modulePath) or (localVersion ~= remoteVersion) then
            print("Updating module:", moduleName, "(v" .. remoteVersion .. ")")
            local moduleURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/common/" .. moduleName .. ".lua"
            if http.get(moduleURL) then
                local file = fs.open(modulePath, "w")
                file.write(http.get(moduleURL).readAll())
                file.close()
                localManifest[moduleName] = remoteVersion
            end
        end
    end

    -- Save updated local manifest
    local file = fs.open(localManifestFile, "w")
    file.write(textutils.serializeJSON(localManifest))
    file.close()
end

return moduleManager

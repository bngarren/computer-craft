local moduleManager = {}

local libraryURL = "https://raw.githubusercontent.com/bngarren/computer-craft/main/src/common/"
local commonManifestURL = libraryURL .. "common_manifest.json"
local installPath = "/bng/common/"

-- Function to fetch remote common manifest
local function fetchCommonManifest()
    local request = http.get({ url = commonManifestURL, headers = { ["Cache-Control"] = "no-cache" } })
    if not request then return nil end
    local content = request.readAll()
    request.close()
    return textutils.unserializeJSON(content)
end

-- Install or update a common module
function moduleManager.ensureModule(moduleName, requiredVersion)
    if not fs.exists(installPath) then fs.makeDir(installPath) end

    local manifest = fetchCommonManifest()
    if not manifest then return end

    local moduleInfo = manifest.modules[moduleName]
    if not moduleInfo then
        print("Module " .. moduleName .. " not found in common manifest.")
        return
    end

    local localPath = installPath .. moduleName .. ".lua"
    if fs.exists(localPath) then
        local file = fs.open(localPath, "r")
        local content = file.readAll()
        file.close()

        if moduleInfo.version == requiredVersion then
            return  -- Already up to date
        end
    end

    -- Download updated module
    local fileURL = libraryURL .. moduleName .. ".lua"
    shell.run("wget", fileURL, localPath)
end

return moduleManager

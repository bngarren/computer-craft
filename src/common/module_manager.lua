local moduleManager = {}

local remoteCommonURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/common/"
local remoteCommonManifestURL = remoteCommonURL .. "common_manifest.json"
local installPath = "/bng/common/"
local localManifestFile = installPath .. "common_manifest.json"

-- Fetch remote common manifest
local function fetchCommonManifest()
    local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
    local request = http.get({ url = remoteCommonManifestURL, headers = headers })
    if not request then
        print("Error: Failed to retrieve common manifest.")
        return nil
    end
    local content = request.readAll()
    print("Module Manager: Remote common_manifest contains: " .. content)
    request.close()
    return textutils.unserializeJSON(content)
end

-- Install or update modules (while respecting installer updates)
function moduleManager.ensureModules(dependencies)
    if not fs.exists(installPath) then fs.makeDir(installPath) end

    local remoteManifest = fetchCommonManifest()
    if not remoteManifest then return end

    local localManifest = fs.exists(localManifestFile) and textutils.unserializeJSON(fs.open(localManifestFile, "r").readAll()) or {}

    for moduleName, moduleInfo in pairs(dependencies) do
        local modulePath = installPath .. "/" .. moduleName .. ".lua"
        local requiredVersion = moduleInfo.version
        local remoteVersion = remoteManifest[moduleName]
        local localVersion = localManifest[moduleName]

        print("[DEBUG] Module Manager: " .. moduleName .. " req " .. requiredVersion .. ", remote " .. remoteVersion .. ", local " ..localVersion)

        -- If the program's manifest.json requires a dependency that doesn't exist remotely, we may have fatal error...
        if requiredVersion ~= remoteVersion then
            print("Module Manager: WARNING - module "..moduleName.." v"..requiredVersion.." is listed as dependency, however, v"..remoteVersion.." exists remotely.")
            if localVersion == remoteVersion then
                print("Module Manager: keeping module "..moduleName.." at v"..localVersion)
                return
            else
                print("FATAL")
                return
            end
        end

        -- Skip modules that were already updated by the installer
        if fs.exists(modulePath) and localVersion == remoteVersion then
            print("Module Manager: Module already up to date (" .. moduleName .. " v" .. localVersion .. ")")
        else
            if not fs.exists(modulePath) then
                print("Module Manager: Installing module:", moduleName, " v" .. remoteVersion)
            else
                print("Module Manager: Updating module:", moduleName, " v" .. localVersion .. " to v" .. remoteVersion)
            end
            local moduleURL = remoteCommonURL .. moduleName .. ".lua"
            local headers = { ["Cache-Control"] = "no-cache, no-store, must-revalidate" }
            local request = http.get({ url = moduleURL, headers = headers })

            if request then
                local content = request.readAll()
                request.close()
                local file = fs.open(modulePath, "w")
                file.write(content)
                file.close()
                localManifest[moduleName] = remoteVersion
            else
                print("Module Manager: Failed to download module:", moduleName)
            end
        end
    end

    -- **✅ Save updated local `common_manifest.json`**
    local file = fs.open(localManifestFile, "w")
    file.write(textutils.serializeJSON(localManifest))
    file.close()
end

return moduleManager

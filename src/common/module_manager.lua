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
function moduleManager.ensureModules(dependencies, forceUpdate)
    if not fs.exists(installPath) then fs.makeDir(installPath) end

    local remoteManifest = fetchCommonManifest()
    if not remoteManifest then return false end

    local localManifest = fs.exists(localManifestFile) and textutils.unserializeJSON(fs.open(localManifestFile, "r").readAll()) or {}

    for moduleName, moduleInfo in pairs(dependencies) do
        local modulePath = installPath .. "/" .. moduleName .. ".lua"
        local requiredVersion = moduleInfo.version
        local remoteVersion = remoteManifest[moduleName]
        local localVersion = localManifest[moduleName]

        print("[DEBUG] Module Manager: " .. moduleName .. " req " .. tostring(requiredVersion) .. ", remote " .. tostring(remoteVersion) .. ", local " .. tostring(localVersion))


        -- If the program's manifest.json requires a dependency that doesn't exist remotely, we may have fatal error...
        if not requiredVersion then
            print("Module Manager: ERROR - Program manifest is missing version info for module: " .. moduleName)
            return false
        end
        
        if not remoteVersion then
            print("Module Manager: ERROR - Remote manifest does not contain module: " .. moduleName)
            return false
        end
        
        if requiredVersion ~= remoteVersion then
            print("Module Manager: WARNING - module " .. moduleName .. " v" .. requiredVersion .. " is listed as dependency, but v" .. remoteVersion .. " exists remotely.")
            if localVersion == remoteVersion then
                print("Module Manager: Keeping module " .. moduleName .. " at v" .. localVersion)
            else
                print("Module Manager: FATAL ERROR - Required module version mismatch. Cannot continue.")
                return false
            end
        end

        -- **✅ Skip version check if forceUpdate is enabled**
        if not forceUpdate and fs.exists(modulePath) and localVersion == remoteVersion then
            print("Module Manager: Module already up to date (" .. moduleName .. " v" .. localVersion .. ")")
        else
            if forceUpdate then
                print("Module Manager: Force updating module:", moduleName, " v" .. tostring(localVersion) .. " → v" .. remoteVersion)
            else
                print("Module Manager: Updating module:", moduleName, " v" .. tostring(localVersion) .. " → v" .. remoteVersion)
            end
            local moduleURL = remoteCommonURL .. moduleName .. ".lua"
            local request = http.get({ url = moduleURL })
            if not request then
                print("Module Manager: Failed to download module:", moduleName)
                return false
            end

            local content = request.readAll()
            request.close()
            local file = fs.open(modulePath, "w")
            file.write(content)
            file.close()
            localManifest[moduleName] = remoteVersion
            print("Module Manager: Successfully updated " .. moduleName .. " to v" .. remoteVersion)
        end
    end

    -- **✅ Save updated local `common_manifest.json`**
    local file = fs.open(localManifestFile, "w")
    file.write(textutils.serializeJSON(localManifest))
    file.close()
    return true
end

return moduleManager

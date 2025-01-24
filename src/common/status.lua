local function checkStatus()
    print("=== Installed Common Modules ===")
    local commonManifest = textutils.unserializeJSON(fs.open("/bng/common/common_manifest.json", "r").readAll())
    for module, version in pairs(commonManifest) do
        print("- " .. module .. " v" .. version)
    end

    print("\n=== Installed Programs ===")
    local programDirs = fs.list("/bng/programs/")
    for _, program in ipairs(programDirs) do
        local manifestPath = "/bng/programs/" .. program .. "/install_manifest.json"
        if fs.exists(manifestPath) then
            local manifest = textutils.unserializeJSON(fs.open(manifestPath, "r").readAll())
            print("- " .. program .. " v" .. manifest.version)
        else
            print("- " .. program .. " (NO MANIFEST)")
        end
    end
end

checkStatus()
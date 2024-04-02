-- github_installer.lua
local args = { ... }
local scriptName = args[1] -- Path to the script within the GitHub repository.

if not scriptName or scriptName == "" then
    print("Usage: installer <programName>")
    return
end

-- Define the base URL for raw user content on GitHub.
local baseURL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/src/"

-- Check if the scriptName ends with '.lua', append if not
if not scriptName:match("%.lua$") then
    scriptName = scriptName .. ".lua"
end

-- Construct the full URL to the script.
local scriptURL = baseURL .. scriptName

-- Determine a local filename to save the script. This could be derived from the scriptPath,
-- or you could allow the user to specify this as a second argument.
local filename = args[2] or scriptName

-- Check if the file already exists and ask for confirmation to overwrite.
if fs.exists(filename) then
    write(filename .. " already exists. Overwrite? [y/N]: ")
    local input = read()
    if input:lower() ~= 'y' then
        print("Installation cancelled.")
        return
    else
        fs.delete(filename)
    end
end

-- Download the script from GitHub.
local success = shell.run("wget", scriptURL, filename)
if not success then
    print("Failed to download " .. scriptName)
    return
end

-- Download the util script from GitHub.
local utilFile = "util.lua"
if fs.exists(utilFile) then
    fs.delete(utilFile)
    local success = shell.run("wget", baseURL .. "util.lua", filename)
    if not success then
        print("Failed to download " .. "util.lua")
        return
    end
end


-- Ask the user if they want to update startup.lua to run the new file.
print("Do you want to update startup.lua to only run this file on boot? [y/N]: ")
local updateStartup = read()
if updateStartup:lower() == 'y' then
    -- Create or overwrite startup.lua
    local startupFile = "startup.lua"
    local file = fs.open(startupFile, "w")
    file.writeLine("-- Auto-generated startup file to run " .. filename)
    file.writeLine("shell.run(\"" .. filename .. "\")")
    file.close()
    print("Startup script updated to run " .. filename)
else
    print("Startup script not modified.")
end

print("Installation complete.")

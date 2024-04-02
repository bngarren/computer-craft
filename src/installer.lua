--[[
    GitHub Repository Script Installer for ComputerCraft
    Author: Ben Garren
    Repository URL: https://github.com/bngarren/computer-craft
    Last Updated: 04/02/2024

    Purpose:
    This script automates the process of installing Lua scripts from my GitHub repository into ComputerCraft computers. 
    It supports automatic dependency resolution via .deps files, ensuring all required scripts are downloaded and available for execution.

    Arguments:
    - <programName>: The name of the main Lua script to be installed from the repository. This script name doesn't have to include the .lua extension, as it is appended automatically.
    - [optionalFileName]: Optionally, a second argument can specify the local filename under which the downloaded script will be saved. If omitted, the script saves as <programName>.lua.

    Dependencies Handling:
    Each Lua script that requires other scripts to function must have an associated .deps file with the same name as the main script. 
    For example, if `scriptX.lua` is the main script, it should have a `scriptX.deps` file in the same directory in the repository.
    The .deps file contains a list of filenames, each representing a dependency. These files are then downloaded automatically by the installer.

    Usage Example:
    Assuming `installer.lua` is saved on a ComputerCraft computer, run it with:
        `installer <programName> [optionalFileName]`
    For instance:
        `installer myScript`

    This will download `myScript.lua` and its dependencies as defined in `myScript.deps`, prepare `startup.lua` to run `myScript.lua` on boot, and handle user confirmation for overwrites.
]]

-- Function to write text in a specified color and then reset to the default color
local function coloredWrite(text, color)
    local defaultColor = term.getTextColor()  -- Save the current text color
    term.setTextColor(color)                  -- Set the new text color
    write(text)                               -- Write the text
    term.setTextColor(defaultColor)           -- Reset the text color back to default
end

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
    coloredWrite(filename .. " already exists. Overwrite? [y/N]: ", colors.orange)
    local input = read()
    if input:lower() ~= 'y' then
        coloredWrite("Installation cancelled.", colors.red)
        return
    else
        fs.delete(filename)
    end
end

-- Function to download and overwrite a file
local function downloadFile(fileURL, filename)
    if fs.exists(filename) then
        fs.delete(filename)
    end
    return shell.run("wget", fileURL, filename)
end

-- Download the main script
local success = downloadFile(scriptURL, filename)
if not success then
    coloredWrite("Failed to download " .. scriptName, colors.red)
    return
end

-- Check for a .deps file and download dependencies
local depsFile = scriptName:gsub("%.lua$", ".deps")
local depsURL = baseURL .. depsFile
if downloadFile(depsURL, "temp.deps") then
    local deps = fs.open("temp.deps", "r")
    local line = deps.readLine()
    while line do
        print("Downloading dependency: " .. line)
        if not downloadFile(baseURL .. line, line) then
            coloredWrite("Failed to download dependency: " .. line, colors.red)
            deps.close()
            return
        end
        line = deps.readLine()
    end
    deps.close()
    fs.delete("temp.deps")
else
    print("No dependencies file found or failed to download.")
end


-- Ask the user if they want to update startup.lua to run the new file.
coloredWrite("Do you want to update startup.lua to only run this file on boot? [y/N]: ", colors.orange)
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

coloredWrite("Installation complete.\n", colors.lime)

-- github_installer.lua
local args = {...}
local scriptName = args[1]  -- Path to the script within the GitHub repository.

if not scriptName or scriptName == "" then
    print("Usage: installer <programName>")
    return
end

-- Define the base URL for raw user content on GitHub.
local baseURL = "https://github.com/bngarren/computer-craft.git/master/src"

-- Construct the full URL to the script.
local scriptURL = baseURL .. scriptName

-- Determine a local filename to save the script. This could be derived from the scriptPath,
-- or you could allow the user to specify this as a second argument.
local filename = args[2] or "downloaded_script.lua"

-- Download the script from GitHub.
print("Downloading script from " .. scriptURL .. " to " .. filename .. "...")
shell.run("wget", scriptURL, filename)

-- Execute the downloaded script.
print("Running " .. filename .. "...")
shell.run(filename)
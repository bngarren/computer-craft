local Logger = {}
Logger.__index = Logger

function Logger:new(log_file)
    local obj = {
        log_file = log_file or "default.log"
    }
    setmetatable(obj, self)
    return obj
end

function Logger:log(message)
    local file = fs.open(self.log_file, "a")
    if file then
        file.writeLine(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message)
        file.close()
    else
        print("Error: Unable to open log file:", self.log_file)
    end
end

function Logger:info(message)
    self:log("[INFO] " .. message)
end

function Logger:warn(message)
    self:log("[WARN] " .. message)
end

function Logger:error(message)
    self:log("[ERROR] " .. message)
end

return Logger
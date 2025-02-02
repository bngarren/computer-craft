local ui = (function()
    -- PrimeUI by JackMacWindows
    -- Public domain/CC0
    -- Packaged from https://github.com/MCJack123/PrimeUI

    local a = require"cc.expect".expect;
    local b = {}
    do
        local c = {}
        local d;
        function b.addTask(e)
            a(1, e, "function")
            local f = {
                coro = coroutine.create(e)
            }
            c[#c + 1] = f;
            _, f.filter = coroutine.resume(f.coro)
        end
        function b.resolve(...)
            coroutine.yield(c, ...)
        end
        function b.clear()
            term.setCursorPos(1, 1)
            term.setCursorBlink(false)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            c = {}
            d = nil
        end
        function b.setCursorWindow(g)
            a(1, g, "table", "nil")
            d = g and g.restoreCursor
        end
        function b.getWindowPos(g, h, i)
            if g == term then
                return h, i
            end
            while g ~= term.native() and g ~= term.current() do
                if not g.getPosition then
                    return h, i
                end
                local j, k = g.getPosition()
                h, i = h + j - 1, i + k - 1;
                _, g = debug.getupvalue(select(2, debug.getupvalue(g.isColor, 1)), 1)
            end
            return h, i
        end
        function b.run()
            while true do
                if d then
                    d()
                end
                local l = table.pack(os.pullEvent())
                for _, m in ipairs(c) do
                    if m.filter == nil or m.filter == l[1] then
                        local n = table.pack(coroutine.resume(m.coro, table.unpack(l, 1, l.n)))
                        if not n[1] then
                            error(n[2], 2)
                        end
                        if n[2] == c then
                            return table.unpack(n, 3, n.n)
                        end
                        m.filter = n[2]
                    end
                end
            end
        end
    end
    function b.borderBox(g, h, i, o, p, q, r)
        a(1, g, "table")
        a(2, h, "number")
        a(3, i, "number")
        a(4, o, "number")
        a(5, p, "number")
        q = a(6, q, "number", "nil") or colors.white;
        r = a(7, r, "number", "nil") or colors.black;
        g.setBackgroundColor(r)
        g.setTextColor(q)
        g.setCursorPos(h - 1, i - 1)
        g.write("\x9C" .. ("\x8C"):rep(o))
        g.setBackgroundColor(q)
        g.setTextColor(r)
        g.write("\x93")
        for s = 1, p do
            g.setCursorPos(g.getCursorPos() - 1, i + s - 1)
            g.write("\x95")
        end
        g.setBackgroundColor(r)
        g.setTextColor(q)
        for s = 1, p do
            g.setCursorPos(h - 1, i + s - 1)
            g.write("\x95")
        end
        g.setCursorPos(h - 1, i + p)
        g.write("\x8D" .. ("\x8C"):rep(o) .. "\x8E")
    end
    function b.button(g, h, i, t, u, q, r, v)
        a(1, g, "table")
        a(2, h, "number")
        a(3, i, "number")
        a(4, t, "string")
        a(5, u, "function", "string")
        q = a(6, q, "number", "nil") or colors.white;
        r = a(7, r, "number", "nil") or colors.gray;
        v = a(8, v, "number", "nil") or colors.lightGray;
        g.setCursorPos(h, i)
        g.setBackgroundColor(r)
        g.setTextColor(q)
        g.write(" " .. t .. " ")
        b.addTask(function()
            local w = false;
            while true do
                local x, y, z, A = os.pullEvent()
                local B, C = b.getWindowPos(g, h, i)
                if x == "mouse_click" and y == 1 and z >= B and z < B + #t + 2 and A == C then
                    w = true;
                    g.setCursorPos(h, i)
                    g.setBackgroundColor(v)
                    g.setTextColor(q)
                    g.write(" " .. t .. " ")
                elseif x == "mouse_up" and y == 1 and w then
                    if z >= B and z < B + #t + 2 and A == C then
                        if type(u) == "string" then
                            b.resolve("button", u)
                        else
                            u()
                        end
                    end
                    g.setCursorPos(h, i)
                    g.setBackgroundColor(r)
                    g.setTextColor(q)
                    g.write(" " .. t .. " ")
                end
            end
        end)
    end
    -- function b.centerLabel(g,h,i,o,t,q,r)a(1,g,"table")a(2,h,"number")a(3,i,"number")a(4,o,"number")a(5,t,"string")q=a(6,q,"number","nil")or colors.white;r=a(7,r,"number","nil")or colors.black;assert(#t<=o,"string is too long")g.setCursorPos(h+math.floor((o-#t)/2),i)g.setTextColor(q)g.setBackgroundColor(r)g.write(t)end;
    -- function b.checkSelectionBox(g,h,i,o,p,D,u,q,r)a(1,g,"table")a(2,h,"number")a(3,i,"number")a(4,o,"number")a(5,p,"number")a(6,D,"table")a(7,u,"function","string","nil")q=a(8,q,"number","nil")or colors.white;r=a(9,r,"number","nil")or colors.black;local E=0;for _ in pairs(D)do E=E+1 end;local F=window.create(g,h,i,o,p)F.setBackgroundColor(r)F.clear()local G=window.create(F,1,1,o-1,E)G.setBackgroundColor(r)G.setTextColor(q)G.clear()local H={}local I,J=1,1;for K,m in pairs(D)do G.setCursorPos(1,I)G.write((m and(m=="R"and"[-] "or"[\xD7] ")or"[ ] ")..K)H[I]={K,not not m}I=I+1 end;if E>p then F.setCursorPos(o,p)F.setBackgroundColor(r)F.setTextColor(q)F.write("\31")end;G.setCursorPos(2,J)G.setCursorBlink(true)b.setCursorWindow(G)local B,C=b.getWindowPos(g,h,i)b.addTask(function()local L=1;while true do local l=table.pack(os.pullEvent())local M;if l[1]=="key"then if l[2]==keys.up then M=-1 elseif l[2]==keys.down then M=1 elseif l[2]==keys.space and D[H[J][1]]~="R"then H[J][2]=not H[J][2]G.setCursorPos(2,J)G.write(H[J][2]and"\xD7"or" ")if type(u)=="string"then b.resolve("checkSelectionBox",u,H[J][1],H[J][2])elseif u then u(H[J][1],H[J][2])else D[H[J][1]]=H[J][2]end;for s,m in ipairs(H)do local N=D[m[1]]=="R"and"R"or m[2]G.setCursorPos(2,s)G.write(N and(N=="R"and"-"or"\xD7")or" ")end;G.setCursorPos(2,J)end elseif l[1]=="mouse_scroll"and l[3]>=B and l[3]<B+o and l[4]>=C and l[4]<C+p then M=l[2]end;if M and(J+M>=1 and J+M<=E)then J=J+M;if J-L<0 or J-L>=p then L=L+M;G.reposition(1,2-L)end;G.setCursorPos(2,J)end;F.setCursorPos(o,1)F.write(L>1 and"\30"or" ")F.setCursorPos(o,p)F.write(L<E-p+1 and"\31"or" ")G.restoreCursor()end end)end;
    -- function b.drawImage(g,h,i,O,P,Q)a(1,g,"table")a(2,h,"number")a(3,i,"number")a(4,O,"string","table")P=a(5,P,"number","nil")or 1;a(6,Q,"boolean","nil")if Q==nil then Q=true end;if type(O)=="string"then local R=assert(fs.open(O,"rb"))local S=R.readAll()R.close()O=assert(textutils.unserialize(S),"File is not a valid BIMG file")end;for T=1,#O[P]do g.setCursorPos(h,i+T-1)g.blit(table.unpack(O[P][T]))end;local U=O[P].palette or O.palette;if Q and U then for s=0,#U do g.setPaletteColor(2^s,table.unpack(U[s]))end end end;
    -- function b.drawText(g,t,V,q,r)a(1,g,"table")a(2,t,"string")a(3,V,"boolean","nil")q=a(4,q,"number","nil")or colors.white;r=a(5,r,"number","nil")or colors.black;g.setBackgroundColor(r)g.setTextColor(q)local W=term.redirect(g)local H=print(t)term.redirect(W)if V then local h,i=g.getPosition()local X=g.getSize()g.reposition(h,i,X,H)end;return H end;
    -- function b.horizontalLine(g,h,i,o,q,r)a(1,g,"table")a(2,h,"number")a(3,i,"number")a(4,o,"number")q=a(5,q,"number","nil")or colors.white;r=a(6,r,"number","nil")or colors.black;g.setCursorPos(h,i)g.setTextColor(q)g.setBackgroundColor(r)g.write(("\x8C"):rep(o))end;
    -- function b.inputBox(g,h,i,o,u,q,r,Y,Z,a0,a1)a(1,g,"table")a(2,h,"number")a(3,i,"number")a(4,o,"number")a(5,u,"function","string")q=a(6,q,"number","nil")or colors.white;r=a(7,r,"number","nil")or colors.black;a(8,Y,"string","nil")a(9,Z,"table","nil")a(10,a0,"function","nil")a(11,a1,"string","nil")local a2=window.create(g,h,i,o,1)a2.setTextColor(q)a2.setBackgroundColor(r)a2.clear()b.addTask(function()local a3=coroutine.create(read)local W=term.redirect(a2)local a4,n=coroutine.resume(a3,Y,Z,a0,a1)term.redirect(W)while coroutine.status(a3)~="dead"do local l=table.pack(os.pullEvent())W=term.redirect(a2)a4,n=coroutine.resume(a3,table.unpack(l,1,l.n))term.redirect(W)if not a4 then error(n)end end;if type(u)=="string"then b.resolve("inputBox",u,n)else u(n)end;while true do os.pullEvent()end end)end;
    function b.interval(a5, u)
        a(1, a5, "number")
        a(2, u, "function", "string")
        local a6 = os.startTimer(a5)
        b.addTask(function()
            while true do
                local _, a7 = os.pullEvent("timer")
                if a7 == a6 then
                    local n;
                    if type(u) == "string" then
                        b.resolve("timeout", u)
                    else
                        n = u()
                    end
                    if type(n) == "number" then
                        a5 = n
                    end
                    if n ~= false then
                        a6 = os.startTimer(a5)
                    end
                end
            end
        end)
        return function()
            os.cancelTimer(a6)
        end
    end
    function b.keyAction(a8, u)
        a(1, a8, "number")
        a(2, u, "function", "string")
        b.addTask(function()
            while true do
                local _, a9 = os.pullEvent("key")
                if a9 == a8 then
                    if type(u) == "string" then
                        b.resolve("keyAction", u)
                    else
                        u()
                    end
                end
            end
        end)
    end
    -- function b.keyCombo(a8,aa,ab,ac,u)a(1,a8,"number")a(2,aa,"boolean")a(3,ab,"boolean")a(4,ac,"boolean")a(5,u,"function","string")b.addTask(function()local ad,ae,af=false,false,false;while true do local x,a9,ag=os.pullEvent()if x=="key"then if a9==a8 and ad==aa and ae==ab and af==ac and not ag then if type(u)=="string"then b.resolve("keyCombo",u)else u()end elseif a9==keys.leftCtrl or a9==keys.rightCtrl then ad=true elseif a9==keys.leftAlt or a9==keys.rightAlt then ae=true elseif a9==keys.leftShift or a9==keys.rightShift then af=true end elseif x=="key_up"then if a9==keys.leftCtrl or a9==keys.rightCtrl then ad=false elseif a9==keys.leftAlt or a9==keys.rightAlt then ae=false elseif a9==keys.leftShift or a9==keys.rightShift then af=false end end end end)end;
    function b.label(g, h, i, t, q, r)
        a(1, g, "table")
        a(2, h, "number")
        a(3, i, "number")
        a(4, t, "string")
        q = a(5, q, "number", "nil") or colors.white;
        r = a(6, r, "number", "nil") or colors.black;
        g.setCursorPos(h, i)
        g.setTextColor(q)
        g.setBackgroundColor(r)
        g.write(t)
    end
    function b.progressBar(g, h, i, o, q, r, ah)
        a(1, g, "table")
        a(2, h, "number")
        a(3, i, "number")
        a(4, o, "number")
        q = a(5, q, "number", "nil") or colors.white;
        r = a(6, r, "number", "nil") or colors.black;
        a(7, ah, "boolean", "nil")
        local function ai(aj)
            a(1, aj, "number")
            if aj < 0 or aj > 1 then
                error("bad argument #1 (value out of range)", 2)
            end
            g.setCursorPos(h, i)
            g.setBackgroundColor(r)
            g.setBackgroundColor(q)
            g.write((" "):rep(math.floor(aj * o)))
            g.setBackgroundColor(r)
            g.setTextColor(q)
            g.write((ah and "\x7F" or " "):rep(o - math.floor(aj * o)))
        end
        ai(0)
        return ai
    end
    -- function b.scrollBox(g,h,i,o,p,ak,al,am,q,r)a(1,g,"table")a(2,h,"number")a(3,i,"number")a(4,o,"number")a(5,p,"number")a(6,ak,"number")a(7,al,"boolean","nil")a(8,am,"boolean","nil")q=a(9,q,"number","nil")or colors.white;r=a(10,r,"number","nil")or colors.black;if al==nil then al=true end;local F=window.create(g==term and term.current()or g,h,i,o,p)F.setBackgroundColor(r)F.clear()local G=window.create(F,1,1,o-(am and 1 or 0),ak)G.setBackgroundColor(r)G.clear()if am then F.setBackgroundColor(r)F.setTextColor(q)F.setCursorPos(o,p)F.write(ak>p and"\31"or" ")end;h,i=b.getWindowPos(g,h,i)b.addTask(function()local L=1;while true do local l=table.pack(os.pullEvent())ak=select(2,G.getSize())local M;if l[1]=="key"and al then if l[2]==keys.up then M=-1 elseif l[2]==keys.down then M=1 end elseif l[1]=="mouse_scroll"and l[3]>=h and l[3]<h+o and l[4]>=i and l[4]<i+p then M=l[2]end;if M and(L+M>=1 and L+M<=ak-p)then L=L+M;G.reposition(1,2-L)end;if am then F.setBackgroundColor(r)F.setTextColor(q)F.setCursorPos(o,1)F.write(L>1 and"\30"or" ")F.setCursorPos(o,p)F.write(L<ak-p and"\31"or" ")end end end)return G end;
    function b.selectionBox(g, h, i, o, p, an, u, ao, q, r)
        a(1, g, "table")
        a(2, h, "number")
        a(3, i, "number")
        a(4, o, "number")
        a(5, p, "number")
        a(6, an, "table")
        a(7, u, "function", "string")
        a(8, ao, "function", "string", "nil")
        q = a(9, q, "number", "nil") or colors.white;
        r = a(10, r, "number", "nil") or colors.black;
        local ap = window.create(g, h, i, o - 1, p)
        local aq, ar = 1, 1;
        local function as()
            ap.setVisible(false)
            ap.setBackgroundColor(r)
            ap.clear()
            for s = ar, ar + p - 1 do
                local at = an[s]
                if not at then
                    break
                end
                ap.setCursorPos(2, s - ar + 1)
                if s == aq then
                    ap.setBackgroundColor(q)
                    ap.setTextColor(r)
                else
                    ap.setBackgroundColor(r)
                    ap.setTextColor(q)
                end
                ap.clearLine()
                ap.write(#at > o - 1 and at:sub(1, o - 4) .. "..." or at)
            end
            ap.setCursorPos(o, 1)
            ap.write(ar > 1 and "\30" or " ")
            ap.setCursorPos(o, p)
            ap.write(ar < #an - p + 1 and "\31" or " ")
            ap.setVisible(true)
        end
        as()
        b.addTask(function()
            while true do
                local _, a8 = os.pullEvent("key")
                if a8 == keys.down and aq < #an then
                    aq = aq + 1;
                    if aq > ar + p - 1 then
                        ar = ar + 1
                    end
                    if type(ao) == "string" then
                        b.resolve("selectionBox", ao, aq)
                    elseif ao then
                        ao(aq)
                    end
                    as()
                elseif a8 == keys.up and aq > 1 then
                    aq = aq - 1;
                    if aq < ar then
                        ar = ar - 1
                    end
                    if type(ao) == "string" then
                        b.resolve("selectionBox", ao, aq)
                    elseif ao then
                        ao(aq)
                    end
                    as()
                elseif a8 == keys.enter then
                    if type(u) == "string" then
                        b.resolve("selectionBox", u, an[aq])
                    else
                        u(an[aq])
                    end
                end
            end
        end)
    end
    function b.textBox(g, h, i, o, p, t, q, r)
        a(1, g, "table")
        a(2, h, "number")
        a(3, i, "number")
        a(4, o, "number")
        a(5, p, "number")
        a(6, t, "string")
        q = a(7, q, "number", "nil") or colors.white;
        r = a(8, r, "number", "nil") or colors.black;
        local a2 = window.create(g, h, i, o, p)
        function a2.getSize()
            return o, math.huge
        end
        local function ai(au)
            a(1, au, "string")
            a2.setBackgroundColor(r)
            a2.setTextColor(q)
            a2.clear()
            a2.setCursorPos(1, 1)
            local W = term.redirect(a2)
            print(au)
            term.redirect(W)
        end
        ai(t)
        return ai
    end
    -- function b.timeout(a5,u)a(1,a5,"number")a(2,u,"function","string")local a6=os.startTimer(a5)b.addTask(function()while true do local _,a7=os.pullEvent("timer")if a7==a6 then if type(u)=="string"then b.resolve("timeout",u)else u()end end end end)return function()os.cancelTimer(a6)end end;
    return b
end)()

function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

local Installer = {
    VERSION = "1.0.0",
    PROGRAM_REGISTRY_URL = "https://raw.githubusercontent.com/bngarren/computer-craft/master/registry.json",
    BASE_PATH = "/bng",
    CONFIG_PATH = "/.bng-config",
    LOG_PATH = "/bng/installer.log",

    boxSizing = {
        mainPadding = 2
    },
    LOG_LEVELS = {
        DEBUG = "DEBUG",
        INFO = "INFO",
        WARN = "WARN",
        ERROR = "ERROR"
    }
}

function Installer:initLogger()
    -- Ensure log directory exists
    local logDir = fs.getDir(self.LOG_PATH)
    if logDir then 
        fs.makeDir(logDir)
    end

    -- Open log file with w+ (always overwrites file on each run)
    self.logFile = fs.open(self.LOG_PATH, "w+")
    
    -- Create log functions for each level
    self.log = {}
    for level, levelName in pairs(self.LOG_LEVELS) do
        self.log[level:lower()] = function(msg, ...)
            if self.logFile then
                local formatted = string.format(msg, ...)
                local timestamp = os.date("[%Y-%m-%d %H:%M:%S]")
                local logLine = string.format("%s [%s] %s", timestamp, levelName, formatted)
                
                -- Write to file
                self.logFile.writeLine(logLine)
                self.logFile.flush()
                
            end
        end
    end
end

function Installer:closeLogger()
    if self.logFile then
        self.logFile.close()
        self.logFile = nil
    end
end

function Installer:httpGet(url)
    self.log.debug("HTTP GET: %s", url)
    local response = http.get(url)
    return response
end

function Installer:init()
    self:initLogger()

    self.log.info("Initializing installer v%s", self.VERSION)

    local termW, termH = term.getSize()
    self.boxSizing.contentBox = termW - self.boxSizing.mainPadding * 2 + 1
    self.boxSizing.borderBox = self.boxSizing.contentBox - 1

    self.COMMON_PATH = self.BASE_PATH .. "/common"
    self.PROGRAMS_PATH = self.BASE_PATH .. "/programs"

    -- Create base directories
    fs.makeDir(self.PROGRAMS_PATH)
    fs.makeDir(self.COMMON_PATH)
end

function Installer:loadConfig()
    if fs.exists(self.CONFIG_PATH) then
        local file = fs.open(self.CONFIG_PATH, "r")
        local config = textutils.unserializeJSON(file.readAll())
        file.close()
        self.log.debug("Loaded .bng-config: %s", dump(config))
        return config
    end
    return {
        installedPrograms = {},
        coreVersion = nil
    }
end

function Installer:saveConfig(config)
    local file = fs.open(self.CONFIG_PATH, "w")
    file.write(textutils.serializeJSON(config))
    file.close()
end

function Installer:fetchRegistry()
    local currentTerm = term.current()
    ui.textBox(currentTerm, self.boxSizing.mainPadding, 6, self.boxSizing.contentBox, 1, "Fetching program registry...")

    local response = self:httpGet(self.PROGRAM_REGISTRY_URL)
    if not response then
        error("Failed to download registry")
    end

    local registry = textutils.unserializeJSON(response.readAll())
    response.close()
    return registry
end

function Installer:downloadFile(url, path, currentProgress)
    local response = self:httpGet(url)
    if not response then
        error("Failed to download: " .. url)
    end

    local content = response.readAll()
    response.close()

    -- Ensure directory exists
    local dir = fs.getDir(path)
    if dir then
        fs.makeDir(dir)
    end

    -- Write file
    local file = fs.open(path, "w")
    file.write(content)
    file.close()

    if currentProgress then
        currentProgress()
    end
end

function Installer:checkCoreRequirements(program)

    -- Check if core is installed at correct version
    local config = self:loadConfig()
    local requiredVersion = program.core.version
    local requiredModules = program.core.modules

    -- Version check
    if not config.coreVersion or config.coreVersion ~= requiredVersion then
        local message = string.format("Core library v%s required (current: %s)", 
            requiredVersion, config.coreVersion or "none")
        return false, message
    end

    -- Get installed modules by scanning directory
    local installedModules = {}
    local corePath = self.COMMON_PATH .. "/bng-cc-core"
    
    if fs.exists(corePath) then
        for _, file in ipairs(fs.list(corePath)) do
            -- Extract module name from filename (remove .lua extension)
            local moduleName = string.match(file, "(.+)%.lua$")
            if moduleName then
                table.insert(installedModules, moduleName)
            end
        end
    end

    local missingModules = {}

    for _, module in ipairs(requiredModules) do
        local found = false
        for _, installedModule in ipairs(installedModules) do
            if module == installedModule then
                found = true
                break
            end
        end
        if not found then
            table.insert(missingModules, module)
        end
    end

    if #missingModules > 0 then
        local message = "Missing core module(s): "
        for _, m in ipairs(missingModules) do
            message = message .. "["..m.."] "
        end
        return false, string.format(message)
    end

    return true
end

function Installer:installCore(version, modules)
    local currentTerm = term.current()
    local progress = ui.progressBar(currentTerm, self.boxSizing.mainPadding, 8, self.boxSizing.contentBox, nil, nil,
                                    true)
    local statusBox = ui.textBox(currentTerm, self.boxSizing.mainPadding, 6, self.boxSizing.contentBox, 1,
                                 "Installing core...")

    -- URLs for different core versions
    local coreBaseUrl = string.format("https://raw.githubusercontent.com/bngarren/bng-cc-core/refs/tags/v%s/src",
                                      version)

    -- Track steps for progress bar
    local totalSteps = #modules
    local currentStep = 0

    -- Create core directory if it doesn't exist
    fs.makeDir(self.BASE_PATH .. "/common/bng-cc-core")

    -- Download each required module
    for _, moduleName in ipairs(modules) do
        statusBox("Downloading core module: " .. moduleName)

        local moduleUrl = string.format("%s/%s.lua", coreBaseUrl, moduleName)
        self:downloadFile(moduleUrl, string.format("%s/common/bng-cc-core/%s.lua", self.BASE_PATH, moduleName), function()
            currentStep = currentStep + 1
            progress(currentStep / totalSteps)
        end)
    end

    -- Save core version to config
    local config = self:loadConfig()
    config.coreVersion = version
    self:saveConfig(config)
end

function Installer:installDependency(dep, progressCallback)
    -- TODO
end

function Installer:installProgram(program)
    local currentTerm = term.current()
    local progress = ui.progressBar(currentTerm, self.boxSizing.mainPadding, 8, self.boxSizing.contentBox, nil, nil,
                                    true)
    local statusBox = ui.textBox(currentTerm, self.boxSizing.mainPadding, 6, self.boxSizing.contentBox, 1, "")

    -- Create program directory
    local programPath = self.BASE_PATH .. "/programs/" .. program.name
    fs.makeDir(programPath)

    -- Calculate total steps (files + dependencies)
    local totalSteps = #program.files
    if program.dependencies then
        totalSteps = totalSteps + #program.dependencies
    end
    local currentStep = 0

    -- Install program files
    for _, file in ipairs(program.files) do
        statusBox("Installing: " .. file.path)
        self:downloadFile(file.url, programPath .. "/" .. file.path, function()
            currentStep = currentStep + 1
            progress(currentStep / totalSteps)
        end)
    end

    -- Install dependencies
    if program.dependencies then
        for _, dep in ipairs(program.dependencies) do
            statusBox("Installing dependency: " .. dep.name)
            self:installDependency(dep, function()
                currentStep = currentStep + 1
                progress(currentStep / totalSteps)
            end)
        end
    end

    -- Save installation to config
    local config = self:loadConfig()
    config.installedPrograms[program.name] = {
        version = program.version,
        installedAt = os.epoch("utc")
    }
    self:saveConfig(config)

end

function Installer:showMainMenu()
    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
               "BNG Installer v" .. self.VERSION .. "\n\nSelect an option:")

    local options = {"Install New Program", "Manage Installed Programs", "Update Core Library", "Exit"}

    local descriptions = {"Browse and install available BNG programs", "View, update, or remove installed programs",
                          "Update the BNG core library to the latest version", "Exit the installer"}

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 3,
                                      descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, options, "done",
                    function(opt)
        descriptionBox(descriptions[opt])
    end)

    return ui.run()
end

function Installer:showProgramSelector(programs)
    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
               "Select a program to install:")

    -- Create arrays for selection box
    local entries = {}
    local descriptions = {}

    for _, program in ipairs(programs) do
        local coreOk, coreMessage = self:checkCoreRequirements(program)
        local desc = program.description or "No description available"
        if not coreOk then
            desc = desc .. "\n\nCore requirement: " .. coreMessage
        end

        table.insert(entries, program.title .. " v" .. program.version)
        table.insert(descriptions, desc)
    end

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 5,
                                      descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, entries, "done",
                    function(opt)
        descriptionBox(descriptions[opt])
    end)

    local _, _, selection = ui.run()

    -- Extract program name from selection and return program
    if selection then
        for _, program in ipairs(programs) do
            if selection:find(program.title, 1, true) then

                self.log.debug("Selected " .. program.name .. "\n".. dump(program))

                return program
            end
        end
    end
end

function Installer:showCoreVersionSelector()
    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3, "Select BNG Core version:")

    local options = {"Stable (Latest Release)", "Development (Main Branch)"}

    local descriptions = {"Use the latest stable release of bng-cc-core",
                          "Use the latest development version from main branch"}

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 3,
                                      descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, options, "done",
                    function(opt)
        descriptionBox(descriptions[opt])
    end)

    local _, _, selection = ui.run()

    return selection == options[1] and "stable" or "dev"
end

function Installer:showComplete(name)
    ui.clear()

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
               name .. " has been installed successfully!")

    ui.button(term.current(), self.boxSizing.mainPadding, 6, "Continue", "done")

    ui.run()
end

function Installer:showProgramManager()
    ui.clear()

    local config = self:loadConfig()

    if not next(config.installedPrograms) then
        ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3,
                   "No programs are currently installed.")

        ui.button(term.current(), self.boxSizing.mainPadding, 6, "Back", "done")

        ui.run()
        return
    end

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 3, "Installed Programs:")

    -- Create entries for selection box
    local entries = {}
    local descriptions = {}

    for name, info in pairs(config.installedPrograms) do
        table.insert(entries, name)
        table.insert(descriptions, string.format("Version: %s\nInstalled: %s", info.version,
                                                 os.date("%Y-%m-%d %H:%M", info.installedAt / 1000)))
    end

    ui.borderBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.borderBox, 8)

    local descriptionBox = ui.textBox(term.current(), self.boxSizing.mainPadding, 15, self.boxSizing.contentBox, 3,
                                      descriptions[1])

    ui.selectionBox(term.current(), self.boxSizing.mainPadding + 1, 6, self.boxSizing.contentBox, 8, entries, "done",
                    function(opt)
        descriptionBox(descriptions[opt])
    end)

    ui.button(term.current(), self.boxSizing.mainPadding, self.boxSizing.contentBox - 4, "Remove", "remove")

    local event, action, selection = ui.run()

    if action == "remove" and selection then
        -- Remove program files
        fs.delete(self.BASE_PATH .. "/programs/" .. selection)

        -- Update config
        config.installedPrograms[selection] = nil
        self:saveConfig(config)

        self:showComplete("Program removed")
    end
end

function Installer:confirmInstall(program)
    ui.clear()

    -- Check core requirements
    local coreOk, coreMessage = self:checkCoreRequirements(program)

    local message = string.format("Program: %s v%s\nAuthor: %s\n\nCore Status: %s\n\nProceed with installation?",
                                  program.title, program.version, program.author,
                                  coreOk and "Ready" or "Needs core v" .. program.core.version)

    ui.textBox(term.current(), self.boxSizing.mainPadding, 2, self.boxSizing.contentBox, 8, message)

    if not coreOk then
        ui.button(term.current(), self.boxSizing.mainPadding, 11, "Install Core First", "core")
    end

    ui.button(term.current(), self.boxSizing.mainPadding, 13, "Install", "install")
    ui.button(term.current(), self.boxSizing.mainPadding + 12, 13, "Cancel", "cancel")

    local _, action = ui.run()
    return action
end

function Installer:run()
    self:init()

    local success, err = pcall(function ()
        while true do
            local _, _, selection = self:showMainMenu()
    
            if selection == "Install New Program" then
                local registry = self:fetchRegistry()
                if registry then
                    local selectedProgram = self:showProgramSelector(registry.programs)
                    if selectedProgram then
                        local action = self:confirmInstall(selectedProgram)
    
                        if action == "core" then
                            -- Install required core version and modules
                            self:installCore(selectedProgram.core.version, selectedProgram.core.modules)
                            -- Show installation screen again
                            action = self:confirmInstall(selectedProgram)
                        end
    
                        if action == "install" then
                            self:installProgram(selectedProgram)
                            self:showComplete(selectedProgram.title)
                        end
                    end
                end
            elseif selection == "Manage Installed Programs" then
                self:showProgramManager()
            elseif selection == "Exit" then
                break
            end
        end
    end
    )

    if not success then
        self.log.error("Installer crashed: %s", err)
    end
    

    -- Cleanup
    self:closeLogger()
    -- ui.clear()
end

-- Start the installer
local installer = Installer
installer:run()

-- startup.lua
-- test-server

-- Load bng-cc-core and init the package env -- *Must come before any other lib requires*
local core = require("/bng.lib.bng-cc-core.bng-cc-core")
-- Fixes package.path to allow easier requiring of lib modules
core.initenv.run()

local vendor = require("bng-cc-core.vendor")

local ecnet2 = vendor.ecnet2

-- open modem
ecnet2.open("top")
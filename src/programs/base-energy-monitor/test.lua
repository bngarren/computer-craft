local core = require("/bng.lib.bng-cc-core.bng-cc-core")
core.initenv.run()

local telem = require("telem")

local backplane = telem.backplane()
  :addInput('my_hello', telem.input.helloWorld(123))
  :addOutput('my_hello', telem.output.helloWorld())
  :cycleEvery(1)()
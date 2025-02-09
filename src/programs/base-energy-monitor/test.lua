require("/bng.common.bng-cc-core.initenv").init_env()

local telem = require("telem")

local backplane = telem.backplane()
  :addInput('my_hello', telem.input.helloWorld(123))
  :addOutput('my_hello', telem.output.helloWorld())
  :cycleEvery(1)()
package.path = "./vendor/mini-doc/lua/?.lua" .. package.path

local minidoc = require("mini.doc")
minidoc.setup()

minidoc.generate({
        "lua/cme/init.lua",
        "plugin/cme.lua",
}, "doc/cme.nvim.txt", {})

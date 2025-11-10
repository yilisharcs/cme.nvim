package.path = "./vendor/mini-doc/lua/?.lua" .. package.path
require("mini.doc").generate({
        "lua/cme.lua",
        "plugin/cme.lua",
}, "doc/cme.nvim.txt", {})

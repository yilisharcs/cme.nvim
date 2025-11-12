if vim.g.loaded_cme == 1 then return end
vim.g.loaded_cme = 1

---@toc_entry CONFIGURATION
---@tag CME-configuration
---@class CME.Config
---
---@field shell string Preferred user shell. Accepts any executor that supports -c.
---     Default: `vim.o.shell`
---
---@usage >lua
---     vim.g.cme = {
---             shell = "python"
---     }
--- <
local DEFAULTS = {
        shell = vim.o.shell,
}

vim.g.cme = vim.tbl_deep_extend("force", DEFAULTS, vim.g.cme or {})

if not vim.g.cme_bin then
        local plugin = debug.getinfo(1, "S").source:match("@?(.*)")
        local root = vim.fs.dirname(vim.fs.dirname(plugin))
        local bin = vim.fs.joinpath(root, "bin/cme-nvim.sh")
        vim.g.cme_bin = bin
end

vim.api.nvim_create_user_command(
        "Compile",
        function(opts) require("cme").compile(opts) end,
        { nargs = "*", complete = "shellcmd" }
)

local augroup = vim.api.nvim_create_augroup("CME", { clear = true })

vim.api.nvim_create_autocmd({ "User" }, {
        group = augroup,
        pattern = "CmeSetQfList",
        callback = function()
                if vim.g.cme_qfformat then
                        vim.o.qftf = ""
                else
                        vim.o.qftf = vim.g.cme_qftf
                        print("Hello world")
                end
        end,
})

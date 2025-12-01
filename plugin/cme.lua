if vim.g.loaded_cme == 1 then return end
vim.g.loaded_cme = 1

---@toc_entry CONFIGURATION
---@tag CME-configuration
---@class CME.Config
---
---@field shell string Preferred user shell.
---     Default: `vim.o.shell`
---
---@field shell_expand boolean Expand '%' to the current file name.
---     Default: `true`
---
---@usage >lua
---     vim.g.cme = {
---             shell = "bash",
---             shell_expand = false,
---     }
--- <
local DEFAULTS = {
        shell = vim.o.shell,
        shell_expand = true,
}

vim.g.cme = vim.tbl_deep_extend("force", DEFAULTS, vim.g.cme or {})

vim.api.nvim_create_user_command(
        "Compile",
        function(opts) require("cme").compile(opts) end,
        { nargs = "*", bang = true, complete = "shellcmd" }
)

local augroup = vim.api.nvim_create_augroup("CME", { clear = true })

vim.api.nvim_create_autocmd({ "FileType", "User" }, {
        desc = "Quickfix prettify",
        group = augroup,
        pattern = { "qf", "CmeFinished" },
        callback = function() require("cme.qf").pretty() end,
})

vim.api.nvim_create_autocmd({ "User" }, {
        desc = "Quickfix prettify",
        group = augroup,
        pattern = "CmeFinished",
        callback = function() require("cme.qf").pretty() end,
})

vim.api.nvim_create_autocmd("CmdlineLeave", {
        desc = "Quickfix prettify for Cfilter",
        group = augroup,
        callback = function()
                if vim.fn.getcmdline():match("^[CL]filter") then
                        vim.schedule(function() require("cme.qf").pretty() end)
                end
        end,
})

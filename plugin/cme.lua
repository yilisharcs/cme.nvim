if vim.g.loaded_cme == 1 then return end
vim.g.loaded_cme = 1

---@toc_entry CONFIGURATION
---@tag CME-configuration
---@class CME.Config
---
---@field efm_rules table<string, string[]> Map errorformat to a list of commands.
---     Default: `require("cme.efm").rules`
---
---@field interrupt boolean Enable <C-c> for the quickfix window.
---     Default: `true`
---
---@field shell string Preferred user shell.
---     Default: `vim.o.shell`
---
---@field shell_expand boolean Expand wildcard characters.
---     Default: `true`
---
---@field sudo_prompt boolean Enable password prompt for one sudo command.
---     Default: `false`
---
---     WARNING: `sudo -S` inherits an open stdin pipe which alters the behavior
---     of programs like ripgrep, so they appear to fail immediately. I lack an
---     exhaustive list of all the tools affected by this, so use with caution.
---
---     Specifically for ripgrep, the fix is provided in its manpage:
---
---         To turn off stdin detection, one can explicitly specify the
---         directory to search, e.g. `rg foo ./`.
---
---@usage >lua
---     vim.g.cme = {
---             efm_rules = { ["%f::0,%l"] = { "find", "fd" } }
---             interrupt = false,
---             shell = "bash",
---             shell_expand = false,
---             sudo_prompt = true,
---     }
--- <
local DEFAULTS = {
        efm_rules = require("cme.efm").rules,
        interrupt = true,
        shell = vim.o.shell,
        shell_expand = true,
        sudo_prompt = false,
}

vim.g.cme = require("cme.utils").tbl_list_concat(DEFAULTS, vim.g.cme or {})

vim.api.nvim_create_user_command("Compile", function(opts) require("cme").compile(opts) end, {
        desc = "Populate the quickfix list with the output of shellcmd",
        nargs = "*",
        bang = true,
        complete = "shellcmd",
})

vim.api.nvim_create_user_command("Recompile", function(opts) require("cme").recompile(opts) end, {
        desc = "Run Compile command after saving a file",
        nargs = "*",
        bang = true,
        complete = "shellcmd",
})

local augroup = vim.api.nvim_create_augroup("Cme", { clear = true })

vim.api.nvim_create_autocmd({ "FileType", "User" }, {
        desc = "Quickfix prettify",
        group = augroup,
        pattern = { "qf", "CmeFinished" },
        callback = function(data)
                if data.match == "CmeFinished" then
                        vim.schedule(function() require("cme.qf").pretty(data.data.bufnr) end)
                else
                        vim.wo[0][0].statusline = "%!v:lua.require'cme.qf'.statusline_expr()"
                        require("cme.qf").pretty(data.buf)
                end
        end,
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

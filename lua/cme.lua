--- *cme.nvim.txt*                                           Compilation Mode Extern
---
--- Apache License 2.0 Copyright (c) 2025 yilisharcs

---                               Table of Contents
---
---@toc

---@toc_entry INTRODUCTION
---@tag CME-intro
---@text
--- cme.nvim provides a `:Compile` command that runs tasks in a terminal and loads
--- their output into the quickfix list. Arguments are passed to a bash script
--- which tracks the command's start time, end time, and duration. If `:Compile` is
--- called with no arguments, it executes the last known task.

local Terminal = require("toggleterm.terminal").Terminal

local M = {}

function M.compile(opts)
        if #opts.fargs ~= 0 then vim.g.cme_last_cmd = ("%s %s"):format(vim.g.cme_bin, opts.args) end

        if not vim.g.cme_last_cmd then
                vim.notify("Argument required", vim.log.levels.ERROR, { title = "cme" })
                return
        end

        local function on_open(term) vim.api.nvim_buf_set_name(term.bufnr, "compilation://run") end

        local output = {}
        local function on_stdout(_, _, data, _)
                for _, line in ipairs(data) do
                        if line == "" then return end

                        -- line feed
                        line = line:gsub("\x0d", "")
                        -- erase in line
                        line = line:gsub("\x1b%[K", "")
                        -- OSC 8 hyperlink
                        line = line:gsub("\x1b]8;[^\x1b]*\x1b\\", "")
                        -- ansi
                        line = line:gsub("\x1b%[[0-9][:;0-9]*m", "")

                        table.insert(output, line)
                end
        end

        local efm
        local qftf = vim.o.qftf and vim.fn.eval(vim.o.qftf) or ""
        if opts.fargs[1] == "grep" then
                efm = vim.o.grepformat
        else
                local compiler = vim.bo.makeprg:match("%w*")
                if compiler ~= "" then
                        efm = vim.bo.errorformat
                else
                        efm = "%m"
                        qftf = ""
                end
        end

        local function on_exit(term, _, code, _)
                local exit_title = ("compilation://exit [%s]"):format(code)
                if code >= 128 then
                        local sig = code - 128
                        vim.api.nvim_buf_set_name(
                                term.bufnr,
                                ("compilation://signal [%s]"):format(sig)
                        )
                else
                        vim.api.nvim_buf_set_name(term.bufnr, exit_title)
                end

                vim.fn.setqflist({}, "r", {
                        title = exit_title,
                        lines = output,
                        efm = efm,
                        quickfixtextfunc = qftf,
                })
        end

        local compile = Terminal:new({
                cmd = vim.g.cme_last_cmd,
                direction = "horizontal",
                close_on_exit = false,
                on_open = on_open,
                on_stdout = on_stdout,
                on_exit = on_exit,
        })
        compile:toggle()
end

return M

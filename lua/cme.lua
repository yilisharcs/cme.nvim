--- *cme.nvim.txt*                                    Compilation Mode, not in Emacs
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
--- called with no arguments, it executes the last known task. If called with
--- `:Compile!`, it won't automatically open the quickfix window on exit.

local Terminal = require("toggleterm.terminal").Terminal

local M = {}

function M.compile(opts)
        if vim.g.cme.shell_expand then
                for i, arg in ipairs(opts.fargs) do
                        if arg:find("%", 1, true) then opts.fargs[i] = vim.fn.expand(arg) end
                end
                opts.args = table.concat(opts.fargs, " ")
        end

        if #opts.args ~= 0 then
                vim.g.cme_last_cmd = opts.args
        elseif vim.g.cme_last_cmd then
                opts.args = vim.g.cme_last_cmd
                opts.fargs = vim.split(vim.g.cme_last_cmd, " ", {})
        end

        if not vim.g.cme_last_cmd then
                vim.notify("Argument required.", vim.log.levels.ERROR, { title = "cme" })
                return
        end

        local function on_open(term)
                vim.api.nvim_buf_set_name(
                        term.bufnr,
                        ("compilation://run [$] [job:%s]"):format(term.job_id)
                )
        end

        local output = {}
        local function on_stdout(_, _, data, _)
                for _, line in ipairs(data) do
                        if line == "" then return end

                        -- line feed
                        line = line:gsub("\x0d", "")
                        -- erase in line
                        if line:match("\x1b%[K") then
                                line = line:gsub("\x1b%[K", "")
                                if output[#output] == "" then table.remove(output) end
                        end
                        -- OSC 8 hyperlink
                        line = line:gsub("\x1b]8;[^\x1b]*\x1b\\", "")
                        -- ansi
                        line = line:gsub("\x1b%[[0-9][:;0-9]*m", "")

                        if opts.fargs[1] == "cargo" then
                                if line:match("^%[.*%] %d+/%d+:") then return end
                                if line:match("Building") then return end
                                if line:match("Compiling") then
                                        if
                                                output[#output] == ""
                                                and not output[#output - 1]:match(
                                                        "Compilation started at"
                                                )
                                        then
                                                table.remove(output)
                                        end
                                end
                        end
                        table.insert(output, line)
                end
        end

        local efm
        if
                opts.fargs[1] == "grep"
                or opts.args:find("| grep")
                or opts.fargs[1] == "rg"
                or opts.args:find("| rg")
        then
                efm = vim.o.grepformat
        else
                local compiler = vim.bo.makeprg:match("%w*")
                if opts.fargs[1] == compiler then
                        efm = vim.bo.errorformat
                else
                        efm = "%l"
                end
        end

        local function on_exit(term, job, code, _)
                local exit_title
                if code >= 128 then
                        local sig
                        if code == 254 then
                                sig = 2
                        else
                                sig = code - 128
                        end
                        exit_title = ("compilation://signal [%s] [job:%s]"):format(sig, job)
                else
                        exit_title = ("compilation://exit [%s] [job:%s]"):format(code, job)
                end
                vim.api.nvim_buf_set_name(term.bufnr, exit_title)

                local co = coroutine.create(function()
                        if #output == 0 then
                                vim.fn.setqflist({}, "r", { title = exit_title, efm = efm })
                        else
                                local chunk_size = 1000
                                for i = 1, #output, chunk_size do
                                        coroutine.yield()
                                        local chunk = {}
                                        for j = i, math.min(i + chunk_size - 1, #output) do
                                                table.insert(chunk, output[j])
                                        end
                                        if i == 1 then
                                                vim.fn.setqflist({}, "r", {
                                                        lines = chunk,
                                                        title = exit_title,
                                                        efm = efm,
                                                })
                                        else
                                                vim.fn.setqflist(chunk, "a")
                                        end
                                end
                        end

                        local qf_list = vim.fn.getqflist()
                        if #qf_list > 0 then
                                local counts = { E = 0, W = 0, I = 0 }
                                for _, item in ipairs(qf_list) do
                                        if item.valid then
                                                if item.type == "E" or item.type == "e" then
                                                        counts.E = counts.E + 1
                                                elseif item.type == "W" or item.type == "w" then
                                                        counts.W = counts.W + 1
                                                elseif item.type == "I" or item.type == "i" then
                                                        counts.I = counts.I + 1
                                                end
                                        end
                                end

                                vim.fn.setqflist({}, "r", {
                                        title = exit_title
                                                .. " "
                                                .. ("[E:%d|W:%d|I:%d]"):format(
                                                        counts.E,
                                                        counts.W,
                                                        counts.I
                                                ),
                                })
                        end

                        if not opts.bang then
                                vim.cmd.copen()
                        else
                                vim.notify(
                                        ("Job complete: `%s`"):format(vim.g.cme_last_cmd),
                                        vim.log.levels.INFO,
                                        { title = "cme" }
                                )
                        end
                end)

                local function resume()
                        local ok, err = coroutine.resume(co)
                        if not ok then
                                vim.notify(tostring(err), vim.log.levels.ERROR, { title = "cme" })
                                return
                        end
                        if coroutine.status(co) == "suspended" then vim.schedule(resume) end
                end
                resume()
        end

        local compile = Terminal:new({
                cmd = ("%s %s %s"):format(vim.g.cme_bin, vim.g.cme.shell, vim.g.cme_last_cmd),
                direction = "horizontal",
                hidden = false,
                close_on_exit = false,
                on_open = on_open,
                on_stdout = on_stdout,
                on_exit = on_exit,
        })
        compile:spawn()
end

return M

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

        local efm
        if
                opts.fargs[1] == "grep"
                or opts.args:find("| grep")
                or opts.fargs[1] == "rg"
                or opts.args:find("| rg")
        then
                efm = vim.o.grepformat
        elseif
                opts.fargs[1] == "find"
                -- NOTE: requires --strip-cwd-prefix=never
                or opts.fargs[1] == "fd"
        then
                efm = "%l,./%f"
        else
                local compiler = vim.bo.makeprg:match("%w*")
                if opts.fargs[1] == compiler then
                        efm = vim.bo.errorformat
                else
                        efm = "%l"
                end
        end

        local stdout = { "" }
        local function on_stdout(_, _, data, _)
                if #data == 0 then return end

                -- Dread "\r\[[K" Destroyer
                local function append_data(chunk, is_continuation)
                        if not chunk:find("\r") then
                                if is_continuation then
                                        stdout[#stdout] = stdout[#stdout] .. chunk
                                else
                                        table.insert(stdout, chunk)
                                end
                                return
                        end

                        local parts = vim.split(chunk, "\r")
                        if is_continuation then
                                stdout[#stdout] = stdout[#stdout] .. parts[1]
                        else
                                table.insert(stdout, parts[1] .. "\r")
                        end

                        -- Here lies Erase in Line. You were a valiant fighter.
                        for i = 2, #parts do
                                table.insert(stdout, parts[i])
                        end
                end

                -- data[1] is always a continuation of the last received line.
                -- data[2..] meanwhile contains proper new lines.
                append_data(data[1], true)
                for i = 2, #data do
                        append_data(data[i], false)
                end
        end

        local function on_exit(term, job, code, _)
                local output = {}
                for i, line in ipairs(stdout) do
                        local raw_line = line
                        local skip_line = false

                        local line_feed = "\r"
                        local erase_in_line = "\x1b%[K"
                        local osc8_hyperlink = "\x1b]8;[^\x1b]*\x1b\\"
                        local ansi_colors = "\x1b%[[0-9][:;0-9]*m"

                        line = line --
                                :gsub(line_feed, "")
                                :gsub(erase_in_line, "")
                                :gsub(osc8_hyperlink, "")
                                :gsub(ansi_colors, "")

                        if opts.fargs[1] == "cargo" then
                                if line:match("Building %[.*%]") then skip_line = true end
                                if line:match("Compiling %S* v%d") then skip_line = true end
                        end

                        -- After all this filtering, is the line empty?
                        if line == "" and raw_line ~= "\r" then skip_line = true end
                        if not skip_line then table.insert(output, line) end

                        -- HACK: The new stdout handler deletes the last empty line.
                        -- Manually inserting a new one solves the problem well enough.
                        local line_pad = 5
                        if i == #stdout and #output ~= line_pad then
                                table.insert(output, #output, "")
                        end
                end

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
                                                .. ("[E:%d|W:%d|I:%d] [cmd:%s]"):format(
                                                        counts.E,
                                                        counts.W,
                                                        counts.I,
                                                        vim.g.cme_last_cmd
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
                cmd = ("%s %s '%s'"):format(
                        vim.g.cme_bin,
                        vim.g.cme.shell,
                        vim.g.cme_last_cmd:gsub("'", "'\\''")
                ),
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

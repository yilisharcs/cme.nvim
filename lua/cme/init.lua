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

local M = {}

local function argparse(opts)
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

        return opts
end

function M.compile(opts)
        if vim.g.cme_blocked == true then
                vim.notify("Wait your turn, bucko!", vim.log.levels.WARN, { title = "cme" })
                return
        else
                vim.g.cme_blocked = true
        end

        opts = argparse(opts)
        if opts == nil then return end

        local efm
        if
                -- TODO: this could be a table/function
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

        local queue = {}
        local buffer = ""
        local flushing = false
        local counts = { E = 0, W = 0, I = 0 }

        -- Swap and Schedule: required because large outputs can be dropped if the shell tool
        -- is too fast. TODO: would be kinda nice if I could make this faster.
        local function write_batch(batch)
                if not batch or #batch == 0 then return end

                local parsed_items = vim.fn.getqflist({ lines = batch, efm = efm }).items
                for _, item in ipairs(parsed_items) do
                        if item.valid == 1 then
                                local t = (item.type and item.type ~= "") and item.type:upper()
                                        or "I"
                                if t == "E" then
                                        counts.E = counts.E + 1
                                elseif t == "W" then
                                        counts.W = counts.W + 1
                                else
                                        counts.I = counts.I + 1
                                end
                        end
                end

                local batch_title = ("compilation://run [E:%d|W:%d|I:%d] [cmd:%s]"):format(
                        counts.E,
                        counts.W,
                        counts.I,
                        vim.g.cme_last_cmd
                )

                vim.fn.setqflist({}, "a", {
                        title = batch_title,
                        items = parsed_items,
                })
                vim.cmd("cbottom")
        end

        local function flush()
                flushing = false
                local batch = queue
                queue = {}
                if #batch > 0 then write_batch(batch) end
        end

        local function on_data(_, data)
                if not data then return end

                local chunk = buffer .. data
                local lines = vim.split(chunk, "\n", { plain = true, trimempty = false })

                -- Discard buffer residue
                buffer = lines[#lines]
                lines[#lines] = nil

                if #lines > 0 then vim.list_extend(queue, lines) end

                if not flushing then
                        flushing = true
                        vim.schedule(flush)
                end
        end

        -- Any two commands with large output back to back will cause horrible lagging.
        -- Deleting the active qf buffer deals with that well enough.
        local qf_size = vim.fn.getqflist({ size = 0 }).size
        if qf_size > 20000 then
                local qf_bufnr = vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr
                if qf_bufnr and qf_bufnr > 0 and vim.api.nvim_buf_is_valid(qf_bufnr) then
                        vim.api.nvim_buf_delete(qf_bufnr, { force = true })
                end
        end

        local cwd, _ = vim.uv.cwd()
        if not cwd then cwd = vim.env.HOME or "/" end
        local pretty_cwd = vim.fn.fnamemodify(cwd, ":~")
        local start_time = os.date("%Y-%m-%d %H:%M:%S")

        local header = {
                ("-*- directory: %s -*-"):format(pretty_cwd),
                "",
                ("Compilation started at %s"):format(start_time),
                "",
        }

        local title = ("compilation://run [0:0:0] [cmd:%s]"):format(vim.g.cme_last_cmd)
        vim.fn.setqflist({}, " ", {
                title = title,
                efm = efm,
                lines = header,
        })
        if not opts.bang then vim.cmd.copen() end

        local command = { vim.g.cme.shell, "-c", vim.g.cme_last_cmd }

        vim.api.nvim_exec_autocmds("User", { pattern = "CmeStarted" })
        local start_ns = vim.uv.hrtime()
        vim.system(command, {
                text = true,
                stdout = on_data,
                stderr = on_data,
                env = { CME_NVIM = 1 },
        }, function(obj)
                vim.schedule(function()
                        local end_ns = vim.uv.hrtime()
                        local delta = (end_ns - start_ns) / 1e9
                        local duration = require("cme.duration").into(delta)

                        if buffer ~= "" then table.insert(queue, buffer) end

                        local end_time = os.date("%Y-%m-%d %H:%M:%S")
                        local footer_msg
                        if obj.code == 0 then
                                footer_msg = ("Compilation finished at %s, duration %s"):format(
                                        end_time,
                                        duration
                                )
                        elseif obj.code >= 128 then
                                local signal = (obj.code == 254) and 2 or (obj.code - 128)
                                footer_msg = ("Compilation exited abnormally with signal %d at %s, duration %s"):format(
                                        signal,
                                        end_time,
                                        duration
                                )
                        else
                                footer_msg = ("Compilation exited abnormally with code %d at %s, duration %s"):format(
                                        obj.code,
                                        end_time,
                                        duration
                                )
                        end

                        table.insert(queue, "")
                        table.insert(queue, footer_msg)
                        write_batch(queue)

                        local prefix = obj.code >= 128
                                        and ("compilation://signal [%d]"):format(
                                                obj.code == 254 and 2 or obj.code - 128
                                        )
                                or ("compilation://exit [%d]"):format(obj.code)

                        local final_title = prefix
                                .. " "
                                .. ("[E:%d|W:%d|I:%d]"):format(counts.E, counts.W, counts.I)
                                .. " "
                                .. ("[cmd:%s]"):format(vim.g.cme_last_cmd)

                        vim.fn.setqflist({}, "a", {
                                title = final_title,
                        })

                        if opts.bang then
                                vim.notify(
                                        ("Job complete: `%s`"):format(vim.g.cme_last_cmd),
                                        vim.log.levels.INFO,
                                        { title = "cme" }
                                )
                        end

                        vim.g.cme_blocked = false
                        vim.api.nvim_exec_autocmds("User", {
                                pattern = "CmeFinished",
                                data = { code = obj.code, signal = obj.signal },
                        })
                end)
        end)
end

return M

--- *cme.nvim.txt*                                    Compilation Mode, not in Emacs
---
--- Apache License 2.0 Copyright (c) 2025 yilisharcs

---                               Table of Contents
---
---@toc

---@toc_entry INTRODUCTION
---@tag CME-intro
---@text
--- cme.nvim provides a `:Compile` command that runs tasks in the background and
--- loads their output into the quickfix list on the fly, along with their start
--- time, end time, duration, and exit codes. If called with no arguments, the
--- last known task is executed. If called as `:Compile!`, it won't automatically
--- open the quickfix window on exit.
---
--- The `:Recompile` command sets up an autocommand to re-run the provided task (or
--- last known) after every write. Note that it doesn't trigger if you move out of
--- the directory where it was called, and any new invocation clears the previous
--- autocommand. Calling `:Recompile` with no arguments while a watcher is active
--- will disable the watcher.

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

local active_job = nil

function M.kill_task()
        if active_job then vim.uv.kill(-active_job.pid, "sigterm") end
end

function M.compile(opts)
        opts = argparse(opts)
        if opts == nil then return end

        -- Clear old task if any exists
        M.kill_task()

        local efm
        for format, commands in pairs(vim.g.cme.efm_rules) do
                for _, cmd in ipairs(commands) do
                        if
                                opts.fargs[1] == cmd
                                or opts.args:match("|%s*" .. vim.pesc(cmd) .. "%f[%W][^|]*$")
                        then
                                -- NOTE: required to match with some cme.efm.rules
                                if cmd == "find" then
                                        opts.args = opts.args .. " -printf '%p::0\\n'"
                                elseif cmd == "fd" then
                                        if not opts.args:match("--format") then
                                                opts.args = opts.args .. ' --format="{}::0"'
                                        end
                                end

                                efm = format
                                break
                        end
                end
                if efm then break end
        end

        if not efm then
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

        -- Swap and schedule: We want live updates for small payloads and batching for fast tools
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

                local batch_title = ("compilation://run [E:%d W:%d I:%d] [cmd:%s]"):format(
                        counts.E,
                        counts.W,
                        counts.I,
                        opts.args
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

        vim.g.cme_cwd, _ = vim.uv.cwd()
        if not vim.g.cme_cwd then vim.g.cme_cwd = vim.env.HOME or "/" end
        local pretty_cwd = vim.fn.fnamemodify(vim.g.cme_cwd, ":~")
        -- HACK: This is not a colon. This is the "Armenian Full Stop", U+0589.
        -- Using this prevents the errorformat from incorrectly picking up the
        -- durations as valid entries.
        local start_time = os.date("%Y-%m-%d %H։%M։%S")

        local header = {
                ("-*- directory: %s -*-"):format(pretty_cwd),
                ("Compilation started at %s"):format(start_time),
                "",
        }

        local title = ("compilation://run [E:0 W:0 I:0] [cmd:%s]"):format(opts.args)
        vim.fn.setqflist({}, " ", {
                title = title,
                efm = efm,
                lines = header,
        })
        if not opts.bang then
                vim.cmd.copen()
                vim.cmd.wincmd("p")
        end

        local command = { vim.g.cme.shell, "-c", opts.args }

        vim.api.nvim_exec_autocmds("User", { pattern = "CmeStarted" })
        local start_ns = vim.uv.hrtime()
        active_job = vim.system(command, {
                text = true,
                detach = true,
                stdout = on_data,
                stderr = on_data,
                env = { CME_NVIM = 1 },
        }, function(obj)
                vim.schedule(function()
                        local end_ns = vim.uv.hrtime()
                        local delta = (end_ns - start_ns) / 1e9
                        local duration = require("cme.duration").into(delta)

                        if buffer ~= "" then table.insert(queue, buffer) end

                        -- HACK: This is not a colon. This is the "Armenian Full Stop", U+0589.
                        -- Using this prevents the errorformat from incorrectly picking up the
                        -- durations as valid entries.
                        local end_time = os.date("%Y-%m-%d %H։%M։%S")
                        local footer_msg

                        if obj.signal ~= 0 then
                                footer_msg = ("Compilation exited abnormally with signal %d at %s, duration %s"):format(
                                        obj.signal,
                                        end_time,
                                        duration
                                )
                        elseif obj.code ~= 0 then
                                footer_msg = ("Compilation exited abnormally with code %d at %s, duration %s"):format(
                                        obj.code,
                                        end_time,
                                        duration
                                )
                        else
                                footer_msg = ("Compilation finished at %s, duration %s"):format(
                                        end_time,
                                        duration
                                )
                        end

                        table.insert(queue, "")
                        table.insert(queue, footer_msg)
                        write_batch(queue)

                        local prefix = obj.signal ~= 0
                                        and ("compilation://signal [%d]"):format(obj.signal)
                                or ("compilation://exit [%d]"):format(obj.code)

                        local final_title = prefix
                                .. " "
                                .. ("[E:%d W:%d I:%d]"):format(counts.E, counts.W, counts.I)
                                .. " "
                                .. ("[cmd:%s]"):format(opts.args)

                        vim.fn.setqflist({}, "a", {
                                title = final_title,
                        })

                        if opts.bang then
                                vim.notify(
                                        ("Job complete: `%s`"):format(opts.args),
                                        vim.log.levels.INFO,
                                        { title = "cme" }
                                )
                        end

                        local qfbufnr = vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr

                        vim.api.nvim_exec_autocmds("User", {
                                pattern = "CmeFinished",
                                data = { code = obj.code, signal = obj.signal, bufnr = qfbufnr },
                        })

                        active_job = nil
                end)
        end)
end

vim.g.cme_watch = nil

function M.recompile(opts)
        if vim.g.cme_watch then
                pcall(vim.api.nvim_del_autocmd, vim.g.cme_watch)
                vim.g.cme_watch = nil

                if #opts.fargs == 0 then
                        vim.notify(
                                "Compilation watcher disabled.",
                                vim.log.levels.INFO,
                                { title = "cme" }
                        )
                        vim.cmd("silent cclose")
                        return
                end
        end

        local augroup = vim.api.nvim_create_augroup("Cme_Recompile", { clear = true })
        vim.g.cme_watch = vim.api.nvim_create_autocmd({ "BufWritePost" }, {
                desc = "Watch for recompilation",
                group = augroup,
                callback = function(data)
                        if not data.match:find(vim.g.cme_cwd, 1, true) then return end

                        local buf = vim.api.nvim_buf_get_name(0)
                        if not buf:find(vim.g.cme_cwd, 1, true) then return end

                        M.compile(opts)
                end,
        })
        M.compile(opts)
end

return M

--- *cme.nvim.txt*                                    Compilation Mode, not in Emacs
---
--- Apache License 2.0 Copyright (c) 2025-2026 yilisharcs

---                               Table of Contents
---
---@toc

---@toc_entry INTRODUCTION
---@tag CME
---@tag CME-intro
---@text
--- *cme.nvim* is a minimalistic task runner inspired by Emacs' compilation-mode.
--- It runs jobs asynchronously, streaming their output into the |quickfix| list in
--- real time, and populates the statusline with metadata like their start time,
--- end time, duration, exit codes, and their error-warning-info counter.
---
--- # Design ~
---
--- I watch Tsoding. He uses Emacs. I don't use Emacs (and I don't plan to either)
--- but I like what Emacs has to offer. Existing plugins were either hard to wrap
--- my head around or not obviously extensible, so I made this. Initially, it was
--- meant to torture the |quickfix| list into acting like an interactive terminal so
--- as to replace my usage of toggleterm.nvim, which didn't work out too well thus
--- far (but I haven't given up, trust!). My goal is to leverage existing features
--- and integrate with native Nvim instead of reinventing the wheel.
---
--- What this plugin doesn't do (yet):
---     - Support `sudo`
---     - Interactive input
---     - Process high outputs without stutter
---
--- # Commands ~
---
---                                                      *:MXCompile*
--- :MXCompile[!] {cmd}     Execute {cmd} in the background. If called with no
---                         arguments, the last known command is re-run.
---                         If called as `:MXCompile!`, it won't automatically
---                         open the quickfix window on completion.
---
---                                                      *:MXRecompile*
--- :MXRecompile[!] {cmd}   Setup a watcher to re-run {cmd} on every buffer save.
---                         Calling with no arguments while a watcher is active
---                         disables it.
---                         If called as `:MXRecompile!`, it won't automatically
---                         open the quickfix window on completion.
---
---                                                      *:MXKill*
--- :MXKill                 Immediately terminate the active background task.
---
--- # Setup ~
---
--- This plugin works out of the box via 'runtimepath'. It can be configured with
--- `vim.g.cme` before the plugin is loaded, and provides a global Lua table for
--- scripting. Call `CME.setup()` to refresh all internal side-effects.
---
--- See |CME-configuration| for `config` structure and default values.
---
--- # Tips ~
---
--- Leverage built-in |quickfix| features to improve your workflow:
---     - Jump between errors with |:cprev| and |:cnext|.
---     - Operate on the quickfix list with |:cdo| and |:cfdo|.
---     - Filter results with |:Cfilter|.
---     - Cycle through previous build results with |:colder| and |:cnewer|.

-- ################################################################################################
--
--                                       MODULE DEFINITION
--
-- ################################################################################################

local CME = {}
local H = {}

local qf = require("cme.qf")

---@toc_entry CONFIGURATION
---@tag CME-configuration
---@class cme.Config
---
---@field shell string Preferred user shell.
---     Default: `vim.o.shell`
---
---@field shell_flags string[] Extra flags to pass to the shell.
---     Default: `{}`
---
---@field shell_expand boolean Expand wildcard characters.
---     Default: `true`
---
---@field interrupt boolean Enable SIGTERM <C-c> for the quickfix window.
---     Default: `true`
---
---@field efm_rules table<string, string[]> Map errorformat to a list of commands.
---     Default:
--- >lua
---     {
---             [vim.o.grepformat] = { "grep", "rg" },
---             ["%f::0,%l"] = { "find", "fd" },
---     }
--- <
---
---@field modifiers table<string, string|function> Command mutation rules.
---     Hooks used to normalize shell tool output for the |quickfix| list.
---     Strings are appended; functions receive the full command and return its
---     replacement. This occurs after expansion but before shell invocation.
---
---     Default:
--- >lua
---     {
---             -- Appends flags to ensure output matches the efm above
---             find = "-printf '%p::0\\n'",
---
---             -- Conditional: only appends flags if user omitted them
---             -- Whitespace prefix on the return value is handled here
---             fd = function(cmd)
---                     if not cmd:match("--format") then
---                             return cmd .. ' --format="{}::0"'
---                     else
---                             return cmd
---                     end
---             end,
---     }
--- <
---
---@usage >lua
---     ---@type cme.Opts
---     vim.g.cme = {
---             shell = "nu",
---             shell_flags = { "-m", "psql" },
---             shell_expand = false,
---             interrupt = false,
---             efm_rules = {
---                     ["buffer"] = { "just" },
---             },
---             modifiers = {
---                     ls = "-la",
---             },
---     }
--- <

---@type cme.Config
CME.config = {
        shell = vim.o.shell,
        shell_flags = {},
        shell_expand = true,
        interrupt = true,
        efm_rules = {
                [vim.o.grepformat] = { "grep", "rg" },
                ["%f::0,%l"] = { "find", "fd" },
        },
        modifiers = {
                find = "-printf '%p::0\\n'",
                fd = function(cmd)
                        if not cmd:match("--format") then
                                return cmd .. ' --format="{}::0"'
                        else
                                return cmd
                        end
                end,
        },
}

--- Module setup.
---
--- Merges the provided {config} OR `vim.g.cme` with the defaults to establish the
--- active state. This function initializes |autocommand|s, |user-commands|, and
--- |mapping|s. Can be called multiple times to reload settings.
---
---@param config cme.Opts? Optional overrides.
function CME.setup(config)
        if vim.version.cmp(vim.version(), { 0, 12, 0 }) < 0 then
                vim.notify(
                        "cme.nvim requires Neovim 0.12+",
                        vim.log.levels.ERROR,
                        { title = "cme" }
                )
                return
        end

        -- export module
        _G.CME = CME

        -- use local var to avoid de/reserialization via lua-vim bridge roundtrip
        local validated_config = H.setup_config(config or vim.g.cme --[[@as cme.Opts?]])
        H.apply_config(validated_config)
end

---@toc_entry PLUGIN API
---@tag CME-api
---@tag CME-API
---@text
--- Public module functions for Compilation Mode, not in Emacs :)

--- Run compilation.
---
--- Internally executes the provided command (or last known) in the background
--- and populates the quickfix list. If {opts.bang} is true, it suppresses the
--- automatic opening of the quickfix window.
---
---@param opts { args: string?, bang: boolean? }? Command options.
function CME.compile(opts)
        opts = opts or {}

        -- parse arguments and set errorformat {{{
        -- resolve the command string from args or history
        local raw_args = (opts.args and opts.args ~= "") and opts.args or H.state.last_cmd
        if not raw_args or raw_args == "" then
                vim.notify("Command required", vim.log.levels.ERROR, { title = "cme" })
                return
        end

        local cmd = CME.config.shell_expand and vim.fn.expandcmd(raw_args) or raw_args

        -- clear old processes if any exist
        CME.kill()

        H.state.last_cmd = cmd
        H.state.cwd = vim.uv.cwd() or vim.env.HOME or "/"

        local exe = H.get_executable(cmd)
        -- apply modifiers
        local mod = exe and CME.config.modifiers[exe]
        if type(mod) == "function" then
                cmd = mod(cmd)
        elseif type(mod) == "string" then
                cmd = cmd .. " " .. mod
        end

        -- universal line-based fallback
        local efm = "%l"
        if not exe then
                goto found_efm
        end

        -- check against configured efm rules
        for rule_efm, commands in pairs(CME.config.efm_rules) do
                if vim.tbl_contains(commands, exe) then
                        if rule_efm == "buffer" then
                                efm = vim.bo.efm ~= "" and vim.bo.efm or vim.o.efm
                        else
                                efm = rule_efm
                        end
                        goto found_efm
                end
        end

        do -- scope `makeprg_exe` here so the goto doesn't cause luajit to shit itself
                -- use buffer's efm if it matches the current compiler
                local makeprg_exe = vim.o.makeprg:match("([^%s]+)")
                if makeprg_exe and H.get_executable(makeprg_exe) == exe then
                        efm = vim.bo.efm ~= "" and vim.bo.efm or vim.o.efm
                        goto found_efm
                end
        end

        ::found_efm::
        -- }}}

        -- any two commands with large output back to back will cause horrible
        -- lagging. deleting the active qf buffer deals with that well enough.
        local qf_size = vim.fn.getqflist({ size = 0 }).size
        if qf_size > 20000 then
                local qf_bufnr = vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr
                if qf_bufnr and qf_bufnr > 0 and vim.api.nvim_buf_is_valid(qf_bufnr) then
                        vim.api.nvim_buf_delete(qf_bufnr, { force = true })
                end
        end

        local title = ("compilation://%-6s %-5s [E:0 W:0 I:0] [cmd:%s]"):format("run", "[_]", cmd)
        local header = {
                ("-*- directory: %s -*-"):format(vim.fn.fnamemodify(H.state.cwd, ":~")),
                -- HACK: this is not a colon. this is the "Armenian Full Stop", U+0589.
                --       using this prevents the errorformat from incorrectly picking
                --       up the duration as a valid entry.
                ("Compilation started at %s"):format(os.date("%Y-%m-%d %H։%M։%S")),
                " ", -- anti `%-G` padding for header and footer
        }
        vim.fn.setqflist({}, " ", {
                title = title,
                efm = efm,
                lines = header,
        })

        if not opts.bang then
                vim.cmd("copen | wincmd p")
        end

        local command = vim.iter({
                CME.config.shell,
                CME.config.shell_flags or {},
                "-c",
                cmd,
        })
                :flatten()
                :totable()

        vim.api.nvim_exec_autocmds("User", { pattern = "CmeStarted" })

        local ctx = {
                job = nil,
                line_fragment = "",
                queue = {},
                first_flush = true,
                flushing = false,
                efm = efm,
                counts = { E = 0, W = 0, I = 0 },
                cmd = cmd,
        }

        local start_ns = vim.uv.hrtime()

        ctx.job = vim.system(command, {
                text = true,
                detach = true,
                stdout = function(_, data)
                        H.on_data(ctx, data)
                end,
                stderr = function(_, data)
                        H.on_data(ctx, data)
                end,
                env = { CME_NVIM = 1 },
        }, function(obj)
                vim.schedule(function()
                        -- exit handler: don't let old jobs hijack the status
                        if H.state.active_job ~= ctx.job then
                                return
                        end

                        -- commit any text with trailing newlines
                        if ctx.line_fragment ~= "" then
                                table.insert(ctx.queue, ctx.line_fragment)
                                ctx.line_fragment = ""
                        end
                        -- flush before we write the footer
                        H.flush_data(ctx)

                        local delta = (vim.uv.hrtime() - start_ns) / 1e9
                        local duration = H.format_duration(delta)

                        -- HACK: this is not a colon. this is the "Armenian Full Stop", U+0589.
                        --       using this prevents the errorformat from incorrectly picking
                        --       up the duration as a valid entry.
                        local end_time = os.date("%Y-%m-%d %H։%M։%S")

                        local footer_msg
                        local t_status = "exit"
                        local exit_val = obj.code

                        -- if killed internally or externally
                        if obj.signal == 15 or obj.signal == 2 then
                                footer_msg = ("Compilation killed at %s, duration %s"):format(
                                        end_time,
                                        duration
                                )
                                t_status = "killed"
                                exit_val = obj.signal
                        elseif obj.signal ~= 0 then
                                footer_msg = ("Compilation exited abnormally with signal %d at %s, duration %s"):format(
                                        obj.signal,
                                        end_time,
                                        duration
                                )
                                t_status = "signal"
                                exit_val = obj.signal
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

                        vim.fn.setqflist({}, "a", {
                                lines = {
                                        " ", -- anti `%-G` padding for header and footer
                                        footer_msg,
                                },
                                title = ("compilation://%-6s %-5s [E:%d W:%d I:%d] [cmd:%s]"):format(
                                        t_status,
                                        ("[%d]"):format(exit_val),
                                        ctx.counts.E,
                                        ctx.counts.W,
                                        ctx.counts.I,
                                        cmd
                                ),
                        })

                        qf.pretty()
                        vim.cmd("cbottom")

                        if opts.bang then
                                local is_err = obj.signal ~= 0 or obj.code ~= 0
                                local msg = ("Job %s: %s"):format(
                                        is_err and "failed" or "complete",
                                        cmd
                                )
                                vim.notify(
                                        msg,
                                        is_err and vim.log.levels.ERROR or vim.log.levels.INFO,
                                        { title = "cme" }
                                )
                        end

                        local qfbuf = vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr
                        vim.api.nvim_exec_autocmds("User", {
                                pattern = "CmeFinished",
                                data = {
                                        code = obj.code,
                                        signal = obj.signal,
                                        bufnr = qfbuf,
                                },
                        })

                        H.state.active_job = nil
                end)
        end)

        -- update global state
        H.state.active_job = ctx.job
end

--- Toggle recompile watcher.
---
--- Sets up or tears down an autocommand to run compilation on buffer save.
--- Calling with no arguments while a watcher is active disables it.
---
---@param opts { args: string?, bang: boolean? }? Command options.
function CME.recompile(opts)
        if H.state.watch_autocmd then
                pcall(vim.api.nvim_del_autocmd, H.state.watch_autocmd)
                H.state.watch_autocmd = nil

                if not opts or not opts.args or opts.args == "" then
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
        H.state.watch_autocmd = vim.api.nvim_create_autocmd({ "BufWritePost" }, {
                desc = "Watch for recompilation",
                group = augroup,
                callback = function(data)
                        local blacklist = {
                                name = {
                                        "COMMIT_EDITMSG",
                                        "git-rebase-todo",
                                },
                                ext = {
                                        "jjdescription",
                                },
                        }

                        local filename = vim.fn.fnamemodify(data.match, ":t")
                        local extension = vim.fn.fnamemodify(data.match, ":e")

                        if
                                vim.tbl_contains(blacklist.name, filename)
                                or vim.tbl_contains(blacklist.ext, extension)
                        then
                                return
                        end

                        if not H.state.cwd or not data.match:find(H.state.cwd, 1, true) then
                                return
                        end

                        -- focus guard: don't re-run if we're in a different project
                        local focused_buf = vim.api.nvim_buf_get_name(0)
                        if not H.state.cwd or not focused_buf:find(H.state.cwd, 1, true) then
                                return
                        end

                        CME.compile(opts)
                end,
        })

        CME.compile(opts)
end

--- Kill active compilation job.
---
--- Sends a SIGTERM to the process group of the currently active job.
---
---@param update_qf boolean? Whether to update the quickfix list with a termination
---     message.
function CME.kill(update_qf)
        if H.state.active_job then
                -- signal the process group to ensure children are terminated
                pcall(vim.uv.kill, -H.state.active_job.pid, "sigterm")
                if not update_qf then
                        H.state.active_job = nil
                end
        end
end

-- ################################################################################################
--
--                                         HELPER DATA
--
-- ################################################################################################

---@private
---@type cme.Config
H.DEFAULT_CONFIG = vim.deepcopy(CME.config)

---@private
---@type cme.State
H.state = {
        active_job = nil,
        last_cmd = nil,
        cwd = nil,
        watch_autocmd = nil,
}

-- ################################################################################################
--
--                                     HELPER FUNCTIONALITY
--
-- ################################################################################################

---@private
--- Setup configuration.
---
---@param config cme.Opts? Raw configuration table.
---
---@return cme.Config # Validated and merged configuration.
function H.setup_config(config)
        H.validate_config(config)

        local base = vim.deepcopy(H.DEFAULT_CONFIG)
        local user = config or {}
        local out = vim.tbl_deep_extend("force", base, user) --[[@as cme.Config]]

        if not user.efm_rules then
                goto done
        end

        -- manually patch keys that should merge lists.
        -- `tbl_deep_extend` does not merge k=v pairs.
        for k, base_list in pairs(base.efm_rules) do
                local user_list = user.efm_rules[k]
                if user_list then
                        out.efm_rules[k] = vim.iter({ base_list, user_list }):flatten():totable()
                end
        end

        ::done::

        return out
end

---@private
---@param config cme.Opts? Raw configuration table.
function H.validate_config(config)
        vim.validate("config", config, "table", true)
        local c = config or {}

        vim.validate("shell", c.shell, "string", true)

        vim.validate("shell_flags", c.shell_flags, "table", true)
        if c.shell_flags then
                for i, flag in ipairs(c.shell_flags) do
                        vim.validate(("shell_flags[%d]"):format(i), flag, "string")
                end
        end

        vim.validate("shell_expand", c.shell_expand, "boolean", true)
        vim.validate("interrupt", c.interrupt, "boolean", true)

        vim.validate("efm_rules", c.efm_rules, "table", true)
        if c.efm_rules then
                for efm, commands in pairs(c.efm_rules) do
                        vim.validate("efm_rules", efm, "string")

                        local context = ('efm_rules["%s"]'):format(efm)
                        vim.validate(context, commands, "table")

                        for i, cmd in ipairs(commands) do
                                vim.validate(("%s[%d]"):format(context, i), cmd, "string")
                        end
                end
        end

        vim.validate("modifiers", c.modifiers, "table", true)
        if c.modifiers then
                for exe, mod in pairs(c.modifiers) do
                        vim.validate("modifiers", exe, "string")
                        vim.validate(("modifiers['%s']"):format(exe), mod, { "string", "function" })
                end
        end
end

---@private
--- Apply configuration side-effects.
---
---@param config cme.Config Validated configuration table.
function H.apply_config(config)
        CME.config = config
        vim.g.cme = config
        H.create_autocommands()
        H.create_usercommands()
end

---@private
--- Create module autocommands.
function H.create_autocommands()
        local augroup = vim.api.nvim_create_augroup("Cme", { clear = true })

        vim.api.nvim_create_autocmd({ "FileType" }, {
                desc = "Quickfix prettify",
                group = augroup,
                pattern = "qf",
                callback = function(data)
                        vim.wo[0][0].statusline = "%!v:lua.require'cme.qf'.statusline_expr()"
                        qf.pretty(data.buf)
                end,
        })

        vim.api.nvim_create_autocmd("BufReadPost", {
                desc = "Quickfix prettify for history navigation",
                group = augroup,
                pattern = "quickfix",
                callback = function(args)
                        vim.schedule(function()
                                qf.pretty(args.buf)
                        end)
                end,
        })
end

---@private
--- Create module user commands.
function H.create_usercommands()
        vim.api.nvim_create_user_command("MXCompile", function(opts)
                CME.compile(opts)
        end, {
                desc = "Run compilation",
                nargs = "*",
                bang = true,
                complete = "shellcmd",
        })

        vim.api.nvim_create_user_command("MXRecompile", function(opts)
                CME.recompile(opts)
        end, {
                desc = "Toggle recompile watcher",
                nargs = "*",
                bang = true,
                complete = "shellcmd",
        })

        vim.api.nvim_create_user_command("MXKill", function()
                CME.kill(true)
        end, {
                desc = "Kill active compilation",
        })
end

---@private
--- Identify the primary subject of a command string.
---
--- Resolves the terminal executable in shell chains, bypassing bridge commands
--- and flags. Used to index errorformat rules.
---
---@param cmd_str string Raw or expanded command string.
---
---@return string? # The normalized executable name, or nil if not found.
function H.get_executable(cmd_str)
        -- why do i need a tokenizer to parse shell commands...?
        local tokens = {}
        -- generate fragments for state analysis
        for token in cmd_str:gmatch("%S+") do
                table.insert(tokens, token)
        end

        local candidate = nil
        local expect_cmd = true
        local quote_char = nil
        local separators = {
                "&&", -- AND
                ";", -- next
                "||", -- OR
                "|", -- the based unix pipe
        }
        local ignores = {
                "sudo",
                "xargs",
        }

        for _, token in ipairs(tokens) do
                -- are we starting a literal string (e.g., "foo ; bar")?
                local entering_quotes = not quote_char and token:match("^['\"]")
                if entering_quotes then
                        quote_char = token:sub(1, 1)
                end
                -- command/separator logic (but only if outside quotes)
                if not quote_char or entering_quotes then
                        local is_separator = vim.tbl_contains(separators, token)
                                or token:sub(-1) == ";"
                        if is_separator then
                                candidate = nil
                                expect_cmd = true
                        elseif expect_cmd then
                                -- skip blacklisted commands and flags
                                if vim.tbl_contains(ignores, token) then
                                        expect_cmd = true
                                elseif token:sub(1, 1) ~= "-" then
                                        candidate = token
                                        expect_cmd = false
                                end
                        end
                end
                -- does this token end the current quote scope? no escaped quotes count!
                if quote_char and token:sub(-1) == quote_char and token:sub(-2, -2) ~= "\\" then
                        quote_char = nil
                end
        end

        if not candidate then
                return nil
        end

        -- strip any outer quotes that might wrap the executable token
        local exe = candidate:gsub("^['\"]", ""):gsub("['\"]$", "")
        -- extract the filename if a full path was provided (/usr/bin/make -> make)
        if exe:find("/") then
                exe = vim.fn.fnamemodify(exe, ":t")
        end
        return exe
end

---@private
--- Process incoming job data.
---
---@param ctx cme.JobContext Job context.
---@param data string? Raw data chunk.
function H.on_data(ctx, data)
        -- input guard: don't process data from dead jobs
        if not data or H.state.active_job ~= ctx.job then
                return
        end

        local chunk = ctx.line_fragment .. data
        chunk = chunk
                -- strip ANSI color sequences
                :gsub("\x1b%[[:;%d]*m", "")
                -- strip WIN literal ^M
                :gsub("\r\n", "\n")
                -- strip UNIX literal ^M
                :gsub("\r", "\n")

        local lines = vim.split(chunk, "\n", { plain = true, trimempty = false })
        ctx.line_fragment = table.remove(lines) or ""

        if #lines > 0 then
                vim.list_extend(ctx.queue, lines)
        end

        if not ctx.flushing and #ctx.queue > 0 then
                ctx.flushing = true
                vim.schedule(function()
                        H.flush_data(ctx)
                end)
        end
end

---@private
--- Process queued lines and update the quickfix list.
---
---@param ctx cme.JobContext Job context.
function H.flush_data(ctx)
        -- ui guard: don't pollute the quickfix with data from a previous job
        if H.state.active_job ~= ctx.job then
                return
        end

        local batch = ctx.queue
        ctx.queue = {}
        ctx.flushing = false

        if #batch == 0 then
                return
        end

        local items = vim.fn.getqflist({ lines = batch, efm = ctx.efm }).items
        -- update error, warning, info counters
        for _, item in ipairs(items) do
                if item.valid == 1 then
                        local t = (item.type and item.type ~= "") and item.type:upper() or "I"
                        local key = ctx.counts[t] and t or "I"
                        ctx.counts[key] = ctx.counts[key] + 1
                end
        end

        vim.fn.setqflist({}, "a", {
                title = ("compilation://%-6s %-5s [E:%d W:%d I:%d] [cmd:%s]"):format(
                        "run",
                        "[_]",
                        ctx.counts.E,
                        ctx.counts.W,
                        ctx.counts.I,
                        ctx.cmd
                ),
                items = items,
        })

        if ctx.first_flush then
                qf.pretty()
                ctx.first_flush = false
        end
        vim.cmd("cbottom")
end

---@private
--- Format seconds into a human-readable duration string using Mixed Radix Conversion.
---
--- This algorithm decomposes a scalar duration into coefficients for a positional
--- numeral system with varying bases (radices). It iteratively divides the input
--- by conversion factors (60, 60, 24) and uses the modulo operator to normalize
--- each unit (ms, s, m, h) within its respective radix (1000, 60, 60, 24).
---
---@param seconds number The duration in seconds to format.
---
---@return string # A formatted string in the format [DD:][HH:][MM:]SS.mmm.
function H.format_duration(seconds)
        local ms = math.floor((seconds % 1) * 1000)
        local s = math.floor(seconds)
        local m = math.floor(s / 60)
        local h = math.floor(m / 60)
        local d = math.floor(h / 24)

        s = s % 60
        m = m % 60
        h = h % 24

        -- HACK: this is not a colon. this is the "Armenian Full Stop", U+0589.
        --       using this prevents the errorformat from incorrectly picking
        --       up the duration as a valid entry.
        if d > 0 then
                return ("%02d։%02d։%02d։%02d.%03d"):format(d, h, m, s, ms)
        elseif h > 0 then
                return ("%02d։%02d։%02d.%03d"):format(h, m, s, ms)
        elseif m > 0 then
                return ("%02d։%02d.%03d"):format(m, s, ms)
        else
                return ("%d.%03d"):format(s, ms)
        end
end

-- expose internal access for Busted and :checkhealth
setmetatable(CME, {
        __index = function(_, key)
                if key == "__INTERNAL_H" then
                        return H
                end
        end,
        -- block set and get metatable
        __metatable = "INTERNAL",
})

return CME

---@toc_entry TROUBLESHOOTING
---@tag CME-troubleshooting
---@text
--- If you encounter issues, please follow these steps:
---
--- Run |:checkhealth| `cme` to verify your environment, Nvim version, and
--- database accessibility.
---
--- Use the provided minimal reproduction script to isolate the issue from your
--- personal configuration:
--- >bash
---     just repro
--- <
--- Alternatively, run it directly with Neovim:
--- >bash
---     nvim --clean -u scripts/repro.lua
--- <
--- If the issue persists in the minimal environment, please report it at:
---     https://codeberg.org/yilisharcs/cme.nvim/issues

---@toc_entry SIMILAR PLUGINS
---@tag CME-similar-plugins
---@text
---     - [tpope-vim-dispatch](https://github.com/tpope/vim-dispatch)
---     - [ej-shafran/compile-mode.nvim](https://github.com/ej-shafran/compile-mode.nvim)

-- NOTE: this modeline automatically formats docstrings for mini.doc
-- vim: textwidth=82

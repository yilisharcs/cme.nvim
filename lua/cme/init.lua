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
--- :MXKill                 Immediately terminate the active background job.
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
---     - Cycle through previous results with |:colder| and |:cnewer|.
---     - Filter results with |:Cfilter|.

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
---@field qf_format boolean Enable the custom |quickfixtextfunc| and |syntax|.
---
---     WARNING: The conceal extmarks used for filename truncation can cause
---              the cursor to behave erratically, jumping left and right as
---              the length of the concealed region changes.
---
---     Default: `true`
---
---@field qf_pad number Width for filename padding and conceal truncation.
---     Default: `34`
---
---@field efm_rules table<string, string[]> Map errorformat to a list of commands.
---     Default:
--- >lua
---     {
---             ["%f:%l:%c:%m,%f:%l:%m"] = { "grep", "rg" },
---             ["%f::0,%l"] = { "find", "fd" },
---     }
--- <
---
---@field modifiers table<string, string|function> Command mutation rules.
---     Hooks used to normalize shell tool output for the |quickfix| list.
---     Strings or function return values are injected after the executable and
---     before other flags; functions return `nil` to skip. This occurs after
---     expansion but before shell invocation.
---
---     Default:
--- >lua
---     {
---             -- Appends flags to ensure output matches the efm above
---             find = "-printf '%p::0\\n'",
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
---@field syntax table<string, string[]> Command-specific syntax injection.
---     Maps command prefixes to |filetype| names for the quickfix buffer.
---
---     Default: `{}`
---
---@usage >lua
---     ---@type cme.Opts
---     vim.g.cme = {
---             shell = "nu",
---             shell_flags = { "-m", "psql" },
---             shell_expand = false,
---             interrupt = false,
---             qf_format = false,
---             qf_pad = 26,
---             efm_rules = {
---                     ["buffer"] = { "just" },
---             },
---             modifiers = {
---                     ls = "-la",
---             },
---             syntax = {
---                     git = { "git" },
---             },
---     }
--- <

---@type cme.Config
CME.config = {
        shell = vim.o.shell,
        shell_flags = {},
        shell_expand = true,
        interrupt = true,
        qf_format = true,
        qf_pad = 34,
        efm_rules = {
                ["%f:%l:%c:%m,%f:%l:%m"] = { "grep", "rg" },
                ["%f::0,%l"] = { "find", "fd" },
        },
        modifiers = {
                find = "-printf '%p::0\\n'",
                fd = function(cmd)
                        if not cmd:match("--format") then
                                return '--format="{}::0"'
                        end
                end,
        },
        syntax = {},
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
                vim.notify("cme.nvim requires Neovim 0.12+", vim.log.levels.ERROR, { title = "cme" })
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
---@param conf cme.RunConf? Per-run configuration.
function CME.compile(opts, conf)
        opts = opts or {}
        conf = conf or {}

        local raw_args, cmd = H.resolve_cmd(opts)
        if not raw_args then
                return
        end

        -- clear old processes if any exist
        CME.kill()

        H.state.last_cmd = cmd
        H.state.cwd = vim.uv.cwd() or vim.env.HOME or "/"

        local exe
        cmd, exe = H.apply_modifiers(cmd)
        local efm = H.resolve_efm(exe)

        H.prepare_qf(efm, cmd, conf, opts.bang)

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
                cmd_display = conf.cmd_display,
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
                        H.on_exit(ctx, opts, start_ns, obj)
                end)
        end)

        -- update global state
        H.state.active_job = ctx.job
end

--- Toggle recompile watcher.
---
--- Sets up or tears down an autocommand to run compilation on buffer save.
--- Calling with no arguments while a watcher is active disables it. If
--- {opts.bang} is true, it suppresses the automatic opening of the quickfix
--- window.
---
---@param opts { args: string?, bang: boolean? }? Command options.
---@param conf cme.RunConf? Per-run configuration.
function CME.recompile(opts, conf)
        if H.state.watch_autocmd then
                pcall(vim.api.nvim_del_autocmd, H.state.watch_autocmd)
                H.state.watch_autocmd = nil

                if not opts or not opts.args or opts.args == "" then
                        vim.notify("Compilation watcher disabled.", vim.log.levels.INFO, { title = "cme" })
                        vim.cmd("silent cclose")
                        return
                end
        end

        local augroup = vim.api.nvim_create_augroup("Cme_Recompile", { clear = true })
        H.state.watch_autocmd = vim.api.nvim_create_autocmd({ "BufWritePost" }, {
                desc = "Watch for recompilation",
                group = augroup,
                callback = H.on_save(opts, conf),
        })

        CME.compile(opts, conf)
end

--- Kill active compilation job.
---
--- Sends a SIGTERM to the process group of the currently active job. When
--- {update_qf} is `true`, the job object is retained so the exit handler can
--- write a termination message to the quickfix list. When `false`, the job
--- reference is cleared immediately.
---
---@param update_qf boolean? Whether to keep the job reference for the exit
---     handler to write a termination message.
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
        vim.validate("qf_format", c.qf_format, "boolean", true)
        vim.validate("qf_pad", c.qf_pad, "number", true)

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

        vim.validate("syntax", c.syntax, "table", true)
        if c.syntax then
                for ft, commands in pairs(c.syntax) do
                        vim.validate("syntax", ft, "string")

                        local context = ('syntax["%s"]'):format(ft)
                        vim.validate(context, commands, "table")

                        for i, cmd in ipairs(commands) do
                                vim.validate(("%s[%d]"):format(context, i), cmd, "string")
                        end
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

        if config.qf_format then
                vim.o.qftf = "{info -> v:lua.require'cme.qf'.quickfixtextfunc(info)}"
        end
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

                        -- apply custom syntax if configured
                        local title = vim.fn.getqflist({ title = 0 }).title
                        if not qf.is_cme_qf(title) then
                                goto done
                        end
                        for ft, commands in pairs(CME.config.syntax) do
                                for _, pattern in ipairs(commands) do
                                        if H.state.last_cmd:match("^" .. vim.pesc(pattern)) then
                                                vim.bo[data.buf].filetype = ft
                                                return
                                        end
                                end
                        end
                        ::done::
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
---@return string?, integer? # Normalized executable name, end position; nil if not found.
function H.get_executable(cmd_str)
        -- why do i need a tokenizer to parse shell commands...?
        local tokens = {}
        -- generate fragments for state analysis
        for token in cmd_str:gmatch("%S+") do
                table.insert(tokens, token)
        end

        local candidate = nil
        local candidate_end = nil
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

        local search_pos = 1
        for _, token in ipairs(tokens) do
                local s = cmd_str:find(vim.pesc(token), search_pos)
                local e = s and s + #token - 1
                -- are we starting a literal string (e.g., "foo ; bar")?
                local entering_quotes = not quote_char and token:match("^['\"]")
                if entering_quotes then
                        quote_char = token:sub(1, 1)
                end
                -- command/separator logic (but only if outside quotes)
                if not quote_char or entering_quotes then
                        local is_separator = vim.tbl_contains(separators, token) or token:sub(-1) == ";"
                        if is_separator then
                                candidate = nil
                                candidate_end = nil
                                expect_cmd = true
                        elseif expect_cmd then
                                -- skip blacklisted commands and flags
                                if vim.tbl_contains(ignores, token) then
                                        expect_cmd = true
                                elseif token:sub(1, 1) ~= "-" then
                                        candidate = token
                                        candidate_end = e
                                        expect_cmd = false
                                end
                        end
                end
                -- does this token end the current quote scope? no escaped quotes count!
                if quote_char and token:sub(-1) == quote_char and token:sub(-2, -2) ~= "\\" then
                        quote_char = nil
                end
                search_pos = e and e + 1 or search_pos
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
        return exe, candidate_end
end

---@private
--- Resolve the command string from arguments or history.
---
---@param opts { args: string? } Command options.
---
---@return string?, string? # raw_args, expanded cmd; nil if unavailable.
function H.resolve_cmd(opts)
        -- resolve the command string from args or history
        local raw_args = (opts.args and opts.args ~= "") and opts.args or H.state.last_cmd
        if not raw_args or raw_args == "" then
                vim.notify("Command required", vim.log.levels.ERROR, { title = "cme" })
                return nil, nil
        end

        local cmd = CME.config.shell_expand and vim.fn.expandcmd(raw_args) or raw_args
        return raw_args, cmd
end

---@private
--- Inject modifier flags after the executable in a command string.
---
---@param cmd string The command to modify.
---
---@return string, string? # Modified command and resolved executable name.
function H.apply_modifiers(cmd)
        local exe, exe_end = H.get_executable(cmd)
        -- apply modifiers
        local mod = exe and CME.config.modifiers[exe]
        local flags
        if type(mod) == "function" then
                flags = mod(cmd)
        elseif type(mod) == "string" then
                flags = mod
        end
        if flags and flags ~= "" and exe_end then
                local before = cmd:sub(1, exe_end)
                local after = cmd:sub(exe_end + 1)
                cmd = before .. " " .. flags .. after
        end
        return cmd, exe
end

---@private
--- Determine the errorformat for a given executable.
---
--- Checks configured efm rules, buffer efm, and makeprg in order.
--- Falls back to line-based parsing ("%l") if no rule matches.
---
---@param exe string? The resolved executable name.
---
---@return string # Errorformat string.
function H.resolve_efm(exe)
        -- universal line-based fallback
        local efm = "%l"

        if not exe then
                return efm
        end

        -- check against configured efm rules
        for rule_efm, commands in pairs(CME.config.efm_rules) do
                if vim.tbl_contains(commands, exe) then
                        if rule_efm == "buffer" then
                                efm = vim.bo.efm ~= "" and vim.bo.efm or vim.o.efm
                        else
                                efm = rule_efm
                        end
                        return efm
                end
        end

        -- use buffer's efm if it matches the current compiler
        local makeprg_exe = vim.o.makeprg:match("([^%s]+)")
        if makeprg_exe and H.get_executable(makeprg_exe) == exe then
                efm = vim.bo.efm ~= "" and vim.bo.efm or vim.o.efm
        end

        return efm
end

---@private
--- Initialize the quickfix list for a new compilation run.
---
--- Trims oversized qf buffers, writes the header, and opens the
--- quickfix window unless {bang} is true.
---
---@param efm string The errorformat for this run.
---@param cmd string The command being executed.
---@param conf cme.RunConf Per-run configuration.
---@param bang boolean? Suppress quickfix opening when true.
function H.prepare_qf(efm, cmd, conf, bang)
        -- any two commands with large output back to back will cause horrible
        -- lagging. deleting the active qf buffer deals with that well enough.
        local qf_size = vim.fn.getqflist({ size = 0 }).size
        if qf_size > 20000 then
                local qf_bufnr = vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr
                if qf_bufnr and qf_bufnr > 0 and vim.api.nvim_buf_is_valid(qf_bufnr) then
                        vim.api.nvim_buf_delete(qf_bufnr, { force = true })
                end
        end

        local title = ("compilation://%-6s %-5s [E:0 W:0 I:0] [cmd:%s]"):format("run", "[_]", conf.cmd_display or cmd)
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

        if not bang then
                vim.cmd("copen | wincmd p")
        end
end

---@private
--- Handle job exit: flush output, write footer, update qf, fire events.
---
---@param ctx cme.JobContext Job context.
---@param opts { bang: boolean? } Command options.
---@param start_ns number High-resolution start timestamp.
---@param obj { code: integer, signal: integer } Exit status from |vim.system()|.
function H.on_exit(ctx, opts, start_ns, obj)
        -- don't let old jobs hijack the status
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
                footer_msg = ("Compilation killed at %s, duration %s"):format(end_time, duration)
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
                footer_msg = ("Compilation finished at %s, duration %s"):format(end_time, duration)
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
                        ctx.cmd_display or ctx.cmd
                ),
        })

        qf.pretty()
        vim.cmd("cbottom")

        if opts.bang then
                local is_err = obj.signal ~= 0 or obj.code ~= 0
                local msg = ("Job %s: %s"):format(is_err and "failed" or "complete", ctx.cmd)
                vim.notify(msg, is_err and vim.log.levels.ERROR or vim.log.levels.INFO, { title = "cme" })
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
end

---@private
--- Build the callback for the recompile watcher autocmd.
---
--- Checks blacklist, cwd, and focus guards before triggering recompilation.
---
---@param opts { args: string? } Command options.
---@param conf cme.RunConf Per-run configuration.
---
---@return fun(data: { match: string }) # Autocommand callback.
function H.on_save(opts, conf)
        local blacklist = {
                name = { "COMMIT_EDITMSG", "git-rebase-todo" },
                ext = { "jjdescription" },
        }

        return function(data)
                local filename = vim.fn.fnamemodify(data.match, ":t")
                local extension = vim.fn.fnamemodify(data.match, ":e")

                if vim.tbl_contains(blacklist.name, filename) or vim.tbl_contains(blacklist.ext, extension) then
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

                CME.compile(opts, conf)
        end
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
                        ctx.cmd_display or ctx.cmd
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
--- Format seconds into a human-readable duration string.
---
--- Uses successive division to decompose the input into days, hours, minutes,
--- seconds, and milliseconds. Each unit is extracted via integer division by
--- its ratio (24, 60, 60, 1000), with the remainder passing to the next level.
---
---@param seconds number The duration in seconds to format.
---
---@return string # Formatted string in the format [DD:][HH:][MM:]SS.mmm.
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
--- Run |:checkhealth| `cme` to verify your environment and Nvim version.
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

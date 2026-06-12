local Health = {}

local start = vim.health.start
local ok = vim.health.ok
local warn = vim.health.warn
local error = vim.health.error
local info = vim.health.info

function Health.check()
        start("cme.nvim [status]")

        -- check version
        if vim.version.cmp(vim.version(), { 0, 12, 0 }) < 0 then
                error("Neovim 0.12.0 or later is required.")
                return
        end

        if jit then
                ok("LuaJIT runtime detected.")
        else
                error("Lua runtime lacks `goto` support.", "Install a LuaJIT-based Neovim build.")

                local src = debug.getinfo(1, "S").source
                local dir = vim.fs.dirname(src:sub(2))

                local incompat = {}
                for name, type in vim.fs.dir(dir) do
                        if type == "file" and vim.fs.ext(name) == "lua" then
                                local count = 0
                                for line in io.lines(vim.fs.joinpath(dir, name)) do
                                        if line:match("goto%s+%w+") or line:match("::%w+::") then
                                                count = count + 1
                                        end
                                end
                                if count > 0 then
                                        table.insert(incompat, ("%s (%d usages)"):format(name, count))
                                end
                        end
                end

                if #incompat > 0 then
                        warn("Files containing `goto`:")
                        for _, f in ipairs(incompat) do
                                info("->     " .. f)
                        end
                end

                return
        end

        -- load module for final checks
        local res, CME = pcall(require, "cme")
        if not res then
                error("Could not load 'cme' module.")
                return
        end

        -- check configuration
        local config_ok, err = pcall(CME.__INTERNAL_H.validate_config, vim.g.cme)
        if not config_ok then
                error(("Invalid configuration: %s"):format(err))
        else
                ok("Configuration is valid.")
        end
end

return Health

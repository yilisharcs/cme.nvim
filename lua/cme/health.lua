local Health = {}

local start = vim.health.start
local ok = vim.health.ok
-- local warn = vim.health.warn
local error = vim.health.error
-- local info = vim.health.info

function Health.check()
        start("cme.nvim [status]")

        -- check version
        if vim.version.cmp(vim.version(), { 0, 12, 0 }) < 0 then
                error("Neovim 0.12.0 or later is required.")
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

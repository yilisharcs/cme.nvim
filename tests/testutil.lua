local CME = require("cme")
local M = {}

M.root = vim.fs.normalize(assert(vim.uv.cwd()))
M.artifacts = vim.fs.joinpath(M.root, "tests/artifacts")

--- Reset the plugin state to a clean baseline.
---
---@param config cme.Opts? Optional configuration overrides.
function M.clear(config)
        -- reload plugin
        CME.setup(vim.tbl_deep_extend("force", {}, config or {}))

        -- reset internal state
        local H = CME.__INTERNAL_H
        H.state = {
                active_job = nil,
                last_cmd = nil,
                cwd = nil,
                watch_autocmd = nil,
        }

        -- clear quickfix list
        vim.fn.setqflist({}, "r")
end

--- Bootstrap the test environment.
---
--- Injects helper functions and registers hooks.
function M.setup()
        local env = getfenv(2)
        local original_cwd = assert(vim.uv.cwd())

        -- inject helpers into the caller's scope
        env.clear = M.clear

        if env.before_each then
                env.before_each(function()
                        M.clear()
                end)
        end

        if env.after_each then
                env.after_each(function()
                        vim.uv.chdir(original_cwd)
                end)
        end
end

--- Create a temporary directory inside artifacts.
---
---@return string # Path to the created directory.
function M.create_temp_dir()
        local hex_id = ("%x"):format(math.random(0x100000, 0xffffff))
        local path = vim.fs.joinpath(M.artifacts, hex_id)
        vim.fn.mkdir(path, "p")
        return path
end

return M

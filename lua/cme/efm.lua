local M = {}

M.rules = {
        -- stylua: ignore start
        [vim.o.grepformat] = { "grep", "rg" },
        ["%f::0,%l"]       = { "find", "fd" },
        -- stylua: ignore end
}

return M

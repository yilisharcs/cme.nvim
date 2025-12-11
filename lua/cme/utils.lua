local M = {}

-- stylua: ignore
local function merge_lists(a, b)
        local out = {}
        for _, v in ipairs(a or {}) do table.insert(out, v) end
        for _, v in ipairs(b or {}) do table.insert(out, v) end
        return out
end

function M.tbl_list_concat(base, user)
        local out = vim.tbl_deep_extend("force", base, user)

        -- manually patch the specific keys that should merge lists
        for k, v in pairs(base.efm_rules) do
                if user.efm_rules and user.efm_rules[k] then
                        out.efm_rules[k] = merge_lists(v, user.efm_rules[k])
                end
        end

        return out
end

return M

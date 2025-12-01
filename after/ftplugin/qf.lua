vim.wo[0][0].concealcursor = "nvc"
vim.wo[0][0].conceallevel = 2

local ns = vim.api.nvim_create_namespace("cme_qf")
vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

-- stylua: ignore start
vim.api.nvim_set_hl(0, "CmeDateTime",    { fg = "#ffaf00", bold = true, ctermfg = "green" })
vim.api.nvim_set_hl(0, "CmeExitSuccess", { fg = "#00af5f", bold = true, ctermfg = "red" })
vim.api.nvim_set_hl(0, "CmeExitFailure", { fg = "#d7005f", bold = true, ctermfg = "yellow" })
vim.api.nvim_set_hl(0, "CmeDuration",    { fg = "#00afff", bold = true, ctermfg = "cyan" })
vim.api.nvim_set_hl(0, "CmeDirectory",   { link = "CmeDuration" })
-- stylua: ignore end

local targets = { 0, 1, 2, vim.api.nvim_buf_line_count(0) - 1 }

local rules = {
        ["%d+-%d+-%d+ %d+:%d+:%d+"] = "CmeDateTime",
        ["%d[%d:]*%.%d%d%d"] = "CmeDuration",
        ["finished"] = "CmeExitSuccess",
        ["exited abnormally"] = "CmeExitFailure",
        ["signal %d+"] = { group = "CmeExitFailure", offset = { left = 6 } },
        ["code %d+"] = { group = "CmeExitFailure", offset = { left = 4 } },
        ["%s[~/].*"] = { group = "CmeDirectory", offset = { right = 4 } },
}

for _, row in ipairs(targets) do
        local text = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
        if text then
                for pattern, opts in pairs(rules) do
                        local group = type(opts) == "string" and opts or opts.group
                        local left = type(opts) == "table" and opts.offset.left or 0
                        local right = type(opts) == "table" and opts.offset.right or 0
                        local s, e = text:find(pattern)
                        if s then
                                vim.api.nvim_buf_set_extmark(0, ns, row, s - 1 + left, {
                                        end_col = e - right,
                                        hl_group = group,
                                })
                        end
                end
        end
end

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
for i, line in ipairs(lines) do
        local row = i - 1
        if line:sub(1, 3) == "|| " then
                vim.api.nvim_buf_set_extmark(0, ns, row, 0, {
                        end_col = 3,
                        conceal = "",
                })
        end
        if #line > 2 and line:sub(-3) == "|| " then
                vim.api.nvim_buf_set_extmark(0, ns, row, #line - 3, {
                        end_col = #line,
                        conceal = "",
                })
        end
end

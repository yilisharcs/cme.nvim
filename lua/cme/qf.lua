local M = {}

--- Whether a quickfix list belongs to cme.
---
---@param title string Quickfix list title.
---@return boolean
function M.is_cme_qf(title)
        return type(title) == "string" and title:match("^compilation://") ~= nil
end

function M.statusline_expr()
        local ok, raw = pcall(vim.api.nvim_win_get_var, vim.g.statusline_winid, "quickfix_title")

        -- stylua: ignore
        local title = (ok and raw) and raw
                :gsub("%%", "%%%%")
                :gsub("%[(%d+)%]", function(code)
                        local hl = (code == "0") and "%#DiagnosticOk#" or "%#DiagnosticError#"
                        return "[" .. hl .. code .. "%*]"
                end)
                :gsub("E:(%d+)", "E:%%#DiagnosticError#%1%%*")
                :gsub("W:(%d+)", "W:%%#DiagnosticWarn#%1%%*")
                :gsub("I:(%d+)", "I:%%#DiagnosticInfo#%1%%*")
                or ""

        return "%t " .. title .. " %=%-15(%l,%c%V%) %P"
end

function M.pretty(target_bufnr)
        local bufnr = target_bufnr or vim.fn.getqflist({ qfbufnr = 0 }).qfbufnr
        if not bufnr or bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
                return
        end

        local ns = vim.api.nvim_create_namespace("cme_qf")
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

        -- stylua: ignore
        local raw = vim.fn.getqflist({ title = 0 }).title
        local is_cme = M.is_cme_qf(raw)

        -- since we globally set 'qftf' and listen to filetype events, we must
        -- differentiate between cme-managed qflists and native ones (helpgrep,
        -- vimgrep, etc.) so we don't apply the header and footer extmarks
        if is_cme then
                local function hl_from(name, link_to)
                        local from = vim.tbl_extend("keep", {}, vim.api.nvim_get_hl(0, { name = link_to }))
                        from.bold = true
                        vim.api.nvim_set_hl(0, name, from)
                end
                hl_from("CmeDateTime", "DiagnosticWarn")
                hl_from("CmeExitSuccess", "DiagnosticOk")
                hl_from("CmeExitFailure", "DiagnosticError")
                hl_from("CmeDuration", "DiagnosticInfo")
                hl_from("CmeDirectory", "DiagnosticInfo")

                local targets = { 0, 1, vim.api.nvim_buf_line_count(bufnr) - 1 }

                local rules = {
                        ["%d+-%d+-%d+ %d+։%d+։%d+"] = "CmeDateTime",
                        ["%d[%d։]*%.%d%d%d"] = "CmeDuration",
                        ["finished"] = "CmeExitSuccess",
                        ["killed"] = "CmeExitFailure",
                        ["exited abnormally"] = "CmeExitFailure",
                        ["signal %d+"] = { group = "CmeExitFailure", offset = { left = 6 } },
                        ["code %d+"] = { group = "CmeExitFailure", offset = { left = 4 } },
                        ["%s[~/].*"] = { group = "CmeDirectory", offset = { right = 4 } },
                }

                for _, row in ipairs(targets) do
                        local text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
                        for pattern, opts in pairs(text and rules or {}) do
                                local group = type(opts) == "string" and opts or opts.group
                                local l = type(opts) == "table" and opts.offset.left or 0
                                local r = type(opts) == "table" and opts.offset.right or 0
                                local s, e = text:find(pattern)
                                if s then
                                        vim.api.nvim_buf_set_extmark(bufnr, ns, row, s - 1 + l, {
                                                end_col = e - r,
                                                hl_group = group,
                                        })
                                end
                        end
                end
        end

        vim.fn.matchadd("Conceal", [[\(^|| \)\|\(|| $\)]], 10, -1, { conceal = "" })

        if not vim.g.cme.qf_format then
                goto skip_conceal
        end
        local limit = vim.g.cme.qf_pad or 34
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local start_row = is_cme and 2 or 0
        local end_row = is_cme and line_count - 2 or line_count - 1
        for row = start_row, end_row do
                local text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
                if not text then
                        break
                end

                -- 3 if typed (E|…), else 1 for untyped filename start
                local fname_start = text:match("^[EWINH]|") and 3 or 1
                local pipe = text:find("|", fname_start + limit)
                if not pipe then
                        goto continue
                end

                -- skip non-formatted entries. `getqflist` considered boilerplate here.
                if not text:sub(pipe + 1):match("^%s+%d+:%d+%s+|") then
                        goto continue
                end

                local fname_slice = text:sub(fname_start, pipe - 2)
                local fname = vim.trim(fname_slice)
                local fname_visual_width = vim.fn.strdisplaywidth(fname)
                if fname_visual_width > limit then
                        -- non-ASCII characters have different widths.
                        -- we can't assume bytecount == length.
                        local suffix_bytes =
                                #vim.fn.matchstr(fname, "\\%>" .. (fname_visual_width - limit + 1) .. "v.*")
                        local cutoff = #fname - suffix_bytes
                        local leading = #fname_slice - #fname_slice:gsub("^%s+", "")
                        local start_col = fname_start + leading - 1
                        vim.api.nvim_buf_set_extmark(bufnr, ns, row, start_col, {
                                end_col = start_col + cutoff,
                                conceal = "…",
                        })
                end

                ::continue::
        end

        ::skip_conceal::
end

-- https://github.com/kevinhwang91/nvim-bqf/?tab=readme-ov-file#customize-quickfix-window-easter-egg
function M.quickfixtextfunc(info)
        local items
        if info.quickfix == 1 then
                items = vim.fn.getqflist({ id = info.id, items = 0 }).items
        else
                items = vim.fn.getloclist(info.winid, { id = info.id, items = 0 }).items
        end

        local ret = {}
        for i = info.start_idx, info.end_idx do
                local e = items[i]
                if e.valid == 1 then
                        local fname = (e.bufnr > 0) and vim.fn.bufname(e.bufnr) or ""
                        if fname == "" then
                                fname = "[No Name]"
                        else
                                fname = fname:gsub("^" .. vim.env.HOME, "~")
                        end
                        local lnum = e.lnum > 99999 and -1 or e.lnum
                        local col = e.col > 999 and -1 or e.col

                        -- strip the ^A helpgrep from the type field
                        local char = e.type:sub(1, 1)
                        local is_tag = char == "\1"
                        local qtype = (e.type == "" or is_tag) and "" or char:upper() .. "|"

                        local pad = vim.g.cme.qf_pad or 34
                        local fname_width = vim.fn.strdisplaywidth(fname)
                        if fname_width < pad then
                                fname = fname .. (" "):rep(pad - fname_width)
                        end
                        -- stylua: ignore
                        local validFmt = (qtype == "")
                                and "%s%s | %5d:%-3d | %s"
                                or "%s %s | %5d:%-3d | %s"
                        table.insert(ret, validFmt:format(qtype, fname, lnum, col, e.text))
                else
                        table.insert(ret, e.text)
                end
        end
        return ret
end

return M

package.path = "./vendor/mini.doc/lua/?.lua;" .. package.path

local minidoc = require("mini.doc")
minidoc.setup()

local spec = {
        id = "cme",
        title = "CME",
        author = "yilisharcs",
        cmd_prefix = "MX",
}

local repo = spec.author .. "/" .. spec.id .. ".nvim"
local url = "https://codeberg.org/" .. repo

-- documentation manifest. `entrypoint` is explicitly placed at the first index
-- of the input array passed to `minidoc.generate()` so it can be accessible as
-- doc[1] in its many hooks.
local manifest = {
        entrypoint = "lua/" .. spec.id .. "/init.lua",
        metadata = {},
}
setmetatable(manifest, {
        __call = function(self)
                return { self.entrypoint, unpack(self.metadata) }
        end,
})

local H = {}

-- indentation levels
H.s4 = string.rep(" ", 4)
H.s8 = string.rep(" ", 8)

--- Check if any line in a section matches a literal pattern.
---
--- This function iterates through the numeric indices of a section object. It
--- returns true on the first match or nil if no match is found.
---@param section table Documentation section object.
---@param pattern string Literal string to find.
---
---@return boolean? # True if found, nil otherwise.
H.has_pattern = function(section, pattern)
        for _, line in ipairs(section) do
                if type(line) == "string" and line:find(pattern, 1, true) then
                        return true
                end
        end
end

--- Find a documentation block by its class name.
H.find_block_by_class = function(doc, class_name)
        local file = doc[1]
        for _, block in ipairs(file) do
                local is_match = block:has_descendant(function(s)
                        return type(s) == "table" and s.info and s.info.id == "@class" and H.has_pattern(s, class_name)
                end)
                if is_match then
                        return block
                end
        end
end

--- Recursively synthesize a Lua table from field definitions.
H.synthesize_lua_table = function(doc, fields, indent)
        local lines = {}

        for _, f in ipairs(fields) do
                -- apply indentation and comment prefix to each line of the description
                local desc = f.desc:gsub("\n", "\n" .. indent .. "-- ")
                table.insert(lines, indent .. "-- " .. desc)

                if f.type:match("^" .. spec.id .. "%.") then
                        local sub_block = H.find_block_by_class(doc, f.type)
                        if sub_block then
                                local sub_fields = H.parse_fields(sub_block)
                                table.insert(lines, indent .. f.name .. " = {")
                                local sub_lines = H.synthesize_lua_table(doc, sub_fields, indent .. H.s8)
                                vim.list_extend(lines, sub_lines)
                                table.insert(lines, indent .. "},")
                        else
                                table.insert(lines, indent .. f.name .. " = {},")
                        end
                elseif f.default and f.default:match("\n") then
                        local body = f.default:gsub("^\n", "")
                        local default_lines = vim.split(body, "\n")
                        local first_line_indent = #(default_lines[1]:match("^(%s*)") or "")
                        local new_lines = {}
                        -- multi-line default: re-indent relative to the first line
                        -- while preserving internal structure, to produce valid Lua
                        for i, dl in ipairs(default_lines) do
                                local leading = dl:match("^(%s*)") or ""
                                local relative_indent = #leading - first_line_indent
                                local trimmed = dl:gsub("^%s*", "")
                                if i == 1 then
                                        new_lines[1] = indent .. f.name .. " = " .. trimmed
                                elseif i == #default_lines then
                                        table.insert(
                                                new_lines,
                                                indent .. string.rep(" ", relative_indent) .. trimmed .. ","
                                        )
                                else
                                        table.insert(new_lines, indent .. string.rep(" ", relative_indent) .. trimmed)
                                end
                        end
                        vim.list_extend(lines, new_lines)
                else
                        table.insert(lines, indent .. f.name .. " = " .. (f.default or "nil") .. ",")
                end
        end

        return lines
end

--- Parse fields from a documentation block.
H.parse_fields = function(block)
        local fields = {}
        for _, s in ipairs(block) do
                local id = (s.info and type(s.info.id) == "string") and s.info.id or ""
                if not id:match("field") then
                        goto next_field
                end

                local lines = {}
                for _, l in ipairs(s) do
                        -- strip structural headers injected by mini.doc
                        if not l:match("Fields%s*.*~") then
                                table.insert(lines, l)
                        end
                end

                local full_text = table.concat(lines, "\n")
                full_text = vim.trim(full_text)

                -- handle mini.doc transformation: {name} -> name
                full_text = full_text:gsub("^{(%S-)}", "%1")

                -- match: name type description...
                -- try mini.doc format `(type)` first to handle spaces in generic types
                local name, type_str, rest
                name, type_str, rest = full_text:match("^(%S+)%s+`%(([^`]+)%)`%s*([\1-\255]*)")
                if not name then
                        name, type_str, rest = full_text:match("^(%S+)%s+(%S+%b<>)%s*([\1-\255]*)")
                end
                if not name then
                        name, type_str, rest = full_text:match("^(%S+)%s+(%S+)%s*([\1-\255]*)")
                end
                if name then
                        local desc = rest:match("^([\1-\255]-)%s*Default:") or rest

                        -- dedent by 4 spaces
                        desc = desc:gsub("\n    ", "\n")

                        -- join lines that are continuations of a sentence while preserving
                        -- the structure of lists and paragraphs. a line is a continuation
                        -- if the previous line doesn't end in punctuation and the current
                        -- line doesn't start with a list marker or whitespace.
                        desc = desc:gsub("([^\n%.%?!:])\n([^-%*%+%s])", "%1 %2")

                        local default = rest:match("Default:%s*([\1-\255]*)$")
                        if default then
                                -- strip backticks from default value
                                default = default:gsub("^`", ""):gsub("`$", "")
                                -- strip vim code block markers from multi-line defaults
                                default = default:gsub("^[\n%s]*>lua\n*", "\n")
                                default = default:gsub("[\n%s]*<[\n%s]*$", "")
                        end
                        table.insert(fields, {
                                name = name,
                                type = type_str,
                                desc = vim.trim(desc),
                                default = default,
                        })
                end

                ::next_field::
        end
        return fields
end

--- Collect specific sections from a block into an accumulator table.
---
---@param block table Documentation block object.
---@param options table Filtering and transformation options.
---@param acc_tbl table Accumulator table for the collected sections.
H.collect_sections = function(block, options, acc_tbl)
        for _, s in ipairs(block) do
                local id = s.info and s.info.id
                if options.id_filter and not options.id_filter(id) then
                        goto next_section
                end

                -- intra-section line filtering
                local content_block = {}
                for _, line in ipairs(s) do
                        local is_invalid = type(line) ~= "string"
                                or line:match("^%s*%-+%s*$")
                                or line:find("Fields ~", 1, true)

                        if is_invalid then
                                goto next_line
                        end
                        table.insert(content_block, line)

                        ::next_line::
                end

                while #content_block > 0 and content_block[#content_block] == "" do
                        table.remove(content_block)
                end

                -- don't accumulate empty section objects in the doctree. you never know...
                if #content_block > 0 then
                        local new_s = { type = "section", info = vim.deepcopy(s.info) }

                        for idx, line in ipairs(content_block) do
                                new_s[idx] = line
                        end

                        -- override section ID for class definitions to suppress the automated
                        -- horizontal line injection, while preserving the actual text content
                        if new_s.info.id == "@class" then
                                new_s.info.id = "@text"
                        end

                        table.insert(acc_tbl, new_s)
                end

                ::next_section::
        end
end

--- shared logic for merging config blocks
H.prepare_doc_tree = function(doc, is_readme)
        local file = doc[1]
        local blocks = { config = nil, var = nil }
        local idxs = { config = nil, var = nil }

        for i, block in ipairs(file) do
                if
                        block:has_descendant(function(s)
                                return type(s) == "table"
                                        and s.info
                                        and s.info.id == "@tag"
                                        and H.has_pattern(s, spec.title .. "-configuration")
                        end)
                then
                        blocks.config, idxs.config = block, i
                elseif
                        block:has_descendant(function(s)
                                return type(s) == "table"
                                        and s.info
                                        and s.info.id == "@tag"
                                        and H.has_pattern(s, spec.title .. ".config")
                        end)
                then
                        blocks.var, idxs.var = block, i
                end
        end

        if is_readme and blocks.config then
                local cfg_fields = H.parse_fields(blocks.config)

                local lines = {
                        "---@type " .. spec.id .. ".Opts",
                        "vim.g." .. spec.id .. " = {",
                }

                -- reassemble configuration documentation from ordered field objects
                -- NOTE: H.s4 offsets mini.doc's default 4-space code block indent so that
                --       after write_pre strips it, the remaining body indent matches H.s8
                local synthesized = H.synthesize_lua_table(doc, cfg_fields, H.s4 .. H.s8)
                vim.list_extend(lines, synthesized)
                table.insert(lines, "}")

                local config_block = blocks.config
                -- wipe existing sections
                for j = 1, #config_block do
                        config_block[j] = nil
                end

                config_block[1] = {
                        type = "section",
                        info = { id = "@text", line_begin = -1, line_end = -1 },
                        [1] = "## CONFIGURATION",
                        [2] = "",
                        parent = config_block,
                        parent_index = 1,
                }

                local code_section = {
                        type = "section",
                        info = { id = "@text", line_begin = -1, line_end = -1 },
                        [1] = ">lua",
                        parent = config_block,
                        parent_index = 2,
                }
                for _, l in ipairs(lines) do
                        table.insert(code_section, l)
                end
                table.insert(code_section, "<")
                config_block[2] = code_section
                return
        end

        if blocks.config and blocks.var then
                local merged_sections = {
                        {
                                type = "section",
                                info = { id = "@text" },
                                [1] = string.rep("-", 78),
                        },
                }

                local blank = {
                        type = "section",
                        info = { id = "@text" },
                        [1] = "",
                }

                -- header tags
                H.collect_sections(blocks.config, {
                        id_filter = function(id)
                                return id == "@tag"
                        end,
                }, merged_sections)
                H.collect_sections(blocks.var, {
                        id_filter = function(id)
                                return id == "@tag"
                        end,
                }, merged_sections)

                -- signature and config class lead
                H.collect_sections(blocks.var, {
                        id_filter = function(id)
                                return id == "@signature"
                        end,
                }, merged_sections)
                H.collect_sections(blocks.config, {
                        id_filter = function(id)
                                return id == "@class"
                        end,
                }, merged_sections)

                table.insert(merged_sections, blank)
                table.insert(merged_sections, {
                        type = "section",
                        info = { id = "@text" },
                        [1] = "Fields ~",
                })

                -- base config fields
                local config_fields = {}
                H.collect_sections(blocks.config, {
                        id_filter = function(id)
                                return id == "@field"
                        end,
                }, config_fields)

                for _, field in ipairs(config_fields) do
                        table.insert(merged_sections, field)
                        table.insert(merged_sections, blank)
                end

                -- footer: config usage and removal of the @type tag
                H.collect_sections(blocks.config, {
                        id_filter = function(id)
                                return id == "@usage"
                        end,
                }, merged_sections)

                -- overwrite entries and trim if the new content is shorter
                for i = 1, #merged_sections do
                        blocks.config[i] = merged_sections[i]
                end
                for i = #merged_sections + 1, #blocks.config do
                        blocks.config[i] = nil
                end

                -- get rid of duplicates
                local duplicates = { idxs.var }

                -- find and remove the block for vim.g.[id] generated
                -- from the @type annotation in the usage block
                for i, block in ipairs(file) do
                        if
                                block:has_descendant(function(s)
                                        return type(s) == "table"
                                                and s.info
                                                and s.info.id == "@tag"
                                                and H.has_pattern(s, "vim.g." .. spec.id)
                                end)
                        then
                                table.insert(duplicates, i)
                        end
                end

                table.sort(duplicates, function(a, b)
                        return a > b
                end)
                for _, idx in ipairs(duplicates) do
                        file:remove(idx)
                end
        end
end

-- logic for Vim help file
local doc_hooks = vim.deepcopy(minidoc.config.hooks)
doc_hooks.doc = function(doc)
        H.prepare_doc_tree(doc, false)
        minidoc.default_hooks.doc(doc)
end

-- logic for README.md
local readme_hooks = vim.deepcopy(minidoc.config.hooks)

-- NOTE: the original hook generates a tags file.
--       the README.md does not need a tags file.
readme_hooks.write_post = function(d)
        local output = d.info.output
        local msg = ("%s is successfully generated."):format(vim.inspect(output))
        vim.notify(msg, vim.log.levels.INFO)
end

readme_hooks.sections["@toc_entry"] = function(s)
        local content = vim.trim(table.concat(s, " "))
        s:clear_lines()
        s:insert("## " .. content)
        s:insert("")
end
readme_hooks.doc = function(doc)
        local file = doc[1]
        H.prepare_doc_tree(doc, true)

        local to_remove = {}
        local skip = false
        for i, block in ipairs(file) do
                local should_remove = false
                -- identify existing blocks to remove for README
                local is_config_tag = block:has_descendant(function(s)
                        return s.info and s.info.id == "@tag" and H.has_pattern(s, spec.title .. "-configuration")
                end)
                local is_class = block:has_descendant(function(s)
                        return s.info
                                and s.info.id == "@class"
                                and H.has_pattern(s, spec.id .. ".")
                                and not H.has_pattern(s, spec.id .. ".Config")
                end)
                local is_var = block:has_descendant(function(s)
                        return s.info and s.info.id == "@tag" and H.has_pattern(s, spec.title .. ".config")
                end)

                if is_config_tag or is_class or is_var then
                        should_remove = true
                end

                -- find the start of the API section
                if
                        block:has_descendant(function(s)
                                return s.info and s.info.id == "@toc_entry" and H.has_pattern(s, "PLUGIN API")
                        end)
                then
                        skip = true
                end

                if skip then
                        should_remove = true
                end

                -- find the next major section to stop skipping
                if
                        block:has_descendant(function(s)
                                return s.info and s.info.id == "@toc_entry" and H.has_pattern(s, "TROUBLESHOOTING")
                        end)
                then
                        skip = false
                        should_remove = false
                end

                if should_remove then
                        table.insert(to_remove, i)
                end
        end

        -- remove the blocks from the tree in reverse
        for i = #to_remove, 1, -1 do
                file:remove(to_remove[i])
        end

        -- remove `[id].Setup` class block
        for i = #file, 1, -1 do
                if
                        file[i]:has_descendant(function(s)
                                return s.info and s.info.id == "@signature" and H.has_pattern(s, spec.title .. ".setup")
                        end)
                then
                        file:remove(i)
                end
        end

        -- NOTE: skip default doc hook which adds Vim modeline!!
        -- minidoc.default_hooks.doc(doc)
end

readme_hooks.write_pre = function(lines)
        -- header
        local res = {
                "# " .. spec.id .. ".nvim",
                "",
                "Compilation Mode, not in Emacs.",
                "",
                "![](./assets/showcase.png)",
                "",
                "## INSTALLATION",
                "",
                "Using Neovim's built-in package manager:",
                "",
                "```lua",
                "vim.pack.add({",
                H.s8 .. 'src = "' .. url .. '",',
                "})",
                "```",
                "",
                "Using [lazy.nvim](https://github.com/folke/lazy.nvim):",
                "",
                "```lua",
                "{",
                H.s8 .. '"' .. repo .. '",',
                H.s8 .. "init = function()",
                H.s8 .. H.s8 .. "vim.g." .. spec.id .. " = { --[[ config goes here ]] }",
                H.s8 .. "end",
                H.s8 .. "specs = { {",
                H.s8 .. H.s8 .. '"https://github.com/nvim-lualine/lualine.nvim",',
                H.s8 .. H.s8 .. "optional = true,",
                H.s8 .. H.s8 .. "-- Fixes the small delay on `on_exit` updates",
                H.s8 .. H.s8 .. "opts = { options = { refresh = { statusline = 16 } } },",
                H.s8 .. "} },",
                "}",
                "```",
                "",
        }

        local in_code_block = false
        for i, line in ipairs(lines) do
                if
                        -- separators
                        line:match("^=+$")
                        or line:match("^%-+$")
                        -- title
                        or line:find(spec.id .. ".nvim.txt", 1, true)
                        -- help tags
                        or line:match("^%s*%*" .. spec.title .. "%S*%*%s*$")
                        -- license line
                        or line:match("^%s*Apache License 2.0 Copyright")
                        -- TOC
                        or line:match("^%s*Table of Contents%s*$")
                        -- modeline
                        or line:match("vim:tw=78:ts=8:noet:ft=help:norl:")
                then
                        goto next_line
                end

                if line:match("^%s+" .. url .. "/issues$") then
                        table.insert(res, "")
                        table.insert(res, vim.trim(line))
                        goto next_line
                end

                -- convert vim code blocks into markdown code blocks
                if line:match("^%s*>lua%s*$") then
                        in_code_block = true
                        table.insert(res, "")
                        table.insert(res, "```lua")
                        goto next_line
                elseif line:match("^%s*>bash%s*$") then
                        in_code_block = true
                        table.insert(res, "")
                        table.insert(res, "```bash")
                        goto next_line
                elseif line:match("^%s*>%s*$") then
                        in_code_block = true
                        table.insert(res, "")
                        table.insert(res, "```")
                        goto next_line
                elseif line:match("^%s*<%s*$") then
                        in_code_block = false
                        table.insert(res, "```")
                        table.insert(res, "")
                        goto next_line
                end

                -- level 3 headers
                local h_title = line:match("^%s*#%s*([^~]-)%s*~%s*$")
                if h_title then
                        table.insert(res, "")
                        table.insert(res, "### " .. vim.trim(h_title))
                        table.insert(res, "")
                        goto next_line
                end

                -- level 5 headers
                local cmd_tag = line:match("^%s+%*(:" .. spec.cmd_prefix .. "%w+)%*%s*$")
                if cmd_tag then
                        local sig = cmd_tag
                        local next_line = lines[i + 1]
                        if next_line then
                                sig = next_line:match("^(:" .. spec.cmd_prefix .. "%w+.-)%s%s") or sig
                        end
                        table.insert(res, "")
                        table.insert(res, "##### " .. sig)
                        table.insert(res, "")
                        goto next_line
                end

                if in_code_block then
                        -- de-indent
                        line = line:gsub("^" .. H.s4, "")
                else
                        line = line:gsub("%*" .. spec.id .. ".nvim%*", "_" .. spec.id .. ".nvim_")
                        -- replace command signature at start of
                        -- line with spaces to maintain alignment
                        line = line:gsub("^:" .. spec.cmd_prefix .. "%w+.-%s%s+", function(m)
                                return string.rep(" ", #m)
                        end)

                        -- inline formatting
                        line = line:gsub("|:checkhealth| `" .. spec.id .. "` ", "`:checkhealth " .. spec.id .. "` ")
                        line = line:gsub("|([^|]+)|", "`%1`")
                end
                table.insert(res, line)

                ::next_line::
        end

        -- append license
        vim.list_extend(res, {
                "",
                "## LICENSE",
                "",
                "Copyright 2025-2026 " .. spec.author,
                "",
                'Licensed under the Apache License, Version 2.0 (the "License");',
                "you may not use this file except in compliance with the License.",
                "You may obtain a copy of the License at",
                "",
                "http://www.apache.org/licenses/LICENSE-2.0",
                "",
                "Unless required by applicable law or agreed to in writing, software",
                'distributed under the License is distributed on an "AS IS" BASIS,',
                "WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.",
                "See the License for the specific language governing permissions and",
                "limitations under the License.",
        })

        -- cleanup: ensure single blank lines between blocks
        local final_res = {}
        for i, line in ipairs(res) do
                if line ~= "" or (final_res[#final_res] ~= "" and i < #res) then
                        table.insert(final_res, line)
                end
        end

        return final_res
end

minidoc.generate(manifest(), "doc/" .. spec.id .. ".nvim.txt", {
        hooks = doc_hooks,
})

minidoc.generate(manifest(), "README.md", {
        hooks = readme_hooks,
})

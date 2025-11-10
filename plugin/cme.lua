if vim.g.loaded_cme == 1 then return end
vim.g.loaded_cme = 1

if not vim.g.cme_bin then
        local plugin = debug.getinfo(1, "S").source:match("@?(.*)")
        local root = vim.fs.dirname(vim.fs.dirname(plugin))
        local bin = vim.fs.joinpath(root, "bin/cme-nvim.sh")
        vim.g.cme_bin = bin
end

vim.api.nvim_create_user_command(
        "Compile",
        function(opts) require("cme").compile(opts) end,
        { nargs = "*", complete = "shellcmd" }
)

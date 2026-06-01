if vim.g.loaded_cme == 1 then
        return
end
vim.g.loaded_cme = 1

require("cme").setup()

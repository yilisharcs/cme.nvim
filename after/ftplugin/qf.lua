if vim.g.cme.interrupt == true then
        vim.keymap.set("n", "<C-c>", function()
                require("cme").kill(true)
        end, {
                buffer = true,
                desc = "Cancel active compilation task",
        })
end

vim.wo[0][0].conceallevel = 2
vim.wo[0][0].concealcursor = "nvc"
vim.wo[0][0].list = false

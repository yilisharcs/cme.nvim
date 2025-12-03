if vim.g.cme.interrupt == true then
        vim.keymap.set("n", "<C-c>", require("cme").kill_task, {
                buffer = true,
                desc = "Cancel active compilation task",
        })
end

vim.wo[0][0].conceallevel = 2
vim.wo[0][0].concealcursor = "nvc"

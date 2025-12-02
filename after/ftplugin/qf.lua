if vim.g.cme.interrupt == true then
        vim.keymap.set("n", "<C-c>", require("cme").kill_task, {
                buffer = true,
                desc = "Cancel active compilation task",
        })
end

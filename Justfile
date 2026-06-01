set shell               := ["nu", "-c"] # for single-line execution
set script-interpreter  := ["nu"]       # for bundled execution

doc:
        nvim --clean --headless -l scripts/doc.lua
[script]
lint:
        $env.VIMRUNTIME = (nvim --clean --headless -c 'lua io.stdout:write(vim.env.VIMRUNTIME)' -c 'q')
        lua-language-server --check . --checklevel=Hint


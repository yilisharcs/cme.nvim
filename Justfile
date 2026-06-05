set shell               := ["nu", "-c"] # for single-line execution
set script-interpreter  := ["nu"]       # for bundled execution

doc:
        nvim --clean --headless -l scripts/docgen.lua

repro:
        nvim --clean -u scripts/repro.lua

check: lint format

[script]
lint:
        $env.VIMRUNTIME = (nvim --clean --headless -c 'lua io.stdout:write(vim.env.VIMRUNTIME)' -c 'q')
        lua-language-server --check . --checklevel=Hint

format:
        stylua .


test:
        nvim --clean --headless -l tests/run.lua

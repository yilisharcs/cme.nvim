set shell               := ["nu", "-c"] # for single-line execution
set script-interpreter  := ["nu"]       # for bundled execution

doc:
        nvim --clean --headless -l scripts/doc.lua

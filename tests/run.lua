-- entry point for tests. run with:
--      `nvim --clean --headless -l tests/run.lua`

-- this is a reliable baseline for tests
dofile("scripts/repro.lua")

-- load up busted
local status, runner = pcall(require, "busted.runner")
if not status then
        print("error: Busted not found. Ensure luajitPackages.busted is in your environment.\n")
        os.exit(1)
end

-- mocking library. returns an object with `:revert()` method
_G.stub = require("luassert.stub").new

-- point busted at the tests/ directory
_G.arg = {
        "tests",
        "--pattern=_spec.lua",
}
runner({
        -- busted is not the entry point; nvim calls it as a library
        standalone = false,
})

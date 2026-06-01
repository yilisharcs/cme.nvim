-- entry point for tests. run with:
--      `nvim --clean --headless -l tests/run.lua`

-- this is a reliable baseline for tests
dofile("scripts/repro.lua")

-- load up buster
local status, runner = pcall(require, "busted.runner")
if not status then
        print("[ERROR] Busted not found. Ensure luajitPackages.busted is in your environment.\n")
        os.exit(1)
end

-- point buster at the tests/ directory
_G.arg = {
        "tests",
        "--pattern=_spec.lua",
}
runner({
        -- busted calls `os.exit` if `standalone` is true OR if tests fail. set it to false
        -- so Nvim handles the exit if tests pass, and let busted force an exit if they fail.
        standalone = false,
})

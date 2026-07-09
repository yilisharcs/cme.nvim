# TODO

- [ ] 1.0 Milestones:
    - [x] Colorize the quickfix list
    - [x] Implement `:Recompile` recompile on BufWritePost autocmd
    - [x] Remove lines with Erase on Line termcode from output
    - [x] Write better documentation
    - [x] Open `:copen` as soon as the terminal window closes/job is over
    - [x] Parse the quickfix list to get the proper number of errors for the qftitle
    - [ ] process massive outputs from ripgrep or fd without stuttering or blocking
- [ ] Add tmux as an option to pass through commands for persistence
- [ ] Try to leverage the location windows for multiple Compile commands
- [ ] make sudo work again
- [ ] Add extra ansi filters
    - [ ] `printf '\e[32m✔\e[0m %s\n' "$@"`
    - [ ] `printf '\e[31m✘\e[0m %s\n' "$@" >&2`
- [ ] expand checkhealth
- [ ] need to stream data more smoothly (`jj la` in neovim git repo)
- [ ] fix existing test
- [ ] more tests

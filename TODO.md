# TODO

- [ ] 1.0 Milestones:
    - [ ] Colorize the quickfix list
    - [ ] Implement `:Compile!` recompile on BufWritePost autocmd
    - [ ] Remove lines with Erase on Line termcode from output
    - [ ] Custom rules table for filtering out stuff that pollutes the quickfixlist
        - [ ] cargo's dynamic progress bar with Erase in Line ansi code
    - [ ] Write better documentation
    - [ ] Open `:copen` as soon as the terminal window closes/job is over
        - NOTE: `on_exit` only seems to work if `close_on_exit` is true

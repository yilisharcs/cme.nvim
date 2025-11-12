# TODO

- [ ] 1.0 Milestones:
    - [x] Colorize the quickfix list
    - [ ] Implement `:Recompile` recompile on BufWritePost autocmd
    - [x] Remove lines with Erase on Line termcode from output
    - [ ] Custom rules table for filtering out stuff that pollutes the quickfixlist
        - [x] cargo's dynamic progress bar with Erase in Line ansi code
    - [ ] Write better documentation
    - [x] Open `:copen` as soon as the terminal window closes/job is over
    - [ ] Parse the quickfix list to get the proper number of errors for the qftitle
        NOTE: if valid = 1 then check type string `vim.fn.getqflist()`
- [x] Is it possible to set the quickfix list without blocking the editor with massive inputs?

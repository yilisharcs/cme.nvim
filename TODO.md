# TODO

- [ ] 1.0 Milestones:
    - [x] Colorize the quickfix list
    - [ ] Implement `:Recompile` recompile on BufWritePost autocmd
    - [x] Remove lines with Erase on Line termcode from output
    - [ ] Write better documentation
    - [x] Open `:copen` as soon as the terminal window closes/job is over
    - [x] Parse the quickfix list to get the proper number of errors for the qftitle
- [x] Is it possible to set the quickfix list without blocking the editor with massive inputs?
- [ ] Add tmux as an option to pass through commands for persistence
- [x] Add errorformat for find, fd
- [x] Look into using extmarks for prettifying the qflist as syntax files are byzantine
- [ ] Create smart filters for cargo (filter nothing while compiling, filter everything after compiling)
- [x] Remove toggleterm dependency
- [ ] Try to leverate the location windows for multiple Compile commands

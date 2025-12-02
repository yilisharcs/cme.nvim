---@diagnostic disable: lowercase-global

package = "cme.nvim"
local repository = package
local namespace = "yilisharcs"

local _MODREV, _SPECREV = "scm", "-1"
version = _MODREV .. _SPECREV
rockspec_format = "3.0"

source = {
        url = ("git+https://github.com/%s/%s"):format(namespace, repository),
        tag = "HEAD",
}

description = {
        summary = "Compilation Mode, not in Emacs.",
        detailed = [[cme.nvim provides a `:Compile` command that runs tasks in a terminal and
        loads their output into the quickfix list. Arguments are passed to a bash script which
        tracks the command's start time, end time, and duration. If `:Compile` is called with
        no arguments, it executes the last known task. If called with `:Compile!`, it won't
        automatically open the quickfix window on exit.]],
        license = "Apache-2.0",
        homepage = ("https://github.com/%s/%s"):format(namespace, repository),
        issues_url = ("https://github.com/%s/%s/issues"):format(namespace, repository),
        maintainer = "yilisharcs <yilisharcs@gmail.com>",
        labels = {
                "neovim",
                "plugin",
        },
}

dependencies = {
        "lua == 5.1",
}

test_dependencies = {}

build = {
        type = "make",
        build_pass = false,
        install_variables = {
                INST_PREFIX = "$(PREFIX)",
                INST_LUADIR = "$(LUADIR)",
        },
}

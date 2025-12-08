#!/usr/bin/env nu

let doc_block = do {
        let lines = (open lua/cme/init.lua | lines)

        let index = (
                $lines
                | enumerate
                | where item =~ "^---@text"
                | first
                | get index
        )

        $lines
        | skip ($index + 1)
        | take while {|e| $e starts-with "---" }
        | each { str replace --regex "^--- ?" ""}
        | to text
}

def update_readme [] {
        let file = "README.md"
        let lines = (open $file | lines)

        let start_idx = (
                $lines
                | enumerate
                | where item =~ "## Usage"
                | first
                | get index
        )

        let rest = ($lines | skip ($start_idx + 1))

        let end_idx = ($rest
                | enumerate
                | where item =~ '^## '
                | first
                | get index?
                | default ($rest | length)
        )

        let content = (
                ($lines | take ($start_idx + 2))
                | append $doc_block
                | append ($rest | skip $end_idx)
                | to text
        )

        $content | save --force $file
}

def update_rockspec [] {
        let file = "cme.nvim-scm-1.rockspec"
        let lines = (open $file | lines)

        let start_idx = (
                $lines
                | enumerate
                | where item =~ 'detailed = \[\['
                | first
                | get index
        )

        let end_idx = (
                $lines
                | enumerate
                | where item =~ '\]\],'
                | first
                | get index
        )

        let indent = ($lines | get $start_idx | str replace --regex "detailed.*" "")

        let indented_body = (
                $doc_block
                | lines
                | each {|line|
                        if ($line | is-empty) {
                            ""
                        } else {
                            $"($indent)($line)"
                        }
                    }
                | to text
        )

        let new_block = $"($indent)detailed = [[\n($indented_body)($indent)]],"

        let content = (
                ($lines | take $start_idx)
                | append $new_block
                | append ($lines | skip ($end_idx + 1))
                | to text
        )

        $content | save --force $file
}

update_readme
update_rockspec

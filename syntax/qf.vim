" Vim syntax file
" Language:	CME Quickfix window
" Maintainer:	yilisharcs <yilisharcs@gmail.com>
" Last Change:	2026-06-31

if exists("b:current_syntax")
        finish
endif

" fall through if user didn't opt-in to the custom quickfixtextfunc
if exists("g:cme") && get(g:cme, "qf_format", 1) == 0
        finish
endif

syn clear

" head WITH error type
syn match qfTypeError  "^E\ze|"  nextgroup=qfSeparator1
syn match qfTypeWarn   "^W\ze|"  nextgroup=qfSeparator1
syn match qfTypeInfo   "^I\ze|"  nextgroup=qfSeparator1
syn match qfTypeNote   "^N\ze|"  nextgroup=qfSeparator1
syn match qfTypeHint   "^H\ze|"  nextgroup=qfSeparator1
syn match qfSeparator1 "|"       contained nextgroup=qfFileWError
syn match qfFileWError "[^|]*\ze|" contained nextgroup=qfSeparator2

" head WITHOUT error type
syn match qfFileName "^\%\([EWINH]|\)\@![^|]*\ze|" nextgroup=qfSeparator2

" shared tail
syn match qfSeparator2 "|"         contained nextgroup=qfLineNr
syn match qfLineNr     "[^|]*\ze|" contained nextgroup=qfSeparator3
syn match qfSeparator3 "|"         contained nextgroup=qfText
syn match qfText       ".*"        contained

hi def link qfTypeError  DiagnosticError
hi def link qfTypeWarn   DiagnosticWarn
hi def link qfTypeInfo   DiagnosticInfo
hi def link qfTypeNote   DiagnosticInfo
hi def link qfTypeHint   DiagnosticHint
hi def link qfFileName   Directory
hi def link qfFileWError Directory
hi def link qfLineNr     String
hi def link qfText       Normal
hi def link qfSeparator1 Delimiter
hi def link qfSeparator2 Delimiter
hi def link qfSeparator3 Delimiter

let b:current_syntax = "qf"

" vim: ts=8

syn match CmeExitSuccess /Compilation \zsfinished\ze/ contained containedin=qfFilename,qfText
syn match CmeExitFailure /Compilation \zsexited abnormally\ze/ contained containedin=qfFilename,qfText
syn match CmeDateTime /\vCompilation.*\zs\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\ze/ contained containedin=qfFilename,qfText
syn match CmeDuration /, duration \zs[^\a]*/ contained containedin=qfFilename,qfText
syn match CmeDirectory /-\*- directory: \zs.*\ze -\*-/ contained containedin=qfFilename,qfText
syn match CmePipe1 /^|/ contained containedin=qfSeparator1 conceal
syn match CmePipe2 /\%(^|\)\@<=|/ contained containedin=qfSeparator2 conceal

hi def CmeExitSuccess guifg=#00af5f gui=bold ctermfg=2
hi def CmeExitFailure guifg=#d7005f gui=bold ctermfg=1
hi def CmeDateTime    guifg=#ffaf00 gui=bold ctermfg=3
hi def CmeDuration    guifg=#00afff gui=bold ctermfg=6
hi def link CmeDirectory CmeDuration
hi def CmePipe1       guifg=bg               ctermfg=0
hi def link CmePipe2 CmePipe1

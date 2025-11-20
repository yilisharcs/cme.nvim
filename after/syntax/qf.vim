syn match CmeExitSuccess /Compilation \zsfinished\ze/ contained containedin=qfFilename
syn match CmeExitFailure /Compilation \zsexited abnormally\ze/ contained containedin=qfFilename
syn match CmeDateTime /\vCompilation.*\zs\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\ze/ contained containedin=qfFilename
syn match CmeDuration /, duration \zs[^\a]*/ contained containedin=qfFilename
syn match CmeDirectory /-\*- directory: \zs.*\ze -\*-/ contained containedin=qfFilename
syn match CmePipes /^||/ conceal

hi def CmeExitSuccess guifg=#00af5f gui=bold ctermfg=2
hi def CmeExitFailure guifg=#d7005f gui=bold ctermfg=1
hi def CmeDateTime    guifg=#ffaf00 gui=bold ctermfg=3
hi def CmeDuration    guifg=#00afff gui=bold ctermfg=6
hi def link CmeDirectory CmeDuration
hi def CmePipes       guifg=bg               ctermfg=0

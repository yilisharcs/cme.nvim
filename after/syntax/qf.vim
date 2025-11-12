" FIXME: why must they all be containedin?
syn match CmeExitSuccess /Compilation \zsfinished\ze/ contained containedin=qfFilename,qfLineNr,qfText
syn match CmeExitFailure /Compilation \zsexited abnormally\ze/ contained containedin=qfFilename,qfLineNr,qfText
syn match CmeDateTime /\vCompilation.*\zs\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\ze/ contained containedin=qfFilename,qfLineNr,qfText
syn match CmeDuration /, duration \zs[^\a]*/ contained containedin=qfFilename,qfLineNr,qfText

hi CmeExitSuccess guifg=#00af5f ctermfg=2
hi CmeExitFailure guifg=#d7005f ctermfg=1
hi CmeDateTime    guifg=#ffaf00 ctermfg=3
hi CmeDuration    guifg=#00afff ctermfg=6

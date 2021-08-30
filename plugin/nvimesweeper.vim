if exists('g:loaded_nvimesweeper')
    finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -nargs=* Nvimesweeper lua require("nvimesweeper").play_cmd(<q-args>)

function! s:DefineHighlights() abort
    highlight default NvimesweeperUnrevealed ctermbg=Grey
    highlight default NvimesweeperMaybe ctermfg=Black ctermbg=Grey
    highlight default NvimesweeperFlag ctermfg=Red ctermbg=Grey

    highlight default NvimesweeperRevealed ctermbg=DarkGrey
    highlight default NvimesweeperTriggeredMine ctermfg=Black ctermbg=Red
    highlight default NvimesweeperMine ctermfg=Black ctermbg=DarkGrey
    highlight default NvimesweeperFlagWrong ctermfg=Red ctermbg=DarkGrey
    highlight default NvimesweeperDanger1 ctermfg=DarkBlue ctermbg=DarkGrey
    highlight default NvimesweeperDanger2 ctermfg=Green ctermbg=DarkGrey
    highlight default NvimesweeperDanger3 ctermfg=Red ctermbg=DarkGrey
    highlight default NvimesweeperDanger4 ctermfg=DarkMagenta ctermbg=DarkGrey
    highlight default NvimesweeperDanger5 ctermfg=DarkRed ctermbg=DarkGrey
    highlight default NvimesweeperDanger6 ctermfg=DarkCyan ctermbg=DarkGrey
    highlight default NvimesweeperDanger7 ctermfg=Black ctermbg=DarkGrey
    highlight default NvimesweeperDanger8 ctermfg=White ctermbg=DarkGrey
endfunction

augroup nvimesweeper_define_highlights
    autocmd!
    " color scheme has probably cleared our default highlights; reload them
    autocmd ColorScheme * call s:DefineHighlights()
augroup END

call s:DefineHighlights()

let &cpoptions = s:save_cpo
unlet s:save_cpo

let g:loaded_nvimesweeper = 1

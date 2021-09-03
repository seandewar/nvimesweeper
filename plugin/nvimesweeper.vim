if !has('nvim-0.5')
    echoerr "[nvimesweeper] Neovim version 0.5 or above is required!"
    finish
endif

if exists('g:loaded_nvimesweeper')
    finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

command! -nargs=* Nvimesweeper lua require("nvimesweeper").play_cmd(<q-args>)

function! s:DefineHighlights() abort
    highlight default NvimesweeperUnrevealed ctermbg=Grey
                \ guibg=#c0c0c0
    highlight default NvimesweeperMaybe ctermfg=Black ctermbg=Grey
                \ guifg=#000000 guibg=#c0c0c0
    highlight default NvimesweeperFlag ctermfg=Red ctermbg=Grey
                \ guifg=#fe0000 guibg=#c0c0c0

    highlight default NvimesweeperRevealed ctermbg=DarkGrey
                \ guibg=#808080
    highlight default NvimesweeperTriggeredMine ctermfg=Black ctermbg=Red
                \ guifg=#000000 guibg=#fe0000
    highlight default NvimesweeperMine ctermfg=Black ctermbg=DarkGrey
                \ guifg=#000000 guibg=#808080
    highlight default NvimesweeperFlagWrong ctermfg=Red ctermbg=DarkGrey
                \ guifg=#fe0000 guibg=#808080
    highlight default NvimesweeperDanger1 ctermfg=DarkBlue ctermbg=DarkGrey
                \ guifg=#0100fe guibg=#808080
    highlight default NvimesweeperDanger2 ctermfg=Green ctermbg=DarkGrey
                \ guifg=#02c902 guibg=#808080
    highlight default NvimesweeperDanger3 ctermfg=Red ctermbg=DarkGrey
                \ guifg=#fe0000 guibg=#808080
    highlight default NvimesweeperDanger4 ctermfg=DarkMagenta ctermbg=DarkGrey
                \ guifg=#00007f guibg=#808080
    highlight default NvimesweeperDanger5 ctermfg=DarkRed ctermbg=DarkGrey
                \ guifg=#800000 guibg=#808080
    highlight default NvimesweeperDanger6 ctermfg=DarkCyan ctermbg=DarkGrey
                \ guifg=#00d4d4 guibg=#808080
    highlight default NvimesweeperDanger7 ctermfg=Black ctermbg=DarkGrey
                \ guifg=#000000 guibg=#808080
    highlight default NvimesweeperDanger8 ctermfg=White ctermbg=DarkGrey
                \ guifg=#ffffff guibg=#808080
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

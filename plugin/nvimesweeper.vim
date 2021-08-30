command! -nargs=* Nvimesweeper lua require("nvimesweeper").play_cmd(<q-args>)

function! s:DefineHighlights() abort
    highlight default NvimesweeperDefaultDanger1 ctermfg=9
    highlight default NvimesweeperDefaultDanger2 ctermfg=10
    highlight default NvimesweeperDefaultDanger3 ctermfg=12
    highlight default NvimesweeperDefaultDanger4 ctermfg=1
    highlight default NvimesweeperDefaultDanger5 ctermfg=4
    highlight default NvimesweeperDefaultDanger6 ctermfg=11
    highlight default NvimesweeperDefaultDanger7 ctermfg=8
    highlight default NvimesweeperDefaultDanger8 ctermfg=7

    highlight default link NvimesweeperFlagged WarningMsg
    highlight default link NvimesweeperMine Error
    highlight default link NvimesweeperDanger1 NvimesweeperDefaultDanger1
    highlight default link NvimesweeperDanger2 NvimesweeperDefaultDanger2
    highlight default link NvimesweeperDanger3 NvimesweeperDefaultDanger3
    highlight default link NvimesweeperDanger4 NvimesweeperDefaultDanger4
    highlight default link NvimesweeperDanger5 NvimesweeperDefaultDanger5
    highlight default link NvimesweeperDanger6 NvimesweeperDefaultDanger6
    highlight default link NvimesweeperDanger7 NvimesweeperDefaultDanger7
    highlight default link NvimesweeperDanger8 NvimesweeperDefaultDanger8
endfunction

augroup nvimesweeper_define_highlights
    autocmd!
    " color scheme has probably cleared our default highlights; reload them
    autocmd ColorScheme * call s:DefineHighlights()
augroup END

call s:DefineHighlights()


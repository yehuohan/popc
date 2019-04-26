
" search interface.

" SECTION: variables {{{1
let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:sea = {
    \ 'char' : '',
    \ }


" SECTION: functions {{{1

" FUNCTION: popc#search#Init() {{{
function! popc#search#Init()
endfunction
" }}}

" FUNCTION: popc#search#Search(layer) {{{
function! popc#search#Search(layer)
    let s:lyr = s:popc[a:layer]

    " take all control in search mode
    call s:search()
endfunction
" }}}

" FUNCTION: s:search() {{{
function! s:search()
    let loop = 1
    let l:chars = ''

    while loop
        redraw
        let s:sea.char = l:chars
        echo ' $> ' . l:chars

        let ret = getchar()
        let ch = (type(ret) == v:t_number ? nr2char(ret) : ret)

        if ch ==# "\<Esc>"
            let loop = 0
        elseif ch ==# "\<BS>"
            let l:chars = l:chars[0:-2]
        elseif ch ==# "\<CR>"
            "
        elseif ch ==# "\<C-j>"
            call popc#ui#MoveBar('down')
        elseif ch ==# 'ê'
            call popc#ui#MoveBar('pgdown')
        elseif ch ==# "\<C-k>"
            call popc#ui#MoveBar('up')
        elseif ch ==# 'ë'
            call popc#ui#MoveBar('pgup')
        elseif ch =~# '\p'
            let l:chars .= ch
        endif
    endwhile
endfunction
" }}}

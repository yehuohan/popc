
" ui of windows interacting for popc.

" SECTION: variables {{{1
let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:id = -1
let s:size = 1
let s:recover = {
    \ 'winnr' : 0,
    \ 'file' : '',
    \ }


" SETCION: functions {{{1

" FUNCTION: popc#ui#popup#Init() {{{
function! popc#ui#popup#Init()
    let l:keys = popc#utils#getKeys()
    let s:keys = {}
    for k in l:keys.lowercase + l:keys.uppercase + l:keys.numbers + l:keys.specials1
        let s:keys[k] = k
    endfor
    for k in l:keys.controls + l:keys.alts + l:keys.specials2
        let s:keys[eval('"\<' . k . '>"')] = k
    endfor

    return {
        \ 'create'  : funcref('s:create'),
        \ 'destroy' : funcref('s:destroy'),
        \ 'toggle'  : { state -> state },
        \ 'operate' : funcref('s:operate'),
        \ 'getval'  : {key -> s:recover[key]},
        \ }
endfunction
" }}}

" FUNCTION: s:create(layer) {{{
function! s:create(layer)
    let s:lyr = s:popc[a:layer]
    if exists('s:flag') && s:flag
        call s:dispPopup()     " just only re-display buffer
        return
    endif
    let s:flag = 1
    call s:saveRecover()
    let s:id = popup_create('', #{
            \ zindex: 1000,
            \ pos: 'center',
            \ col: 30,
            \ maxwidth: &columns - 10,
            \ minwidth: &columns - 30,
            \ cursorline: 1,
            \ mapping: 0,
            \ wrap: 0,
            \ title: 'Popc',
            \ filter: funcref('s:keyHandler'),
            \ })
    call s:dispPopup()
endfunction
" }}}

" FUNCTION: s:keyHandler(id, key) {{{
function! s:keyHandler(id, key)
    call win_execute(s:id, 'let l:index = line(".") - 1')
    if has_key(s:keys, a:key)
        call popc#ui#Trigger(s:keys[a:key], l:index)
    endif
    return 1
endfunction
" }}}

" FUNCTION: s:saveRecover() {{{
function! s:saveRecover()
    let s:recover.winnr = winnr()
    let s:recover.file = expand('%:p')
endfunction
" }}}

" FUNCTION: s:destroy() {{{
function! s:destroy()
    if !(exists('s:flag') && s:flag)
        return
    endif
    call popup_close(s:id)
    let s:flag = 0
endfunction
" }}}

" FUNCTION: s:dispPopup() {{{
function! s:dispPopup()
    let l:list = s:lyr.getBufs()
    let s:size = len(l:list)
    call popup_settext(s:id, l:list)
    if s:lyr.mode == 'normal'
        call s:operate('num', s:lyr.info.lastIndex + 1)
    else
        call s:operate('num', 1)
    endif
endfunction
" }}}

" FUNCTION: s:operate(dir, ...) {{{
function! s:operate(dir, ...)
    if a:0 > 0
        call win_execute(s:id, 'noautocmd call s:operate_internal("' . a:dir . '", '. a:1 . ')')
    else
        call win_execute(s:id, 'noautocmd call s:operate_internal("' . a:dir . '")')
    endif
endfunction
" }}}

" FUNCTION: s:operate_internal(dir, ...) {{{
function! s:operate_internal(dir, ...)
    let l:oldLine = line('.')
    if s:size < 1
        return
    endif

    if a:dir ==# 'down'
        let l:pos = line('.') + 1
    elseif a:dir ==# 'up'
        let l:pos = line('.') - 1
    elseif a:dir ==# 'top'
        let l:pos = 1
    elseif a:dir ==# 'bottom'
        let l:pos = line('$')
    elseif a:dir ==# 'pgup'
        let l:pos = line('.') - winheight(0)
        if l:pos < 1
            let l:pos = 1
        endif
    elseif a:dir ==# 'pgdown'
        let l:pos = line('.') + winheight(0)
        if l:pos > line('$')
            let l:pos = line('$')
        endif
    elseif a:dir ==# 'num'
        let l:pos = (a:0 >= 1) ? a:1 : 0
    elseif a:dir ==# 'quit'
        call s:destroy()
        return
    endif

    if l:pos < 1
        call cursor(s:size - l:pos, 1)
    elseif l:pos > s:size
        call cursor(l:pos - s:size, 1)
    else
        call cursor(l:pos, 1)
    endif

    " mark index line with '>'
    let l:newLine = line('.')
    if l:oldLine != l:newLine
        call setline(l:oldLine, ' ' . strpart(getline(l:oldLine), 1))
    endif
    call setline(l:newLine, '>' . strpart(getline(l:newLine), 1))

    " save layer index
    if s:lyr.mode == 'normal'
        call s:lyr.setInfo('lastIndex', line('.') - 1)
        if s:lyr.info.userCmd
            doautocmd User PopcUiIndexChanged
        endif
    endif
endfunction
" }}}

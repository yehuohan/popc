
" ui of windows interacting for popc.

" SECTION: variables {{{1
let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:ctx = {}
let s:id = -1
let s:id_title = -1
let s:recover = {
    \ 'winnr' : 0,
    \ 'file' : '',
    \ 'line' : {
        \ 'cur' : 1,
        \ 'old' : 1,
        \ 'cnt' : 1,
        \ },
    \ }
let s:ptr = s:conf.usePowerFont ? s:conf.selectPointer : s:conf.symbols.Ptr


" SETCION: functions {{{1

" FUNCTION: popc#ui#popup#Init() {{{
function! popc#ui#popup#Init()
    let l:keys = popc#utils#GetKeys()
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
        call s:dispPopup(1)     " just only re-display buffer
        return
    endif
    let s:flag = 1
    call s:saveRecover()
    if empty(getwininfo(s:id))
        let s:id = popup_create('', #{
                \ zindex: 1000,
                \ pos: 'topleft',
                \ border: [0, 1, 0, 1],
                \ borderchars: ['', ' ', '', ' '],
                \ borderhighlight: [],
                \ cursorline: 1,
                \ highlight: 'PopcTxt',
                \ mapping: 0,
                \ wrap: 0,
                \ filter: funcref('s:keyHandler'),
                \ callback: { id, result -> (result == -1) && s:destroy()}
            \ })
        let s:id_title = popup_create('Popc', #{
                \ zindex: 1000,
                \ pos: 'topleft',
                \ border: [0, 1, 0, 1],
                \ borderchars: ['', ' ', '', ' '],
                \ borderhighlight: ['PopcSlLabel'],
                \ mapping: 0,
                \ wrap: 0,
                \ })
        let s:title = [#{text: '', props: []}]
        call add(s:title[0].props, #{col: 1, length: 1, type: 'PopcSlLabel'})
        call add(s:title[0].props, #{col: 1, length: 1, type: 'PopcSlSep'})
        call add(s:title[0].props, #{col: 1, length: 1, type: 'PopcSl'})
        call add(s:title[0].props, #{col: 1, length: 1, type: 'PopcSlSep'})
        call add(s:title[0].props, #{col: 1, length: 1, type: 'PopcSlLabel'})
    else
        call popup_show(s:id)
        call popup_show(s:id_title)
    endif
    call setbufvar(winbufnr(s:id), '&filetype', 'Popc')
    set guicursor+=n:block--blinkon0
    call s:dispPopup(1)
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
    call popup_hide(s:id)
    call popup_hide(s:id_title)
    set guicursor-=n:block--blinkon0
    let s:flag = 0
endfunction
" }}}

" FUNCTION: s:dispPopup(updateall) {{{
function! s:dispPopup(updateall)
if a:updateall
    if s:lyr.mode == 'normal'
        let s:recover.line.cur = s:lyr.info.lastIndex + 1
    else
        let s:recover.line.cur = 1
    endif
    let s:ctx = popc#stl#CreateContext(
                \ s:lyr,
                \ &columns - 10,
                \ (s:conf.maxHeight > 0) ? s:conf.maxHeight : (float2nr(&lines * 0.7)))
    let s:recover.line.cnt = s:ctx.size

    " disp text
    call popup_settext(s:id, s:ctx.text)
    call popup_move(s:id, #{
            \ maxheight: s:ctx.hei,
            \ maxwidth: s:ctx.wid,
            \ line: (&lines - s:ctx.hei) / 2 + 1,
            \ col: (&columns - s:ctx.wid) / 2,
            \ })

    " disp title
    let l:pos = popup_getpos(s:id)
    if l:pos.scrollbar > 0
        let s:ctx.title[2] .= ' '
    endif

    " set cursor
    call s:operate('num', s:recover.line.cur)
else
    " disp title
    let s:ctx.title[-1] = popc#stl#CreateRank(s:lyr, s:recover.line.cnt, s:recover.line.cur)
    let s:title[0].props[0].col = 1
    let s:title[0].props[0].length = strlen(s:ctx.title[0])
    for k in range(1, 4)
        let s:title[0].props[k].col = s:title[0].props[k-1].col + s:title[0].props[k-1].length
        let s:title[0].props[k].length = strlen(s:ctx.title[k])
    endfor
    let s:title[0].text = join(s:ctx.title, '')
    let l:pos = popup_getpos(s:id)
    call popup_settext(s:id_title, s:title)
    call popup_move(s:id_title, #{
            \ line: l:pos.line - 1,
            \ col: l:pos.col,
            \ })
endif
endfunction
" }}}

" FUNCTION: s:operate(dir, ...) {{{
function! s:operate(dir, ...)
    if a:0 > 0
        call win_execute(s:id, printf('noautocmd call s:operate_internal("%s", %d)', a:dir, a:1))
    else
        call win_execute(s:id, printf('noautocmd call s:operate_internal("%s")', a:dir))
    endif

    " do user command
    if s:lyr.mode == 'normal'
        if s:lyr.info.userCmd
            doautocmd User PopcUiIndexChanged
        endif
    endif

    " update title
    call s:dispPopup(0)
endfunction
" }}}

" FUNCTION: s:operate_internal(dir, ...) {{{
function! s:operate_internal(dir, ...)
    if s:ctx.size < 1
        return
    endif

    let l:oldLine = line('.')
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
    endif

    if l:pos < 1
        call cursor(s:ctx.size - l:pos, 1)
    elseif l:pos > s:ctx.size
        call cursor(l:pos - s:ctx.size, 1)
    else
        call cursor(l:pos, 1)
    endif

    " mark index line with '>'
    let l:newLine = line('.')
    if l:oldLine != l:newLine
        call setline(l:oldLine, ' ' . strcharpart(getline(l:oldLine), 1))
    endif
    call setline(l:newLine, s:ptr . strcharpart(getline(l:newLine), 1))

    " save layer index
    let s:recover.line.old = l:oldLine
    let s:recover.line.cur = l:newLine
    if s:lyr.mode == 'normal'
        call s:lyr.setInfo('lastIndex', line('.') - 1)
    endif
endfunction
" }}}

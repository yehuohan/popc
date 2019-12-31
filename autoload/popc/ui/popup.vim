
" ui of windows interacting for popc.

" SECTION: variables {{{1
let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:id = -1
let s:id_title = -1
let s:size = 1
let s:recover = {
    \ 'winnr' : 0,
    \ 'file' : '',
    \ }


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
        call s:dispPopup()     " just only re-display buffer
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
    call popup_hide(s:id)
    call popup_hide(s:id_title)
    set guicursor-=n:block--blinkon0
    let s:flag = 0
endfunction
" }}}

" FUNCTION: s:dispPopup() {{{
function! s:dispPopup()
    let [l:title, l:text, s:size, l:width, l:height] = popc#ui#popup#createContext(
                \ s:lyr,
                \ &columns - 10,
                \ (s:conf.maxHeight > 0) ? s:conf.maxHeight : (float2nr(&lines * 0.7)))

    " disp text
    call popup_settext(s:id, l:text)
    call popup_move(s:id, #{
            \ maxheight: l:height,
            \ maxwidth: l:width,
            \ line: (&lines - l:height) / 2 + 1,
            \ col: (&columns - l:width) / 2,
            \ })

    " disp title
    let l:pos = popup_getpos(s:id)
    if l:pos.scrollbar > 0
        let l:title[2] .= ' '
    endif
    let s:title[0].props[0].col = 1
    let s:title[0].props[0].length = strlen(l:title[0])
    for k in range(1, 4)
        let s:title[0].props[k].col = s:title[0].props[k-1].col + s:title[0].props[k-1].length
        let s:title[0].props[k].length = strlen(l:title[k])
    endfor
    let s:title[0].text = join(l:title, '')
    call popup_settext(s:id_title, s:title)
    call popup_move(s:id_title, #{
            \ line: l:pos.line - 1,
            \ col: l:pos.col,
            \ })

    " init line
    if s:lyr.mode == 'normal'
        call s:operate('num', s:lyr.info.lastIndex + 1)
    else
        call s:operate('num', 1)
    endif
endfunction
" }}}

" FUNCTION: popc#ui#popup#createContext(lyr, maxwidth, maxheight) {{{
" @return: [title-segs, text-list, text-size, text-width, text-height]
function! popc#ui#popup#createContext(lyr, maxwidth, maxheight)
    let l:list = a:lyr.getBufs()
    let l:size = len(l:list)
    let l:height = (l:size <= a:maxheight) ? l:size : a:maxheight
    let l:width = max(map(copy(l:list), {key, val -> strwidth(val)})) + 2   " text end with 2 spaces

    " title
    if s:conf.usePowerFont
        let l:spl  = s:conf.separator.left
        let l:spr  = s:conf.separator.right
    else
        let l:spl  = ''
        let l:spr  = ''
    endif
    let l:title = ['Popc', l:spl, ' ' . a:lyr.info.centerText . ' ', l:spr, ' ' . a:lyr.name]
    let l:wseg = 0
    for seg in l:title
        let l:wseg += strwidth(seg)
    endfor
    let l:width = min([max([l:width, l:wseg]), a:maxwidth])
    if l:wseg < l:width
        let l:title[2] .= repeat(' ', l:width - l:wseg)
    elseif l:wseg > l:width
        let l:title[2] = strpart(l:title[2], 0, strlen(l:title[2]) - (l:wseg - l:width))
    endif

    " text
    let l:text = map(copy(l:list), 'v:val . repeat(" ", l:width - strwidth(v:val))')

    return [l:title, l:text, l:size, l:width, l:height]
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
    endif
endfunction
" }}}

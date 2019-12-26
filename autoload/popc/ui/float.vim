
" ui of windows interacting for popc.

" SECTION: variables {{{1
let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:hbuf = -1
let s:hwin = -1
let s:size = 1
let s:recover = {
    \ 'winnr' : 0,
    \ 'file' : '',
    \ }


" SETCION: functions {{{1

" FUNCTION: popc#ui#float#Init() {{{
function! popc#ui#float#Init()
    " init keys
    let l:keys = popc#utils#getKeys()
    let s:keys = {}
    for k in l:keys.lowercase + l:keys.uppercase + l:keys.numbers + l:keys.specials1
        let s:keys[(k == '"') ? '\"' : k] = k
    endfor
    for k in l:keys.controls + l:keys.alts + l:keys.specials2
        if k == 'C-m' || k == 'C-i'
            " <C-m> is same as <CR>
            " <C-i> is same as <Tab>
            continue
        endif
        let s:keys[k] = '<' . k . '>'
    endfor

    return {
        \ 'create'  : funcref('s:create'),
        \ 'destroy' : funcref('s:destroy'),
        \ 'toggle'  : funcref('s:toggle'),
        \ 'operate' : funcref('s:operate'),
        \ 'getval'  : {key -> s:recover[key]},
        \ }
endfunction
" }}}

" FUNCTION: s:create(layer) {{{
function! s:create(layer)
    let s:lyr = s:popc[a:layer]
    if exists('s:flag') && s:flag
        call s:dispFloat()     " just only re-display buffer
        return
    endif
    let s:flag = 1
    call s:saveRecover()
    call s:setFloat()
    call s:dispFloat()
endfunction
" }}}

" FUNCTION: s:saveRecover() {{{
function! s:saveRecover()
    let s:recover.winnr = winnr()
    let s:recover.file = expand('%:p')
    if &timeout
        let s:recover.timeoutlen = &timeoutlen
    endif
endfunction
" }}}

" FUNCTION: s:destroy() {{{
function! s:destroy()
    if !(exists('s:flag') && s:flag)
        return
    endif
    if &timeout
        silent execute 'set timeoutlen=' . s:recover.timeoutlen
    endif

    if s:recover.winnr <= winnr('$')
        silent execute 'noautocmd ' . s:recover.winnr . 'wincmd w'
    endif

    call nvim_win_close(s:hwin, v:false)
    let s:flag = 0
endfunction
" }}}

" FUNCTION: s:toggle(state) {{{
function! s:toggle(state)
    if exists('s:flag') && s:flag
        if a:state
            call win_gotoid(s:hwin)
            redraw
        else
            silent execute 'noautocmd ' . s:recover.winnr . 'wincmd w'
        endif
    endif
endfunction
" }}}

" FUNCTION: s:setFloat() {{{
function! s:setFloat()
    let s:hbuf = nvim_create_buf(v:false, v:true)

    " option
    call nvim_buf_set_option(s:hbuf, 'swapfile', v:false)
    call nvim_buf_set_option(s:hbuf, 'buftype', 'nofile')
    call nvim_buf_set_option(s:hbuf, 'bufhidden', 'delete')
    call nvim_buf_set_option(s:hbuf, 'buflisted', v:false)
    call nvim_buf_set_option(s:hbuf, 'modifiable', v:false)
    call nvim_buf_set_option(s:hbuf, 'filetype', 'Popc')
    if &timeout
        set timeoutlen=10
    endif

    " key
    for [key, val] in items(s:keys)
        call nvim_buf_set_keymap(s:hbuf,
                \ 'n',
                \ val, ':call popc#ui#float#Trigger("' . key . '")<CR>',
                \ {'noremap': v:true})
    endfor

    " window
    let s:hwin = nvim_open_win(s:hbuf, v:true, {
            \ 'relative': 'editor',
            \ 'width': 1,
            \ 'height': 1,
            \ 'col': 1,
            \ 'row': 1,
            \ 'style': 'minimal',
            \ })
    call nvim_win_set_option(s:hwin, 'wrap', v:false)
    call nvim_win_set_option(s:hwin, 'foldenable', v:false)
    call win_gotoid(s:hwin)
    if has('syntax')
        syntax clear
        syntax match PopcTxt /  .*/
        syntax match PopcSel /> .*/hs=s+1
    endif
endfunction
" }}}

" FUNCTION: s:dispFloat() {{{
function! s:dispFloat()
    let l:list = s:lyr.getBufs()
    let s:size = len(l:list)
    let l:maxheight = (s:conf.maxHeight > 0) ? s:conf.maxHeight : (&lines / 2)
    let l:maxwidth = &columns - 10
    let l:height = (s:size <= l:maxheight) ? s:size : l:maxheight
    let l:width = max(map(copy(l:list), {key, val -> strwidth(val)})) + 2   " text end with 2 spaces
    let l:width = min([l:maxwidth, l:width])

    " set text
    let l:text = map(copy(l:list), 'v:val . repeat(" ", l:width - strwidth(v:val))')
    call nvim_buf_set_option(s:hbuf, 'modifiable', v:true)
    if s:size > nvim_buf_line_count(s:hbuf)
        call nvim_buf_set_lines(s:hbuf, 0, s:size, v:false, l:text)
    else
        call nvim_buf_set_lines(s:hbuf, 0, nvim_buf_line_count(s:hbuf), v:false, l:text)
    endif
    call nvim_buf_set_option(s:hbuf, 'modifiable', v:false)
    call nvim_win_set_config(s:hwin, {
            \ 'relative' : 'editor',
            \ 'width': l:width,
            \ 'height': l:height,
            \ 'col': (&columns - l:width) / 2,
            \ 'row': (&lines - l:height) / 2,
            \ })

    " init line
    if s:lyr.mode == 'normal'
        call s:operate('num', s:lyr.info.lastIndex + 1)
    else
        call s:operate('num', 1)
    endif
endfunction
" }}}

" FUNCTION: s:operate(dir, ...) {{{
function! s:operate(dir, ...)
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
    call nvim_buf_set_option(s:hbuf, 'modifiable', v:true)
    if l:oldLine != l:newLine
        call setline(l:oldLine, ' ' . strpart(getline(l:oldLine), 1))
    endif
    call setline(l:newLine, '>' . strpart(getline(l:newLine), 1))
    call nvim_buf_set_option(s:hbuf, 'modifiable', v:false)

    " save layer index
    if s:lyr.mode == 'normal'
        call s:lyr.setInfo('lastIndex', line('.') - 1)
        if s:lyr.info.userCmd
            doautocmd User PopcUiIndexChanged
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#ui#float#Trigger(key) {{{
function! popc#ui#float#Trigger(key)
    call popc#ui#Trigger(a:key, line('.') - 1)
endfunction
" }}}

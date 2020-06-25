
" ui of windows interacting for popc.

" SECTION: variables {{{1
let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:hbuf = -1
let s:hwin = -1
let s:nsid = -1
let s:hbuf_title = -1
let s:hwin_title = -1
let s:nsid_title = -1
let s:size = 1
let s:recover = {
    \ 'winnr' : 0,
    \ 'file' : '',
    \ 'line' : [1, 1],
    \ 'timeoutlen' : 0,
    \ }


" SETCION: functions {{{1

" FUNCTION: popc#ui#float#Init() {{{
function! popc#ui#float#Init()
    " init keys
    let l:keys = popc#utils#GetKeys()
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

    " namespace
    let s:nsid = nvim_create_namespace('')
    let s:nsid_title = nvim_create_namespace('')

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
        call s:dispFloat(1)     " just only re-display buffer
        return
    endif
    let s:flag = 1
    call s:saveRecover()
    call s:setFloat()
    call s:dispFloat(1)
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
    set guicursor-=n:block-PopcSel-blinkon0
    if &timeout
        silent execute 'set timeoutlen=' . s:recover.timeoutlen
    endif

    if s:recover.winnr <= winnr('$')
        silent execute 'noautocmd ' . s:recover.winnr . 'wincmd w'
    endif

    call nvim_win_close(s:hwin, v:false)
    call nvim_win_close(s:hwin_title, v:false)
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
    " title
    let s:hbuf_title = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_option(s:hbuf_title, 'swapfile', v:false)
    call nvim_buf_set_option(s:hbuf_title, 'buftype', 'nofile')
    call nvim_buf_set_option(s:hbuf_title, 'bufhidden', 'delete')
    call nvim_buf_set_option(s:hbuf_title, 'buflisted', v:false)
    call nvim_buf_set_option(s:hbuf_title, 'filetype', 'Popc')
    let s:hwin_title = nvim_open_win(s:hbuf_title, v:true, {
            \ 'relative': 'editor',
            \ 'width': 1,
            \ 'height': 1,
            \ 'col': 1,
            \ 'row': 1,
            \ 'style': 'minimal',
            \ })
    call nvim_win_set_option(s:hwin_title, 'wrap', v:false)
    call nvim_win_set_option(s:hwin_title, 'foldenable', v:false)

    " buffer
    let s:hbuf = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_option(s:hbuf, 'swapfile', v:false)
    call nvim_buf_set_option(s:hbuf, 'buftype', 'nofile')
    call nvim_buf_set_option(s:hbuf, 'bufhidden', 'delete')
    call nvim_buf_set_option(s:hbuf, 'buflisted', v:false)
    call nvim_buf_set_option(s:hbuf, 'filetype', 'Popc')
    if &timeout
        set timeoutlen=10
    endif

    " buffer-key
    for [key, val] in items(s:keys)
        call nvim_buf_set_keymap(s:hbuf,
                \ 'n',
                \ val, ':call popc#ui#float#Trigger("' . key . '")<CR>',
                \ {'noremap': v:true, 'silent': v:true})
    endfor

    " buffer-window
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
endfunction
" }}}

" FUNCTION: s:dispFloat(updateall) {{{
function! s:dispFloat(updateall)
    let [l:title, l:text, s:size, l:width, l:height] = popc#stl#CreateTitle(
                \ s:lyr,
                \ &columns - 10,
                \ (s:conf.maxHeight > 0) ? s:conf.maxHeight : (float2nr(&lines * 0.7)))

    " set text
if a:updateall
    if s:size > nvim_buf_line_count(s:hbuf)
        call nvim_buf_set_lines(s:hbuf, 0, s:size, v:false, l:text)
    else
        call nvim_buf_set_lines(s:hbuf, 0, nvim_buf_line_count(s:hbuf), v:false, l:text)
    endif
    call nvim_win_set_config(s:hwin, {
            \ 'relative' : 'editor',
            \ 'width': l:width,
            \ 'height': l:height,
            \ 'row': (&lines - l:height) / 2 + 1,
            \ 'col': (&columns - l:width) / 2,
            \ })
    set guicursor+=n:block-PopcSel-blinkon0
endif

    " set title
    call nvim_buf_set_lines(s:hbuf_title, 0, 1, v:false, [join(l:title, ''), ])
    let l:len = map(copy(l:title), {k, v -> strlen(v)})
    let l:col_s = [0, ] + l:len
    let l:col_s = map(l:col_s, {k, v -> (k == 0) ? v : v + l:col_s[k - 1]})
    let l:col_e = copy(l:len)
    let l:col_e = map(l:col_e, {k, v -> (k == 0) ? v : v + l:col_e[k - 1]})
    call nvim_buf_clear_namespace(s:hbuf_title, s:nsid_title, 0, -1)
    call nvim_buf_add_highlight(s:hbuf_title, s:nsid_title, 'PopcSlLabel', 0, l:col_s[0], l:col_e[0])
    call nvim_buf_add_highlight(s:hbuf_title, s:nsid_title, 'PopcSlSep'  , 0, l:col_s[1], l:col_e[1])
    call nvim_buf_add_highlight(s:hbuf_title, s:nsid_title, 'PopcSl'     , 0, l:col_s[2], l:col_e[2])
    call nvim_buf_add_highlight(s:hbuf_title, s:nsid_title, 'PopcSlSep'  , 0, l:col_s[3], l:col_e[3])
    call nvim_buf_add_highlight(s:hbuf_title, s:nsid_title, 'PopcSlLabel', 0, l:col_s[4], l:col_e[4])
    call nvim_win_set_config(s:hwin_title, {
            \ 'relative' : 'editor',
            \ 'width': l:width,
            \ 'height': 1,
            \ 'row': (&lines - l:height) / 2,
            \ 'col': (&columns - l:width) / 2,
            \ })

    " init line
if a:updateall
    if s:lyr.mode == 'normal'
        call s:operate('num', s:lyr.info.lastIndex + 1)
    else
        call s:operate('num', 1)
    endif
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
    if l:oldLine != l:newLine
        call setline(l:oldLine, ' ' . strpart(getline(l:oldLine), 1))
    endif
    call setline(l:newLine, '>' . strpart(getline(l:newLine), 1))

    " save layer index
    let s:recover.line = [line('$'), line('.')]
    if s:lyr.mode == 'normal'
        call s:lyr.setInfo('lastIndex', line('.') - 1)
        if s:lyr.info.userCmd
            doautocmd User PopcUiIndexChanged
        endif
    endif

    " update buf and title
    call nvim_buf_clear_namespace(s:hbuf, s:nsid, l:oldLine-1, l:oldLine)
    call nvim_buf_add_highlight(s:hbuf, s:nsid, 'PopcSel', l:newLine-1, 1, -1)
    call s:dispFloat(0)
endfunction
" }}}

" FUNCTION: popc#ui#float#Trigger(key) {{{
function! popc#ui#float#Trigger(key)
    call popc#ui#Trigger(a:key, line('.') - 1)
endfunction
" }}}

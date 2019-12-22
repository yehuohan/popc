
" ui of windows interacting for popc.

" SECTION: variables {{{1
let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer


" SETCION: functions {{{1

" FUNCTION: popc#ui#default#Init() {{{
function! popc#ui#default#Init()
    call s:initKeys()
    return {
        \ 'create'  : funcref('s:create'),
        \ 'destroy' : funcref('s:destroy'),
        \ 'display' : funcref('s:dispBuffer'),
        \ 'toggle'  : funcref('s:toggle'),
        \ 'operate' : funcref('s:operate'),
        \ 'input'   : funcref('s:input'),
        \ 'confirm' : funcref('s:confirm'),
        \ 'message' : funcref('s:msg'),
        \ }
endfunction
" }}}

" FUNCTION: s:initKeys() {{{
function! s:initKeys()
    let lowercase = 'q w e r t y u i o p a s d f g h j k l z x c v b n m'
    let uppercase = toupper(lowercase)

    let controlList = []
    for l in split(lowercase, ' ')
        call add(controlList, 'C-' . l)
    endfor
    call add(controlList, 'C-^')
    call add(controlList, 'C-]')

    let altList = []
    for l in split(lowercase, ' ')
        call add(altList, 'M-' . l)
    endfor

    let controls = join(controlList, ' ')
    let alts = join(altList, ' ')

    let numbers  = '1 2 3 4 5 6 7 8 9 0'
    let specials = 'Esc F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 ' .
                 \ '` ~ ! @ # $ % ^ & * ( ) - = _ + BS ' .
                 \ 'Tab S-Tab [ ] { } BSlash Bar ' .
                 \ '; : '' " CR ' .
                 \ 'Space , < . > / ? ' .
                 \ 'Down Up Left Right Home End PageUp PageDown ' .
                 \ 'MouseDown MouseUp LeftDrag LeftRelease 2-LeftMouse '

    let s:keys = split(join([lowercase, uppercase, controls, alts, numbers, specials], ' '), ' ')
endfunction
" }}}

" FUNCTION: s:create(layer) {{{
function! s:create(layer)
    if exists('s:flag') && s:flag
        if s:lyr.name ==# a:layer
            call s:dispBuffer()     " just only re-display buffer
            return
        else
            call s:destroy()
        endif
    endif
    let s:flag = 1
    let s:lyr = s:popc[a:layer]

    call popc#ui#saveRecover()

    silent execute 'noautocmd botright pedit popc'
    " before the line below, all command is executed in recover-buffer
    " after the line below, all command is executed in Popc-buffer
    silent execute 'noautocmd wincmd P'

    call s:setBuffer()
    call s:dispBuffer()
endfunction
" }}}

" FUNCTION: s:destroy() {{{
function! s:destroy()
    if !(exists('s:flag') && s:flag)
        return
    endif

    " recover window
    let l:recover = popc#ui#GetRecover()
    if &timeoutlen
        silent execute 'set timeoutlen=' . l:recover.timeoutlen
    endif
    set guicursor-=n:block-PopcSel-blinkon0
    bwipeout
    " before the line below, all command is executed in Popc-buffer
    " after the line below, all command is executed in recover-buffer
    if l:recover.winnr <= winnr('$')
        silent execute 'noautocmd ' . l:recover.winnr . 'wincmd w'
    endif

    let s:flag = 0
endfunction
" }}}

" FUNCTION: s:toggle(state) {{{
function! s:toggle(state)
    if exists('s:flag') && s:flag
        let l:recover = popc#ui#GetRecover()
        " use noautocmd to avoid BufLeave of preview window
        silent execute a:state ?
                    \ ('noautocmd wincmd P') :
                    \ ('noautocmd ' . l:recover.winnr . 'wincmd w')
    endif
endfunction
" }}}

" FUNCTION: s:setBuffer() {{{
function! s:setBuffer()
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nowrap
    setlocal nonumber
    if exists('+relativenumber')
        setlocal norelativenumber
    endif
    setlocal nocursorcolumn
    setlocal nocursorline
    setlocal nofoldenable
    setlocal foldcolumn=1
    setlocal nospell
    setlocal nolist
    setlocal scrolloff=0
    setlocal colorcolumn=
    setlocal filetype=Popc
    if &timeout
        set timeoutlen=10
    endif

    " set root path
    if !empty(s:lyr.info.rootDir)
        silent execute 'lcd ' . s:lyr.info.rootDir
    endif

    " set auto-command
    augroup PopcUiSetBuffer
        autocmd!
        autocmd BufLeave <buffer> call s:destroy()
    augroup END

    " set up syntax highlighting
    if has('syntax')
        syntax clear
        syntax match PopcText /  .*/
        syntax match PopcSel /> .*/hs=s+1
    endif
    set guicursor+=n:block-PopcSel-blinkon0

    " set statusline
    if s:conf.useStatusline
        silent execute 'let &l:statusline=' . s:conf.statusLine
        silent execute 'setlocal statusline=%!' . s:conf.statusLine
    endif

    " create maps
    for key in s:keys
        let k = strlen(key) > 1 ? ('<' . key . '>') : key
        let a = (key == '"') ? '\"' : key
        silent execute 'nnoremap <silent><buffer> ' . k . ' :call popc#ui#default#Trigger("' . a . '")<CR>'
    endfor
endfunction
" }}}

" FUNCTION: s:dispBuffer() {{{
function! s:dispBuffer()
    " set buffer text and maps
    let l:list = s:lyr.getBufs()
    let b:size = len(l:list)
    let b:text = ''
    for k in range(b:size)
        let b:text .= l:list[k] . repeat(' ', &columns - strwidth(l:list[k]) + 1) . "\n"
    endfor

    " resize buffer
    let l:max = (s:conf.maxHeight > 0) ? s:conf.maxHeight : (&lines / 3)
    silent execute 'resize' ((b:size > l:max) ? l:max : b:size)

    " put buffer
    setlocal modifiable
    silent normal! gg"_dG
    silent put! = b:text
    silent normal! GkJgg
    setlocal nomodifiable
    if s:lyr.mode == s:MODE.Normal || s:lyr.mode == s:MODE.Help
        call s:operate('num', s:lyr.info.lastIndex + 1)
    elseif s:lyr.mode == s:MODE.Filter
        call s:operate('num', b:size)
    endif
endfunction
" }}}

" FUNCTION: s:operate(dir, ...) {{{
function! s:operate(dir, ...)
    setlocal modifiable
    let l:oldLine = line('.')
    if b:size < 1
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
        call cursor(b:size - l:pos, 1)
    elseif l:pos > b:size
        call cursor(l:pos - b:size, 1)
    else
        call cursor(l:pos, 1)
    endif

    " mark index line with '>'
    let l:newLine = line('.')
    if l:oldLine != l:newLine
        call setline(l:oldLine, ' ' . strpart(getline(l:oldLine), 1))
    endif
    call setline(l:newLine, '>' . strpart(getline(l:newLine), 1))
    setlocal nomodifiable

    " save layer index
    if s:lyr.mode == s:MODE.Normal
        call s:lyr.setInfo('lastIndex', line('.') - 1)
        if s:lyr.info.userCmd
            doautocmd User PopcUiIndexChanged
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#ui#default#Trigger(key) {{{
function! popc#ui#default#Trigger(key)
    let l:index = line('.') - 1
    if s:lyr.mode == s:MODE.Filter
        let l:index = s:lyr.fltr.index[l:index]
    endif
    call popc#ui#Trigger(a:key, l:index)
endfunction
" }}}

" FUNCTION: s:input(prompt, ...) {{{
function! s:input(prompt, ...)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:prompt, '\M\n', '\n   ', 'g')
    redraw
    return a:0 == 0 ? input(l:msg) :
         \ a:0 == 1 ? input(l:msg, a:1) :
         \            input(l:msg, a:1, a:2)
endfunction
" }}}

" FUNCTION: s:confirm(prompt) {{{
function! s:confirm(prompt)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:prompt, '\M\n', '\n   ', 'g') . ' (yN): '
    redraw
    return input(l:msg) ==# 'y'
endfunction
" }}}

" FUNCTION: s:msg(msg) {{{
function! s:msg(msg)
    redraw
    echo ' ' . s:conf.symbols.Popc . ' ' . substitute(a:msg, '\M\n', '\n   ', 'g')
endfunction
" }}}


" SETCION: simple filter {{{1

" FUNCTION: s:filter(layer) {{{
function! s:filter(layer) abort
    set guicursor-=n:block-PopcSel-blinkon0

    call s:filterUpdate()
    while 1
        redraw
        echo ' > ' . s:lyr.fltr.chars

        let ret = getchar()
        let ch = (type(ret) == v:t_number ? nr2char(ret) : ret)

        if ch ==# "\<Esc>" || ch ==# "\<CR>"
            break
        elseif ch ==# "\<C-j>" || ch ==# "\<Down>"
            call s:operate('down')
        elseif ch ==# "\<C-k>" || ch ==# "\<Up>"
            call s:operate('up')
        elseif ch ==# "\<M-j>"
            call s:operate('pgdown')
        elseif ch ==# "\<M-k>"
            call s:operate('pgup')
        elseif ch ==# "\<BS>" || ch ==# "\<C-h>"
            let s:lyr.fltr.chars = s:lyr.fltr.chars[0:-2]
            call s:filterUpdate()
        elseif ch =~# '\p'
            let s:lyr.fltr.chars .= ch
            call s:filterUpdate()
        endif
    endwhile

    set guicursor+=n:block-PopcSel-blinkon0
endfunction
" }}}

" FUNCTION: s:filterUpdate() {{{
function! s:filterUpdate() abort
    let l:cnt = 0
    let l:txt = []
    let l:pat = ''

    for k in range(strchars(s:lyr.fltr.chars))
        let l:pat .= s:lyr.fltr.chars[k]
        let l:pat .= '.*'
    endfor
    for k in range(len(s:lyr.fltr.lines))
        if s:lyr.fltr.lines[k] =~? l:pat
            let s:lyr.fltr.index[l:cnt] = k
            let l:cnt += 1
            call add(l:txt, s:lyr.fltr.lines[k])
        endif
    endfor

    call s:lyr.setBufs(v:t_list, l:txt)
    call s:dispBuffer()
endfunction
" }}}

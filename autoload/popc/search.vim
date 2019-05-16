
" search interface.

" SECTION: variables {{{1
let s:popc = popc#popc#GetPopc()[0]
let s:lyr = {}


" SECTION: functions {{{1

" FUNCTION: popc#search#Init() {{{
function! popc#search#Init()
    let s:chars    = ''
    let s:txt      = ''
    let s:cnt      = 0
    let s:timer    = 0
    let s:job      = v:null
endfunction
" }}}

" FUNCTION: popc#search#Search(layer) {{{
function! popc#search#Search(layer)
    let s:lyr = s:popc[a:layer]

    " start timer
    let s:lastChars = ''
    let s:timer = timer_start(100, funcref('s:timerHandler'), {'repeat': -1})

    " take all control in search mode
    call s:search()
    call popc#search#Terminate()
endfunction
" }}}

" FUNCTION: popc#search#Terminate() {{{
function! popc#search#Terminate()
    " stop timer
    if !empty(timer_info(s:timer))
        call timer_stop(s:timer)
    endif
    unlet s:lastChars

    " stop job
    if type(s:job) == v:t_job
        call job_stop(s:job)
    endif

    call popc#search#Init()
endfunction
" }}}

" FUNCTION: s:timerHandler(timerId) {{{
function! s:timerHandler(timerId)
    "call s:lyr.setBufs(v:t_string, 1, '  ' . s:chars)
    "call popc#ui#Create(s:lyr.name)
    "return
    if s:lastChars ==# s:chars
        " update layer's bufs
        if empty(s:chars)
            call s:lyr.setBufs(v:t_string, 0, '')
        else
            call s:lyr.setBufs(v:t_string, s:cnt, s:txt)
        endif
        call popc#ui#Create(s:lyr.name)
        return
    endif

    " create layer's bufs
    let s:lastChars = s:chars
    let s:cnt = 0
    let s:txt = ''
    call s:lyr.setBufs(v:t_string, s:cnt, s:txt)

    if type(s:job) == v:t_job
        call job_stop(s:job)
    endif
    if has('win32') && !has('win32unix') && (&shell =~ 'cmd.exe')
        let l:cmd = 'rg -e ' . s:chars . ' ./ --vimgrep'
    else
        let l:cmd = [&shell, &shellcmdflag, 'rg -e' . s:chars . ' ./ --vimgrep']
    endif
    let s:job = job_start(l:cmd,
                \ {
                    \ 'callback' : funcref('s:jobHandler'),
                    \ 'exit_cb'  : funcref('s:jobHandler_exit'),
                    \ 'in_io'    : 'null'
                \ })

    if job_status(s:job) ==# 'fail'
        let s:job = v:none
        return
    endif
endfunction
" }}}

" FUNCTION: s:jobHandler(channel, msg) {{{
function! s:jobHandler(channel, msg)
    let s:cnt += 1
    let l:line = '  ' . a:msg
    let l:line .= repeat(' ', &columns - strwidth(l:line))
    let s:txt .= l:line . "\n"
endfunction
" }}}

" FUNCTION: s:jobHandler_exit(job, status) {{{
function! s:jobHandler_exit(job, status)
    if s:job == a:job
        let s:job = v:none
    endif
endfunction
" }}}

" FUNCTION: s:search() {{{
function! s:search()
    let s:chars = ''
    while 1
        redraw
        echo ' $> ' . s:chars

        let ret = getchar()
        let ch = (type(ret) == v:t_number ? nr2char(ret) : ret)

        if ch ==# "\<Esc>"
            break
        elseif ch ==# "\<C-j>"
            call popc#ui#MoveBar('down')
        elseif ch ==# "\<C-k>"
            call popc#ui#MoveBar('up')
        elseif ch ==# 'ê'           " <M-j>
            call popc#ui#MoveBar('pgdown')
        elseif ch ==# 'ë'           " <M-k>
            call popc#ui#MoveBar('pgup')
        elseif ch ==# "\<Up>"
        elseif ch ==# "\<Down>"
        elseif ch ==# "\<CR>"
            "
        elseif ch ==# "\<BS>"
            let s:chars = s:chars[0:-2]
        elseif ch =~# '\p'
            let s:chars .= ch
        endif
    endwhile
endfunction
" }}}

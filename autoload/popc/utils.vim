
" utils script.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()
let s:log = []
let s:dbg = {}

" SECTION: api functions {{{1

" FUNCTION: popc#utils#GetKeys() {{{
function! popc#utils#GetKeys()
    let lowercase = split('q w e r t y u i o p a s d f g h j k l z x c v b n m', ' ')
    let uppercase = split('Q W E R T Y U I O P A S D F G H J K L Z X C V B N M', ' ')

    let controls = []
    for l in lowercase
        call add(controls, 'C-' . l)
    endfor
    call add(controls, 'C-^')
    call add(controls, 'C-]')

    let alts = []
    for l in lowercase
        call add(alts, 'M-' . l)
    endfor

    let numbers  = split('1 2 3 4 5 6 7 8 9 0', ' ')
    let specials1 = split(
                 \ '` ~ ! @ # $ % ^ & * ( ) - = _ + ' .
                 \ '[ ] { } ' .
                 \ '; : '' " ' .
                 \ ', < . > / ?', ' ')
    let specials2 = split('Esc F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 ' .
                 \ 'BS ' .
                 \ 'Tab S-Tab BSlash Bar ' .
                 \ 'CR ' .
                 \ 'Space ' .
                 \ 'Down Up Left Right Home End PageUp PageDown ' .
                 \ 'LeftDrag LeftRelease LeftMouse 2-LeftMouse 3-LeftMouse 4-LeftMouse ' .
                 \ 'RightDrag RightRelease RightMouse 2-RightMouse 3-RightMouse 4-RightMouse ' .
                 \ 'MiddleDrag MiddleRelease MiddleMouse 2-MiddleMouse 3-MiddleMouse 4-MiddleMouse ' .
                 \ 'ScrollWheelUp 2-ScrollWheelUp 3-ScrollWheelUp 4-ScrollWheelUp ' .
                 \ 'S-ScrollWheelUp 2-S-ScrollWheelUp 3-S-ScrollWheelUp 4-S-ScrollWheelUp ' .
                 \ 'C-ScrollWheelUp 2-C-ScrollWheelUp 3-C-ScrollWheelUp 4-C-ScrollWheelUp ' .
                 \ 'ScrollWheelDown 2-ScrollWheelDown 3-ScrollWheelDown 4-ScrollWheelDown ' .
                 \ 'S-ScrollWheelDown 2-S-ScrollWheelDown 3-S-ScrollWheelDown 4-S-ScrollWheelDown ' .
                 \ 'C-ScrollWheelDown 2-C-ScrollWheelDown 3-C-ScrollWheelDown 4-C-ScrollWheelDown ' .
                 \ 'ScrollWheelLeft M-ScrollWheelLeft M-2-ScrollWheelLeft M-3-ScrollWheelLeft M-4-ScrollWheelLeft ' .
                 \ 'ScrollWheelRight M-ScrollWheelRight M-2-ScrollWheelRight M-3-ScrollWheelRight M-4-ScrollWheelRight', ' ')

    return {
        \ 'lowercase' : lowercase,
        \ 'uppercase' : uppercase,
        \ 'controls'  : controls,
        \ 'alts'      : alts,
        \ 'numbers'   : numbers,
        \ 'specials1'  : specials1,
        \ 'specials2'  : specials2,
        \ }
endfunction
" }}}

" FUNCTION: popc#utils#Num2RankStr(num) {{{
" @param num: the num in integer format
function! popc#utils#Num2RankStr(num)
    if s:conf.useNerdSymbols
        let l:str = ''
        let l:numStr = string(a:num)
        for k in range(len(l:numStr))
            let l:str .= s:conf.symbols.Nums[str2nr(l:numStr[k])]
        endfor
    else
        let l:str = '#' . string(a:num)
    endif
    return l:str
endfunction
" }}}

" FUNCTION: popc#utils#SortByName(a, b) {{{
" dict item format {'name': , 'path': }
function! popc#utils#SortByName(a, b)
    if a:a.name < a:b.name
        return -1
    elseif a:a.name > a:b.name
        return 1
    else
        if a:a.path < a:b.path
            return -1
        elseif a:a.path > a:b.path
            return 1
        else
            return 0
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#utils#SortByPath(a, b) {{{
function! popc#utils#SortByPath(a, b)
    if a:a.path < a:b.path
        return -1
    elseif a:a.path > a:b.path
        return 1
    else
        if a:a.name < a:b.name
            return -1
        elseif a:a.name > a:b.name
            return 1
        else
            return 0
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#utils#FindRoot() {{{
function! popc#utils#FindRoot()
    if empty(s:conf.wksRootPatterns)
        return ''
    endif

    let l:dir = fnamemodify(expand('%'), ':p:h')
    let l:dirLast = ''
    while l:dir !=# l:dirLast
        let l:dirLast = l:dir
        for m in s:conf.wksRootPatterns
            let l:root = l:dir . '/' . m
            if filereadable(l:root) || isdirectory(l:root)
                return fnameescape(l:dir)
            endif
        endfor
        let l:dir = fnamemodify(l:dir, ':p:h:h')
    endwhile
    return ''
endfunction
" }}}

" FUNCTION: popc#utils#UseSlashPath(path) {{{
function! popc#utils#UseSlashPath(path)
    if exists('+shellslash')
        let s:sslSave = &shellslash
        set shellslash
    endif
    let l:path = expand(a:path)
    if exists('s:sslSave')
        let &shellslash = s:sslSave
        unlet! s:sslSave
    endif
    return l:path
endfunction
" }}}

" FUNCTION: s:getParentDir(l, s) {{{
" @l: long dir
" @s: short dir
function! s:getParentDir(l, s)
    let l:ldir = popc#utils#UseSlashPath(a:l)
    let l:sdir = popc#utils#UseSlashPath(a:s)
    let l:sdirLast = l:sdir
    while l:ldir . '/' !~# '^' . l:sdir . '/'
        let l:sdir = fnamemodify(l:sdir, ':h')
        if l:sdirLast ==# l:sdir
            let l:sdir = ''
            break
        endif
        let l:sdirLast = l:sdir
    endwhile
    return l:sdir
endfunction
" }}}

" FUNCTION: popc#utils#GetParentDir(dirs) {{{
function! popc#utils#GetParentDir(dirs)
    if empty(a:dirs)
        return ''
    endif
    if len(a:dirs) == 1
        return a:dirs[0]
    endif

    " find the max and min length of dir
    let l:maxSize = strchars(a:dirs[0])
    let l:minSize = strchars(a:dirs[0])
    let l:min = 0
    let l:max = 0
    for k in range(len(a:dirs))
        let l:dsize = strchars(a:dirs[k])
        if l:dsize < l:minSize
            let l:min = k
            let l:minSize = l:dsize
        endif
        if l:dsize > l:maxSize
            let l:max = k
            let l:maxSize = l:dsize
        endif
    endfor
    " get parent dir
    let l:pdir = s:getParentDir(a:dirs[l:max], a:dirs[l:min])
    for d in a:dirs
        if empty(l:pdir)
            break
        else
            let l:pdir = s:getParentDir(d, l:pdir)
        endif
    endfor
    return l:pdir
endfunction
" }}}

" FUNCTION: popc#utils#Dbg([tag, args]) {{{
function! popc#utils#Dbg(...)
    let l:str = ''
    if a:0 > 0
        if has_key(s:dbg, a:1)
            let l:func = s:dbg[a:1].func
            let l:args = (a:0 > 1) ? a:2 : s:dbg[a:1].args
            let l:str .= printf("%s:\n%s", a:1, "\t" . join(function(l:func)(l:args), "\n\t"))
        else
            let l:str .= printf("'%s' is NOT one of the registered tag:\n%s", a:1, "\t" . join(keys(s:dbg), "\n\t"))
        endif
    else
        for [key, tag] in items(s:dbg)
            if !empty(l:str)
                let l:str .= "\n"
            endif
            let l:str .= printf("%s:\n%s", key, "\t" . join(function(tag.func)(tag.args), "\n\t"))
        endfor
    endif
    echo l:str
endfunction
" }}}

" FUNCTION: popc#utils#RegDbg(tag, func, args) {{{
" func should return string-list
function! popc#utils#RegDbg(tag, func, args)
    let s:dbg[a:tag] = {'func': a:func, 'args': a:args}
endfunction
" }}}

" FUNCTION: popc#utils#LogDebugger(type) {{{
function! popc#utils#LogDebugger(type)
if s:conf.enableLog
    let l:log = []
    if a:type == 'all'
        let l:log = readfile(popc#init#GetJson('log'))
    endif
    return l:log + s:log
endif
endfunction
" }}}

" FUNCTION: popc#utils#Log(tag, str, [args]) {{{
function! popc#utils#Log(tag, str, ...)
if s:conf.enableLog
    let l:line = printf("[%s][%s] %s", strftime('%M:%S'), a:tag, a:str)
    if a:0 > 0
        let l:line = call('printf', [l:line] + a:000)
    endif
    call add(s:log, l:line)

    if len(s:log) > 100
        call popc#utils#WriteLog()
    endif
endif
endfunction
" }}}

" FUNCTION: popc#utils#WriteLog() {{{
function! popc#utils#WriteLog()
if s:conf.enableLog
    call writefile(s:log, popc#init#GetJson('log'), 'a')
    let s:log = []
endif
endfunction
" }}}
" }}}

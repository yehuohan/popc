
" utils script.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()

" SECTION: api functions {{{1

" FUNCTION: popc#utils#getKeys() {{{
function! popc#utils#getKeys()
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
                 \ 'ScrollWheelUp ScrollWheelDown ScrollWheelLeft ScrollWheelRight', ' ')

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
    if s:conf.useUnicode
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
    if empty(s:conf.useLayerRoots)
        return ''
    endif

    let l:dir = fnamemodify(expand('%'), ':p:h')
    let l:dirLast = ''
    while l:dir !=# l:dirLast
        let l:dirLast = l:dir
        for m in s:conf.useLayerRoots
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

" FUNCTION: popc#utils#useSlashPath(path) {{{
function! popc#utils#useSlashPath(path)
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
    let l:ldir = popc#utils#useSlashPath(a:l)
    let l:sdir = popc#utils#useSlashPath(a:s)
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

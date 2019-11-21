
" utils script.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()

" SECTION: api functions {{{1

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

" FUNCTION: popc#utils#createHelpBuffer() {{{
" mapsData format [function-name, key-list, help-text]
function! popc#utils#createHelpBuffer(mapsData)
    let l:text = ''

    " get max name width
    let l:max = 0
    for md in a:mapsData
        let l:wid = strwidth(join(md[1], ','))
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    let l:max += 2

    " get context
    for md in a:mapsData
        let l:line =  '  ' . join(md[1], ',')
        let l:line .= repeat(' ', l:max - strwidth(l:line)) . ' | '
        let l:line .= md[2]
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
    endfor

    return l:text
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
    if empty(s:conf.useRoots)
        return ''
    endif

    let l:dir = fnamemodify(expand('%'), ':p:h')
    let l:dirLast = ''
    while l:dir !=# l:dirLast
        let l:dirLast = l:dir
        for m in s:conf.useRoots
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
    let l:maxSize = strlen(a:dirs[0])
    let l:minSize = strlen(a:dirs[0])
    let l:min = 0
    let l:max = 0
    for k in range(len(a:dirs))
        let l:dsize = strlen(a:dirs[k])
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


" init configuration for popc.

" SECTION: variables {{{1

let s:conf = {
    \ 'symbols'        : {},
    \ 'useUnicode'     : 1,
    \ 'useTabline'     : 1,
    \ 'useStatusline'  : 1,
    \ 'usePowerFont'   : 0,
    \ 'separator'      : {'left' : '', 'right': ''},
    \ 'subSeparator'   : {'left' : '', 'right': ''},
    \ 'statusLine'     : 'popc#ui#StatusLine()',
    \ 'tabLine'        : 'popc#ui#TabLine()',
    \ 'maxHeight'      : 0,
    \ 'json'           : {},
    \ 'jsonPath'       : expand($HOME),
    \ 'useLayer'       : {'Buffer': 1, 'Bookmark': 1, 'Workspace': 0, 'File': 0, 'Reg': 0},
    \ 'useRoots'       : ['.root', '.git', '.svn'],
    \ 'commonMaps'     : {},
    \ 'operationMaps'  : {
        \ 'moveCursorDown'   : ['j', 'C-j'],
        \ 'moveCursorUp'     : ['k', 'C-k'],
        \ 'moveCursorBottom' : ['J'],
        \ 'moveCursorTop'    : ['K'],
        \ 'moveCursorPgDown' : ['M-j'],
        \ 'moveCursorPgUp'   : ['M-k'],
        \ 'quit'             : ['q', 'Esc'],
        \ },
    \ }
let s:defaultSymbols = {
    \ 'unicode' : {
        \ 'Popc'   : '⌘',
        \ 'Buf'    : '•',
        \ 'Wks'    : '፨',
        \ 'Bm'     : '♥',
        \ 'Tab'    : '▫',
        \ 'CTab'   : '▪',
        \ 'WIn'    : '★',
        \ 'WOut'   : '☆',
        \ 'Rank'   : '≡',
        \ 'Arr'    : '→',
        \ 'Dots'   : '…',
        \ 'Nums'   : ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']
        \ },
    \ 'ascii' : {
        \ 'Popc'   : '#',
        \ 'Buf'    : '*',
        \ 'Wks'    : '&',
        \ 'Bm'     : '$',
        \ 'Tab'    : '~',
        \ 'CTab'   : '%',
        \ 'WIn'    : '*',
        \ 'WOut'   : '-',
        \ 'Rank'   : '=',
        \ 'Arr'    : '->',
        \ 'Dots'   : '...',
        \ 'Nums'   : ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
        \ },
    \ }
let s:json = {}
let s:rootDir = ''


" SECTION: functions {{{1

" FUNCTION: popc#init#Init() {{{
function! popc#init#Init()
    call s:initConfig()
    call s:checkConfig()
    call s:readJson()

    augroup PopcInitInit
        autocmd!
        autocmd BufAdd * let s:rootDir=s:findRoot()
    augroup END

    if s:conf.useLayer.Buffer
        command! -nargs=0 -range Popc :call popc#popc#Popc('Buffer')
        command! -nargs=0 -range PopcBuffer :call popc#popc#Popc('Buffer')
        command! -nargs=0 -range PopcBufferSwitchLeft :call popc#layer#buf#SwitchBuffer('left')
        command! -nargs=0 -range PopcBufferSwitchRight :call popc#layer#buf#SwitchBuffer('right')
    endif
    if s:conf.useLayer.Bookmark
        command! -nargs=0 -range PopcBookmark :call popc#popc#Popc('Bookmark')
    endif
endfunction
" }}}

" FUNCTION: popc#init#GetConfig() {{{
function! popc#init#GetConfig()
    return s:conf
endfunction
" }}}

" FUNCTION: popc#init#GetRoot() {{{
function! popc#init#GetRoot()
    return s:rootDir
endfunction
" }}}

" FUNCTION: s:readJson() {{{
function! s:readJson()
    if filereadable(s:conf.jsonPath . '/.popc.json')
        let s:json = json_decode(join(readfile(s:conf.jsonPath . '/.popc.json')))
    else
        let s:json = {'bookmarks' : [], 'workspaces' : []}
        call popc#init#SaveJson()
    endif
endfunction
" }}}

" FUNCTION: popc#init#SaveJson() {{{
function! popc#init#SaveJson()
    let l:json = json_encode(s:json)
    call writefile([l:json], s:conf.jsonPath . '/.popc.json')
endfunction
" }}}

" FUNCTION: popc#init#GetJson() {{{
function! popc#init#GetJson()
    return s:json
endfunction
" }}}

" FUNCTION: s:initConfig() {{{
function! s:initConfig()
    " set confiuration's value and list
    for k in ['useUnicode', 'useTabline', 'useStatusline', 'usePowerFont',
            \ 'statusLine', 'tabLine', 'maxHeight', 'jsonPath',
            \ 'useRoots']
        if exists('g:Popc_' . k)
            let s:conf[k] = g:{'Popc_' . k}
        endif
    endfor

    " set confiuration's dictionary and list
    let s:conf.symbols = deepcopy(s:conf.useUnicode ? s:defaultSymbols.unicode : s:defaultSymbols.ascii)
    unlet s:defaultSymbols
    for k in ['symbols', 'separator', 'subSeparator', 'useLayer',
            \  'commonMaps', 'operationMaps']
        if exists('g:Popc_' . k)
            call extend(s:conf[k], g:{'Popc_' . k}, 'force')
        endif
    endfor
endfunction
" }}}

" FUNCTION: s:checkConfig() {{{
function! s:checkConfig()
    if s:conf.useTabline && !s:conf.useLayer.Buffer
        let s:conf.useLayer.Buffer = 1
    endif
endfunction
" }}}

" FUNCTION: s:findRoot() {{{
function! s:findRoot()
    if empty(s:conf.useRoots) || !empty(s:rootDir)
        return ''
    endif

    let l:dir = fnamemodify('.', ':p:h')
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

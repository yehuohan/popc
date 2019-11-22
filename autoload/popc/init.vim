
" init configuration for popc.

" SECTION: variables {{{1

let s:conf = {
    \ 'jsonPath'       : $VIM,
    \ 'useGlobalPath'  : 0,
    \ 'symbols'        : {},
    \ 'useUnicode'     : 1,
    \ 'useTabline'     : 1,
    \ 'useStatusline'  : 1,
    \ 'usePowerFont'   : 0,
    \ 'separator'      : {'left' : '', 'right': ''},
    \ 'subSeparator'   : {'left' : '', 'right': ''},
    \ 'statusLine'     : 'popc#ui#StatusLine()',
    \ 'tabLine'        : 'popc#ui#TabLine()',
    \ 'tabLineLayout'  : {'left' : 'buffer', 'right': 'tab'},
    \ 'maxHeight'      : 0,
    \ 'useLayer'       : {'Buffer': 1, 'Bookmark': 1, 'Workspace': 1, 'File': 0, 'Reg': 0},
    \ 'useRoots'       : ['.popc', '.git', '.svn'],
    \ 'layerInit'      : {},
    \ 'layerComMaps'   : {},
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
        \ 'Popc'   : '❖',
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
let s:json = {
    \ 'json' : {},
    \ 'file' : '',
    \ 'dir' : '',
    \ }


" SECTION: functions {{{1

" FUNCTION: popc#init#Init() {{{
function! popc#init#Init()
    call s:initConfig()
    call s:checkConfig()
    call s:initJson()

    if s:conf.useLayer.Buffer
        command! -nargs=0 Popc :call popc#popc#Popc('Buffer')
        command! -nargs=0 PopcBuffer :call popc#popc#Popc('Buffer')
        command! -nargs=0 PopcBufferSwitchLeft :call popc#layer#buf#SwitchBuffer('left')
        command! -nargs=0 PopcBufferSwitchRight :call popc#layer#buf#SwitchBuffer('right')
    endif
    if s:conf.useLayer.Bookmark
        command! -nargs=0 PopcBookmark :call popc#popc#Popc('Bookmark')
    endif
    if s:conf.useLayer.Workspace
        command! -nargs=0 PopcWorkspace :call popc#popc#Popc('Workspace')
    endif
endfunction
" }}}

" FUNCTION: popc#init#GetConfig() {{{
function! popc#init#GetConfig()
    return s:conf
endfunction
" }}}

" FUNCTION: s:initJson() {{{
function! s:initJson()
    let s:json.file = s:conf.jsonPath . '/.popc.json'
    let s:json.dir = s:conf.jsonPath . '/.popc'

    if !filereadable(s:json.file)
        let s:json.json = {'bookmarks' : [], 'workspaces' : []}
        call popc#init#SaveJson()
    endif
    if s:conf.useGlobalPath
        if !isdirectory(s:json.dir)
            call mkdir(s:json.dir, 'p')
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#init#SaveJson() {{{
function! popc#init#SaveJson()
    let l:json = json_encode(s:json.json)
    call writefile([l:json], s:json.file)
endfunction
" }}}

" FUNCTION: popc#init#GetJson(type) {{{
function! popc#init#GetJson(type)
    if a:type == 'json'
        let s:json.json = json_decode(join(readfile(s:json.file)))
        return s:json.json
    elseif a:type == 'dir'
        return s:json.dir
    endif
endfunction
" }}}

" FUNCTION: s:initConfig() {{{
function! s:initConfig()
    " set confiuration's value and list
    for k in ['jsonPath', 'useGlobalPath', 'useUnicode',
            \ 'useTabline', 'useStatusline', 'usePowerFont',
            \ 'statusLine', 'tabLine', 'maxHeight', 'useRoots']
        if exists('g:Popc_' . k)
            let s:conf[k] = g:{'Popc_' . k}
        endif
    endfor

    " set confiuration's dictionary and list
    let s:conf.symbols = deepcopy(s:conf.useUnicode ? s:defaultSymbols.unicode : s:defaultSymbols.ascii)
    unlet s:defaultSymbols
    for k in ['symbols', 'separator', 'subSeparator', 'tabLineLayout',
            \ 'useLayer', 'layerInit', 'layerComMaps', 'operationMaps']
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
    if s:conf.useLayer.Workspace
        let s:conf.useLayer.Buffer = 1
    endif
endfunction
" }}}

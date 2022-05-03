
" init configuration for popc.

" SECTION: variables {{{1

let s:conf = {
    \ 'jsonPath'                        : $HOME,
    \ 'useFloatingWin'                  : 0,
    \ 'symbols'                         : {},
    \ 'useUnicode'                      : 1,
    \ 'highlight' : {
        \ 'text'                        : 'Pmenu',
        \ 'selected'                    : 'PmenuSel',
        \ 'lineTxt'                     : 'Pmenu',
        \ 'lineSel'                     : 'PmenuSel',
        \ 'modifiedTxt'                 : '',
        \ 'modifiedSel'                 : 'DiffAdd',
        \ 'labelTxt'                    : 'IncSearch',
        \ 'blankTxt'                    : 'Normal',
        \ },
    \ 'useTabline'                      : 1,
    \ 'useStatusline'                   : 1,
    \ 'usePowerFont'                    : 0,
    \ 'selectPointer'                   : '',
    \ 'separator'                       : {'left' : '', 'right': ''},
    \ 'subSeparator'                    : {'left' : '', 'right': ''},
    \ 'statusLine'                      : 'popc#stl#StatusLine()',
    \ 'tabLine'                         : 'popc#stl#TabLine()',
    \ 'tabLineLayout'                   : {'left' : 'buffer', 'right': 'tab'},
    \ 'maxHeight'                       : 0,
    \ 'useLayer'                        : {'Buffer': 1, 'Bookmark': 1, 'Workspace': 1},
    \ 'bufShowUnlisted'                 : 0,
    \ 'wksRootPatterns'                 : ['.popc', '.git', '.svn', '.hg'],
    \ 'wksSaveUnderRoot'                : 0,
    \ 'operationMaps'  : {
        \ 'moveCursorDown'              : ['j', 'C-j'],
        \ 'moveCursorUp'                : ['k', 'C-k'],
        \ 'moveCursorBottom'            : ['J'],
        \ 'moveCursorTop'               : ['K'],
        \ 'moveCursorPgDown'            : ['M-j'],
        \ 'moveCursorPgUp'              : ['M-k'],
        \ 'help'                        : ['?'],
        \ 'back'                        : ['q'],
        \ 'quit'                        : ['Esc']
        \ },
    \ 'enableLog' : 0
    \ }
let s:defaultSymbols = {
    \ 'unicode' : {
        \ 'Popc'   : '❖',
        \ 'Buf'    : '⌂',
        \ 'Wks'    : '♥',
        \ 'Bms'    : '★',
        \ 'CTab'   : '●',
        \ 'Tab'    : '○',
        \ 'WIn'    : '▪',
        \ 'WOut'   : '▫',
        \ 'Rank'   : '≡',
        \ 'Arr'    : '→',
        \ 'Dots'   : '…',
        \ 'Ptr'    : '►',
        \ 'Nums'   : ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹']
        \ },
    \ 'ascii' : {
        \ 'Popc'   : '#',
        \ 'Buf'    : '@',
        \ 'Wks'    : '&',
        \ 'Bms'    : '$',
        \ 'Tab'    : '~',
        \ 'CTab'   : '%',
        \ 'WIn'    : '*',
        \ 'WOut'   : '-',
        \ 'Rank'   : '=',
        \ 'Arr'    : '->',
        \ 'Dots'   : '...',
        \ 'Ptr'    : '>',
        \ 'Nums'   : ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
        \ },
    \ }
let s:json = {
    \ 'json' : {},
    \ 'fp_json' : '',
    \ 'fp_log' : '',
    \ 'dir' : '',
    \ }


" SECTION: functions {{{1

" FUNCTION: popc#init#Init() {{{
function! popc#init#Init()
    call s:initConfig()
    call s:checkConfig()
    call s:initJson()

    command! -nargs=1 -complete=customlist,popc#popc#GetLayerList Popc :call popc#popc#Popc(<f-args>)
    if s:conf.useLayer.Buffer
        command! -nargs=0 PopcBuffer :call popc#popc#Popc('Buffer')
        command! -nargs=0 -bang PopcBufferSwitchTabLeft :call popc#layer#buf#SwitchTab('left', <bang>0)
        command! -nargs=0 -bang PopcBufferSwitchTabRight :call popc#layer#buf#SwitchTab('right', <bang>0)
        command! -nargs=0 -bang PopcBufferSwitchLeft :call popc#layer#buf#SwitchBuffer('left', <bang>0)
        command! -nargs=0 -bang PopcBufferSwitchRight :call popc#layer#buf#SwitchBuffer('right', <bang>0)
        command! -nargs=0 PopcBufferJumpNext :call popc#layer#buf#JumpBuffer('next')
        command! -nargs=0 PopcBufferJumpPrev :call popc#layer#buf#JumpBuffer('prev')
        command! -nargs=0 -bang PopcBufferClose :call popc#layer#buf#CloseBuffer(<bang>0)
    endif
    if s:conf.useLayer.Bookmark
        command! -nargs=0 PopcBookmark :call popc#popc#Popc('Bookmark')
    endif
    if s:conf.useLayer.Workspace
        command! -nargs=0 PopcWorkspace :call popc#popc#Popc('Workspace')
    endif
    command! -nargs=* PopcDbg :call popc#utils#Dbg(<f-args>)
endfunction
" }}}

" FUNCTION: popc#init#GetConfig() {{{
function! popc#init#GetConfig()
    return s:conf
endfunction
" }}}

" FUNCTION: s:initJson() {{{
function! s:initJson()
    let s:json.dir = s:conf.jsonPath . '/.popc'
    let s:json.fp_json = s:conf.jsonPath . '/.popc.json'

    " create .popc.json file
    if !filereadable(s:json.fp_json)
        let s:json.json = {'bookmarks' : [], 'workspaces' : []}
        call popc#init#SaveJson()
        call popc#utils#Log('init', '%s was created', s:json.fp_json)
    endif
    " create .popc dir
    if !isdirectory(s:json.dir)
        call mkdir(s:json.dir, 'p')
        call popc#utils#Log('init', '%s was created', s:json.dir)
    endif
    " create .popc.log file
    if s:conf.enableLog
        let s:json.fp_log = s:json.dir . '/.popc.log'
        call writefile([], s:json.fp_log)
        call popc#utils#Log('init', '%s was created', s:json.fp_log)
        augroup PopcInitInit
            autocmd!
            autocmd VimLeave * call popc#utils#Log('init', 'vim was exited') | call popc#utils#WriteLog()
        augroup END
        call popc#utils#RegDbg('log', 'popc#utils#DbgDispLog', 'all')
    endif
endfunction
" }}}

" FUNCTION: popc#init#SaveJson() {{{
function! popc#init#SaveJson()
    let l:json = json_encode(s:json.json)
    call writefile([l:json], s:json.fp_json)
endfunction
" }}}

" FUNCTION: popc#init#GetJson(type) {{{
function! popc#init#GetJson(type)
    if a:type == 'json'
        let s:json.json = json_decode(join(readfile(s:json.fp_json)))
        return s:json.json
    elseif a:type == 'log'
        return s:json.fp_log
    elseif a:type == 'dir'
        return s:json.dir
    endif
endfunction
" }}}

" FUNCTION: s:initConfig() {{{
function! s:initConfig()
    " check deprecated configs
    let l:msg = []
    if exists('g:Popc_useLayerRoots')
        let g:Popc_wksRootPatterns = g:Popc_useLayerRoots
        call add(l:msg, 'Popc_useLayerRoots is deprecated, and use Popc_wksRootPatterns instead.')
    endif
    if exists('g:Popc_useLayerPath')
        let g:Popc_wksSaveUnderRoot = g:Popc_useLayerPath
        call add(l:msg, 'Popc_useLayerPath is deprecated, and use Popc_wksSaveUnderRoot instead.')
    endif
    if !empty(l:msg)
        echohl WarningMsg
        echomsg '[Popc] Deprecated configs:'
        for msg in l:msg
            echomsg msg
        endfor
        echohl None
    endif

    " set confiuration's value and list
    for k in ['jsonPath', 'useFloatingWin', 'useUnicode',
            \ 'useTabline', 'useStatusline', 'usePowerFont', 'selectPointer',
            \ 'statusLine', 'tabLine', 'maxHeight',
            \ 'bufShowUnlisted', 'wksRootPatterns', 'wksSaveUnderRoot',
            \ 'enableLog']
        if exists('g:Popc_' . k)
            let s:conf[k] = g:{'Popc_' . k}
        endif
    endfor

    " set confiuration's dictionary and list
    let s:conf.symbols = deepcopy(s:conf.useUnicode ? s:defaultSymbols.unicode : s:defaultSymbols.ascii)
    unlet s:defaultSymbols
    for k in ['symbols', 'highlight', 'separator', 'subSeparator', 'tabLineLayout',
            \ 'useLayer', 'operationMaps']
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

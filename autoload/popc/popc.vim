
" popc center unit.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()
let s:popc = {}
let s:layer = {
    \ 'name' : '',
    \ 'mode' : 0,
    \ 'maps' : {},
    \ 'bufs' : {'typ': v:t_string, 'fnc': '', 'cnt': 0, 'txt': ''},
    \ 'info' : {
        \ 'rootDir'    : '',
        \ 'lastIndex'  : 0,
        \ 'centerText' : '',
        \ 'userCmd'    : 0,
        \ }
    \ }
let s:MODE = {
    \ 'Normal' : 0,
    \ 'Search' : 1,
    \ 'Help'   : 2,
    \ }


" SECTION: dictionary function {{{1

" FUNCTION: s:popc.addLayer(layer, ...) dict {{{
" @param(a:1): bind to common maps or not
function! s:popc.addLayer(layer, ...) dict
    let self[a:layer] = deepcopy(s:layer)
    let self[a:layer].name = a:layer
    let self[a:layer].mode = s:MODE.Normal
    let l:bindCom = (a:0 > 0) ? a:1 : 1
    call popc#key#InitMaps(a:layer, self[a:layer].maps, l:bindCom)
    return self[a:layer]
endfunctio
" }}}

" FUNCTION: s:popc.removeLayer(layer) dict {{{
function! s:popc.removeLayer(layer) dict
    if has_key(self, a:layer)
        call remove(self, a:layer)
    endif
endfunction
" }}}

" FUNCTION: s:layer.addMaps(funcName, keys) dict {{{
" @funcName: one args for map-key at least and must be the last args.
" @keys: the map-key.
function! s:layer.addMaps(funcName, keys) dict
    for k in a:keys
        let self.maps[k] = function(a:funcName, [k])
    endfor
endfunction
" }}}

" FUNCTION: s:layer.setMode(md) dict {{{
function! s:layer.setMode(md) dict
    let self.mode = a:md
endfunction
" }}}

" FUNCTION: s:layer.setBufs(type, ...) dict {{{
" @type: v:t_func or v:t_string
" @param(a:000): funcref for v:t_func or cnt,txt for v:t_string
function! s:layer.setBufs(type, ...) dict
    let self.bufs.typ = a:type
    if self.bufs.typ == v:t_func
        let self.bufs.fnc = a:1
    elseif self.bufs.typ == v:t_string
        let self.bufs.cnt = a:1
        let self.bufs.txt = a:2
    endif
endfunction
" }}}

" FUNCTION: s:layer.getBufs() dict {{{
function! s:layer.getBufs() dict
    if self.bufs.typ == v:t_func
        let [l:cnt, l:txt] = self.bufs.fnc()
    elseif self.bufs.typ == v:t_string
        let [l:cnt, l:txt] = [self.bufs.cnt, self.bufs.txt]
    endif

    " creat buffer text
    if empty(l:txt)
        let l:txt = '  Nothing to pop.'
        let l:txt .= repeat(' ', &columns - strwidth(l:txt))
        let l:cnt = 1
    endif
    if self.mode == s:MODE.Help
        " append help information
        let l:text = ''
        let l:line = '  ~~~~~ ' . g:popc_version . ' (In layer ' . self.name . ') ~~~~~'
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
        let l:text .= repeat(' ', &columns) . "\n" . l:txt
        " append help for operation
        let l:text .= repeat(' ', &columns) . "\n"
        let l:line = printf('  Up  : [%s]    Top   : [%s]    Page up  : [%s]',
                            \ join(s:conf.operationMaps['moveCursorUp']     , ','),
                            \ join(s:conf.operationMaps['moveCursorTop']    , ','),
                            \ join(s:conf.operationMaps['moveCursorPgUp']   , ',')
                            \ )
        let l:text .= l:line . repeat(' ', &columns - strwidth(l:line)) . "\n"
        let l:line = printf('  Down: [%s]    Bottom: [%s]    Page down: [%s]    Quit: [%s]',
                            \ join(s:conf.operationMaps['moveCursorDown']   , ','),
                            \ join(s:conf.operationMaps['moveCursorBottom'] , ','),
                            \ join(s:conf.operationMaps['moveCursorPgDown'] , ','),
                            \ join(s:conf.operationMaps['quit']             , ',')
                            \ )
        let l:text .= l:line . repeat(' ', &columns - strwidth(l:line)) . "\n"

        let l:txt = l:text
        let l:cnt += 5
    endif
    return [l:cnt, l:txt]
endfunction
" }}}

" FUNCTION: s:layer.setInfo(key, value) dict {{{
function! s:layer.setInfo(key, value) dict
    let self.info[a:key] = a:value
endfunction
" }}}


" SECTION: functions {{{1

" FUNCTION: popc#popc#Init() {{{
function! popc#popc#Init()
    call popc#init#Init()
    call popc#key#Init()
    call popc#search#Init()
    call popc#ui#Init()
    call popc#layer#com#Init()
endfunction
" }}}

" FUNCTION: popc#popc#GetPopc() {{{
function! popc#popc#GetPopc()
    return [s:popc, s:MODE]
endfunction
" }}}

" FUNCTION: popc#popc#Popc(layername) {{{
function! popc#popc#Popc(layername)
    if a:layername ==# 'Buffer'
        call popc#layer#buf#Pop('h')
    elseif a:layername ==# 'Bookmark'
        call popc#layer#bms#Pop('b')
    elseif a:layername ==# 'Workspace'
        call popc#layer#wks#Pop('w')
    endif
endfunction
" }}}

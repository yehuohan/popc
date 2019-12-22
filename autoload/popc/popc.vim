
" popc center unit.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()
let s:popc = {}
let s:layer = {
    \ 'name' : '',
    \ 'mode' : 0,
    \ 'maps' : {},
    \ 'bufs' : {'typ': v:t_list, 'fnc': '', 'txt': []},
    \ 'fltr' : {'chars': '', 'lines': [], 'index': []},
    \ 'info' : {
        \ 'useCm'      : 0,
        \ 'rootDir'    : '',
        \ 'lastIndex'  : 0,
        \ 'centerText' : '',
        \ 'userCmd'    : 0,
        \ }
    \ }
" {{{ s:layer format
"{
"   'name' : ''                 " layer name
"   'mode' : 0                  " layer mode(s:MODE)
"   'maps' : {}                 " all key-mappings of layer
"   'bufs' : {}                 " buffer text to pop
"   'fltr' : []                 " filter-data used by layer
"   'info' : {}                 " info-data used by layer
"}
" }}}
let s:MODE = {
    \ 'Normal' : 0,
    \ 'Filter' : 1,
    \ 'Help'   : 2,
    \ }


" SECTION: dictionary function {{{1

" FUNCTION: s:popc.addLayer(layer, ...) dict {{{
" @param(a:1): bind to common maps or not
function! s:popc.addLayer(layer, ...) dict
    let self[a:layer] = deepcopy(s:layer)
    let self[a:layer].name = a:layer
    let self[a:layer].mode = s:MODE.Normal
    call self[a:layer].setInfo('useCm', (a:0 > 0) ? a:1 : 1)
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
" @type: v:t_func or v:t_list
" @param(a:000): funcref for v:t_func or txt-list for v:t_list
function! s:layer.setBufs(type, ...) dict
    let self.bufs.typ = a:type
    if self.bufs.typ == v:t_func
        let self.bufs.fnc = a:1
    elseif self.bufs.typ == v:t_list
        let self.bufs.txt = a:1
    endif
endfunction
" }}}

" FUNCTION: s:layer.getBufs() dict {{{
function! s:layer.getBufs() dict
    if self.bufs.typ == v:t_func
        let l:txt = self.bufs.fnc()
    elseif self.bufs.typ == v:t_list
        let l:txt = self.bufs.txt
    endif

    " creat buffer text
    if empty(l:txt)
        call add(l:txt, '  Nothing to pop.')
    endif
    if self.mode == s:MODE.Help
        " append help information
        call insert(l:txt,  '  ~~~~~ ' . g:popc_version . ' (In layer ' . self.name . ') ~~~~~', 0)
        call insert(l:txt,  '', 1)
    endif

    return l:txt
endfunction
" }}}

" FUNCTION: s:layer.setFltr() dict {{{
function! s:layer.setFltr() dict
    let self.fltr.chars = ''
    let self.fltr.lines = self.getBufs()
    let self.fltr.index = let(self.fltr.lines)
endfunction
" }}}

" FUNCTION: s:layer.setInfo(key, value) dict {{{
function! s:layer.setInfo(key, value) dict
    let self.info[a:key] = a:value
endfunction
" }}}


" SECTION: functions {{{1

" FUNCTION: s:initLayers() {{{
function! s:initLayers()
    " common maps init
    if s:conf.useLayer.Buffer
        call popc#ui#AddComMap('popc#layer#buf#Pop', 'h')
    endif
    if s:conf.useLayer.Bookmark
        call popc#ui#AddComMap('popc#layer#bms#Pop', 'b')
    endif
    if s:conf.useLayer.Workspace
        call popc#ui#AddComMap('popc#layer#wks#Pop', 'w')
    endif
    for m in values(s:conf.layerComMaps)
        " {'layerName': [funcName, key]}
        call popc#ui#AddComMap(m[0], m[1])
    endfor

    " layer init
    if s:conf.useLayer.Buffer
        call popc#layer#buf#Init()
    endif
    if s:conf.useLayer.Bookmark
        call popc#layer#bms#Init()
    endif
    if s:conf.useLayer.Workspace
        call popc#layer#wks#Init()
    endif
    for l in values(s:conf.layerInit)
        " {'layerName': initFuncName}
        call function(l)()
    endfor
    "call popc#ui#AddComMap('popc#layer#exp#Pop', 'p')
    "call popc#layer#exp#Init()
endfunction
" }}}

" FUNCTION: popc#popc#Init() {{{
function! popc#popc#Init()
    call popc#init#Init()
    call popc#ui#Init()
    call s:initLayers()
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
        call popc#layer#buf#Pop('h', 0)
    elseif a:layername ==# 'Bookmark'
        call popc#layer#bms#Pop('b', 0)
    elseif a:layername ==# 'Workspace'
        call popc#layer#wks#Pop('w', 0)
    endif
endfunction
" }}}

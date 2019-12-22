
" popc center unit.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()
let s:popc = {}
let s:layer = {
    \ 'name' : '',
    \ 'mode' : 'normal',
    \ 'maps' : {},
    \ 'help' : [],
    \ 'bufs' : {'typ': v:t_list, 'fnc': '', 'txt': []},
    \ 'info' : {
        \ 'useCm'      : 0,
        \ 'rootDir'    : '',
        \ 'lastIndex'  : 0,
        \ 'centerText' : '',
        \ 'userCmd'    : 0,
        \ }
    \ }


" SECTION: dictionary function {{{1

" FUNCTION: s:popc.addLayer(layer, ...) dict {{{
" @param(a:1): bind to common maps or not
function! s:popc.addLayer(layer, ...) dict
    let self[a:layer] = deepcopy(s:layer)
    let self[a:layer].name = a:layer
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
" @keys: the map-key-list.
" @param(a:1): map-key help text
function! s:layer.addMaps(funcName, keys, ...) dict
    for k in a:keys
        let self.maps[k] = function(a:funcName, [k])
    endfor
    call add(self.help, [a:keys, (a:0 > 0) ? a:1 : ''])
endfunction
" }}}

" FUNCTION: s:layer.createHelp() dict {{{
function! s:layer.createHelp() dict
    if !empty(self.help) && type(self.help[0]) == v:t_string
        return self.help
    endif

    let l:text = [
        \ '  ~~~~~ ' . g:popc_version . ' (In layer ' . self.name . ') ~~~~~',
        \ '',
        \ ]

    " get max name width
    let l:max = 0
    for md in self.help
        let l:wid = strwidth(join(md[0], ','))
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    let l:max += 2

    " get context
    for md in self.help
        let l:line =  '  ' . join(md[0], ',')
        let l:line .= repeat(' ', l:max - strwidth(l:line)) . ' | '
        let l:line .= md[1]
        call add(l:text, l:line)
    endfor

    " append help for operation
    call add(l:text, '')
    let l:line = printf('  Up  : [%s]    Top   : [%s]    Page up  : [%s]',
                        \ join(s:conf.operationMaps['moveCursorUp']     , ','),
                        \ join(s:conf.operationMaps['moveCursorTop']    , ','),
                        \ join(s:conf.operationMaps['moveCursorPgUp']   , ',')
                        \ )
    call add(l:text, l:line)
    let l:line = printf('  Down: [%s]    Bottom: [%s]    Page down: [%s]    Quit: [%s]',
                        \ join(s:conf.operationMaps['moveCursorDown']   , ','),
                        \ join(s:conf.operationMaps['moveCursorBottom'] , ','),
                        \ join(s:conf.operationMaps['moveCursorPgDown'] , ','),
                        \ join(s:conf.operationMaps['quit']             , ',')
                        \ )
    call add(l:text, l:line)

    let self.help = l:text
    return self.help
endfunction
" }}}

" FUNCTION: s:layer.setBufs(type, val) dict {{{
" @type: v:t_func or v:t_list
" @val: funcref for v:t_func or txt-list for v:t_list
function! s:layer.setBufs(type, val) dict
    let self.bufs.typ = a:type
    if self.bufs.typ == v:t_func
        let self.bufs.fnc = a:val
    elseif self.bufs.typ == v:t_list
        let self.bufs.txt = a:val
    endif
endfunction
" }}}

" FUNCTION: s:layer.getBufs() dict {{{
function! s:layer.getBufs() dict
    if self.mode == 'help'
        return self.createHelp()
    else
        if self.bufs.typ == v:t_func
            let l:txt = self.bufs.fnc()
        elseif self.bufs.typ == v:t_list
            let l:txt = self.bufs.txt
        endif
        if empty(l:txt)
            call add(l:txt, '  Nothing to pop.')
        endif
        return l:txt
    endif
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
    return s:popc
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


" popc center unit.

" SECTION: variables {{{1

let s:popc = {}
let s:layer = {
    \ 'name' : '',
    \ 'mode' : 0,
    \ 'maps' : {},
    \ 'bufs' : {'cnt': 0, 'txt': ''},
    \ 'info' : {
        \ 'centerText' : '',
        \ 'lastIndex' : 1,
        \ 'cursorMovedCb' : '',
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

" FUNCTION: s:layer.setBufs(cnt, text) dict {{{
function! s:layer.setBufs(cnt, text) dict
    let self.bufs.cnt = a:cnt
    if (self.mode == s:MODE.Normal) || (self.mode == s:MODE.Search)
        if empty(a:text)
            let l:text = '  Nothing to pop.'
            while strwidth(l:text) < &columns
                let l:text .= ' '
            endwhile
        else
            let l:text = a:text
        endif
        let self.bufs.txt = l:text
    elseif self.mode == s:MODE.Help
        let l:line = '  --- ' . g:popc_version . ' (In layer ' . self.name . ') ---'
        while strwidth(l:line) < &columns
            let l:line .= '-'
        endwhile
        let self.bufs.txt = l:line . "\n"

        let self.bufs.txt .= repeat(' ', &columns) . "\n" . a:text . repeat(' ', &columns) . "\n"

        let l:line = '  --- Copyright (c) yehuohan<yehuohan@gmail.com, yehuohan@qq.com>'
        while strwidth(l:line) < &columns
            let l:line .= '-'
        endwhile
        let self.bufs.txt .= l:line

        let self.bufs.cnt += 4
    endif
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

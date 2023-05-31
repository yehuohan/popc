
" ui of windows interacting for popc.

" SECTION: variables {{{1

let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:ui = {
    \ 'maps' : {
        \ 'operation' : {},
        \ 'common'    : {},
        \ },
    \ 'api' : {
        \ 'create'  : '',
        \ 'destroy' : '',
        \ 'toggle'  : '',
        \ 'operate' : '',
        \ 'getval'  : '',
        \ }
    \ }


" SETCION: ui functions {{{1

" FUNCTION: popc#ui#Init() {{{
function! popc#ui#Init()
    call popc#stl#Init()

    " set api
    if s:conf.useFloatingWin && !has('nvim') && v:version >= 802 " exists('+popupwin')
        call extend(s:ui.api, popc#ui#popup#Init(), 'force')
        highlight default link PopupSelected PopcSel
        call prop_type_add('PopcSlLabel', {'highlight': 'PopcSlLabel'})
        call prop_type_add('PopcSlSep',   {'highlight': 'PopcSlSep'})
        call prop_type_add('PopcSl',      {'highlight': 'PopcSl'})
    elseif s:conf.useFloatingWin && has('nvim-0.4.2')
        call extend(s:ui.api, popc#ui#float#Init(), 'force')
    else
        call extend(s:ui.api, popc#ui#default#Init(), 'force')
    endif

    " set operation
    for k in s:conf.operationMaps.moveCursorDown
        let s:ui.maps.operation[k] = funcref('s:ui.api.operate', ['down'])
    endfor
    for k in s:conf.operationMaps.moveCursorUp
        let s:ui.maps.operation[k] = funcref('s:ui.api.operate', ['up'])
    endfor
    for k in s:conf.operationMaps.moveCursorTop
        let s:ui.maps.operation[k] = funcref('s:ui.api.operate', ['top'])
    endfor
    for k in s:conf.operationMaps.moveCursorBottom
        let s:ui.maps.operation[k] = funcref('s:ui.api.operate', ['bottom'])
    endfor
    for k in s:conf.operationMaps.moveCursorPgDown
        let s:ui.maps.operation[k] = funcref('s:ui.api.operate', ['pgdown'])
    endfor
    for k in s:conf.operationMaps.moveCursorPgUp
        let s:ui.maps.operation[k] = funcref('s:ui.api.operate', ['pgup'])
    endfor
    for k in s:conf.operationMaps.help
        let s:ui.maps.operation[k] = funcref('s:switchMode', ['help'])
    endfor
    for k in s:conf.operationMaps.back
        let s:ui.maps.operation[k] = funcref('s:switchMode', [v:null])
    endfor
    for k in s:conf.operationMaps.quit
        let s:ui.maps.operation[k] = funcref('s:ui.api.destroy')
    endfor
endfunction
" }}}

" FUNCTION: popc#ui#Create(layer) {{{
function! popc#ui#Create(layer)
    let s:lyr = s:popc[a:layer]
    call s:switchMode('normal')
endfunction
" }}}

" FUNCTION: s:switchMode(mode) {{{
" @param mode: 'normal' to display layer's text
"             'help' to display help-text
"             v:null to back to normal mode or destroy display
function! s:switchMode(mode)
    if a:mode == v:null
        if s:lyr.mode !=# 'normal'
            call s:switchMode('normal')
        else
            if type(get(s:lyr.info.events, 'onQuit')) == v:t_func
                call s:lyr.info.events.onQuit()
            endif
            call s:ui.api.destroy()
        endif
    else
        let s:lyr.mode = a:mode
        call s:ui.api.create(s:lyr.name)
    endif
endfunction
" }}}

" FUNCTION: popc#ui#Destroy() {{{
function! popc#ui#Destroy()
    call s:ui.api.destroy()
endfunction
" }}}

" FUNCTION: popc#ui#Toggle(state) {{{
" @param state: 0 for toggle out Popc temporarily to execute command in recover window
"               1 fot toggle back to Popc
function! popc#ui#Toggle(state)
    call s:ui.api.toggle(a:state)
endfunction
" }}}

" FUNCTION: popc#ui#GetVal(key) {{{
function! popc#ui#GetVal(key)
    return s:ui.api.getval(a:key)
endfunction
" }}}

" FUNCTION: popc#ui#Input(prompt, [text, completion]) {{{
" global input funtion interface for ui of popc.
function! popc#ui#Input(prompt, ...)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:prompt, '\M\n', '\n   ', 'g')
    redraw
    if has('nvim')
        let l:opts = {
            \ 'prompt': l:msg,
            \ 'default': a:0 >= 1 ? a:1 : '',
            \ 'cancelreturn': v:null,
            \ }
        if a:0 >= 2
            let l:opts['completion'] = a:2
        endif
        let l:ret = input(l:opts)
        " v:null returned by input() would be string type, so check with v:null before real return
        return l:ret == v:null ? v:null : l:ret
    else
        " BUG: we can NOT input '' in vim because pressing <ESC> will return '' too
        let l:ret = (a:0 == 0) ? input(l:msg) :
                  \ (a:0 == 1) ? input(l:msg, a:1) :
                  \              input(l:msg, a:1, a:2)
        return l:ret == '' ? v:null : l:ret
    endif
endfunction
" }}}

" FUNCTION: popc#ui#Confirm(prompt, [args]) {{{
" global confirm funtion interface for ui of popc.
" input 'y' for 'Yes', and anythin else for 'No'.
function! popc#ui#Confirm(prompt, ...)
    let l:msg = (a:0 > 0) ? call('printf', [a:prompt] + a:000) : a:prompt
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(l:msg, '\M\n', '\n   ', 'g') . ' (yN): '
    redraw
    return input(l:msg) ==# 'y'
endfunction
" }}}

" FUNCTION: popc#ui#Msg(msg, [args]) {{{
" global message function interface for ui of popc.
function! popc#ui#Msg(msg, ...)
    redraw
    let l:msg = (a:0 > 0) ? call('printf', [a:msg] + a:000) : a:msg
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(l:msg, '\M\n', '\n   ', 'g')
    if has('nvim')
        call v:lua.vim.notify(l:msg, luaeval('vim.log.levels.INFO'))
    else
        echo l:msg
    endif
endfunction
" }}}

" FUNCTION: popc#ui#Trigger(key, index) {{{
function! popc#ui#Trigger(key, index)
    " key response priority： operation > common > layer > default
    if has_key(s:ui.maps.operation, a:key)
        call s:ui.maps.operation[a:key]()
        if (type(get(s:lyr.info.events, 'onQuit')) == v:t_func) && (index(s:conf.operationMaps.quit, a:key) >= 0)
            call s:lyr.info.events.onQuit()
        endif
    elseif s:lyr.info.bindCom && has_key(s:ui.maps.common, a:key)
        call s:ui.maps.common[a:key](a:index)
    elseif has_key(s:lyr.maps, a:key) && s:lyr.mode == 'normal'
        call s:lyr.maps[a:key](a:index)
    else
        call popc#ui#Msg('Key ''%s'' doesn''t work in layer ''%s''.', a:key, s:lyr.name)
    endif
endfunction
" }}}

" FUNCTION: popc#ui#AddComMap(funcName, key) {{{
function! popc#ui#AddComMap(funcName, key)
    let s:ui.maps.common[a:key] = function(a:funcName, [a:key])
endfunction
" }}}

" FUNCTION: popc#ui#CurrentLayer() {{{
" current layer displayed to ui
function! popc#ui#CurrentLayer()
    return s:lyr
endfunction
" }}}

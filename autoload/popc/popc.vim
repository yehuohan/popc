
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
        \ 'bindCom'    : 0,
        \ 'fnCom'      : [],
        \ 'fnPop'      : v:null,
        \ 'lastIndex'  : 0,
        \ 'centerText' : '',
        \ 'events'     : {
            \ 'onUiIndexChanged' : v:null,
            \ },
        \ },
    \ }


" SECTION: dictionary function {{{1

" FUNCTION: s:popc.addLayer(layer, ...) dict {{{
" @param layer: layer name as index of s:popc
" @param(a:1): v:t_number or v:t_bool for value decide bind to common maps or not
"              v:t_dict for info value with keys bellow
"   - bindCom: the `layer` should response to common mappings or not
"   - fnCom: common mapping of the `layer` in format ['funcName', 'key'], which used by `popc#ui#AddComMap`
"   - fnPop: pop function of the `layer` in type v:t_func, which used by `popc#popc#Popc`
"   - lastIndex: last index of item of `layer`
"   - centerText: text about `layer` to display
"   - events: layer events callback functions
"       - onUiIndexChanged(index): ui index (just the lastIndex) changed
function! s:popc.addLayer(layer, ...) dict
    let self[a:layer] = deepcopy(s:layer)
    let self[a:layer].name = a:layer
    if a:0 > 0
        if type(a:1) == v:t_number || type(a:1) == v:t_bool
            call self[a:layer].setInfo('bindCom', a:1)
        elseif type(a:1) == v:t_dict
            call extend(self[a:layer].info, a:1, 'force')
        endif
    endif
    if !empty(self[a:layer].info.fnCom)
        call popc#ui#AddComMap(self[a:layer].info.fnCom[0], self[a:layer].info.fnCom[1])
    endif
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

" FUNCTION: s:layer.addMaps(funcName, keys, [help-text]) dict {{{
" @funcName: function(key, index) format with map-key and selected index
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

    " get help-operation keys
    let l:optkeys = [
        \ join(s:conf.operationMaps['moveCursorUp']  , ',') .. '/' .. join(s:conf.operationMaps['moveCursorDown']  , ','),
        \ join(s:conf.operationMaps['moveCursorPgUp'], ',') .. '/' .. join(s:conf.operationMaps['moveCursorPgDown'], ','),
        \ join(s:conf.operationMaps['moveCursorTop'] , ',') .. '/' .. join(s:conf.operationMaps['moveCursorBottom'], ','),
        \ join(s:conf.operationMaps['back']          , ',') .. '/' .. join(s:conf.operationMaps['quit']            , ','),
        \ join(s:conf.operationMaps['help']          , ','),
        \ ]
    let l:optmax = max(map(copy(l:optkeys), {-> len(v:val)}))

    " get line-format
    let l:max = 0
    for md in self.help
        let l:wid = strwidth(join(md[0], ','))
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    for md in values(s:conf.operationMaps)
        let l:wid = strwidth(join(md, ','))
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    let l:max = (l:optmax > l:max) ? l:optmax : l:max
    let l:fmt = printf('  %%-%ds | %%s', l:max)

    " add help-context
    let l:text = []
    for md in self.help
        call add(l:text, printf(l:fmt, join(md[0], ','), md[1]))
    endfor

    " add help-operation
    call add(l:text, printf(l:fmt, l:optkeys[0], 'Operation up/down'))
    call add(l:text, printf(l:fmt, l:optkeys[1], 'Operation page up/down'))
    call add(l:text, printf(l:fmt, l:optkeys[2], 'Operation top/bottom'))
    call add(l:text, printf(l:fmt, l:optkeys[3], 'Operation back/quit'))
    call add(l:text, printf(l:fmt, l:optkeys[4], 'Operation help'))

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
" see s:layer.addLayer
function! s:layer.setInfo(key, value) dict
    let self.info[a:key] = a:value
endfunction
" }}}


" SECTION: functions {{{1

" FUNCTION: popc#popc#Init() {{{
function! popc#popc#Init()
    call popc#init#Init()
    call popc#ui#Init()

    " init layers
    "call popc#layer#exp#Init()
    if s:conf.useLayer.Buffer
        call popc#layer#buf#Init()
    endif
    if s:conf.useLayer.Bookmark
        call popc#layer#bms#Init()
    endif
    if s:conf.useLayer.Workspace
        call popc#layer#wks#Init()
    endif
endfunction
" }}}

" FUNCTION: popc#popc#GetPopc() {{{
function! popc#popc#GetPopc()
    return s:popc
endfunction
" }}}

" FUNCTION: popc#popc#GetLayerList(ArgLead, CmdLine, CursorPos) {{{
function! popc#popc#GetLayerList(ArgLead, CmdLine, CursorPos)
    return filter(keys(s:popc),
                \ {key, val -> val !=# 'addLayer' && val !=# 'removeLayer' && val =~# a:ArgLead})
endfunction
" }}}

" FUNCTION: popc#popc#Popc(layername) {{{
function! popc#popc#Popc(layername)
    if has_key(s:popc, a:layername)
        if type(s:popc[a:layername].info.fnPop) != v:t_func
            call popc#ui#Msg('Layer ''%s'' doesn''t provide fnPop.', a:layername)
        else
            call s:popc[a:layername].info.fnPop()
        endif
    else
        call popc#ui#Msg('Popc doest''t contain layer ''%s''.', a:layername)
    endif
endfunction
" }}}

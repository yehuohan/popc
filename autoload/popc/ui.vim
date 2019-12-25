
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
    \ 'funcs' : {
        \ 'create'  : '',
        \ 'destroy' : '',
        \ 'toggle'  : '',
        \ 'operate' : '',
        \ 'getval'  : '',
        \ }
    \ }
let s:hi = {
    \ 'text'        : '',
    \ 'selected'    : '',
    \ 'lineTxt'     : '',
    \ 'lineSel'     : '',
    \ 'modifiedTxt' : '',
    \ 'modifiedSel' : '',
    \ 'labelTxt'    : '',
    \ 'blankTxt'    : '',
    \ }


" SETCION: ui functions {{{1

" FUNCTION: popc#ui#Init() {{{
function! popc#ui#Init()
    " set funcs
    if s:conf.useFloatingWin && !has('nvim') && v:version >= 802 " exists('+popupwin')
        call extend(s:ui.funcs, popc#ui#popup#Init(), 'force')
    elseif s:conf.useFloatingWin && has('nvim-0.4.3') && 0
        call extend(s:ui.funcs, popc#ui#float#Init(), 'force')
    else
        call extend(s:ui.funcs, popc#ui#default#Init(), 'force')
    endif

    " set operation
    for k in s:conf.operationMaps.moveCursorDown
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.operate', ['down'])
    endfor
    for k in s:conf.operationMaps.moveCursorUp
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.operate', ['up'])
    endfor
    for k in s:conf.operationMaps.moveCursorTop
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.operate', ['top'])
    endfor
    for k in s:conf.operationMaps.moveCursorBottom
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.operate', ['bottom'])
    endfor
    for k in s:conf.operationMaps.moveCursorPgDown
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.operate', ['pgdown'])
    endfor
    for k in s:conf.operationMaps.moveCursorPgUp
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.operate', ['pgup'])
    endfor
    for k in s:conf.operationMaps.help
        let s:ui.maps.operation[k] = funcref('s:createHelp')
    endfor
    for k in s:conf.operationMaps.quit
        let s:ui.maps.operation[k] = funcref('s:ui.funcs.destroy')
    endfor

    " set highlight
    if s:conf.useTabline || s:conf.useStatusline
        call popc#ui#InitHi(s:conf.highlight)
        augroup PopcUiInit
            autocmd!
            autocmd ColorScheme * call popc#ui#InitHi(s:hi)
        augroup END
    endif
    if s:conf.useTabline
        set showtabline=2
        silent execute 'set tabline=%!' . s:conf.tabLine
    endif
endfunction
" }}}

" FUNCTION: popc#ui#Create(layer) {{{
function! popc#ui#Create(layer)
    let s:lyr = s:popc[a:layer]
    let s:lyr.mode = 'normal'
    call s:ui.funcs.create(a:layer)
endfunction
" }}}

" FUNCTION: s:createHelp() {{{
function! s:createHelp()
    let s:lyr.mode = 'help'
    call s:ui.funcs.create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#ui#Destroy() {{{
function! popc#ui#Destroy()
    call s:ui.funcs.destroy()
endfunction
" }}}

" FUNCTION: popc#ui#Toggle(state) {{{
" @param state: 0 for toggle out Popc temporarily to execute command in recover window
"               1 fot toggle back to Popc
function! popc#ui#Toggle(state)
    call s:ui.funcs.toggle(a:state)
endfunction
" }}}

" FUNCTION: popc#ui#GetVal(key) {{{
function! popc#ui#GetVal(key)
    return s:ui.funcs.getval(a:key)
endfunction
" }}}

" FUNCTION: popc#ui#Input(prompt, ...) {{{
" global input funtion interface for ui of popc.
function! popc#ui#Input(prompt, ...)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:prompt, '\M\n', '\n   ', 'g')
    redraw
    return a:0 == 0 ? input(l:msg) :
         \ a:0 == 1 ? input(l:msg, a:1) :
         \            input(l:msg, a:1, a:2)
endfunction
" }}}

" FUNCTION: popc#ui#Confirm(prompt) {{{
" global confirm funtion interface for ui of popc.
" input 'y' for 'Yes', and anythin else for 'No'.
function! popc#ui#Confirm(prompt)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:prompt, '\M\n', '\n   ', 'g') . ' (yN): '
    redraw
    return input(l:msg) ==# 'y'
endfunction
" }}}

" FUNCTION: popc#ui#Msg(msg) {{{
" global message function interface for ui of popc.
function! popc#ui#Msg(msg)
    redraw
    echo ' ' . s:conf.symbols.Popc . ' ' . substitute(a:msg, '\M\n', '\n   ', 'g')
endfunction
" }}}

" FUNCTION: popc#ui#Trigger(key, index) {{{
function! popc#ui#Trigger(key, index)
    " key response priority： operation > common > layer > default
    if has_key(s:ui.maps.operation, a:key)
        call s:ui.maps.operation[a:key]()
    elseif s:lyr.info.useCm && has_key(s:ui.maps.common, a:key)
        call s:ui.maps.common[a:key](a:index)
    elseif has_key(s:lyr.maps, a:key) && s:lyr.mode == 'normal'
        call s:lyr.maps[a:key](a:index)
    else
        call popc#ui#Msg('Key ''' . a:key . ''' doesn''t work in layer ''' . s:lyr.name . '''.')
    endif
endfunction
" }}}

" FUNCTION: popc#ui#AddComMap(funcName, key) {{{
function! popc#ui#AddComMap(funcName, key)
    let s:ui.maps.common[a:key] = function(a:funcName, [a:key])
endfunction
" }}}


" SETCION: statusline and tabline {{{1

" FUNCTION: s:createHiSep() {{{
function! s:createHiSep(hifg, hibg, hinew)
    let r = range(4)
    let r[0] = synIDattr(synIDtrans(hlID(a:hifg)), 'reverse', 'gui') ? 'fg' : 'bg'
    let r[1] = synIDattr(synIDtrans(hlID(a:hibg)), 'reverse', 'gui') ? 'fg' : 'bg'
    let r[2] = synIDattr(synIDtrans(hlID(a:hifg)), 'reverse', 'cterm') ? 'fg' : 'bg'
    let r[3] = synIDattr(synIDtrans(hlID(a:hibg)), 'reverse', 'cterm') ? 'fg' : 'bg'
    let c = range(4)
    let c[0] = synIDattr(synIDtrans(hlID(a:hifg)), r[0], 'gui')      " separator guifg
    let c[1] = synIDattr(synIDtrans(hlID(a:hibg)), r[1], 'gui')      " separator guibf
    let c[2] = synIDattr(synIDtrans(hlID(a:hifg)), r[2], 'cterm')    " separator ctermfg
    let c[3] = synIDattr(synIDtrans(hlID(a:hibg)), r[3], 'cterm')    " separator ctrembf
    let c[0] = empty(c[0]) ? 'NONE' : c[0]
    let c[1] = empty(c[1]) ? 'NONE' : c[1]
    let c[2] = empty(c[2]) ? 'NONE' : c[2]
    let c[3] = empty(c[3]) ? 'NONE' : c[3]
    execute printf('highlight %s guifg=%s guibg=%s ctermfg=%s ctermbg=%s', a:hinew, c[0], c[1], c[2], c[3])
    return a:hinew
endfunction
" }}}

" FUNCTION: popc#ui#InitHi(hi) {{{
function! popc#ui#InitHi(hi)
    let s:hi.text        = a:hi.text
    let s:hi.selected    = a:hi.selected
    let s:hi.lineTxt     = !empty(a:hi.lineTxt)     ? a:hi.lineTxt     : a:hi.text
    let s:hi.lineSel     = !empty(a:hi.lineSel)     ? a:hi.lineSel     : a:hi.selected
    let s:hi.labelTxt    = !empty(a:hi.labelTxt)    ? a:hi.labelTxt    : a:hi.selected
    let s:hi.blankTxt    = !empty(a:hi.blankTxt)    ? a:hi.blankTxt    : a:hi.text
    let s:hi.modifiedSel = !empty(a:hi.modifiedSel) ? a:hi.modifiedSel : a:hi.selected
    let s:hi.modifiedTxt = !empty(a:hi.modifiedTxt) ? a:hi.modifiedTxt :
                           \ s:createHiSep(s:hi.modifiedSel, s:hi.text, 'PopcModifiedTxt')
    " menu
    execute printf('highlight default link PopcText     %s', s:hi.text)
    execute printf('highlight default link PopcSel      %s', s:hi.selected)

    " statusline
    execute printf('highlight default link PopcSlLabel  %s', s:hi.labelTxt)
    execute printf('highlight default link PopcSl       %s', s:hi.lineTxt)
    call s:createHiSep('PopcSlLabel', 'PopcSl', 'PopcSlSep')

    " tabline
    execute printf('highlight default link PopcTlLabel  %s', s:hi.labelTxt)
    execute printf('highlight default link PopcTl       %s', s:hi.lineTxt)
    execute printf('highlight default link PopcTlSel    %s', s:hi.lineSel)
    execute printf('highlight default link PopcTlM      %s', s:hi.modifiedTxt)
    execute printf('highlight default link PopcTlMSel   %s', s:hi.modifiedSel)
    execute printf('highlight default link PopcTlBlank  %s', s:hi.blankTxt)
    " lable -> separator -> title
    call s:createHiSep('PopcTlLabel', 'PopcTl'     , 'PopcTlSepL0')
    call s:createHiSep('PopcTlLabel', 'PopcTlM'    , 'PopcTlSepL1')
    call s:createHiSep('PopcTlLabel', 'PopcTlSel'  , 'PopcTlSepL2')
    call s:createHiSep('PopcTlLabel', 'PopcTlMsel' , 'PopcTlSepL3')
    call s:createHiSep('PopcTlLabel', 'PopcTlBlank', 'PopcTlSepL4')
    " title
    "       sel,mod = 0,0 = 0
    "       sel,mod = 0,1 = 1
    "       sel,mod = 1,0 = 2
    "       sel,mod = 1,1 = 3
    highlight default link PopcTl0  PopcTl
    highlight default link PopcTl1  PopcTlM
    highlight default link PopcTl2  PopcTlSel
    highlight default link PopcTl3  PopcTlMSel
    " title -> separator -> title
    "       (sel,mod) -> (sel,mod) = (0,0) -> (0,0) = 0, 0 = 0
    "       (sel,mod) -> (sel,mod) = (0,0) -> (0,1) = 0, 1 = 1
    "       (sel,mod) -> (sel,mod) = (0,0) -> (1,0) = 0, 2 = 2
    "       (sel,mod) -> (sel,mod) = (0,0) -> (1,1) = 0, 3 = 3
    "       (sel,mod) -> (sel,mod) = (0,1) -> (0,0) = 4, 0 = 4
    "       (sel,mod) -> (sel,mod) = (0,1) -> (0,1) = 4, 1 = 5
    "       (sel,mod) -> (sel,mod) = (0,1) -> (1,0) = 4, 2 = 6
    "       (sel,mod) -> (sel,mod) = (0,1) -> (1,1) = 4, 3 = 7
    "       (sel,mod) -> (sel,mod) = (1,0) -> (0,0) = 8, 0 = 8
    "       (sel,mod) -> (sel,mod) = (1,0) -> (0,1) = 8, 1 = 9
    "       (sel,mod) -> (sel,mod) = (1,1) -> (0,0) = 12, 0 = 12
    "       (sel,mod) -> (sel,mod) = (1,1) -> (0,1) = 12, 1 = 13
    highlight default link                          PopcTlSep0 PopcTl
    highlight default link                          PopcTlSep1 PopcTl
    call s:createHiSep('PopcTl'    , 'PopcTlSel' , 'PopcTlSep2')
    call s:createHiSep('PopcTl'    , 'PopcTlMSel', 'PopcTlSep3')
    highlight default link                          PopcTlSep4 PopcTl
    highlight default link                          PopcTlSep5 PopcTl
    call s:createHiSep('PopcTlM'   , 'PopcTlSel' , 'PopcTlSep6')
    call s:createHiSep('PopcTlM'   , 'PopcTlMSel', 'PopcTlSep7')
    call s:createHiSep('PopcTlSel' , 'PopcTl'    , 'PopcTlSep8')
    call s:createHiSep('PopcTlSel' , 'PopcTlM'   , 'PopcTlSep9')
    call s:createHiSep('PopcTlMSel', 'PopcTl'    , 'PopcTlSep12')
    call s:createHiSep('PopcTlMSel', 'PopcTlM'   , 'PopcTlSep13')
    " title -> separator -> blank
    call s:createHiSep('PopcTl'    , 'PopcTlBlank', 'PopcTlSepB0')
    call s:createHiSep('PopcTlM'   , 'PopcTlBlank', 'PopcTlSepB1')
    call s:createHiSep('PopcTlSel' , 'PopcTlBlank', 'PopcTlSepB2')
    call s:createHiSep('PopcTlMSel', 'PopcTlBlank', 'PopcTlSepB3')
endfunction
" }}}

" FUNCTION: popc#ui#GetStatusLineSegments(seg) abort {{{
function! popc#ui#GetStatusLineSegments(seg) abort
    let l:segs = []

    if a:seg =~? '[al]'
        let l:left = 'Popc'
        call add(l:segs, l:left)
    endif

    if a:seg =~? '[ac]'
        let l:center = s:lyr.info.centerText
        call add(l:segs, l:center)
    endif

    if a:seg =~? '[ar]'
        let l:rank = '[' . string(len(s:lyr.bufs.txt)) . ']' . popc#utils#Num2RankStr(line('.'))
        let l:right = l:rank . ' ' . s:conf.symbols.Rank . ' '. s:lyr.name
        call add(l:segs, l:right)
    endif

    return l:segs
endfunction
" }}}

" FUNCTION: popc#ui#StatusLine() abort {{{
function! popc#ui#StatusLine() abort
    if s:conf.usePowerFont
        let l:spl  = s:conf.separator.left
        let l:spr  = s:conf.separator.right
    else
        let l:spl  = ''
        let l:spr  = ''
    endif

    let [l:left, l:center, l:right] = popc#ui#GetStatusLineSegments('a')
    let l:value  = ('%#PopcSlLabel# ' . l:left . ' ') . ('%#PopcSlSep#' . l:spl)
    let l:value .= ('%#PopcSl# ' . l:center . ' ')
    let l:value .= '%='
    let l:value .= ('%#PopcSlSep#' . l:spr) . ('%#PopcSlLabel# ' . l:right . ' ')
    return l:value
endfunction
" }}}

" FUNCTION: popc#ui#TabLine() abort {{{
function! popc#ui#TabLine() abort
    if s:conf.usePowerFont
        let l:spl  = s:conf.separator.left
        let l:spr  = s:conf.separator.right
        let l:sspl = s:conf.subSeparator.left
        let l:sspr = s:conf.subSeparator.right
    else
        let l:spl  = ''
        let l:spr  = ''
        let l:sspl = '|'
        let l:sspr = '|'
    endif

    " left {{{
    if empty(s:conf.tabLineLayout.left)
        let l:lhs = '%#PopcTlBlank#%='
    else
        if s:conf.tabLineLayout.left ==# 'tab'
            let l:list = popc#layer#buf#GetTabs()
            let l:ch = 'T'
        else
            let l:list = popc#layer#buf#GetBufs(tabpagenr())
            let l:ch = 'B'
        endif
        let l:len = len(l:list)
        " lable -> separator -> title
        let l:id = (l:len > 0) ? string(l:list[0].selected*2 + l:list[0].modified) : '4'
        let l:lhs = '%#PopcTlLabel#' . l:ch . '%#PopcTlSepL' . l:id . '#' . l:spl
        for k in range(l:len)
            let i = l:list[k]
            " title
            let l:id = string(i.selected*2 + i.modified)
            let l:hi = '%#PopcTl' . l:id . '#'
            if (k+1 < l:len)
                " title -> separator -> title
                let ii = l:list[k+1]
                let l:id = string(i.selected*8 + i.modified*4 + ii.selected*2 + ii.modified)
                let l:hisep = '%#PopcTlSep' . l:id . '#'
                let l:sep = (i.selected || ii.selected) ? l:spl : l:sspl
            else
                " title -> separator -> blank
                let l:id = string(i.selected*2 + i.modified)
                let l:hisep = '%#PopcTlSepB' . l:id . '#'
                let l:sep = l:spl
            endif
            let l:lhs .= (l:hi) . ('%'.(i.index).'T ' .(i.title).(i.modified?'+':' '). '%T')
            let l:lhs .= l:hisep . l:sep
        endfor
        let l:lhs .= '%#PopcTlBlank#%='
    endif
    " }}}
    " right {{{
    if empty(s:conf.tabLineLayout.right)
        let l:rhs = ''
    else
        if s:conf.tabLineLayout.right ==# 'buffer'
            let l:list = popc#layer#buf#GetBufs(tabpagenr())
            let l:ch = 'B'
        else
            let l:list = popc#layer#buf#GetTabs()
            let l:ch = 'T'
        endif
        let l:len = len(l:list)
        let l:rhs = ''
        for k in range(l:len)
            let i = l:list[k]
            " title
            let l:id = string(i.selected*2 + i.modified)
            let l:hi = '%#PopcTl' . l:id . '#'
            if k == 0
                " blank -> separator -> title
                let l:hisep = '%#PopcTlSepB' . l:id . '#'
                let l:sep = l:spr
            else
                " title -> separator -> title
                let ii = l:list[k-1]
                let l:id = string(i.selected*8 + i.modified*4 + ii.selected*2 + ii.modified)
                let l:hisep = '%#PopcTlSep' . l:id . '#'
                let l:sep = (i.selected || ii.selected) ? l:spr : l:sspr
            endif
            let l:rhs .= l:hisep . l:sep
            let l:rhs .= (l:hi) . ('%'.(i.index).'T ' .(i.title).(i.modified?'+':' '). '%T')
        endfor
        " title -> separator -> lable
        let l:id = (l:len > 0) ? string(l:list[-1].selected*2 + l:list[-1].modified) : '4'
        let l:rhs .= '%#PopcTlSepL' . l:id . '#' . l:spr
        let l:rhs .= '%#PopcTlLabel#' . l:ch
    endif
    " }}}

    return l:lhs . l:rhs
endfunction
" }}}

" FUNCTION: popc#ui#TabLineSetLayout(lhs, rhs) abort {{{
function! popc#ui#TabLineSetLayout(lhs, rhs) abort
    let s:conf.tabLineLayout.left = a:lhs
    let s:conf.tabLineLayout.right = a:rhs
    if empty(a:lhs) && empty(a:rhs)
        let s:conf.useTabline = 0
        set showtabline=0
    else
        let s:conf.useTabline = 1
        set showtabline=2
    endif
    if s:conf.useTabline
        silent execute 'set tabline=%!' . s:conf.tabLine
    endif
endfunction
" }}}

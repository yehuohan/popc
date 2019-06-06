
" ui of windows interacting for popc.

" SECTION: variables {{{1

let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}              " current layer
let s:hi = {
    \ 'text'        : 'PmenuSbar',
    \ 'selected'    : 'PmenuSel',
    \ 'label'       : 'IncSearch',
    \ 'modifiedTxt' : '',
    \ 'modifiedSel' : 'DiffChange',
    \ 'blankTxt'    : 'Normal',
    \ }
let s:recover = {
    \ 'winnr' : 0,
    \ 'file'  : '',
    \ 'timeoutlen' : 0,
    \ }

" SETCION: functions {{{1

" FUNCTION: popc#ui#Init() {{{
function! popc#ui#Init()
    highlight default link PopcText PmenuSbar
    highlight default link PopcSel  PmenuSel

    " set highlight
    if s:conf.useTabline || s:conf.useStatusline
        call popc#ui#InitHi(s:hi)
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
    if exists('s:flag') && s:flag
        if s:lyr.name ==# a:layer
            call s:dispBuffer()     " just only re-display buffer
            return
        else
            call popc#ui#Destroy()
        endif
    endif
    let s:flag = 1
    let s:lyr = s:popc[a:layer]

    call s:saveRecover()

    silent execute 'noautocmd botright pedit popc'
    " before the line below, all command is executed in recover-buffer
    " after the line below, all command is executed in Popc-buffer
    silent execute 'noautocmd wincmd P'

    call s:setBuffer()
    call s:dispBuffer()
    if s:lyr.mode == s:MODE.Search
        set guicursor-=n:block-PopcSel-blinkon0
        call popc#search#Search(a:layer)
        set guicursor+=n:block-PopcSel-blinkon0
        call popc#ui#Destroy()
    endif
endfunction
" }}}

" FUNCTION: popc#ui#Destroy() {{{
function! popc#ui#Destroy()
    if !(exists('s:flag') && s:flag)
        return
    endif

    " recover window
    if &timeoutlen
        silent execute 'set timeoutlen=' . s:recover.timeoutlen
    endif
    set guicursor-=n:block-PopcSel-blinkon0
    bwipeout
    " before the line below, all command is executed in Popc-buffer
    " after the line below, all command is executed in recover-buffer
    if s:recover.winnr <= winnr('$')
        silent execute 'noautocmd ' . s:recover.winnr . 'wincmd w'
    endif

    let s:flag = 0
endfunction
" }}}

" FUNCTION: popc#ui#Toggle(state) {{{
function! popc#ui#Toggle(state)
    " 0 for toggle out Popc temporarily to execute command in recover window
    " 1 fot toggle back to Popc
    if exists('s:flag') && s:flag
        " use noautocmd to avoid BufLeave of preview window
        silent execute a:state ?
                    \ ('noautocmd wincmd P') :
                    \ ('noautocmd ' . s:recover.winnr . 'wincmd w')
    endif
endfunction
" }}}

" FUNCTION: s:setBuffer() {{{
function! s:setBuffer()
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=delete
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal nowrap
    setlocal nonumber
    if exists('+relativenumber')
        setlocal norelativenumber
    endif
    setlocal nocursorcolumn
    setlocal nocursorline
    setlocal nofoldenable
    setlocal foldcolumn=1
    setlocal nospell
    setlocal nolist
    setlocal scrolloff=0
    setlocal colorcolumn=
    setlocal filetype=Popc
    if &timeout
        set timeoutlen=10
    endif

    " set root path
    if !empty(s:lyr.info.rootDir)
        silent execute 'lcd ' . s:lyr.info.rootDir
    endif

    " set auto-command
    augroup PopcUiSetBuffer
        autocmd!
        autocmd BufLeave <buffer> call popc#ui#Destroy()
    augroup END

    " set up syntax highlighting
    if has('syntax')
        syntax clear
        syntax match PopcText /  .*/
        syntax match PopcSel /> .*/hs=s+1
    endif
    set guicursor+=n:block-PopcSel-blinkon0

    " set statusline
    if s:conf.useStatusline
        silent execute 'let &l:statusline=' . s:conf.statusLine
        silent execute 'setlocal statusline=%!' . s:conf.statusLine
    endif

    " create maps
    call popc#key#CreateKeymaps()
endfunction
" }}}

" FUNCTION: s:dispBuffer() {{{
function! s:dispBuffer()
    " set buffer text and maps
    let [b:size, b:text] = s:lyr.getBufs()
    call popc#key#SetMaps(s:lyr)

    " resize buffer
    let l:max = (s:conf.maxHeight > 0) ? s:conf.maxHeight : (&lines / 3)
    silent execute 'resize' ((b:size > l:max) ? l:max : b:size)

    " put buffer
    setlocal modifiable
    silent normal! ggdG
    silent put! = b:text
    silent normal! GkJgg
    setlocal nomodifiable
    call popc#ui#MoveBar('num', s:lyr.info.lastIndex + 1)
endfunction
" }}}

" FUNCTION: popc#ui#MoveBar(dir, ...) {{{
function! popc#ui#MoveBar(dir, ...)
    setlocal modifiable
    let l:oldLine = line('.')
    if b:size < 1
        return
    endif

    if a:dir ==# 'down'
        let l:pos = line('.') + 1
    elseif a:dir ==# 'up'
        let l:pos = line('.') - 1
    elseif a:dir ==# 'top'
        let l:pos = 1
    elseif a:dir ==# 'bottom'
        let l:pos = line('$')
    elseif a:dir ==# 'pgup'
        let l:pos = line('.') - winheight(0)
        if l:pos < 1
            let l:pos = 1
        endif
    elseif a:dir ==# 'pgdown'
        let l:pos = line('.') + winheight(0)
        if l:pos > line('$')
            let l:pos = line('$')
        endif
    elseif a:dir ==# 'num'
        let l:pos = (a:0 >= 1) ? a:1 : 0
    endif

    if l:pos < 1
        call cursor(b:size - l:pos, 1)
    elseif l:pos > b:size
        call cursor(l:pos - b:size, 1)
    else
        call cursor(l:pos, 1)
    endif

    " mark index line with '>'
    let l:newLine = line('.')
    if l:oldLine != l:newLine
        call setline(l:oldLine, ' ' . strpart(getline(l:oldLine), 1))
    endif
    call setline(l:newLine, '>' . strpart(getline(l:newLine), 1))
    setlocal nomodifiable

    " save layer index
    if s:lyr.mode == s:MODE.Normal
        call s:lyr.setInfo('lastIndex', popc#ui#GetIndex())
        doautocmd User PopcUiIndexChanged
    endif
endfunction
" }}}

" FUNCTION: popc#ui#GetIndex() {{{
function! popc#ui#GetIndex()
    return line('.') - 1
endfunction
" }}}

" FUNCTION: s:saveRecover() {{{
function! s:saveRecover()
    let s:recover.winnr = winnr()
    let s:recover.file = expand('%:p')
    if &timeout
        let s:recover.timeoutlen = &timeoutlen
    endif
endfunction
" }}}

" FUNCTION: popc#ui#GetRecover() {{{
function! popc#ui#GetRecover()
    return s:recover
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
    let s:hi.label       = has_key(a:hi, 'label')       ? a:hi.label       : a:hi.selected
    let s:hi.blankTxt    = has_key(a:hi, 'blankTxt')    ? a:hi.blankTxt    : a:hi.text
    let s:hi.modifiedSel = has_key(a:hi, 'modifiedSel') ? a:hi.modifiedSel : a:hi.selected
    let s:hi.modifiedTxt = s:createHiSep(s:hi.modifiedSel, s:hi.text, 'PopcModifiedTxt')

    " menu
    execute printf('highlight default link PopcText     %s', s:hi.text)
    execute printf('highlight default link PopcSel      %s', s:hi.selected)

    " statusline
    execute printf('highlight default link PopcSlLabel  %s', s:hi.label)
    execute printf('highlight default link PopcSl       %s', s:hi.text)
    call s:createHiSep('PopcSlLabel', 'PopcSl', 'PopcSlSep')

    " tabline
    execute printf('highlight default link PopcTlLabel  %s', s:hi.label)
    execute printf('highlight default link PopcTl       %s', s:hi.text)
    execute printf('highlight default link PopcTlSel    %s', s:hi.selected)
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

" FUNCTION: popc#ui#GetStatusLineSegments() abort {{{
function! popc#ui#GetStatusLineSegments(seg) abort
    let l:segs = []

    if a:seg =~? '[al]'
        let l:left = 'Popc'
        call add(l:segs, l:left)
    endif

    if a:seg =~? '[ac]'
        if s:lyr.mode == s:MODE.Normal || s:lyr.mode == s:MODE.Search
            let l:center = s:lyr.info.centerText
        elseif s:lyr.mode == s:MODE.Help
            let l:center = 'Help for ''' . s:lyr.name . ''' layer'
        endif
        call add(l:segs, l:center)
    endif

    if a:seg =~? '[ar]'
        let l:rank = '[' . string(s:lyr.bufs.cnt) . ']' . popc#ui#Num2RankStr(line('.'))
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
        let l:spl  = ' '
        let l:spr  = ' '
        let l:sspl = '|'
        let l:sspr = '|'
    endif

    " buffers {{{
    let l:list = popc#layer#buf#GetBufs(tabpagenr())
    let l:len = len(l:list)
    " lable -> separator -> title
    let l:id = (l:len > 0) ? string(l:list[0].selected*2 + l:list[0].modified) : '4'
    let l:bufs = '%#PopcTlLabel# B%#PopcTlSepL' . l:id . '#' . l:spl
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
        let l:bufs .= (l:hi) . ('%'.(i.index).'T ' .(i.title).(i.modified?'+':' '). '%T')
        let l:bufs .= l:hisep . l:sep
    endfor
    let l:bufs .= '%#PopcTlBlank#%='
    "}}}

    " tabs {{{
    let l:list = popc#layer#buf#GetTabs()
    let l:len = len(l:list)
    let l:tabs = ''
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
        let l:tabs .= l:hisep . l:sep
        let l:tabs .= (l:hi) . ('%'.(i.index).'T ' .(i.title).(i.modified?'+':' '). '%T')
    endfor
    " title -> separator -> lable
    let l:id = (l:len > 0) ? string(l:list[-1].selected*2 + l:list[-1].modified) : '4'
    let l:tabs .= '%#PopcTlSepL' . l:id . '#' . l:spr
    let l:tabs .= '%#PopcTlLabel#T '
    "}}}

    return l:bufs . l:tabs
endfunction
" }}}


" SETCION: utils {{{1

" FUNCTION: popc#ui#Num2RankStr(num) {{{
function! popc#ui#Num2RankStr(num)
    if s:conf.useUnicode
        let l:str = ''
        let l:numStr = string(a:num)
        for k in range(len(l:numStr))
            let l:str .= s:conf.symbols.Nums[str2nr(l:numStr[k])]
        endfor
    else
        let l:str = '#' . string(a:num)
    endif
    return l:str
endfunction
" }}}

" FUNCTION: popc#ui#Input(promot, ...) {{{
function! popc#ui#Input(promot, ...)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:promot, '\M\n', '\n   ', 'g')
    redraw
    return a:0 == 0 ? input(l:msg) :
         \ a:0 == 1 ? input(l:msg, a:1) :
         \            input(l:msg, a:1, a:2)
endfunction
" }}}

" FUNCTION: popc#ui#Confirm(prompt) {{{
function! popc#ui#Confirm(prompt)
    let l:msg = ' ' . s:conf.symbols.Popc . ' ' . substitute(a:prompt, '\M\n', '\n   ', 'g') . ' (yN): '
    redraw
    return input(l:msg) ==# 'y'
endfunction
" }}}

" FUNCTION: popc#ui#Msg(msg) {{{
function! popc#ui#Msg(msg)
    redraw
    echo ' ' . s:conf.symbols.Popc . ' ' . substitute(a:msg, '\M\n', '\n   ', 'g')
endfunction
" }}}

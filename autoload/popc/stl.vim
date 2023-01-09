
" statusline and tabline

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()
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
let s:lst = {}
" {
"   'sum' : 0,              " sum length of all items
"   'idx' : 0,              " the index of selected item
"   'len' : [],             " length for each item
"   'res' : []              " result: 1 for visible, 0 for hidden, -1 for replace item
" }
if s:conf.usePowerFont
    let s:spl = s:conf.separator.left
    let s:spr = s:conf.separator.right
    let s:sspl = s:conf.subSeparator.left
    let s:sspr = s:conf.subSeparator.right
else
    let s:spl = ''
    let s:spr = ''
    let s:sspl = '\'
    let s:sspr = '/'
endif


" SECTION: dictionary function {{{1

" FUNCTION: s:lst.calcLen(lst, extwid) dict {{{
function! s:lst.calcLen(lst, extwid) dict
    let self.sum = 0
    let self.idx = 0
    let self.len = []
    if !empty(a:lst)
        let self.sum += 2
        for k in range(len(a:lst))
            call add(self.len, strwidth(a:lst[k].title) + a:extwid)
            let self.sum += self.len[-1]
            if a:lst[k].selected
                let self.idx = k
            endif
        endfor
    endif
endfunction
" }}}

" FUNCTION: s:lst.calcMin(lst) dict {{{
" the min struct is only one buf and one tab: ... > item > ...
function! s:lst.calcMin(lst) dict
    let self.sum = 0
    if !empty(a:lst)
        let self.res = repeat([0], len(a:lst))
        let self.sum += 2

        if self.idx - 1 >= 0
            let self.sum += 6
            let self.res[self.idx - 1] = -1
        endif

        let self.res[self.idx] = 1
        let self.sum += self.len[self.idx]

        if self.idx + 1 < len(a:lst)
            let self.sum += 6
            let self.res[self.idx + 1] = -1
        endif
    endif
endfunction
" }}}

" FUNCTION: s:lst.calcExt(lst, csum) dict {{{
" extend list
function! s:lst.calcExt(lst, csum) dict
    let l = self.idx
    let r = self.idx
    let l:sz = len(a:lst)
    while (r - l + 1 < l:sz)
        if (r + 1 < l:sz)
            let r += 1
            if self.sum + a:csum + self.len[r] <= &columns
                let self.sum += self.len[r]
                let self.res[r] = 1
                if r + 1 < l:sz
                    let self.res[r + 1] = -1
                endif
            else
                break
            endif
        endif
        if (l - 1 >= 0)
            let l -= 1
            if self.sum + a:csum + self.len[l] <= &columns
                let self.sum += self.len[l]
                let self.res[l] = 1
                if l - 1 >= 0
                    let self.res[l - 1] = -1
                endif
            else
                break
            endif
        endif
    endwhile
endfunction
" }}}

" FUNCTION: s:lst.calcRes(lst) dict {{{
function! s:lst.calcRes(lst) dict
    let l:out = []
    for k in range(len(a:lst))
        if self.res[k] >= 1
            call add(l:out, a:lst[k])
        elseif self.res[k] <= -1
            if has('nvim')
                let l:maxnr = v:numbermax
            else
                let l:maxnr = 9223372036854775807
            endif
            call add(l:out,
                \ {
                    \ 'index': empty(l:out) ? 0 : l:maxnr,
                    \ 'title': s:conf.symbols.Dots,
                    \ 'modified': 0,
                    \ 'selected': 0
                \ })
        endif
    endfor
    return l:out
endfunction
" }}}

" FUNCTION: popc#stl#ShortenTabsBufs(buflst, tablst, ele_extwid) abort {{{
" @param *lst [{'index': 0, 'title': '', 'modified': 0, 'selected': 0}, ...]
" @param ele_extwid extend width of each tab or buf element
function! popc#stl#ShortenTabsBufs(buflst, tablst, ele_extwid) abort
    let l:buf = copy(s:lst)
    let l:tab = copy(s:lst)

    call l:buf.calcLen(a:buflst, a:ele_extwid)
    call l:tab.calcLen(a:tablst, a:ele_extwid)

    " columns is enough
    if l:buf.sum + l:tab.sum <= &columns
        return [a:buflst, a:tablst]
    endif

    " get min struct
    call l:buf.calcMin(a:buflst)
    call l:tab.calcMin(a:tablst)

    " extend buf firstly and then tab
    call l:buf.calcExt(a:buflst, l:tab.sum)
    call l:tab.calcExt(a:tablst, l:buf.sum)

    " return short list
    return [l:buf.calcRes(a:buflst), l:tab.calcRes(a:tablst)]
endfunction
" }}}


" SETCION: functions {{{1

" FUNCTION: popc#stl#Init() {{{
function! popc#stl#Init()
    call popc#stl#InitHighLight(s:conf.highlight)
    if s:conf.useTabline || s:conf.useStatusline
        augroup PopcStlInit
            autocmd!
            autocmd ColorScheme * call popc#stl#InitHighLight(s:hi)
        augroup END
    endif
    if s:conf.useTabline
        set showtabline=2
        silent execute 'set tabline=%!' . s:conf.tabLine
    endif
endfunction
" }}}

" FUNCTION: s:createHiSep(hifg, hibg, hinew) {{{
function! s:createHiSep(hifg, hibg, hinew)
    let r = ['', '', '', '']
    let r[0] = synIDattr(synIDtrans(hlID(a:hifg)), 'reverse', 'gui') ? 'fg' : 'bg'
    let r[1] = synIDattr(synIDtrans(hlID(a:hibg)), 'reverse', 'gui') ? 'fg' : 'bg'
    let r[2] = synIDattr(synIDtrans(hlID(a:hifg)), 'reverse', 'cterm') ? 'fg' : 'bg'
    let r[3] = synIDattr(synIDtrans(hlID(a:hibg)), 'reverse', 'cterm') ? 'fg' : 'bg'
    let c = ['', '', '', '']
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

" FUNCTION: popc#stl#InitHighLight(hi) {{{
function! popc#stl#InitHighLight(hi)
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
    execute printf('highlight default link PopcTxt      %s', s:hi.text)
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

" FUNCTION: popc#stl#StatusLineGetSegments(seg) abort {{{
" @param seg a=all, l=left, c=center, r=right
function! popc#stl#StatusLineGetSegments(seg) abort
    let l:segs = []
    if a:seg =~? '[al]'
        call add(l:segs, 'Popc')
    endif
    if a:seg =~? '[ac]'
        call add(l:segs, popc#ui#CurrentLayer().info.centerText)
    endif
    if a:seg =~? '[ar]'
        let l:line = popc#ui#GetVal('line')
        let l:rank = popc#stl#CreateRank(popc#ui#CurrentLayer(), l:line.cnt, l:line.cur)
        call add(l:segs, l:rank)
    endif
    return l:segs
endfunction
" }}}

" FUNCTION: popc#stl#StatusLine() abort {{{
function! popc#stl#StatusLine() abort
    let [l:left, l:center, l:right] = popc#stl#StatusLineGetSegments('a')
    let l:value  = ('%#PopcSlLabel# ' . l:left . ' ') . ('%#PopcSlSep#' . s:spl)
    let l:value .= ('%#PopcSl# ' . l:center . ' ')
    let l:value .= '%='
    let l:value .= ('%#PopcSlSep#' . s:spr) . ('%#PopcSlLabel# ' . l:right . ' ')
    return l:value
endfunction
" }}}

" FUNCTION: popc#stl#TabLineSetLayout(lhs, rhs) abort {{{
function! popc#stl#TabLineSetLayout(lhs, rhs) abort
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

" has('tablineat') {{{
if has('tablineat')
function! popc#stl#SwitchBuffer(minwid, clicks, button, modifiers)
    " BUG: v:numbermax becomes -1 from statusline '@'
    if a:clicks == 1 && a:button ==# 'l'
        if a:minwid == 0
            call popc#layer#buf#SwitchBuffer('left', 0)
        elseif a:minwid == -1
            call popc#layer#buf#SwitchBuffer('right', 0)
        else
            silent! execute 'buffer ' . string(a:minwid)
        endif
    endif
endfunction

function! popc#stl#SwitchTab(minwid, clicks, button, modifiers)
    " BUG: v:numbermax becomes -1 from statusline '@'
    if a:clicks == 1 && a:button ==# 'l'
        if a:minwid == 0
            call popc#layer#buf#SwitchTab('left', 0)
        elseif a:minwid == -1
            call popc#layer#buf#SwitchTab('right', 0)
        else
            silent! execute string(a:minwid) . 'tabnext'
        endif
    endif
endfunction
endif
" }}}

" FUNCTION: s:createTabLineLeft(lst, ch, fn) abort {{{
function! s:createTabLineLeft(lst, ch, fn) abort
    let l:list = a:lst

    if empty(l:list)
        let l:lhs = '%#PopcTlBlank#%='
    else
        let l:len = len(l:list)
        " lable -> separator -> title
        let l:id = (l:len > 0) ? string(l:list[0].selected*2 + l:list[0].modified) : '4'
        let l:lhs = '%#PopcTlLabel#' . a:ch . '%#PopcTlSepL' . l:id . '#' . s:spl
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
                let l:sep = (i.selected || ii.selected) ? s:spl : s:sspl
            else
                " title -> separator -> blank
                let l:id = string(i.selected*2 + i.modified)
                let l:hisep = '%#PopcTlSepB' . l:id . '#'
                let l:sep = s:spl
            endif
            " append item of with separator
            if has('tablineat')
                " <highlight>%<nr>@<func>@ <item>%T<sep-item>
                let l:lhs .= printf("%s%%%d@%s@ %s%%T%s",
                            \ l:hi,
                            \ i.index,
                            \ a:fn,
                            \ (i.title) . (i.modified?'+':' '),
                            \ l:hisep . l:sep)
            else
                " <highlight>%<nr>T <item>%T<sep-item>
                let l:lhs .= printf("%s%%%dT %s%%T%s",
                            \ l:hi,
                            \ i.index,
                            \ (i.title) . (i.modified?'+':' '),
                            \ l:hisep . l:sep)
            endif
        endfor
        let l:lhs .= '%#PopcTlBlank#%='
    endif
    return l:lhs
endfunction
" }}}

" FUNCTION: s:createTabLineRight(lst, ch, fn) abort {{{
function! s:createTabLineRight(lst, ch, fn) abort
    let l:list = a:lst

    if empty(l:list)
        let l:rhs = ''
    else
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
                let l:sep = s:spr
            else
                " title -> separator -> title
                let ii = l:list[k-1]
                let l:id = string(i.selected*8 + i.modified*4 + ii.selected*2 + ii.modified)
                let l:hisep = '%#PopcTlSep' . l:id . '#'
                let l:sep = (i.selected || ii.selected) ? s:spr : s:sspr
            endif
            " append item of with separator
            if has('tablineat')
                " <sep-item><highlight>%<nr>@<func>@ <item>%T
                let l:rhs .= printf("%s%s%%%d@%s@ %s%%T",
                            \ l:hisep . l:sep,
                            \ l:hi,
                            \ i.index,
                            \ a:fn,
                            \ (i.title) . (i.modified?'+':' '))
            else
                " <sep-item><highlight>%<nr>T <item>%T
                let l:rhs .= printf("%s%s%%%dT %s%%T",
                            \ l:hisep . l:sep,
                            \ l:hi,
                            \ i.index,
                            \ (i.title) . (i.modified?'+':' '))
            endif
        endfor
        " title -> separator -> lable
        let l:id = (l:len > 0) ? string(l:list[-1].selected*2 + l:list[-1].modified) : '4'
        let l:rhs .= '%#PopcTlSepL' . l:id . '#' . s:spr
        let l:rhs .= '%#PopcTlLabel#' . a:ch
    endif
    return l:rhs
endfunction
" }}}

" FUNCTION: popc#stl#TabLine() abort {{{
function! popc#stl#TabLine() abort
    " init buf and tab list"
    let l:buflst = []
    let l:tablst = []
    if s:conf.tabLineLayout.left ==# 'tab' || s:conf.tabLineLayout.right ==# 'tab'
        let l:tablst = popc#layer#buf#GetTabs()
    endif
    if s:conf.tabLineLayout.left ==# 'buffer' || s:conf.tabLineLayout.right ==# 'buffer'
        let l:buflst = popc#layer#buf#GetBufs(tabpagenr())
    endif
    let [l:buflst, l:tablst] = popc#stl#ShortenTabsBufs(l:buflst, l:tablst, 3)

    " left side
    let l:lhs = '%#PopcTlBlank#%='
    if s:conf.tabLineLayout.left ==# 'tab'
        let l:lhs = s:createTabLineLeft(l:tablst, 'T', 'popc#stl#SwitchTab')
    elseif s:conf.tabLineLayout.left ==# 'buffer'
        let l:lhs = s:createTabLineLeft(l:buflst, 'B', 'popc#stl#SwitchBuffer')
    endif

    " right side
    let l:rhs = ''
    if s:conf.tabLineLayout.right ==# 'tab'
        let l:rhs = s:createTabLineRight(l:tablst, 'T', 'popc#stl#SwitchTab')
    elseif s:conf.tabLineLayout.right ==# 'buffer'
        let l:rhs = s:createTabLineRight(l:buflst, 'B', 'popc#stl#SwitchBuffer')
    endif

    return l:lhs . l:rhs
endfunction
" }}}

" FUNCTION: popc#stl#CreateRank(lyr, cnt, cur) {{{
function! popc#stl#CreateRank(lyr, cnt, cur)
    let l:fmt = printf('[%%s]%%-%dS %%s %%s', strwidth(string(a:cnt)))
    return printf(l:fmt,
                \ a:cnt, popc#utils#Num2RankStr(a:cur),
                \ s:conf.symbols.Rank, a:lyr.name)
endfunction
" }}}

" FUNCTION: popc#stl#CreateContext(lyr, maxwidth, maxheight) {{{
" @return: {title-segs, text-list, text-size, text-width, text-height}
function! popc#stl#CreateContext(lyr, maxwidth, maxheight)
    let l:list = a:lyr.getBufs()
    let l:size = len(l:list)
    let l:height = (l:size <= a:maxheight) ? l:size : a:maxheight
    let l:width = max(map(copy(l:list), {key, val -> strwidth(val)})) + 2   " text end with 2 spaces

    " title
    let l:rank = popc#stl#CreateRank(a:lyr, l:size, popc#ui#GetVal('line').cur)
    let l:title = ['Popc', s:spl, ' ' . a:lyr.info.centerText . ' ', s:spr, l:rank]
    let l:wseg = 0
    for seg in l:title
        let l:wseg += strwidth(seg)
    endfor
    let l:width = min([max([l:width, l:wseg]), a:maxwidth])
    if l:wseg < l:width
        let l:title[2] .= repeat(' ', l:width - l:wseg)
    elseif l:wseg > l:width
        let l:title[2] = strpart(l:title[2], 0, strlen(l:title[2]) - (l:wseg - l:width))
    endif

    " text
    let l:text = map(copy(l:list), 'v:val . repeat(" ", l:width - strwidth(v:val))')

    return {
        \ 'title' : l:title,
        \ 'text' : l:text,
        \ 'size' : l:size,
        \ 'wid' : l:width,
        \ 'hei' : l:height
        \ }
endfunction
" }}}


" buffer and tab layer.

" SECTION: variables {{{1

let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}          " this layer
let s:tab = {
    \ 'bnr' : [],
    \ 'idx' : [],
    \ 'pos' : [],
    \ 'lbl' : [],
    \ 'cnt' : {},
    \ }                 " only manager Popc's internal tab-buffers data instead of
                        " operateing(edit,open,close...) vim's tab-buffers actually
" {{{ s:tab format
"{
"   'bnr' : [                           " all tab's bufnr
"       {'nr6' : bufname, 'nr3' : bufname},
"       {'nr6' : bufname, 'nr9' : bufname},
"       ...
"   ],
"   'idx' : [                           " all tas's bufnr index, use in self.bnr[idx[k]]
"       ['nr3', 'nr6', ...],
"       ['nr6', 'nr9', ...],
"       ...
"   ],
"   'pos' : [1, 0, ...]                 " current bufnr index position of each tab, use in self.idx[i][pos[k]]
"   'lbl' : ['tab1', 'tab2', ...],      " all tab's label
"   'cnt' :                             " reference counter of each bufnr
"   {
"       'nr3' : 1,
"       'nr6' : 2,
"       'nr9' : 1,
"       ...
"   }
"}
" }}}
let s:STATE = {
    \ 'Sigtab' : 'h',
    \ 'Alltab' : 'a',
    \ 'Listab' : 'l',
    \ }
let s:rootBuf = ''
let s:mapsData = [
    \ ['popc#layer#buf#Pop'          , ['h','a','l'],             'Pop buffers layer (h-Tab buffers, a-All buffers, l-Tab list)'],
    \ ['popc#layer#buf#Load'         , ['CR','Space'],            'Load buffers (Space to stay in popc)'],
    \ ['popc#layer#buf#SplitTab'     , ['s','S','v','V','t','T'], 'Split or tab buffers (SVT to stay in popc)'],
    \ ['popc#layer#buf#Goto'         , ['g','G'],                 'Goto window contain the current buffer(G to stay in popc)'],
    \ ['popc#layer#buf#Close'        , ['c','C'],                 'Close one buffer (C-Close tab''s all buffer)'],
    \ ['popc#layer#buf#SwitchTab'    , ['i','o'],                 'Switch to left/right(i/o) tab'],
    \ ['popc#layer#buf#MoveBuffer'   , ['I','O'],                 'Move buffer to left/right(I/O) tab'],
    \ ['popc#layer#buf#SetTabName'   , ['n'],                     'Set current tab name'],
    \ ['popc#layer#buf#Edit'         , ['e'],                     'Edit a new file'],
    \ ['popc#layer#buf#Help'         , ['?'],                     'Show help of buffers layer'],
    \ ]


" SECTION: dictionary function {{{1

" FUNCTION: s:tab.insertTab(tidx) dict {{{
function! s:tab.insertTab(tidx) dict
    call insert(self.bnr, {}, a:tidx)
    call insert(self.idx, [], a:tidx)
    call insert(self.pos, 0,  a:tidx)
    call insert(self.lbl, '', a:tidx)
endfunction
" }}}

" FUNCTION: s:tab.removeTab(tidx) dict {{{
function! s:tab.removeTab(tidx) dict
    for k in self.idx[a:tidx]
        let self.cnt[k] -= 1
        if self.cnt[k] == 0
            call remove(self.cnt, k)
        endif
    endfor
    call remove(self.bnr, a:tidx)
    call remove(self.idx, a:tidx)
    call remove(self.pos, a:tidx)
    call remove(self.lbl, a:tidx)
endfunction
" }}}

" FUNCTION: s:tab.num(...) dict {{{
" @param(a:1): get tab's num or buffer's num of tab a:1
function! s:tab.num(...) dict
    return (a:0 == 0 ? len(self.idx) : len(self.idx[a:1]))
endfunction
" }}}

" FUNCTION: s:tab.isTabEmpty(...) dict {{{
function! s:tab.isTabEmpty(...) dict
    let l:tidx = (a:0 == 0) ? (tabpagenr() - 1) : a:1
    return !self.num(l:tidx)
endfunction
" }}}

" FUNCTION: s:tab.isTabModified(tidx, ...) dict {{{
" @param(a:1): list to store nr of modified buffer
function! s:tab.isTabModified(tidx, ...) dict
    for bnr in self.idx[a:tidx]
        if getbufvar(str2nr(bnr), '&modified')
            if a:0 >= 1
                call add(a:1, str2nr(bnr))
            else
                return 1
            endif
        endif
    endfor
    return (a:0 >= 1 && len(a:1) > 0) ? 1: 0
endfunction
" }}}

" FUNCTION: s:tab.insertBuffer(tidx, bnr) dict {{{
function! s:tab.insertBuffer(tidx, bnr) dict
    let l:cbnr = self.bnr[a:tidx]
    let l:cidx = self.idx[a:tidx]

    let l:bnr = (type(a:bnr) == v:t_number) ? string(a:bnr) : a:bnr
    let b = getbufinfo(str2nr(l:bnr))[0]
    if b.loaded && b.listed && getbufvar(str2nr(l:bnr), '&filetype') != 'Popc'
        if !has_key(l:cbnr, l:bnr)
            " insert index in order to s:tab.idx
            if (len(l:cidx) == 0) || (l:cbnr[l:cidx[-1]] <= b.name)
                call add(l:cidx, l:bnr)
            else
                for k in range(len(l:cidx))
                    if b.name < l:cbnr[l:cidx[k]]
                        call insert(l:cidx, l:bnr, k)
                        break
                    endif
                endfor
            endif
            " count reference to s:tab.cnt
            let self.cnt[l:bnr] = has_key(self.cnt, l:bnr) ? self.cnt[l:bnr] + 1 : 1
        endif
        " add or update buffer to s:tab.bnr
        call extend(l:cbnr, {l:bnr : b.name}, 'force')
        " set tabel to s:tab.lbl
        let self.lbl[a:tidx] = empty(b.name) ? l:bnr . '.NoName' : fnamemodify(b.name, ':t')
    endif
endfunction
" }}}

" FUNCTION: s:tab.removeBuffer(tidx, bnr) dict {{{
function! s:tab.removeBuffer(tidx, bnr) dict
    let l:bnr = (type(a:bnr) == v:t_number) ? string(a:bnr) : a:bnr
    " s:tab.bnr
    call remove(self.bnr[a:tidx], l:bnr)
    " s:tab.idx
    call filter(self.idx[a:tidx], 'v:val !=#' . l:bnr)
    " s:tab.pos
    if self.num(a:tidx) == 0
        let self.pos[a:tidx] = 0
    elseif self.pos[a:tidx] >= self.num(a:tidx)
        let self.pos[a:tidx] = self.num(a:tidx) - 1
    endif
    " s:tab.cnt
    let self.cnt[l:bnr] -= 1
    if self.cnt[l:bnr] == 0
        call remove(self.cnt, l:bnr)
    endif
endfunction
" }}}

" FUNCTION: s:tab.checkBuffer(tidx) dict {{{
function! s:tab.checkBuffer(tidx) dict
    " remove buffer not closed by s:closeBuffer
    for k in range(self.num(a:tidx) - 1, 0, -1)    " traversal must in reverse order
        let l:bnr = self.idx[a:tidx][k]
        if !bufexists(str2nr(l:bnr))
            call s:tab.removeBuffer(a:tidx, l:bnr)
        else
            let b = getbufinfo(str2nr(l:bnr))[0]
            if !b.listed || !b.loaded
                call s:tab.removeBuffer(a:tidx, l:bnr)
            endif
        endif
    endfor
endfunction
" }}}


" SECTION: functions {{{1

" FUNCTION: popc#layer#buf#Init() {{{
function! popc#layer#buf#Init()
    let s:lyr = s:popc.addLayer('Buffer')
    call s:lyr.setInfo('state', s:STATE.Sigtab)
    call s:lyr.setInfo('centerText', s:conf.symbols.Buf)
    call s:lyr.setInfo('userCmd', 1)

    augroup PopcLayerBufInit
        autocmd!
        autocmd TabNew    * call s:tabCallback('new')
        autocmd TabClosed * call s:tabCallback('close')
        autocmd BufEnter  * call s:bufCallback('enter')
        autocmd BufNew    * let s:rootBuf=popc#layer#com#FindRoot()
        autocmd User PopcUiIndexChanged call s:indexChanged(s:lyr.info.lastIndex)
    augroup END

    for md in s:mapsData
        call s:lyr.addMaps(md[0], md[1])
    endfor
endfunction
" }}}

" FUNCTION: s:updateTabNr() {{{
function! s:updateTabNr()
    let l:closedTabNr = 0
    for tnr in range(1, tabpagenr('$'))
        let l:nr = gettabvar(tnr, 'PopcLayerBuf_TabNr')
        if type(l:nr) == v:t_number
            if l:nr != tnr
                if l:nr > tnr && l:closedTabNr == 0
                    " this is the closed tab
                    let l:closedTabNr = l:nr - 1
                endif
                call settabvar(tnr, 'PopcLayerBuf_TabNr', tnr)
            endif
        else
            " this is a new tab
            call settabvar(tnr, 'PopcLayerBuf_TabNr', tnr)
        endif
    endfor
    " l:closedTabNr = 0 means the last tab is the closed tab
    return l:closedTabNr
endfunction
" }}}

" FUNCTION: s:tabCallback(type) {{{
function! s:tabCallback(type)
    let l:tidx = tabpagenr() - 1
    if a:type ==# 'new'
        " all tab will be added from here
        call s:tab.insertTab(l:tidx)
        call s:updateTabNr()
    elseif a:type ==# 'close'
        " all tab will be deleted from here
        let l:tnr = s:updateTabNr()
        if assert_true(l:tnr >= 0, 'l:tnr >= 0')
            echoerr v:errors[-1]
            return
        endif
        let l:tidx = l:tnr - 1  " s:tab.idx[-1] means the last is the closed tab when l:tnr=0
        if assert_true(s:tab.num() > 0 && l:tidx < s:tab.num(), 's:tab.num() > 0 && l:tidx < s:tab.num()')
            echoerr v:errors[-1]
            return
        endif
        let l:bnrs = copy(s:tab.idx[l:tidx])
        call s:tab.removeTab(l:tidx)
        for bnr in l:bnrs
            if !has_key(s:tab.cnt, bnr) && !getbufvar(str2nr(bnr), "&modified")
                silent execute 'noautocmd bdelete! ' . bnr
            endif
        endfor
    endif
endfunction
" }}}

" FUNCTION: s:bufCallback() {{{
function! s:bufCallback(type)
    let l:tidx = tabpagenr() - 1
    if a:type == 'enter'
        if !s:tab.num()
            call s:tab.insertTab(l:tidx)
        endif
        call s:tab.insertBuffer(l:tidx, bufnr('%'))
    endif
endfunction
" }}}

" FUNCTION: s:createBuffer() {{{
function! s:createBuffer()
    let l:text = ''
    let l:textCnt = 0

    " create buffer
    if s:lyr.info.state ==# s:STATE.Sigtab
        let [l:textCnt, l:text] = s:createTabBuffer(tabpagenr() - 1)
    elseif s:lyr.info.state ==# s:STATE.Alltab
        for k in range(s:tab.num())
            let [c, t] = s:createTabBuffer(k)
            let l:textCnt += c
            let l:text .= t
        endfor
    elseif s:lyr.info.state ==# s:STATE.Listab
        let [l:textCnt, l:text] = s:createTabList()
    endif
    return [l:textCnt, l:text]
endfunction
" }}}

" FUNCTION: s:createTabBuffer(tidx) {{{
function! s:createTabBuffer(tidx)
    call s:tab.checkBuffer(a:tidx)

    " BUG: it's unknown why it's necessary to 'lcd' again in Popc buffer when
    " close a buffer.
    if getbufvar(bufnr('%'), '&filetype') == 'Popc'
        execute 'lcd ' . getcwd()
    endif

    " join lines
    let l:text = ''
    let l:winid = win_getid(
                \ ((a:tidx == tabpagenr() - 1) ? popc#ui#GetRecover().winnr : tabpagewinnr(a:tidx + 1)),
                \ a:tidx + 1)
    for k in range(s:tab.num(a:tidx))
        let l:bnr = s:tab.idx[a:tidx][k]
        let b = getbufinfo(str2nr(l:bnr))[0]

        let l:line  = '  '
        " symbol for tab
        if s:lyr.info.state ==# s:STATE.Alltab
            if a:tidx == tabpagenr() - 1
                let l:line .= (k > 0) ? '|' : s:conf.symbols.CTab
            else
                let l:line .= (k > 0) ? ' ' : s:conf.symbols.Tab
            endif
        else
            let l:line .= ' '
        endif
        " symbol for buffer
        if empty(b.windows)
            let l:line .= ' '
        else
            let l:sym = ' '
            for l:id in b.windows
                if win_id2tabwin(l:id)[0] == a:tidx + 1
                    " Note that a buffer may appear in more than one window.
                    let l:sym = s:conf.symbols.WOut
                    if l:id == l:winid
                        let l:sym = s:conf.symbols.WIn
                        break
                    endif
                endif
            endfor
            let l:line .= l:sym
        endif
        " symbol for changed
        let l:line .= b.changed ? '+' : ' '
        let l:line .= ' ' . (empty(b.name) ? '[' . l:bnr . '.NoName]' : fnamemodify(b.name, ':.'))
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
    endfor

    return [s:tab.num(a:tidx), l:text]
endfunction
" }}}

" FUNCTION: s:createTabList() {{{
function! s:createTabList()
    let l:text = ''

    for k in range(s:tab.num())
        let l:tname = gettabvar(k + 1, 'PopcLayerBuf_TabName')
        let l:line = '  '
        let l:line .= (k == tabpagenr() - 1) ? s:conf.symbols.CTab : s:conf.symbols.Tab
        let l:line .= s:tab.isTabModified(k) ? '+' : ' '
        let l:line .= ' ' . '[' . (empty(l:tname) ? s:tab.lbl[k] : l:tname) . ']'
                        \ . popc#ui#Num2RankStr(s:tab.num(k))
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
    endfor

    return [s:tab.num(), l:text]
endfunction
" }}}

" FUNCTION: s:getIndexs(index) {{{
" get current tab index and buffer index
" @index: current bar index from ui
function! s:getIndexs(index)
    let l:tidx = 0
    let l:bidx = a:index

    if s:lyr.info.state ==# s:STATE.Sigtab
        let l:tidx = tabpagenr() - 1
    elseif s:lyr.info.state ==# s:STATE.Alltab
        " calc the bufnr index and tab index in all tabs
        for k in range(s:tab.num())
            if l:bidx >= s:tab.num(k)
                let l:bidx -= s:tab.num(k)
                let l:tidx += 1
            else
                break
            endif
        endfor
    elseif s:lyr.info.state ==# s:STATE.Listab
        let l:tidx = l:bidx
        let l:bidx = s:tab.pos[l:tidx]
    endif

    return [l:tidx, l:bidx, (s:tab.num() && s:tab.num(l:tidx)) ? s:tab.idx[l:tidx][l:bidx] : '']
endfunction
" }}}

" FUNCTION: s:indexChanged(index) {{{
function! s:indexChanged(index)
    if (s:lyr.info.state ==# s:STATE.Sigtab) || (s:lyr.info.state ==# s:STATE.Alltab)
        let [l:tidx, l:bidx] = s:getIndexs(a:index)[0:1]
        let s:tab.pos[l:tidx] = l:bidx
    endif
endfunction
" }}}

" FUNCTION: s:getTabParentDir(tidx) {{{
function! s:getTabParentDir(tidx)
    let l:dirs = []
    for bnr in s:tab.idx[a:tidx]
        if bufexists(str2nr(bnr))
            call add(l:dirs, fnamemodify(getbufinfo(str2nr(bnr))[0].name, ':h'))
        endif
    endfor
    return popc#layer#com#GetParentDir(l:dirs)
endfunction
" }}}

" FUNCTION: s:pop(state) {{{
function! s:pop(state)
    call s:lyr.setMode(s:MODE.Normal)
    call s:lyr.setInfo('state', a:state)
    call s:lyr.setBufs(v:t_func, funcref('s:createBuffer'))
    " set lastIndex
    if a:state ==# s:STATE.Sigtab
        call s:lyr.setInfo('lastIndex', s:tab.pos[tabpagenr() - 1])
    endif
    " set rootDir
    let l:root = popc#layer#wks#GetCurrentWks()[1]
    if empty(l:root)
        let l:root = s:rootBuf
    endif
    if empty(l:root)
        let l:root = s:getTabParentDir(tabpagenr() - 1)
    endif
    call s:lyr.setInfo('rootDir', l:root)
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Pop(key) {{{
function! popc#layer#buf#Pop(key)
    if (a:key ==# 'h')
        \ || (a:key ==# 'a' && s:lyr.info.state ==# s:STATE.Alltab)
        \ || (a:key ==# 'l' && s:lyr.info.state ==# s:STATE.Listab)
        let l:state = s:STATE.Sigtab
    elseif a:key ==# 'a'
        " calculate buffer index from Sigle or Listab
        if (s:lyr.info.state ==# s:STATE.Sigtab) || (s:lyr.info.state ==# s:STATE.Listab)
            let [l:tidx, l:bidx] = s:getIndexs(popc#ui#GetIndex())[0:1]
            for k in range(s:tab.num())
                if k < l:tidx
                    let l:bidx += s:tab.num(k)
                endif
            endfor
            call s:lyr.setInfo('lastIndex', l:bidx)
        endif
        let l:state = s:STATE.Alltab
    elseif a:key ==# 'l'
        " calculate tab index from Sigle or Alltab
        if (s:lyr.info.state ==# s:STATE.Sigtab) || (s:lyr.info.state ==# s:STATE.Alltab)
            call s:lyr.setInfo('lastIndex', s:getIndexs(popc#ui#GetIndex())[0])
        endif
        let l:state = s:STATE.Listab
    endif

    call s:pop(l:state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Load(key) {{{
function! popc#layer#buf#Load(key)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(popc#ui#GetIndex())

    call popc#ui#Destroy()
    if s:lyr.info.state ==# s:STATE.Listab
        " load tab
        silent execute string(l:tidx + 1) . 'tabnext'
    else
        " load buffer
        silent execute 'buffer ' . l:bnr
    endif
    if a:key ==# 'Space'
        call s:pop(s:lyr.info.state)
    endif
endfunction
" }}}

" FUNCTION: popc#layer#buf#SplitTab(key) {{{
function! popc#layer#buf#SplitTab(key)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(popc#ui#GetIndex())

    call popc#ui#Destroy()
    if s:lyr.info.state ==# s:STATE.Listab
        call popc#ui#Msg("Can NOT split or tabedit in tab-list.")
        call s:pop(s:lyr.info.state)
    else
        if a:key ==? 's'
            silent execute 'split'
        elseif a:key ==? 'v'
            silent execute 'vsplit'
        elseif a:key ==? 't'
            set eventignore+=BufEnter
            silent execute 'tabedit'
            set eventignore-=BufEnter
        endif
        silent execute 'buffer ' . l:bnr
        if a:key ==# 'T'
            silent execute string(l:tidx + 1) . 'tabnext'
        endif
        if a:key =~# '[SVT]'
            call s:pop(s:lyr.info.state)
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#layer#buf#Goto(key) {{{
function! popc#layer#buf#Goto(key)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(popc#ui#GetIndex())

    if s:lyr.info.state ==# s:STATE.Listab
        call popc#ui#Destroy()
        silent execute string(l:tidx + 1) . 'tabnext'
        if a:key ==# 'G'
            call s:pop(s:lyr.info.state)
        endif
    else
        let b = getbufinfo(str2nr(l:bnr))[0]
        for l:id in b.windows
            let [l:tabnr, l:winnr] = win_id2tabwin(l:id)
            if l:tabnr == l:tidx + 1
                call popc#ui#Destroy()
                if l:tabnr == tabpagenr()
                    silent execute string(l:tabnr) . 'tabnext'
                endif
                call win_gotoid(l:id)
                if a:key ==# 'G'
                    call s:pop(s:lyr.info.state)
                endif
                return
            endif
        endfor
        call popc#ui#Msg("No window contain current buffer.")
    endif
endfunction
" }}}

" FUNCTION: s:closeBuffer(tidx, bidx) {{{
function! s:closeBuffer(tidx, bidx)
    let l:bnr = s:tab.idx[a:tidx][a:bidx]
    if getbufvar(str2nr(l:bnr), "&modified") && (s:tab.cnt[l:bnr] == 1)
        \ && !popc#ui#Confirm('The buffer '''
                            \ . fnamemodify(bufname(str2nr(l:bnr)), ':t')
                            \ . ''' contains unsaved changes. Continue anyway?')
        return
    endif

    call popc#ui#Toggle(0)

    " remove Popc's internal buffer data
    call s:tab.removeBuffer(a:tidx, l:bnr)

    " close vim's buffer but keep tab (use noautocmd to avoid 'updateBuffer')
    let l:tnr = tabpagenr()
    silent execute 'noautocmd' . string(a:tidx + 1) . 'tabnext'
    if s:tab.isTabEmpty(a:tidx)
        enew
    else
        if str2nr(l:bnr) == bufnr('%')
            silent execute 'buffer ' . s:tab.idx[a:tidx][
                        \ (a:bidx < s:tab.num(a:tidx)) ? a:bidx : a:bidx - 1]
        endif
    endif
    if !has_key(s:tab.cnt, l:bnr)
        " delete bnr if no tab contain bnr
        silent execute 'noautocmd bdelete! ' . l:bnr
    endif
    silent execute 'noautocmd' . string(l:tnr) . 'tabnext'

    call popc#ui#Toggle(1)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Close(key) {{{
function! popc#layer#buf#Close(key)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx] = s:getIndexs(popc#ui#GetIndex())[0:1]

    if a:key ==# 'C' || s:lyr.info.state ==# s:STATE.Listab
        for k in range(s:tab.num(l:tidx) - 1, 0, -1)
            call s:closeBuffer(l:tidx, k)
        endfor
    elseif a:key ==# 'c'
        call s:closeBuffer(l:tidx, l:bidx)
    endif
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#SwitchTab(key) {{{
function! popc#layer#buf#SwitchTab(key)
    call popc#ui#Destroy()
    if a:key == 'i'
        silent normal! gT
    elseif a:key == 'o'
        silent normal! gt
    endif
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#SwitchBuffer(type) {{{
function! popc#layer#buf#SwitchBuffer(type)
    if s:tab.isTabEmpty()
        return
    endif

    let l:tidx = tabpagenr() - 1
    let l:bidx = index(s:tab.idx[l:tidx], string(bufnr('%')))

    if a:type == 'left'
        if l:bidx == 0
            let l:bidx = s:tab.num(l:tidx) - 1
        else
            let l:bidx -= 1
        endif
    elseif a:type == 'right'
        if l:bidx == s:tab.num(l:tidx) - 1
            let l:bidx = 0
        else
            let l:bidx += 1
        endif
    endif
    let l:bnr = s:tab.idx[l:tidx][l:bidx]
    silent execute 'buffer ' . l:bnr
endfunction
" }}}

" FUNCTION: popc#layer#buf#MoveBuffer(key) {{{
function! popc#layer#buf#MoveBuffer(key)
    if s:tab.isTabEmpty() || (s:tab.num() <= 1)
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(popc#ui#GetIndex())
    call popc#ui#Destroy()

    " goto origin tab
    if s:lyr.info.state ==# s:STATE.Alltab
        silent execute string(l:tidx + 1) . 'tabnext'
    endif
    " goto target tab
    if a:key == 'I'
        silent normal! gT
    elseif a:key == 'O'
        silent normal! gt
    endif
    " move buffer from origin tab to target tab
    if s:lyr.info.state ==# s:STATE.Listab
        for k in s:tab.idx[l:tidx]
            silent execute 'buffer ' . k
        endfor
        for k in range(s:tab.num(l:tidx) - 1, 0, -1)
            call s:closeBuffer(l:tidx, k)
        endfor
    else
        silent execute 'buffer ' . l:bnr
        call s:closeBuffer(l:tidx, l:bidx)
    endif

    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#SetTabName(key) {{{
function! popc#layer#buf#SetTabName(key)
    let l:tidx = s:getIndexs(popc#ui#GetIndex())[0]
    let l:name = popc#ui#Input('Input tab name: ', gettabvar(l:tidx + 1, 'PopcLayerBuf_TabName'))
    call settabvar(l:tidx + 1, 'PopcLayerBuf_TabName', l:name)
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Edit(key) {{{
function! popc#layer#buf#Edit(key)
    if s:tab.isTabEmpty()
        return
    endif

    let l:bnr = s:getIndexs(popc#ui#GetIndex())[2]
    let l:name = getbufinfo(str2nr(l:bnr))[0].name
    if empty(l:name)
        return
    endif
    let l:file = fnamemodify(l:name, ':h')
    " BUG: file string can't be indexed by -1
    if l:file[len(l:file) - 1] != '/'
        let l:file .= has('win32') ? '\' : '/'
    endif
    let l:file = popc#ui#Input('Edit new file: ', l:file, 'file')
    if empty(l:file)
        return
    endif

    call popc#ui#Toggle(0)
    silent execute 'edit ' . l:file
    call popc#ui#Toggle(1)
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Help(key) {{{
function! popc#layer#buf#Help(key)
    call s:lyr.setMode(s:MODE.Help)
    call s:lyr.setBufs(v:t_string, len(s:mapsData), popc#layer#com#createHelpBuffer(s:mapsData))
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}


" SECTION: api functions {{{1

" FUNCTION: popc#layer#buf#GetBufs(tabnr) abort {{{
" @param tabnr: get all buffers information of tabnr.
" this function is used for tabline setting.
function! popc#layer#buf#GetBufs(tabnr) abort
    let l:tidx = a:tabnr - 1
    let l:list = []

    if !s:tab.num()
        return l:list
    endif
    call s:tab.checkBuffer(l:tidx)

    if getbufvar(bufnr('%'), '&filetype') == 'Popc'
        let l:curIdx = index(s:tab.idx[l:tidx], string(winbufnr(popc#ui#GetRecover().winnr)))
    else
        let l:curIdx = index(s:tab.idx[l:tidx], string(bufnr('%')))
    endif
    for k in range(s:tab.num(l:tidx))
        let l:bnr = s:tab.idx[l:tidx][k]
        let b = getbufinfo(str2nr(l:bnr))[0]
        call add(l:list, {
                    \ 'index' : string(k+1),
                    \ 'title' : empty(b.name) ? '[' . l:bnr . '.NoName]' : fnamemodify(b.name, ':t'),
                    \ 'modified' : b.changed ? 1 : 0,
                    \ 'selected' : (k == l:curIdx) ? 1 : 0,
                    \ })
    endfor
    return l:list
endfunction
" }}}

" FUNCTION: popc#layer#buf#GetTabs() abort {{{
" return all tabs information.
" this function is used for tabline setting.
function! popc#layer#buf#GetTabs() abort
    let l:list = []
    for k in range(s:tab.num())
        let l:tname = gettabvar(k + 1, 'PopcLayerBuf_TabName')
        call add(l:list, {
                    \ 'index' : string(k+1),
                    \ 'title' : '[' . (empty(l:tname) ? s:tab.lbl[k] : l:tname) . ']'
                              \ . popc#ui#Num2RankStr(s:tab.num(k)),
                    \ 'modified' : s:tab.isTabModified(k),
                    \ 'selected' : (k+1 == tabpagenr()) ? 1 : 0,
                    \ })
    endfor
    return l:list
endfunction
" }}}

" FUNCTION: popc#layer#buf#Empty() {{{
" close all buffers and tabs. using this funtion carefully.
function! popc#layer#buf#Empty()
    call popc#ui#Destroy()

    " detect modified buffer
    let l:mbuf = []
    for k in range(s:tab.num())
        call s:tab.isTabModified(k, l:mbuf)
    endfor
    if len(l:mbuf) > 0
        let l:prompt = 'There are buffers containing unsaved changes:'
        for bnr in l:mbuf
            let l:prompt .= "\n" . getbufinfo(bnr)[0].name
        endfor
        let l:prompt .= "\n" . 'Continue anyway?'
        if !popc#ui#Confirm(l:prompt)
            return
        endif
    endif

    " close all tab and buffer
    silent! execute '0tabnew'
    silent! execute 'tabonly!'
    silent! execute '%bwipeout!'
endfunction
" }}}

" FUNCTION: popc#layer#buf#GetView(tabnr) {{{
" @param tabnr: get bufnr list of tabnr, used in workspace layer.
function! popc#layer#buf#GetView(tabnr)
    let l:tidx = a:tabnr - 1
    if s:tab.isTabEmpty(l:tidx)
        return []
    endif
    return s:tab.idx[l:tidx]
endfunction
" }}}

" FUNCTION: popc#layer#buf#GetFiles(type) {{{
" @param type: 'sigtab' for files of current tab, 'alltab' for all files
"              of all tabs.
function! popc#layer#buf#GetFiles(type)
    " get files
    let l:files = []
    if a:type == 'sigtab'
        let l:tidx = tabpagenr() - 1
        for bnr in s:tab.idx[l:tidx]
            call add(l:files, getbufinfo(str2nr(bnr))[0].name)
        endfor
    elseif a:type == 'alltab'
        for k in range(s:tab.num())
            for bnr in s:tab.idx[k]
                call add(l:files, getbufinfo(str2nr(bnr))[0].name)
            endfor
        endfor
    endif
    return l:files
endfunction
" }}}

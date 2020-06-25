
" buffer and tab layer.

" SECTION: variables {{{1

let s:popc = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}          " this layer
let s:tab = {
    \ 'idx' : [],
    \ 'pos' : [],
    \ 'sel' : [],
    \ 'lbl' : [],
    \ 'cnt' : {},
    \ }                 " only manager Popc's internal tab-buffers data instead of
                        " operateing(edit,open,close...) vim's tab-buffers actually
" {{{ s:tab format
"{
"   'idx' : [                           " all tas's bufnr index, use in self.idx[k]
"       [nr3, nr6, ...],                " nr is number type
"       [nr6, nr9, ...],
"       ...
"   ],
"   'pos' : [1, 0, ...]                 " current bufnr index position of each tab, use in self.idx[i][self.pos[k]]
"   'sel' : [0, 1, ...]                 " current selected bufnr index for tabline selected attribute, use in self.idx[i][self.sel[k]]
"   'lbl' : ['tl1', 'tl2', ...],        " all tab's label
"   'cnt' :                             " reference counter of each bufnr
"   {
"       nr3 : 1,                        " use nr as key of dict
"       nr6 : 2,
"       nr9 : 1,
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
    \ ['popc#layer#buf#Close'        , ['c','C'],                 'Close one buffer (C to close all buffers of current tab)'],
    \ ['popc#layer#buf#SwitchTab'    , ['i','o'],                 'Switch to left/right(i/o) tab'],
    \ ['popc#layer#buf#Move'         , ['I','O'],                 'Move buffer or tab to the left/right(I/O)'],
    \ ['popc#layer#buf#SetTabName'   , ['n'],                     'Set current tab name'],
    \ ['popc#layer#buf#Edit'         , ['e'],                     'Edit a new file'],
    \ ]


" SECTION: dictionary function {{{1

" FUNCTION: s:tab.insertTab(tidx) dict {{{
function! s:tab.insertTab(tidx) dict
    call insert(self.idx, [], a:tidx)
    call insert(self.pos, 0,  a:tidx)
    call insert(self.sel, 0,  a:tidx)
    call insert(self.lbl, '', a:tidx)
    call popc#utils#Log('buf', 'add tab: %s', a:tidx)
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
    call remove(self.idx, a:tidx)
    call remove(self.pos, a:tidx)
    call remove(self.sel, a:tidx)
    call remove(self.lbl, a:tidx)
    call popc#utils#Log('buf', 'remove tab: %s', a:tidx)
endfunction
" }}}

" FUNCTION: s:tab.swapTab(ltdix, rtidx) dict {{{
function! s:tab.swapTab(ltidx, rtidx) dict
    let l:lhs = (a:ltidx < self.num()) ? a:ltidx : 0
    let l:rhs = (a:rtidx < self.num()) ? a:rtidx : 0
    let [self.idx[l:lhs], self.idx[l:rhs]] = [self.idx[l:rhs], self.idx[l:lhs]]
    let [self.pos[l:lhs], self.pos[l:rhs]] = [self.pos[l:rhs], self.pos[l:lhs]]
    let [self.sel[l:lhs], self.sel[l:rhs]] = [self.sel[l:rhs], self.sel[l:lhs]]
    let [self.lbl[l:lhs], self.lbl[l:rhs]] = [self.lbl[l:rhs], self.lbl[l:lhs]]
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
        if getbufvar(bnr, '&modified')
            if a:0 >= 1
                call add(a:1, bnr)
            else
                return 1
            endif
        endif
    endfor
    return (a:0 >= 1 && len(a:1) > 0) ? 1: 0
endfunction
" }}}

" FUNCTION: s:tab.isBufferValid(bnr) dict {{{
function! s:tab.isBufferValid(bnr) dict
    if !bufexists(a:bnr)
        return 0
    else
        let b = getbufinfo(a:bnr)[0]
        let l:ft = getbufvar(a:bnr, '&filetype')
        if !b.loaded || !b.listed || l:ft ==# 'Popc' || l:ft ==# 'qf'
            return 0
        endif
    endif
    return 1
endfunction
" }}}

" FUNCTION: s:tab.insertBuffer(tidx, bnr) dict {{{
function! s:tab.insertBuffer(tidx, bnr) dict
    let l:bnr = (type(a:bnr) == v:t_string) ? str2nr(a:bnr) : a:bnr

    if self.isBufferValid(l:bnr)
        let b = getbufinfo(l:bnr)[0]
        let l:ft = getbufvar(l:bnr, '&filetype')

        " insert buffer
        let l:bidx = index(self.idx[a:tidx], l:bnr)
        if l:bidx == -1
            " append bnr to s:tab.idx
            call add(self.idx[a:tidx], l:bnr)
            let s:selSave = self.sel[a:tidx]
            let self.sel[a:tidx] = self.num(a:tidx) - 1
            " count reference to s:tab.cnt
            let self.cnt[l:bnr] = has_key(self.cnt, l:bnr) ? self.cnt[l:bnr] + 1 : 1
            call popc#utils#Log('buf', 'tab %s add buffer nr: %s, filetype: %s', a:tidx, l:bnr, l:ft)
        else
            let self.sel[a:tidx] = l:bidx
        endif

        " set tabel to s:tab.lbl
        let self.lbl[a:tidx] = empty(b.name) ? l:bnr . '.NoName' : fnamemodify(b.name, ':t')
    endif
endfunction
" }}}

" FUNCTION: s:tab.removeBuffer(tidx, bnr) dict {{{
function! s:tab.removeBuffer(tidx, bnr) dict
    let l:bnr = (type(a:bnr) == v:t_string) ? str2nr(a:bnr) : a:bnr
    " s:tab.idx
    call filter(self.idx[a:tidx], 'v:val !=#' . l:bnr)
    " s:tab.pos
    if self.num(a:tidx) == 0
        let self.pos[a:tidx] = 0
    elseif self.pos[a:tidx] >= self.num(a:tidx)
        let self.pos[a:tidx] = self.num(a:tidx) - 1
    endif
    " s:tab.sel
    if self.num(a:tidx) == 0
        let self.sel[a:tidx] = 0
    elseif self.sel[a:tidx] >= self.num(a:tidx)
        let self.sel[a:tidx] = self.num(a:tidx) - 1
    endif
    " s:tab.cnt
    let self.cnt[l:bnr] -= 1
    if self.cnt[l:bnr] == 0
        call remove(self.cnt, l:bnr)
    endif
    call popc#utils#Log('buf', 'tab %s remove buffer nr: %s, filetype: %s', a:tidx, l:bnr, getbufvar(l:bnr, '&filetype'))
endfunction
" }}}

" FUNCTION: s:tab.swapBuffer(tidx, lbnr, rbnr) dict {{{
function! s:tab.swapBuffer(tidx, lbnr, rbnr) dict
    let l:lhs = (a:lbnr < self.num(a:tidx)) ? a:lbnr : 0
    let l:rhs = (a:rbnr < self.num(a:tidx)) ? a:rbnr : 0
    let [self.idx[a:tidx][l:lhs], self.idx[a:tidx][l:rhs]] = [self.idx[a:tidx][l:rhs], self.idx[a:tidx][l:lhs]]
endfunction
" }}}

" FUNCTION: s:tab.checkBuffer(tidx) dict {{{
function! s:tab.checkBuffer(tidx) dict
    " remove buffer not closed by s:closeBuffer
    for k in range(self.num(a:tidx) - 1, 0, -1)    " traversal must in reverse order
        let l:bnr = self.idx[a:tidx][k]
        if !self.isBufferValid(l:bnr)
            if l:bnr == self.idx[a:tidx][self.sel[a:tidx]]
                call popc#utils#Log('buf', 'backup sel from %s to %s', self.sel[a:tidx], s:selSave)
                let self.sel[a:tidx] = s:selSave
            endif
            call s:tab.removeBuffer(a:tidx, l:bnr)
        endif
    endfor
endfunction
" }}}


" SECTION: functions {{{1

" FUNCTION: popc#layer#buf#Init() {{{
function! popc#layer#buf#Init()
    let s:lyr = s:popc.addLayer('Buffer', {
                \ 'bindCom' : 1,
                \ 'centerText' : s:conf.symbols.Buf,
                \ 'userCmd' : 1,
                \ 'state' : s:STATE.Sigtab,
                \ 'rootDir' : ''
                \ })
    call popc#utils#RegDbg('buf', 'popc#layer#buf#DbgInfo', '')
    call popc#utils#Log('buf', 'buffer layer was enabled')

    augroup PopcLayerBufInit
        autocmd!
        autocmd TabNew    * call s:tabCallback('new')
        autocmd TabClosed * call s:tabCallback('close')
        autocmd BufEnter  * call s:bufCallback('enter')
        autocmd BufNew    * let s:rootBuf=popc#utils#FindRoot()
        autocmd User PopcUiIndexChanged call s:indexChanged(s:lyr.info.lastIndex)
    augroup END

    for md in s:mapsData
        call s:lyr.addMaps(md[0], md[1], md[2])
    endfor
    unlet! s:mapsData
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
            if !has_key(s:tab.cnt, bnr) && !getbufvar(bnr, "&modified")
                silent execute 'noautocmd bdelete! ' . bnr
            endif
        endfor
    endif
endfunction
" }}}

" FUNCTION: s:bufCallback(type) {{{
function! s:bufCallback(type)
    let l:tidx = tabpagenr() - 1
    if a:type ==# 'enter'
        if !s:tab.num()
            call s:tab.insertTab(l:tidx)
        endif
        call s:tab.insertBuffer(l:tidx, bufnr('%'))
    endif
endfunction
" }}}

" FUNCTION: s:createBuffer() {{{
function! s:createBuffer()
    let l:text = []

    " create buffer
    if s:lyr.info.state ==# s:STATE.Sigtab
        call extend(l:text, s:createTabBuffer(tabpagenr() - 1))
    elseif s:lyr.info.state ==# s:STATE.Alltab
        for k in range(s:tab.num())
            call extend(l:text, s:createTabBuffer(k))
        endfor
    elseif s:lyr.info.state ==# s:STATE.Listab
        let l:text = s:createTabList()
    endif
    return l:text
endfunction
" }}}

" FUNCTION: s:createTabBuffer(tidx) {{{
function! s:createTabBuffer(tidx)
    call s:tab.checkBuffer(a:tidx)
    try
        silent execute 'lcd ' . s:lyr.info.rootDir
    catch
    endtry

    " join lines
    let l:text = []
    let l:winid = win_getid(
                \ ((a:tidx == tabpagenr() - 1) ? popc#ui#GetVal('winnr') : tabpagewinnr(a:tidx + 1)),
                \ a:tidx + 1)
    for k in range(s:tab.num(a:tidx))
        let l:bnr = s:tab.idx[a:tidx][k]
        let b = getbufinfo(l:bnr)[0]

        " symbol for tab
        let l:symTab = ' '
        if s:lyr.info.state ==# s:STATE.Alltab
            if a:tidx == tabpagenr() - 1
                let l:symTab = (k > 0) ? '.' : s:conf.symbols.CTab
            else
                let l:symTab = (k > 0) ? ' ' : s:conf.symbols.Tab
            endif
        endif
        " symbol for buffer
        let l:symWin = ' '
        if !empty(b.windows)
            for l:id in b.windows
                if win_id2tabwin(l:id)[0] == a:tidx + 1
                    " Note that a buffer may appear in more than one window.
                    let l:symWin = s:conf.symbols.WOut
                    if l:id == l:winid
                        let l:symWin = s:conf.symbols.WIn
                        break
                    endif
                endif
            endfor
        endif
        " final line
        let l:line = printf('  %s%s%s %s',
                    \ l:symTab, l:symWin, b.changed ? '+' : ' ',
                    \ (empty(b.name) ? '[' . string(l:bnr) . '.NoName]' : fnamemodify(b.name, ':.'))
                    \ )
        "let l:root = escape(expand(s:lyr.info.rootDir), '\:')
        "if l:root =~# '[/\\]$'
        "    let l:root = strcharpart(l:root, 0, strchars(l:root) - 1)
        "endif
        "let l:bname = (empty(b.name) ? '[' . string(l:bnr) . '.NoName]' : fnamemodify(b.name, ':s?' . l:root . '??'))
        call add(l:text, l:line)
    endfor

    return l:text
endfunction
" }}}

" FUNCTION: s:createTabList() {{{
function! s:createTabList()
    let l:text = []

    for k in range(s:tab.num())
        let l:tname = gettabvar(k + 1, 'PopcLayerBuf_TabName')
        let l:line = printf('  %s%s [%s]%s',
                    \ (k == tabpagenr() - 1) ? s:conf.symbols.CTab : s:conf.symbols.Tab,
                    \ s:tab.isTabModified(k) ? '+' : ' ',
                    \ (empty(l:tname) ? s:tab.lbl[k] : l:tname),
                    \ popc#utils#Num2RankStr(s:tab.num(k))
                    \ )
        call add(l:text, l:line)
    endfor

    return l:text
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
        if bufexists(bnr)
            call add(l:dirs, fnamemodify(getbufinfo(bnr)[0].name, ':h'))
        endif
    endfor
    return popc#utils#GetParentDir(l:dirs)
endfunction
" }}}

" FUNCTION: s:pop(state) {{{
function! s:pop(state)
    call s:lyr.setInfo('state', a:state)
    call s:lyr.setBufs(v:t_func, funcref('s:createBuffer'))
    " set lastIndex
    if a:state ==# s:STATE.Sigtab
        call s:lyr.setInfo('lastIndex', s:tab.pos[tabpagenr() - 1])
    endif
    " set rootDir
    let l:root = popc#layer#wks#GetCurrentWks('root')
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

" FUNCTION: popc#layer#buf#Pop(key, index) {{{
function! popc#layer#buf#Pop(key, index)
    if (a:key ==# 'h')
        \ || (a:key ==# 'a' && s:lyr.info.state ==# s:STATE.Alltab)
        \ || (a:key ==# 'l' && s:lyr.info.state ==# s:STATE.Listab)
        let l:state = s:STATE.Sigtab
    elseif a:key ==# 'a'
        " calculate buffer index from Sigle or Listab
        if (s:lyr.info.state ==# s:STATE.Sigtab) || (s:lyr.info.state ==# s:STATE.Listab)
            let [l:tidx, l:bidx] = s:getIndexs(a:index)[0:1]
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
            call s:lyr.setInfo('lastIndex', s:getIndexs(a:index)[0])
        endif
        let l:state = s:STATE.Listab
    endif

    call s:pop(l:state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Load(key, index) {{{
function! popc#layer#buf#Load(key, index)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(a:index)

    call popc#ui#Destroy()
    if s:lyr.info.state ==# s:STATE.Listab
        " load tab
        silent execute string(l:tidx + 1) . 'tabnext'
    else
        " load buffer
        silent execute 'buffer ' . string(l:bnr)
    endif
    if a:key ==# 'Space'
        call s:pop(s:lyr.info.state)
    endif
endfunction
" }}}

" FUNCTION: popc#layer#buf#SplitTab(key, index) {{{
function! popc#layer#buf#SplitTab(key, index)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(a:index)

    call popc#ui#Destroy()
    if s:lyr.info.state ==# s:STATE.Listab
        call popc#ui#Msg('Can NOT split or tabedit in tab-list.')
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
        silent execute 'buffer ' . string(l:bnr)
        if a:key ==# 'T'
            silent execute string(l:tidx + 1) . 'tabnext'
        endif
        if a:key =~# '[SVT]'
            call s:pop(s:lyr.info.state)
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#layer#buf#Goto(key, index) {{{
function! popc#layer#buf#Goto(key, index)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(a:index)

    if s:lyr.info.state ==# s:STATE.Listab
        call popc#ui#Destroy()
        silent execute string(l:tidx + 1) . 'tabnext'
        if a:key ==# 'G'
            call s:pop(s:lyr.info.state)
        endif
    else
        let b = getbufinfo(l:bnr)[0]
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
        call popc#ui#Msg('No window contain current buffer.')
    endif
endfunction
" }}}

" FUNCTION: s:closeBuffer(tidx, bidx) {{{
function! s:closeBuffer(tidx, bidx)
    let l:bnr = s:tab.idx[a:tidx][a:bidx]
    if getbufvar(l:bnr, "&modified") && (s:tab.cnt[l:bnr] == 1)
        \ && !popc#ui#Confirm('The buffer '''
                            \ . fnamemodify(bufname(l:bnr), ':t')
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
        if l:bnr == bufnr('%')
            silent execute 'buffer ' . s:tab.idx[a:tidx][
                        \ (a:bidx < s:tab.num(a:tidx)) ? a:bidx : a:bidx - 1]
        endif
    endif
    if !has_key(s:tab.cnt, l:bnr)
        " delete bnr if no tab contain bnr
        silent execute 'noautocmd bdelete! ' . string(l:bnr)
    endif
    silent execute 'noautocmd' . string(l:tnr) . 'tabnext'

    call popc#ui#Toggle(1)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Close(key, index) {{{
function! popc#layer#buf#Close(key, index)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx] = s:getIndexs(a:index)[0:1]

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

" FUNCTION: popc#layer#buf#SwitchTab(key, index) {{{
function! popc#layer#buf#SwitchTab(key, index)
    call popc#ui#Destroy()
    if a:key ==# 'i'
        silent normal! gT
    elseif a:key ==# 'o'
        silent normal! gt
    endif
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Move(key, index) {{{
function! popc#layer#buf#Move(key, index)
    if s:tab.isTabEmpty()
        return
    endif

    let [l:tidx, l:bidx, l:bnr] = s:getIndexs(a:index)

    if (s:lyr.info.state ==# s:STATE.Sigtab)
        " swap buffer with the left or right
        if (s:tab.num(l:tidx) < 2)
            call popc#ui#Msg('Number of buffer < 2.')
        else
            call popc#ui#Destroy()
            if a:key ==# 'I'
                call s:tab.swapBuffer(l:tidx, l:bidx, l:bidx - 1)
                let s:tab.pos[l:tidx] = l:bidx - 1
                let s:tab.sel[l:tidx] = l:bidx - 1
            elseif a:key ==# 'O'
                call s:tab.swapBuffer(l:tidx, l:bidx, l:bidx + 1)
                let s:tab.pos[l:tidx] = l:bidx + 1
                let s:tab.sel[l:tidx] = l:bidx + 1
            endif
            call s:pop(s:lyr.info.state)
        endif
    elseif (s:lyr.info.state ==# s:STATE.Alltab)
        " move buffer to the left or right tab
        if (s:tab.num() < 2)
            call popc#ui#Msg('Number of tab < 2.')
        else
            call popc#ui#Destroy()
            let l:tnr = tabpagenr()
            silent execute string(l:tidx + 1) . 'tabnext'
            if a:key ==# 'I'
                silent normal! gT
            elseif a:key ==# 'O'
                silent normal! gt
            endif
            silent execute 'buffer ' . string(l:bnr)
            call s:closeBuffer(l:tidx, l:bidx)
            silent execute string(l:tnr) . 'tabnext'
            call s:pop(s:lyr.info.state)
        endif
    elseif (s:lyr.info.state ==# s:STATE.Listab)
        " swap tab with the left or right
        if (s:tab.num() < 2)
            call popc#ui#Msg('Number of tab < 2.')
        elseif (a:key ==# 'I' && l:tidx == 0) || (a:key ==# 'O' && l:tidx == s:tab.num() - 1)
            call popc#ui#Msg('Can NOT swap the boundary tab.')
        else
            call popc#ui#Destroy()
            if a:key ==# 'I'
                let l:ltidx = l:tidx - 1
                let l:rtidx = l:tidx
                call s:lyr.setInfo('lastIndex', a:index - 1)
            elseif a:key ==# 'O'
                let l:ltidx = l:tidx
                let l:rtidx = l:tidx + 1
                call s:lyr.setInfo('lastIndex', a:index + 1)
            endif
            silent execute string(l:ltidx + 1) . 'tabnext'
            " BUG: it gets wrong when use '-tabmove', '0tabmove' or '$tabmove'
            noautocmd +tabmove
            call s:tab.swapTab(l:ltidx, l:rtidx)
            call s:pop(s:lyr.info.state)
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#layer#buf#SetTabName(key, index) {{{
function! popc#layer#buf#SetTabName(key, index)
    let l:tidx = s:getIndexs(a:index)[0]
    let l:name = popc#ui#Input('Input tab name: ', gettabvar(l:tidx + 1, 'PopcLayerBuf_TabName'))
    call settabvar(l:tidx + 1, 'PopcLayerBuf_TabName', l:name)
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Edit(key, index) {{{
function! popc#layer#buf#Edit(key, index)
    if s:tab.isTabEmpty()
        return
    endif

    let l:bnr = s:getIndexs(a:index)[2]
    let l:name = getbufinfo(l:bnr)[0].name
    if empty(l:name)
        return
    endif
    let l:file = fnamemodify(l:name, ':h')
    if l:file[len(l:file) - 1] != '/' && l:file[len(l:file) - 1] != '\'
        let l:file = expand(l:file . '/')
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


" SECTION: api functions {{{1

" FUNCTION: popc#layer#buf#CloseBuffer(bang) {{{
" @param bang 0:NOT keep window 1:keep window
function! popc#layer#buf#CloseBuffer(bang)
    let l:tidx = tabpagenr() - 1
    let l:curIdx = index(s:tab.idx[l:tidx], bufnr('%'))

    if a:bang
        call s:closeBuffer(l:tidx, l:curIdx)
        call popc#utils#Log('buf', 'buf num: %s, cur idx: %s', s:tab.num(l:tidx), l:curIdx)
    else
        let l:winNum = 0
        for k in range(1, winnr('$'))
            if index(s:tab.idx[l:tidx], winbufnr(k)) > -1
                let l:winNum += 1
                if l:winNum > 1
                    break
                endif
            endif
        endfor
        call popc#utils#Log('buf', 'buf num: %s, win num: %s, cur idx: %s', s:tab.num(l:tidx), l:winNum, l:curIdx)

        " close buffer only there's only one 'valid win' and more than one buffer of current tab.
        " 'valid win' means one win contains a buffer that was managed by popc-buffer layer.
        if (s:tab.num(l:tidx) > 1) && (l:winNum == 1) && (0 <= l:curIdx && l:curIdx < s:tab.num(l:tidx))
            call s:closeBuffer(l:tidx, l:curIdx)
        else
            quit
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#layer#buf#SwitchBuffer(type) {{{
function! popc#layer#buf#SwitchBuffer(type)
    if s:tab.isTabEmpty()
        return
    endif

    let l:tidx = tabpagenr() - 1
    let l:bidx = index(s:tab.idx[l:tidx], bufnr('%'))

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
    let s:tab.sel[l:tidx] = l:bidx
    silent execute 'buffer ' . string(l:bnr)
endfunction
" }}}

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
        let l:curIdx = index(s:tab.idx[l:tidx], winbufnr(popc#ui#GetVal('winnr')))
    else
        let l:curIdx = index(s:tab.idx[l:tidx], bufnr('%'))
    endif
    if 0 <= l:curIdx && l:curIdx < s:tab.num(l:tidx)
        let s:tab.sel[l:tidx] = l:curIdx
    else
        let l:curIdx = s:tab.sel[l:tidx]
    endif

    for k in range(s:tab.num(l:tidx))
        let l:bnr = s:tab.idx[l:tidx][k]
        let b = getbufinfo(l:bnr)[0]
        call add(l:list, {
                    \ 'index' : string(k+1),
                    \ 'title' : empty(b.name) ? '[' . string(l:bnr) . '.NoName]' : fnamemodify(b.name, ':t'),
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
                              \ . popc#utils#Num2RankStr(s:tab.num(k)),
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

" FUNCTION: popc#layer#buf#GetWksFiles(tabnr) {{{
" this function is used for workspace layer.
function! popc#layer#buf#GetWksFiles(tabnr)
    let l:files = []
    for bnr in s:tab.idx[a:tabnr - 1]
        call add(l:files, getbufinfo(bnr)[0].name)
    endfor
    return l:files
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
            call add(l:files, getbufinfo(bnr)[0].name)
        endfor
    elseif a:type == 'alltab'
        for k in range(s:tab.num())
            for bnr in s:tab.idx[k]
                call add(l:files, getbufinfo(bnr)[0].name)
            endfor
        endfor
    endif
    return l:files
endfunction
" }}}

" FUNCTION: popc#layer#buf#DbgInfo(type) {{{
function! popc#layer#buf#DbgInfo(type)
    let l:info = []
    if empty(a:type)
        call add(l:info, 'idx: ' . string(s:tab.idx))
        call add(l:info, 'pos: ' . string(s:tab.pos))
        call add(l:info, 'sel: ' . string(s:tab.sel))
        call add(l:info, 'lbl: ' . string(s:tab.lbl))
        call add(l:info, 'cnt: ' . string(s:tab.cnt))
    else
        call add(l:info, printf("%s: %s", a:type, string(s:tab[a:type])))
    endif
    return l:info
endfunction
" }}}

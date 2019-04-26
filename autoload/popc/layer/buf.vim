
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
    \ 'nam' : [],
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
"   'nam' : ['test', 'TEST', ...],      " all tab's name
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
let s:mapsData = [
    \ ['popc#layer#buf#Pop'          , ['h', 'a', 'l'],                        'Pop buffers layer (h-Tab buffers, a-All buffers, l-Tab list)'],
    \ ['popc#layer#buf#Load'         , ['CR','Space','s','S','v','V','t','T'], 'Load buffers (CR-Load, Space-Load and stay, svt-Split or tabedit, SVT-Split or tabedit and stay)'],
    \ ['popc#layer#buf#Close'        , ['c', 'C'],                             'Close one buffer (C-Close tab''s all buffer)'],
    \ ['popc#layer#buf#SwitchTab'    , ['i','o'],                              'Switch to left/right(i/o) tab'],
    \ ['popc#layer#buf#MoveBuffer'   , ['I','O'],                              'Move buffer to left/right(I/O) tab'],
    \ ['popc#layer#buf#SetTabName'   , ['n'],                                  'Set current tab name'],
    \ ['popc#layer#buf#Search'       , ['/'],                                  'Search buffer content'],
    \ ['popc#layer#buf#Help'         , ['?'],                                  'Show help of buffers layer'],
    \ ]


" SECTION: dictionary function {{{1

" FUNCTION: s:tab.insertTab(tidx) dict {{{
function! s:tab.insertTab(tidx) dict
    call insert(self.bnr, {}, a:tidx)
    call insert(self.idx, [], a:tidx)
    call insert(self.pos, 0,  a:tidx)
    call insert(self.lbl, '', a:tidx)
    call insert(self.nam, '', a:tidx)
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
    call remove(self.nam, a:tidx)
endfunction
" }}}

" FUNCTION: s:tab.set(opt, tidx, bidx) dict {{{
" @opt: pos, lbl, nam
function! s:tab.set(opt, tidx, bidx) dict
    let self[a:opt][a:tidx] = a:bidx
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

" FUNCTION: s:tab.isTabModified(...) dict {{{
function! s:tab.isTabModified(...) dict
    let l:tidx = (a:0 == 0) ? (tabpagenr() - 1) : a:1
    for bnr in self.idx[l:tidx]
        if getbufvar(str2nr(bnr), '&modified')
            return 1
        endif
    endfor
    return 0
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
            " add buffer to s:tab.bnr
            call extend(l:cbnr, {l:bnr : b.name}, 'force')

            " insert index in order to s:tab.idx
            if (len(l:cidx) == 0) || (l:cbnr[l:cidx[-1]] <= l:cbnr[l:bnr])
                call add(l:cidx, l:bnr)
            else
                for k in range(len(l:cidx))
                    if l:cbnr[l:bnr] < l:cbnr[l:cidx[k]]
                        call insert(l:cidx, l:bnr, k)
                        break
                    endif
                endfor
            endif

            " count reference to s:tab.cnt
            let self.cnt[l:bnr] = has_key(self.cnt, l:bnr) ? self.cnt[l:bnr] + 1 : 1
        endif
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
    " remove unloaded or unlisted buffer of tab
    for k in range(self.num(a:tidx) - 1, 0, -1)    " traversal must in reverse order
        let l:bnr = self.idx[a:tidx][k]
        let b = getbufinfo(str2nr(l:bnr))
        if empty(b) || !b[0].listed || !b[0].loaded
            call s:tab.removeBuffer(a:tidx, l:bnr)
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
    call s:lyr.setInfo('cursorMovedCb', 'popc#layer#buf#CursorMovedCb')

    augroup PopcLayerBufInit
        autocmd!
        autocmd TabNew    * call s:tabCallback('new')
        autocmd TabClosed * call s:tabCallback('close')
        autocmd TabLeave  * call s:tabCallback('leave')
        autocmd BufEnter  * call s:bufCallback('enter')
    augroup END

    for md in s:mapsData
        call s:lyr.addMaps(md[0], md[1])
    endfor
endfunction
" }}}

" FUNCTION: s:tabCallback(type) {{{
function! s:tabCallback(type)
    let l:tidx = tabpagenr() - 1
    if a:type ==# 'new'
        " all tab will be added from here
        call s:tab.insertTab(l:tidx)
    elseif a:type ==# 'close'
        " all tab will be deleted from here
        if exists('s:lastTidx')
            call s:tab.removeTab(s:lastTidx)
            unlet s:lastTidx
        endif
        "call s:tab.removeTab(l:tidx)
    elseif a:type == 'leave'
        let s:lastTidx = l:tidx
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

    " set root path
    let l:root = popc#init#GetRoot()
    if !empty(l:root)
        silent execute 'lcd ' . l:root
    endif

    " create buffer
    if s:lyr.info.state == s:STATE.Sigtab
        let [l:textCnt, l:text] = s:createTabBuffer(tabpagenr() - 1)
    elseif s:lyr.info.state == s:STATE.Alltab
        for k in range(s:tab.num())
            let [c, t] = s:createTabBuffer(k)
            let l:textCnt += c
            let l:text .= t
        endfor
    elseif s:lyr.info.state == s:STATE.Listab
        let [l:textCnt, l:text] = s:createTabList()
    endif
    call s:lyr.setBufs(l:textCnt, l:text)
endfunction
" }}}

" FUNCTION: s:createTabBuffer(tidx) {{{
function! s:createTabBuffer(tidx)
    call s:tab.checkBuffer(a:tidx)
    let l:text = ''
    let l:cbnr = s:tab.bnr[a:tidx]
    let l:cidx = s:tab.idx[a:tidx]

    " join lines
    let l:winid = win_getid(popc#ui#GetRecover().winnr, a:tidx + 1)
    for k in range(len(l:cidx))
        let l:bnr = l:cidx[k]
        let b = getbufinfo(str2nr(l:bnr))[0]

        let l:line  = '  '
        if s:lyr.info.state == s:STATE.Alltab
            if a:tidx == tabpagenr() - 1
                let l:line .= (k > 0) ? '|' : s:conf.symbols.CTab
            else
                let l:line .= (k > 0) ? ' ' : s:conf.symbols.Tab
            endif
        else
            let l:line .= ' '
        endif
        let l:line .= empty(b.windows) ? ' ' : ((join(b.windows, '|') =~ l:winid) ? s:conf.symbols.WIn : s:conf.symbols.WOut)
        let l:line .= b.changed ? '+' : ' '
        let l:line .= ' ' . (empty(b.name) ? '[' . l:bnr . '.NoName]' : fnamemodify(b.name, ':.'))

        while strwidth(l:line) < &columns
            let l:line .= ' '
        endwhile
        let l:text .= l:line . "\n"
    endfor

    return [s:tab.num(a:tidx), l:text]
endfunction
" }}}

" FUNCTION: s:createTabList() {{{
function! s:createTabList()
    let l:text = ''

    for k in range(s:tab.num())
        let l:line = '  '
        let l:line .= (k == tabpagenr() - 1) ? s:conf.symbols.CTab : s:conf.symbols.Tab
        let l:line .= s:tab.isTabModified(k) ? '+' : ' '
        let l:line .= ' ' . '[' . (empty(s:tab.nam[k]) ? s:tab.lbl[k] : s:tab.nam[k]) . ']'
                        \ . popc#ui#Num2RankStr(s:tab.num(k))

        while strwidth(l:line) < &columns
            let l:line .= ' '
        endwhile
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

    if s:lyr.info.state == s:STATE.Sigtab
        let l:tidx = tabpagenr() - 1
    elseif s:lyr.info.state == s:STATE.Alltab
        " calc the bufnr index and tab index in all tabs
        for k in range(s:tab.num())
            if l:bidx >= s:tab.num(k)
                let l:bidx -= s:tab.num(k)
                let l:tidx += 1
            else
                break
            endif
        endfor
    elseif s:lyr.info.state == s:STATE.Listab
        let l:tidx = l:bidx
        let l:bidx = s:tab.pos[l:tidx]
    endif

    return [l:tidx, l:bidx, (s:tab.num() && s:tab.num(l:tidx)) ? s:tab.idx[l:tidx][l:bidx] : '']
endfunction
" }}}

" FUNCTION: popc#layer#buf#CursorMovedCb(index) {{{
function! popc#layer#buf#CursorMovedCb(index)
    if (s:lyr.info.state == s:STATE.Sigtab) || (s:lyr.info.state == s:STATE.Alltab)
        let [l:tidx, l:bidx] = s:getIndexs(a:index)[0:1]
        call s:tab.set('pos', l:tidx, l:bidx)
    endif
endfunction
" }}}

" FUNCTION: s:pop(state) {{{
function! s:pop(state)
    call s:lyr.setMode(s:MODE.Normal)
    call s:lyr.setInfo('state', a:state)
    call s:createBuffer()
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Pop(key) {{{
function! popc#layer#buf#Pop(key)
    if (a:key ==# 'h')
        \ || (a:key ==# 'a' && s:lyr.info.state == s:STATE.Alltab)
        \ || (a:key ==# 'l' && s:lyr.info.state == s:STATE.Listab)
        call s:lyr.setInfo('lastIndex', s:tab.pos[tabpagenr() - 1])
        let l:state = s:STATE.Sigtab
    elseif a:key ==# 'a'
        " calculate buffer index from Sigle or Listab
        if (s:lyr.info.state == s:STATE.Sigtab) || (s:lyr.info.state == s:STATE.Listab)
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
        if (s:lyr.info.state == s:STATE.Sigtab) || (s:lyr.info.state == s:STATE.Alltab)
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
    if s:lyr.info.state == s:STATE.Listab
        " load tab
        if a:key ==# 'CR'
            silent execute string(l:tidx + 1) . 'tabnext'
        elseif a:key ==# 'Space'
            silent execute string(l:tidx + 1) . 'tabnext'
            call s:pop(s:lyr.info.state)
        endif
    else
        " load buffer
        if a:key ==# 'CR'
            silent execute string(l:tidx + 1) . 'tabnext'
            silent execute 'buffer ' . l:bnr
        elseif a:key ==# 'Space'
            silent execute 'buffer ' . l:bnr
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

    " close vim's buffer buf keep tab (use noautocmd to avoid 'updateBuffer')
    let l:tnr = tabpagenr()
    silent execute 'noautocmd' . string(a:tidx + 1) . 'tabnext'
    if s:tab.isTabEmpty(a:tidx)
        enew
    else
        silent execute 'noautocmd buffer ' . s:tab.idx[a:tidx][
                    \ (a:bidx < s:tab.num(a:tidx)) ? a:bidx : a:bidx - 1]
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

    if a:key ==# 'C' || s:lyr.info.state == s:STATE.Listab
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
    if s:lyr.info.state == s:STATE.Alltab
        silent execute string(l:tidx + 1) . 'tabnext'
    endif
    " goto target tab
    if a:key == 'I'
        silent normal! gT
    elseif a:key == 'O'
        silent normal! gt
    endif
    " move buffer from origin tab to target tab
    if s:lyr.info.state == s:STATE.Listab
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
    let l:name = popc#ui#Input('Input tab name: ', s:tab.nam[l:tidx])
    call s:tab.set('nam', l:tidx, l:name)
    call s:pop(s:lyr.info.state)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Search(key) {{{
function! popc#layer#buf#Search(key)
    if s:tab.isTabEmpty()
        return
    endif

    " TODO(required or not?): search content of tab's buffer
    return

    call popc#ui#Destroy()
    call s:lyr.setMode(s:MODE.Search)
    "call s:lyr.setBufs(, s:createSearchBuffer())
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#layer#buf#Help(key) {{{
function! popc#layer#buf#Help(key)
    call s:lyr.setMode(s:MODE.Help)
    call s:lyr.setBufs(len(s:mapsData), popc#layer#com#createHelpBuffer(s:mapsData))
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}


" SECTION: api for tabline {{{1

" FUNCTION: popc#layer#buf#GetBufs(tabnr) abort {{{
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
                    \ 'index' : k,
                    \ 'title' : empty(b.name) ? '[' . l:bnr . '.NoName]' : fnamemodify(b.name, ':t'),
                    \ 'modified' : b.changed ? 1 : 0,
                    \ 'selected' : (k == l:curIdx) ? 1 : 0,
                    \ })
    endfor
    return l:list
endfunction
" }}}

" FUNCTION: popc#layer#buf#GetTabs() abort {{{
function! popc#layer#buf#GetTabs() abort
    let l:list = []
    for k in range(s:tab.num())
        call add(l:list, {
                    \ 'index' : k,
                    \ 'title' : '[' . (empty(s:tab.nam[k]) ? s:tab.lbl[k] : s:tab.nam[k]) . ']'
                              \ . popc#ui#Num2RankStr(s:tab.num(k)),
                    \ 'modified' : s:tab.isTabModified(k),
                    \ 'selected' : (k+1 == tabpagenr()) ? 1 : 0,
                    \ })
    endfor
    return l:list
endfunction
" }}}

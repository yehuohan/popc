
" bookmark layer.

" SECTION: variables {{{1

let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}          " this layer
let s:bms = []          " bookmarks from .popc.json
let s:mapsData = [
    \ ['popc#layer#bms#Pop'   , ['b'],                                  'Pop bookmarks layer'],
    \ ['popc#layer#bms#Load'  , ['CR','Space','s','S','v','V','t','T'], 'Load bookmark (CR-Open, Space-Stay, sSvV-Split, tT-Tab)'],
    \ ['popc#layer#bms#Add'   , ['a'],                                  'Add file as bookmark'],
    \ ['popc#layer#bms#Delete', ['d'],                                  'Delete one bookmark'],
    \ ['popc#layer#bms#Sort'  , ['g'],                                  'Display sorted bookmaks'],
    \ ['popc#layer#bms#Help'  , ['?'],                                  'Show help of bookmarks layer'],
    \ ]

" SECTION: functions {{{1

" FUNCTION: popc#layer#bms#Init() {{{
function! popc#layer#bms#Init()
    let s:lyr = s:popc.addLayer('Bookmark')
    call s:lyr.setInfo('sort', 'path')
    call s:lyr.setInfo('centerText', s:conf.symbols.Bm)

    for md in s:mapsData
        call s:lyr.addMaps(md[0], md[1])
    endfor
endfunction
" }}}

" FUNCTION: s:createBuffer() {{{
function! s:createBuffer()
    let l:text = ''

    " get max name width
    let l:max = 0
    for item in s:bms
        let l:wid = strwidth(item.name)
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    let l:max += 2

    " get context
    for k in range(len(s:bms))
        let l:line =  '  ' . s:bms[k].name
        let l:line .= repeat(' ', l:max - strwidth(l:line)) . ' ' . s:conf.symbols.Arr . ' '
        let l:line .= s:bms[k].path
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
    endfor

    call s:lyr.setBufs(v:t_string, len(s:bms), l:text)
endfunction
" }}}

" FUNCTION: popc#layer#bms#Pop(key) {{{
function! popc#layer#bms#Pop(key)
    let s:bms = popc#init#GetJson('json').bookmarks
    call s:lyr.setMode(s:MODE.Normal)
    call s:createBuffer()
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#layer#bms#Load(type) {{{
function! popc#layer#bms#Load(key)
    if empty(s:bms)
        return
    endif

    let l:index = popc#ui#GetIndex()
    call popc#ui#Destroy()
    if a:key ==# 'CR'
        silent execute 'edit ' . s:bms[l:index].path . '/' . s:bms[l:index].name
    elseif a:key ==# 'Space'
        silent execute 'edit ' . s:bms[l:index].path . '/' . s:bms[l:index].name
        call popc#ui#Create(s:lyr.name)
    else
        if a:key ==? 's'
            silent execute 'split ' . s:bms[l:index].path . '/' . s:bms[l:index].name
        elseif a:key ==? 'v'
            silent execute 'vsplit ' . s:bms[l:index].path . '/' . s:bms[l:index].name
        elseif a:key ==? 't'
            silent execute 'tabedit ' . s:bms[l:index].path . '/' . s:bms[l:index].name
        endif
        if a:key =~# '[SVT]'
            call popc#ui#Create(s:lyr.name)
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#layer#bms#Add(key) {{{
function! popc#layer#bms#Add(key)
    let l:rc = popc#ui#GetRecover()
    let l:name = fnamemodify(l:rc.file, ':p:t')
    let l:path = fnamemodify(l:rc.file, ':p:h')

    if empty(l:name) || empty(l:path)
        call popc#ui#Msg('Nothing can add to bookmarks.')
        return
    endif
    for item in s:bms
        if l:name ==# item.name && l:path ==# item.path
            call popc#ui#Msg('Bookmark ''' . l:name . ''' is already existed.')
            return
        endif
    endfor
    if !popc#ui#Confirm('Add to bookmarks: ' . l:rc.file . " ?")
        return
    endif

    call add(s:bms, {'name' : l:name, 'path' : l:path})
    call popc#init#SaveJson()
    call popc#layer#bms#Pop('b')
    call popc#ui#Msg('Add bookmark ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#bms#Delete(key) {{{
function! popc#layer#bms#Delete(key)
    if empty(s:bms)
        return
    endif

    let l:index = popc#ui#GetIndex()
    let l:name = s:bms[l:index].name

    if !popc#ui#Confirm('Delete bookmark ''' . l:name . ''' ?')
        return
    endif

    call remove(s:bms, l:index)
    call popc#init#SaveJson()
    call popc#layer#bms#Pop('b')
    call popc#ui#Msg('Delete bookmark ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#bms#Sort(key) {{{
function! popc#layer#bms#Sort(key)
    if empty(s:bms)
        return
    endif

    if s:lyr.info.sort ==# 'name'
        call sort(s:bms, function('popc#utils#SortByPath'))
        call s:lyr.setInfo('sort', 'path')
    elseif s:lyr.info.sort ==# 'path'
        call sort(s:bms, function('popc#utils#SortByName'))
        call s:lyr.setInfo('sort', 'name')
    endif
    call popc#init#SaveJson()
    call popc#layer#bms#Pop('b')
    call popc#ui#Msg('Bookmarks sorted by: ''' . s:lyr.info.sort  . '''.')
endfunction
" }}}

" FUNCTION: popc#layer#bms#Help(key) {{{
function! popc#layer#bms#Help(key)
    call s:lyr.setMode(s:MODE.Help)
    let [l:cnt, l:txt] = popc#utils#createHelpBuffer(s:mapsData)
    call s:lyr.setBufs(v:t_string, l:cnt, l:txt)
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}


" SECTION: api functions {{{1
" FUNCTION: popc#layer#bms#GetBmsFiles() {{{
function! popc#layer#bms#GetBmsFiles()
    let l:files = []
    let s:bms = popc#init#GetJson('json').bookmarks
    for item in s:bms
        call add(l:files, item.path . '/' . item.name)
    endfor
    return l:files
endfunction
" }}}

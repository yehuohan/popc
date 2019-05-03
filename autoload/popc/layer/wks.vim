
" workspace layer.

" SECTION: variables {{{1

let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}          " this layer
let s:wks = []          " workspaces from .popc.json
let s:view = {
    \ 'name': '',
    \ 'files': [],
    \ 'windows': [],
    \ }
let s:mapsData = [
    \ ['popc#layer#wks#Pop'    , ['w'],                  'Pop workspace layer'],
    \ ['popc#layer#wks#Load'   , ['CR','Space','t','T'], 'Load workspace (CR-Open, Space-Stay, tT-Tab)'],
    \ ['popc#layer#wks#Add'    , ['a'],                  'Add new workspace'],
    \ ['popc#layer#wks#Save'   , ['s'],                  'Save the workspace'],
    \ ['popc#layer#wks#Delete' , ['d'],                  'Delete the workspace'],
    \ ['popc#layer#wks#Close'  , ['C'],                  'Close current workspace'],
    \ ['popc#layer#wks#SetName', ['n'],                  'Set workspace''s name'],
    \ ['popc#layer#wks#Sort'   , ['g'],                  'Display sorted workspaces'],
    \ ['popc#layer#wks#Help'   , ['?'],                  'Show help of workspaces layer'],
    \]


" SECTION: functions {{{1

" FUNCTION: popc#layer#wks#Init() {{{
function! popc#layer#wks#Init()
    let s:lyr = s:popc.addLayer('Workspace')
    call s:lyr.setInfo('sort', 'path')
    call s:lyr.setInfo('wksName', '')
    call s:lyr.setInfo('rootDir', '')
    call s:lyr.setInfo('centerText', s:conf.symbols.Wks)
    let s:wks = popc#init#GetJson().json.workspaces

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
    for item in s:wks
        let l:wid = strwidth(item.name)
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    let l:max += 2

    " get context
    for k in range(len(s:wks))
        let l:line =  '  ' . s:wks[k].name
        let l:line .= repeat(' ', l:max - strwidth(l:line)) . ' ' . s:conf.symbols.Arr . ' '
        let l:line .= s:wks[k].path
        while strwidth(l:line) < &columns
            let l:line .= ' '
        endwhile

        let l:text .= l:line . "\n"
    endfor

    call s:lyr.setBufs(v:t_string, len(s:wks), l:text)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Pop(key) {{{
function! popc#layer#wks#Pop(key)
    call s:lyr.setMode(s:MODE.Normal)
    call s:createBuffer()
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: s:createView(tnr, bnrs) {{{
function! s:createView(tnr, bnrs)
    let l:view = deepcopy(s:view)

    " tab name
    let l:view.name = gettabvar(a:tnr, 'PopcLayerBuf_TabName')
    " buffer's file
    for bnr in a:bnrs
        let l:bname = getbufinfo(str2nr(bnr))[0].name
        if !empty(l:bname)
            call add(l:view.files, l:bname)
        endif
    endfor
    " tab's window layout
    let l:wids = gettabinfo(a:tnr)[0].windows
    for wid in l:wids
        let l:bnr = winbufnr(wid)
        if -1 == index(a:bnrs, string(l:bnr))
            continue
        endif
        call add(l:view.windows, {
                                \ 'bname' : bufname(l:bnr),
                                \ 'wid' : winwidth(wid),
                                \ 'hei' : winheight(wid),
                                \ })
    endfor

    return l:view
endfunction
" }}}

" FUNCTION: s:dispView(tnr, view) {{{
function! s:dispView(tnr, view)
    silent execute string(a:tnr) . 'tabnext'

    " tab name
    if !empty(a:view.name)
        call settabvar(a:tnr, 'PopcLayerBuf_TabName', a:view.name)
    endif
    " buffer's file
    for fname in a:view.files
        if filereadable(fname)
            silent execute 'edit ' . fname
        endif
    endfor
    " tab's window layout
    for k in range(len(a:view.windows))
        if k > 0
            silent execute float2nr(fmod(k, 2)) ? 'vsplit' : 'split'
        endif
        silent execute 'buffer ' . string(bufnr(a:view.windows[k].bname))
    endfor
endfunction
" }}}

" FUNCTION: s:saveWorkspace(name, path) {{{
function! s:saveWorkspace(name, path)
    let l:ws = []
    for tnr in range(1, tabpagenr('$'))
        call add(l:ws, s:createView(tnr, popc#layer#buf#GetView(tnr)))
    endfor

    let l:file = popc#init#GetJson().dir . '/wks.' . a:name
    let l:jsonWs = json_encode(l:ws)
    call writefile([l:jsonWs], l:file)

    " set root and name of layer
    call s:lyr.setInfo('wksName', a:name)
    call s:lyr.setInfo('rootDir', a:path)
endfunction
" }}}

" FUNCTION: s:loadWorkspace(name, path, ...) {{{
" param(a:1): the base tab nr to display view of tab
function! s:loadWorkspace(name, path, ...)
    let l:file = popc#init#GetJson().dir . '/wks.' . a:name
    if !filereadable(l:file)
        call popc#ui#Msg('Nothing in workspace''' . a:name . '''.')
        return
    endif

    let l:base = (a:0 >= 1) ? a:1 : 0
    let l:ws = json_decode(join(readfile(l:file)))
    for k in range(len(l:ws))
        if tabpagenr('$') < (l:base + k + 1)
            tabedit
        endif
        call s:dispView(l:base + k + 1, l:ws[k])
    endfor

    " set widget's title
    if &title
        silent execute 'set titlestring=' . a:name
    endif

    " set root and name of layer
    call s:lyr.setInfo('wksName', a:name)
    call s:lyr.setInfo('rootDir', a:path)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Close(key) {{{
function! popc#layer#wks#Close(key)
    if !popc#ui#Confirm('Close all buffers and tabs in current workspace?')
        return
    endif
    call popc#layer#buf#Empty()
endfunction
" }}}

" FUNCTION: popc#layer#wks#Load(key) {{{
function! popc#layer#wks#Load(key)
    if empty(s:wks)
        return
    endif

    let l:index = popc#ui#GetIndex()
    let l:name = s:wks[l:index].name
    let l:path = s:wks[l:index].path

    call popc#ui#Destroy()
    if a:key ==# 'CR' || a:key ==# 'Space'
        call popc#layer#buf#Empty()
        call s:loadWorkspace(l:name, l:path)
    elseif a:key ==? 't'
        call s:loadWorkspace(l:name, l:path, tabpagenr('$'))
    endif
    if a:key ==# 'Space' || a:key ==# 'T'
        call popc#layer#wks#Pop('w')
    endif
    call popc#ui#Msg('Load workspace ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#Add(key) {{{
function! popc#layer#wks#Add(key)
    " workspace name
    let l:name = popc#ui#Input('Input workspace name: ')
    if empty(l:name)
        call popc#ui#Msg('No name for workspace.')
        return
    endif
    for item in s:wks
        if l:name ==# item.name
            call popc#ui#Msg('Workspace ''' . l:name . ''' is already existed.')
            return
        endif
    endfor
    " workspace path
    let l:path = popc#ui#Input('Input workspace root: ', popc#ui#FindRoot(), 'dir')
    if empty(l:path)
        call popc#ui#Msg('No root for workspace.')
        return
    endif
    let l:path = fnamemodify(l:path, ':p')
    " save workspace
    call s:saveWorkspace(l:name, l:path)
    call add(s:wks, {'name' : l:name, 'path' : l:path})
    call popc#init#SaveJson()
    call popc#layer#wks#Pop('w')
    call popc#ui#Msg('Add workspace ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#Save(key) {{{
function! popc#layer#wks#Save(key)
    if empty(s:wks)
        return
    endif

    let l:index = popc#ui#GetIndex()
    let l:name = s:wks[l:index].name
    let l:path = s:wks[l:index].path

    if empty(s:lyr.info.wksName)
        if !popc#ui#Confirm('Override workspace ''' . l:name . ''' ?')
            return
        endif
    elseif l:name !=# s:lyr.info.wksName
        call popc#ui#Msg('This is NOT current workspace: ' . s:lyr.info.wksName . ' [' . s:lyr.info.rootDir . ']')
        return
    endif

    call s:saveWorkspace(l:name, l:path)
    call popc#ui#Msg('Save workspace ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#Delete(key) {{{
function! popc#layer#wks#Delete(key)
    if empty(s:wks)
        return
    endif

    let l:index = popc#ui#GetIndex()
    let l:name = s:wks[l:index].name
    if !popc#ui#Confirm('Delete workspace ''' . l:name . ''' ?')
        return
    endif

    let l:file = popc#init#GetJson().dir . '/wks.' . l:name
    if filereadable(l:file)
        call delete(l:file)
    endif
    call remove(s:wks, l:index)
    call popc#init#SaveJson()
    call popc#layer#wks#Pop('w')
    call popc#ui#Msg('Delete workspace ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#SetName(key) {{{
function! popc#layer#wks#SetName(key)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Sort(key) {{{
function! popc#layer#wks#Sort(key)
    if empty(s:wks)
        return
    endif

    if s:lyr.info.sort ==# 'name'
        call sort(s:wks, function('popc#layer#com#SortByPath'))
        call s:lyr.setInfo('sort', 'path')
    elseif s:lyr.info.sort ==# 'path'
        call sort(s:wks, function('popc#layer#com#SortByName'))
        call s:lyr.setInfo('sort', 'name')
    endif
    call popc#init#SaveJson()
    call popc#layer#wks#Pop('w')
    call popc#ui#Msg('Workspaces sorted by: ''' . s:lyr.info.sort  . '''.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#Help(key) {{{
function! popc#layer#wks#Help(key)
    call s:lyr.setMode(s:MODE.Help)
    call s:lyr.setBufs(v:t_string, len(s:mapsData), popc#layer#com#createHelpBuffer(s:mapsData))
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

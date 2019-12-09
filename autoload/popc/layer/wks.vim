
" workspace layer.

" SECTION: variables {{{1

let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}          " this layer
let s:wks = []          " workspaces from .popc.json
let s:mapsData = [
    \ ['popc#layer#wks#Pop'    , ['w'],                  'Pop workspace layer'],
    \ ['popc#layer#wks#Load'   , ['CR','Space','t','T'], 'Load workspace (CR-Open, Space-Stay, tT-Tab)'],
    \ ['popc#layer#wks#Add'    , ['a'],                  'Add new workspace'],
    \ ['popc#layer#wks#Save'   , ['s', 'S'],             'Save the workspace (S-Save in force)'],
    \ ['popc#layer#wks#Delete' , ['d'],                  'Delete the workspace'],
    \ ['popc#layer#wks#Close'  , ['C'],                  'Close current workspace'],
    \ ['popc#layer#wks#SetName', ['n'],                  'Set name of workspace'],
    \ ['popc#layer#wks#SetRoot', ['r'],                  'Set root of workspace'],
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
    let l:max += 4

    " get context
    for k in range(len(s:wks))
        let l:line =  '  '
        let l:line .= (s:lyr.info.wksName ==# s:wks[k].name && s:lyr.info.rootDir ==# s:wks[k].path) ? s:conf.symbols.WIn : ' '
        let l:line .= ' ' . s:wks[k].name
        let l:line .= ' ' . repeat(' ', l:max - strwidth(l:line)) . s:conf.symbols.Arr
        let l:line .= ' ' . s:wks[k].path
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
    endfor

    call s:lyr.setBufs(v:t_string, len(s:wks), l:text)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Pop(key) {{{
function! popc#layer#wks#Pop(key)
    let s:wks = popc#init#GetJson('json').workspaces
    call s:lyr.setMode(s:MODE.Normal)
    call s:createBuffer()
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: s:useSlash(path, endslash) {{{
function! s:useSlash(path, endslash)
    let l:path = popc#utils#useSlashPath(a:path)
    if a:endslash && l:path !~# '/$'
        let l:path .= '/'
    elseif !a:endslash && l:path =~# '/$'
        let l:path = strcharpart(l:path, 0, strchars(l:path) - 1)
    endif
    return l:path
endfunction
" }}}

" FUNCTION: s:switchSettings(switch) {{{
function! s:switchSettings(switch)
    if a:switch ==# 'on'
        " sessionoptions
        let l:ssopSave = &sessionoptions
        set sessionoptions=winsize,tabpages,slash,unix,curdir
        " switchbuf
        if !empty(&switchbuf)
            let s:swbSave = &switchbuf
            set switchbuf=
        endif
        " autochdir
        if &autochdir
            let s:acdSave = 1
            set noautochdir
        endif
    elseif a:switch ==# 'off'
        " sessionoptions
        if exists('s:ssopSave')
            let &sessionoptions = s:ssopSave
            unlet s:ssopSave
        endif
        " switchbuf
        if exists('s:swbSave')
            let &switchbuf = s:swbSave
            unlet! s:swbSave
        endif
        " autochdir
        if exists('s:acdSave')
            set autochdir
            unlet! s:acdSave
        endif
    endif
endfunction
" }}}

" FUNCTION: s:makeSession(filename, root) {{{
function! s:makeSession(filename, root)
    let l:lines = [
            \ 'let s:session_root = popc#layer#wks#GetCurrentWks()[1]',
            \ 'let s:session_tabbase = tabpagenr()']
    let l:root = escape(fnameescape(a:root), '\')   " <Space> must convert to '\\ '
    let l:tabnr = 1
    for l:cmd in readfile(a:filename)
        if l:cmd =~# '^cd'
            call add(l:lines, 'exe "cd " . s:session_root')
        elseif l:cmd =~# '^lcd'
            call add(l:lines, 'exe "lcd " . s:session_root')
        elseif ((l:cmd =~# '^%argdel') && (l:tabnr == 1)) ||
             \ ((l:cmd =~# '^tabnew') && (l:tabnr > 1)) ||
             \ ((l:cmd =~# '^tabedit') && (l:tabnr > 1))
            " add tab files
            call add(l:lines, l:cmd)
            let l:tabfiles = popc#layer#buf#GetWksFiles(l:tabnr)
            for l:file in l:tabfiles
                let l:file = fnameescape(s:useSlash(l:file, 0))
                call add(l:lines, substitute('edit ' . l:file, l:root, '', 'g'))
            endfor
            let l:tabnr += 1
        elseif l:cmd =~# '^tabrewind'
            " start from base tabnr
            call add(l:lines, 'exe "tabnext " . s:session_tabbase')
        elseif l:cmd =~# '^tabnext \d\+'
            " back to init tab
            let l:inc = string(str2nr(split(l:cmd)[-1]) - 1)
            call add(l:lines, 'exe "tabnext " . string(s:session_tabbase + ' . l:inc . ')')
        elseif l:cmd =~# 'win_findbuf(s:wipebuf)'
            " only remove no name buffer
            call add(l:lines, 'if exists(''s:wipebuf'') && empty(bufname(s:wipebuf))')
        elseif l:cmd =~# l:root
            " use relative path to root
            call add(l:lines, substitute(l:cmd, l:root, '', 'g'))
        elseif l:cmd =~# '^\$argadd' || l:cmd =~# '^silent only' || l:cmd =~# '^silent tabonly'
            " delete lines
            continue
        else
            call add(l:lines, l:cmd)
        endif
    endfor
    call writefile(l:lines, a:filename)
endfunction
" }}}

" FUNCTION: s:saveWorkspace(name, root) {{{
function! s:saveWorkspace(name, root)
    let l:filename = s:getWksFileName(a:name, a:root)

    " set root and name of layer
    call s:lyr.setInfo('wksName', a:name)
    call s:lyr.setInfo('rootDir', a:root)
    " set widget's title
    if &title
        silent execute 'set titlestring=' . a:name
    endif

    call s:switchSettings('on')
    execute 'cd ' . a:root
    silent execute 'mksession! ' . l:filename
    call s:makeSession(l:filename, a:root)
    call s:switchSettings('off')
endfunction
" }}}

" FUNCTION: s:loadWorkspace(name, root) {{{
function! s:loadWorkspace(name, root)
    let l:filename = s:getWksFileName(a:name, a:root)
    if !filereadable(l:filename)
        return 0
    endif

    " set root and name of layer
    call s:lyr.setInfo('wksName', a:name)
    call s:lyr.setInfo('rootDir', a:root)
    " set widget's title
    if &title
        silent execute 'set titlestring=' . a:name
    endif

    call s:switchSettings('on')
    execute 'cd ' . a:root
    silent execute 'source ' . l:filename
    call s:switchSettings('off')
    return 1
endfunction
" }}}

" FUNCTION: s:checkWksFile(name, path) {{{
function! s:checkWksFile(name, path)
    if s:conf.useLayerPath
        for item in s:wks
            if a:name ==# item.name && a:path ==# item.path
                return 0
            endif
        endfor
    else
        for item in s:wks
            if a:name ==# item.name
                return 0
            endif
        endfor
    endif
    return 1
endfunction
" }}}

" FUNCTION: s:getWksFilePath(root) {{{
function! s:getWksFilePath(root)
    if s:conf.useLayerPath
        let l:path = a:root . '.popc'
        if !isdirectory(l:path)
            call mkdir(l:path, 'p')
        endif
    else
        let l:path = popc#init#GetJson('dir')
    endif
    return l:path
endfunction
" }}}

" FUNCTION: s:getWksFileName(name, root) {{{
function! s:getWksFileName(name, root)
    return (s:getWksFilePath(a:root) . '/' . a:name . '.wks')
endfunction
" }}}

" FUNCTION: popc#layer#wks#Close(key) {{{
function! popc#layer#wks#Close(key)
    if !popc#ui#Confirm('Close all buffers and tabs in current workspace?')
        return
    endif
    call popc#layer#buf#Empty()
    if &title
        set titlestring=
    endif
    call s:lyr.setInfo('wksName', '')
    call s:lyr.setInfo('rootDir', '')
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
    call popc#ui#Msg('Loading workspace ''' . l:name . ''' ......')
    if a:key ==# 'CR' || a:key ==# 'Space'
        call popc#layer#buf#Empty()
    elseif a:key ==? 't'
        tablast
        tabedit
    endif
    let l:ret = s:loadWorkspace(l:name, l:path)
    if l:ret
        if a:key ==# 'Space' || a:key ==# 'T'
            call popc#layer#wks#Pop('w')
        endif
        call popc#ui#Msg('Load workspace ''' . l:name . ''' successful.')
    else
        call popc#layer#wks#Pop('w')
        call popc#ui#Msg('The workspace ''' . l:name . ''' is NOT valid which should be removed.')
    endif
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
    " workspace root
    let l:path = popc#ui#Input(
                \ 'Input workspace root: ',
                \ empty(s:lyr.info.rootDir) ? popc#utils#FindRoot() : s:lyr.info.rootDir,
                \ 'dir')
    if empty(l:path)
        call popc#ui#Msg('No root for workspace.')
        return
    endif
    let l:path = s:useSlash(fnamemodify(l:path, ':p'), 1)
    " check workspace
    if !s:checkWksFile(l:name, l:path)
        call popc#ui#Msg('Workspace ''' . l:name . ''' is already existed.')
        return
    endif
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

    if a:key ==# 's'
        if l:name !=# s:lyr.info.wksName || l:path !=# s:lyr.info.rootDir
            call popc#ui#Msg('Can NOT override with the workspace: ' . s:lyr.info.wksName . ' [' . s:lyr.info.rootDir . ']')
            return
        elseif !popc#ui#Confirm('Save to workspace ''' . l:name . ''' ?')
            return
        endif
    elseif a:key ==# 'S'
        if !popc#ui#Confirm('ATTENTION: Override the workspace ''' . l:name . ''' in force?')
            return
        endif
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
    let l:path = s:wks[l:index].path
    if !popc#ui#Confirm('Delete workspace ''' . l:name . ''' ?')
        return
    endif
    " delete wks file
    let l:filename = s:getWksFileName(l:name, l:path)
    if filereadable(l:filename)
        call delete(l:filename)
    endif
    " save
    call remove(s:wks, l:index)
    call popc#init#SaveJson()
    call popc#layer#wks#Pop('w')
    call popc#ui#Msg('Delete workspace ''' . l:name . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#SetName(key) {{{
function! popc#layer#wks#SetName(key)
    if empty(s:wks)
        return
    endif

    let l:index = popc#ui#GetIndex()
    let l:name = s:wks[l:index].name
    let l:path = s:wks[l:index].path
    " workspace name
    let l:newName = popc#ui#Input('Input new workspace name: ')
    if empty(l:newName)
        call popc#ui#Msg('No new name for workspace.')
        return
    endif
    " check workspace
    if !s:checkWksFile(l:newName, l:path)
        call popc#ui#Msg('Workspace ''' . l:newName . ''' is already existed.')
        return
    endif
    " rename <name>.wks file
    let l:oldFile = s:getWksFileName(l:name, l:path)
    let l:newFile = s:getWksFileName(l:newName, l:path)
    call rename(l:oldFile, l:newFile)
    " save
    let s:wks[l:index].name = l:newName
    if &title
        silent execute 'set titlestring=' . l:newName
    endif
    call s:lyr.setInfo('wksName', l:newName)
    call popc#init#SaveJson()
    call popc#layer#wks#Pop('w')
    call popc#ui#Msg('Rename workspace to ''' . l:newName . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#SetRoot(key) {{{
" not only change root of workspace but also move the wks file.
function! popc#layer#wks#SetRoot(key)
    if empty(s:wks)
        return
    endif

    let l:index = popc#ui#GetIndex()
    let l:name = s:wks[l:index].name
    let l:path = s:wks[l:index].path
    " workspace root
    let l:newPath = popc#ui#Input('Input new workspace root: ', l:path, 'dir')
    if empty(l:newPath)
        call popc#ui#Msg('No new root for workspace.')
        return
    endif
    let l:newPath = s:useSlash(fnamemodify(l:newPath, ':p'), 1)
    let s:wks[l:index].path = l:newPath
    call s:lyr.setInfo('rootDir', l:newPath)
    " move wks file
    let l:oldFile = s:getWksFileName(l:name, l:path)
    let l:newFile = s:getWksFileName(l:name, l:newPath)
    if l:oldFile !=# l:newFile && filereadable(l:oldFile)
        call rename(l:oldFile, l:newFile)
        call delete(l:oldFile)
    endif
    " save
    call popc#init#SaveJson()
    call popc#layer#wks#Pop('w')
    call popc#ui#Msg('Set root of workspace to ''' . l:newPath . ''' successful.')
endfunction
" }}}

" FUNCTION: popc#layer#wks#Sort(key) {{{
function! popc#layer#wks#Sort(key)
    if empty(s:wks)
        return
    endif

    if s:lyr.info.sort ==# 'name'
        call sort(s:wks, function('popc#utils#SortByPath'))
        call s:lyr.setInfo('sort', 'path')
    elseif s:lyr.info.sort ==# 'path'
        call sort(s:wks, function('popc#utils#SortByName'))
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
    let [l:cnt, l:txt] = popc#utils#createHelpBuffer(s:mapsData)
    call s:lyr.setBufs(v:t_string, l:cnt, l:txt)
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" SECTION: api functions {{{1

" FUNCTION: popc#layer#wks#GetCurrentWks() {{{
" return current workspace name and root path.
" be attention that workspace name and root path can be empty.
function! popc#layer#wks#GetCurrentWks()
    return [s:lyr.info.wksName, s:lyr.info.rootDir]
endfunction
" }}}

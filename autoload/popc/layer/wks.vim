
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
    \ ['popc#layer#wks#Save'   , ['s'],                  'Save the workspace'],
    \ ['popc#layer#wks#Delete' , ['d'],                  'Delete the workspace'],
    \ ['popc#layer#wks#SetName', ['n'],                  'Set workspace''s name'],
    \ ['popc#layer#wks#Sort'   , ['g'],                  'Display sorted workspaces'],
    \ ['popc#layer#wks#Help'   , ['?'],                  'Show help of workspaces layer'],
    \]


" SECTION: functions {{{1

" FUNCTION: popc#layer#wks#Init() {{{
function! popc#layer#wks#Init()
    let s:lyr = s:popc.addLayer('Workspace')
    call s:lyr.setInfo('sort', 'path')
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

    call s:lyr.setBufs(len(s:wks), l:text)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Pop(key) {{{
function! popc#layer#wks#Pop(key)
    call s:lyr.setMode(s:MODE.Normal)
    call s:createBuffer()
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Load(key) {{{
function! popc#layer#wks#Load(key)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Add(key) {{{
function! popc#layer#wks#Add(key)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Save(key) {{{
function! popc#layer#wks#Save(key)
endfunction
" }}}

" FUNCTION: popc#layer#wks#Delete(key) {{{
function! popc#layer#wks#Delete(key)
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
    call s:lyr.setBufs(len(s:mapsData), popc#layer#com#createHelpBuffer(s:mapsData))
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

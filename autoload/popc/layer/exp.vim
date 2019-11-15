
" example layer

" SECTION: variables {{{1

let [s:popc, s:MODE] = popc#popc#GetPopc()
let s:conf = popc#init#GetConfig()
let s:lyr = {}          " this layer
let s:exp = [
    \ 'This is example layer.',
    \ 'Add layer init function: let g:Popc_layerInit={"Exp": "popc#layer#exp#Init"}',
    \ 'Add layer common maps if necessary: let g:Popc_layerComMaps = {"Exp" : ["popc#layer#exp#Pop", "p"]}',
    \ 'Use s:popc.addLayer to add layer.',
    \ 'Use s:popc.removeLayer to remove layer.',
    \ 'Use s:lyr.addMaps to add maps for layer.',
    \ 'Use s:lyr.setMode to change mode of layer.',
    \ 'Use s:lyr.setBufs to set layer content fo show.',
    \ 'Use s:lyr.setInfo to set layer information data.',
    \ 'Use popc#ui#Create open layer.',
    \ 'Use popc#ui#Destroy close layer.',
    \ 'Use popc#ui#GetIndex to get current content index.',
    \ 'Use popc#ui#Input to get input.',
    \ 'Use popc#ui#Confirm to show confirm interface.',
    \ 'Use popc#ui#Msg to show message.',
    \ ]
let s:mapsData = [
    \ ['popc#layer#exp#Pop'  , ['p'],          'Pop example layer'],
    \ ['popc#layer#exp#Get'  , ['CR','Space'], 'Get example layer content'],
    \ ['popc#layer#exp#Help' , ['?'],          'Show help of example layer'],
    \]


" SECTION: functions {{{1

" FUNCTION: popc#layer#exp#Init() {{{
function! popc#layer#exp#Init()
    let s:lyr = s:popc.addLayer('Example')
    call s:lyr.setInfo('centerText', 'This Is Example Layer')

    for md in s:mapsData
        call s:lyr.addMaps(md[0], md[1])
    endfor
endfunction
" }}}

" FUNCTION: s:createBuffer() {{{
function! s:createBuffer()
    let l:text = ''

    for k in range(len(s:exp))
        let l:line = '  ' . string(k) . ' '
        let l:line .= s:exp[k]
        let l:line .= repeat(' ', &columns - strwidth(l:line))
        let l:text .= l:line . "\n"
    endfor

    call s:lyr.setBufs(v:t_string, len(s:exp), l:text)
endfunction
" }}}

" FUNCTION: popc#layer#exp#Pop(key) {{{
function! popc#layer#exp#Pop(key)
    call s:lyr.setMode(s:MODE.Normal)
    call s:createBuffer()
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}

" FUNCTION: popc#layer#exp#Get(key) {{{
function! popc#layer#exp#Get(key)
    let l:index = popc#ui#GetIndex()

    if a:key ==# 'CR'
        echo s:exp[l:index]
        let s:exp[l:index] .= ' [This line was got]'
        call popc#ui#Destroy()
    elseif a:key ==# 'Space'
        echo s:exp[l:index]
        let s:exp[l:index] .= ' [This line was got]'
        call s:createBuffer()
        call popc#ui#Create(s:lyr.name)
    endif
endfunction
" }}}

" FUNCTION: popc#layer#exp#Help(key) {{{
function! popc#layer#exp#Help(key)
    call s:lyr.setMode(s:MODE.Help)
    call s:lyr.setBufs(v:t_string, len(s:mapsData), popc#layer#com#createHelpBuffer(s:mapsData))
    call popc#ui#Create(s:lyr.name)
endfunction
" }}}


" common script.

" SECTION: variables {{{1

let s:conf = popc#init#GetConfig()


" SECTION: functions {{{1

" FUNCTION: popc#layer#com#Init() {{{
function! popc#layer#com#Init()
    " common maps init
    if s:conf.useLayer.Buffer
        call popc#key#AddComMaps('popc#layer#buf#Pop', 'h')
    endif
    if s:conf.useLayer.Bookmark
        call popc#key#AddComMaps('popc#layer#bms#Pop', 'b')
    endif
    if s:conf.useLayer.Workspace
        call popc#key#AddComMaps('popc#layer#wks#Pop', 'w')
    endif
    for m in values(s:conf.commonMaps)
        " {'layerName': [funcName, key]}
        call popc#key#AddComMaps(m[0], m[1])
    endfor

    " layer init
    if s:conf.useLayer.Buffer
        call popc#layer#buf#Init()
    endif
    if s:conf.useLayer.Bookmark
        call popc#layer#bms#Init()
    endif
    if s:conf.useLayer.Workspace
        call popc#layer#wks#Init()
    endif
    if s:conf.useLayer.File
        call popc#layer#fls#Init()
    endif
    if s:conf.useLayer.Reg
        call popc#layer#reg#Init()
    endif
endfunction
" }}}

" FUNCTION: popc#layer#com#createHelpBuffer() {{{
" mapsData format [function-name, key-list, help-text]
function! popc#layer#com#createHelpBuffer(mapsData)
    let l:text = ''

    " get max name width
    let l:max = 0
    for md in a:mapsData
        let l:wid = strwidth(join(md[1], ','))
        let l:max = (l:wid > l:max) ? l:wid : l:max
    endfor
    let l:max += 2

    " get context
    for md in a:mapsData
        let l:line =  '  ' . join(md[1], ',')
        let l:line .= repeat(' ', l:max - strwidth(l:line)) . ' | '
        let l:line .= md[2]
        while strwidth(l:line) < &columns
            let l:line .= ' '
        endwhile

        let l:text .= l:line . "\n"
    endfor

    return l:text
endfunction
" }}}

" FUNCTION: popc#layer#com#SortByName(a, b) {{{
" dict item format {'name': , 'path': }
function! popc#layer#com#SortByName(a, b)
    if a:a.name < a:b.name
        return -1
    elseif a:a.name > a:b.name
        return 1
    else
        if a:a.path < a:b.path
            return -1
        elseif a:a.path > a:b.path
            return 1
        else
            return 0
        endif
    endif
endfunction
" }}}

" FUNCTION: popc#layer#com#SortByPath(a, b) {{{
function! popc#layer#com#SortByPath(a, b)
    if a:a.path < a:b.path
        return -1
    elseif a:a.path > a:b.path
        return 1
    else
        if a:a.name < a:b.name
            return -1
        elseif a:a.name > a:b.name
            return 1
        else
            return 0
        endif
    endif
endfunction
" }}}

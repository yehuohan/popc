
" basic key-maps interacting for popc.

" SECTION: variables {{{1

let s:MODE = popc#popc#GetPopc()[1]
let s:conf = popc#init#GetConfig()
let s:keys = []             " all available keys
let s:maps = {}             " current maps in usage
let s:mapsCommon = {}       " common maps
let s:mapsHelp = {}         " maps for Help mode


" SECTION: functions {{{1

" FUNCTION: popc#key#Init() {{{
function! popc#key#Init()
    call s:initKeys()
    call s:initHelpMaps()
endfunction
" }}}

" FUNCTION: popc#key#InitMaps(name, maps, bindCom) {{{
function! popc#key#InitMaps(name, maps, bindCom)
    for k in s:keys
        let a:maps[k] = function('popc#key#FuncDefault', [a:name, k])
    endfor
    if (a:bindCom)
        call extend(a:maps, s:mapsCommon, 'force')
    endif

    for k in s:conf.operationMaps.moveCursorDown
        let a:maps[k] = function('popc#ui#MoveBar', ['down'])
    endfor
    for k in s:conf.operationMaps.moveCursorUp
        let a:maps[k] = function('popc#ui#MoveBar', ['up'])
    endfor
    for k in s:conf.operationMaps.moveCursorTop
        let a:maps[k] = function('popc#ui#MoveBar', ['top'])
    endfor
    for k in s:conf.operationMaps.moveCursorBottom
        let a:maps[k] = function('popc#ui#MoveBar', ['bottom'])
    endfor
    for k in s:conf.operationMaps.moveCursorPgDown
        let a:maps[k] = function('popc#ui#MoveBar', ['pgdown'])
    endfor
    for k in s:conf.operationMaps.moveCursorPgUp
        let a:maps[k] = function('popc#ui#MoveBar', ['pgup'])
    endfor
    for k in s:conf.operationMaps.quit
        let a:maps[k] = function('popc#ui#Destroy')
    endfor
endfunction
" }}}

" FUNCTION: popc#key#AddComMaps(funcName, key) {{{
function! popc#key#AddComMaps(funcName, key)
    let s:mapsCommon[a:key] = function(a:funcName, [a:key])
endfunction
" }}}

" FUNCTION: popc#key#FuncDefault(name, key) {{{
function! popc#key#FuncDefault(name, key)
    call popc#ui#Msg('Key ''' . a:key . ''' doesn''t work in layer ''' . a:name . '''.')
endfunction
" }}}

" FUNCTION: popc#key#FuncTrigger(key) {{{
function! popc#key#FuncTrigger(key)
    if has_key(s:maps, a:key)
        call s:maps[a:key]()
    endif
endfunction
" }}}

" FUNCTION: popc#key#CreateKeymaps() {{{
function! popc#key#CreateKeymaps()
    for key in s:keys
        let k = strlen(key) > 1 ? ('<' . key . '>') : key
        let a = (key == '"') ? '\"' : key
        silent execute 'nnoremap <silent><buffer> ' . k . ' :call popc#key#FuncTrigger("' . a . '")<CR>'
    endfor
endfunction
" }}}

" FUNCTION: popc#key#SetMaps(layer) {{{
function! popc#key#SetMaps(layer)
    if a:layer.mode == s:MODE.Normal || a:layer.mode == s:MODE.Filter
        let s:maps = a:layer.maps
    elseif a:layer.mode == s:MODE.Help
        let s:maps = s:mapsHelp
    endif
endfunction
" }}}

" FUNCTION: s:initKeys() {{{
function! s:initKeys()
    let lowercase = 'q w e r t y u i o p a s d f g h j k l z x c v b n m'
    let uppercase = toupper(lowercase)

    let controlList = []
    for l in split(lowercase, ' ')
        call add(controlList, 'C-' . l)
    endfor
    call add(controlList, 'C-^')
    call add(controlList, 'C-]')

    let altList = []
    for l in split(lowercase, ' ')
        call add(altList, 'M-' . l)
    endfor

    let controls = join(controlList, ' ')
    let alts = join(altList, ' ')

    let numbers  = '1 2 3 4 5 6 7 8 9 0'
    let specials = 'Esc F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 ' .
                 \ '` ~ ! @ # $ % ^ & * ( ) - = _ + BS ' .
                 \ 'Tab S-Tab [ ] { } BSlash Bar ' .
                 \ '; : '' " CR ' .
                 \ 'Space , < . > / ? ' .
                 \ 'Down Up Left Right Home End PageUp PageDown ' .
                 \ 'MouseDown MouseUp LeftDrag LeftRelease 2-LeftMouse '

    let s:keys = split(join([lowercase, uppercase, controls, alts, numbers, specials], ' '), ' ')
endfunction
" }}}

" FUNCTION: s:initHelpMaps() {{{
function! s:initHelpMaps()
    call popc#key#InitMaps('Help', s:mapsHelp, 0)
    let s:mapsHelp['CR'] = function('popc#ui#MoveBar', ['down'])
endfunction
" }}}

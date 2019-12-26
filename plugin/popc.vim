
" Popc: Popc manager for vim.
" Maintainer: yehuohan, <yehuohan@qq.com>, <yehuohan@gmail.com>
" Version: g:popc_version
"
" MIT License
"
" Copyright (c) 2019 lrx
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

" SETCION: vim-script {{{1

scriptencoding utf-8

if exists('g:popc_loaded')
    finish
endif

let s:errors = []
if v:version < 800
    call add(s:errors, 'Popc: Vim8.0 or higher is required.')
endif
if &hidden == 0
    call add(s:errors, 'Popc: requires "hidden" option enabled.')
endif
if &compatible
    call add(s:errors, 'Popc: requires "nocompatible" option enabled.')
endif

if !empty(s:errors)
    echohl WarningMsg
    for msg in s:errors
        echomsg msg
    endfor
    echohl None
    finish
endif

call popc#popc#Init()
let g:popc_version = 'Popc 3.5.15'
let g:popc_loaded = 1

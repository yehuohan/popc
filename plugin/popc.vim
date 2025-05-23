" Popc: Pop Out Panel of Custom user mode
" Maintainer: yehuohan@qq.com
"
" MIT License
" 
" Copyright (c) 2019 yehuohan
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

if has('nvim')
    " Disable VimL version by default on Neovim
else
    let s:err = []
    if v:version < 800
        call add(s:err, 'Vim8.0 or higher is required.')
    endif
    if &hidden == 0
        call add(s:err, 'Requires "hidden" option enabled.')
    endif
    if &compatible
        call add(s:err, 'Requires "nocompatible" option enabled.')
    endif

    if !empty(s:err)
        echohl WarningMsg
        echomsg '[Popc] Error settings:'
        for msg in s:err
            echomsg msg
        endfor
        echohl None
        finish
    endif

    call popc#popc#Init()

    let g:popc_version = 'Popc 3.10.6' " Only for VimL version
endif

let g:popc_loaded = 1

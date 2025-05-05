require('popc').setup({})

local helper = require('popc.helper')
local tabuf = require('popc.panel.tabuf')
local fn = vim.fn
local api = vim.api
local eq = assert.are.same

describe('tabuf', function()
    local _wdir = vim.fs.dirname(fn.tempname())
    local _wids = { {}, {}, {} }

    before_each(function()
        helper.override_input('y')
        tabuf.cmd_clear_all()
        -- Will trigger tabuf.tab_callback and tabuf.buf_callback
        vim.cmd([[silent! execute '%bwipeout!']])
        vim.cmd.edit({ args = { _wdir .. '/test.lua' }, mods = { silent = true } })
        vim.cmd.edit({ args = { _wdir .. '/test.vim' }, mods = { silent = true } })
        _wids[1]['test.vim'] = api.nvim_get_current_win()
        vim.cmd.split({ args = { _wdir .. '/test.py' }, mods = { silent = true } })
        _wids[1]['test.py'] = api.nvim_get_current_win()
        fn.append(1, 'import os')

        vim.cmd.tabedit({ args = { _wdir .. '/test.c' }, mods = { silent = true } })
        _wids[2]['test.c'] = api.nvim_get_current_win()
        vim.cmd.split({ args = { _wdir .. '/test.cpp' }, mods = { silent = true } })
        _wids[2]['test.cpp'] = api.nvim_get_current_win()

        vim.cmd.tabedit({ args = { _wdir .. '/test.rs' }, mods = { silent = true } })
        fn.append(1, 'fn main() {}')
        vim.cmd.buffer({ count = fn.bufnr('test.c') })
        _wids[3]['test.c'] = api.nvim_get_current_win()
        vim.cmd.split()
        vim.cmd.buffer({ count = fn.bufnr('test.rs') })
        _wids[3]['test.rs'] = api.nvim_get_current_win()
    end)

    describe('. internal', function()
        it('. tab_callback/buf_callback', function()
            vim.cmd.bwipeout({ count = fn.bufnr('test.c') })
            local tids = api.nvim_list_tabpages()
            eq(1, tabuf.buf_num(tids[2]))
            eq(1, tabuf.buf_num(tids[3]))

            vim.cmd.tabclose('2')
            eq(2, tabuf.tab_num())
        end)

        it('. tab_num/buf_num', function()
            local tids = api.nvim_list_tabpages()
            eq(3, tabuf.tab_num())
            eq(3, tabuf.buf_num(tids[1]))
            eq(2, tabuf.buf_num(tids[2]))
            eq(2, tabuf.buf_num(tids[3]))
        end)

        it('. get_modified_bufs', function()
            local tids = api.nvim_list_tabpages()
            eq({ fn.bufnr('test.py') }, tabuf.get_modified_bufs(tids[1]))
            eq({}, tabuf.get_modified_bufs(tids[2]))
            eq({ fn.bufnr('test.rs') }, tabuf.get_modified_bufs(tids[3]))
        end)

        it('. get_target_wins', function()
            local tids = api.nvim_list_tabpages()
            eq({ _wids[1]['test.py'], _wids[1]['test.vim'] }, tabuf.get_target_wins(tids[1], true))
            eq({ _wids[2]['test.cpp'], _wids[2]['test.c'] }, tabuf.get_target_wins(tids[2], true))
            eq({ _wids[3]['test.rs'], _wids[3]['test.c'] }, tabuf.get_target_wins(tids[3], true))
        end)

        it('. get_state_items', function()
            eq({
                { '▪+', _wdir .. '/test.rs' },
                { '▫ ', _wdir .. '/test.c' },
            }, tabuf.get_state_items(tabuf.State.Sigtab))
            eq({
                { ' +', '[test.py]³' },
                { '  ', '[test.cpp]²' },
                { '+', '[test.rs]²' },
            }, tabuf.get_state_items(tabuf.State.Listab))
            eq({
                -- Tab 1
                { '╭  ', _wdir .. '/test.lua' },
                { '│▫ ', _wdir .. '/test.vim' },
                { '╰▪+', _wdir .. '/test.py' },
                -- Tab 2
                { '╭▫ ', _wdir .. '/test.c' },
                { '╰▪ ', _wdir .. '/test.cpp' },
                -- Tab 3
                { '┏▪+', _wdir .. '/test.rs' },
                { '┗▫ ', _wdir .. '/test.c' },
            }, tabuf.get_state_items(tabuf.State.Alltab))
        end)

        it('. get_tabstatus/get_bufstatus', function()
            local tids = api.nvim_list_tabpages()
            eq({
                { id = tids[1], idx = 1, name = 'test.py³', current = false, modified = true },
                { id = tids[2], idx = 2, name = 'test.cpp²', current = false, modified = false },
                { id = tids[3], idx = 3, name = 'test.rs²', current = true, modified = true },
            }, tabuf.get_tabstatus())

            eq({
                { id = fn.bufnr('test.lua'), idx = 1, name = 'test.lua', current = false, modified = false },
                { id = fn.bufnr('test.vim'), idx = 2, name = 'test.vim', current = false, modified = false },
                { id = fn.bufnr('test.py'), idx = 3, name = 'test.py', current = true, modified = true },
            }, tabuf.get_bufstatus(tids[1]))
            eq({
                { id = fn.bufnr('test.c'), idx = 1, name = 'test.c', current = false, modified = false },
                { id = fn.bufnr('test.cpp'), idx = 2, name = 'test.cpp', current = true, modified = false },
            }, tabuf.get_bufstatus(tids[2]))
            eq({
                { id = fn.bufnr('test.rs'), idx = 1, name = 'test.rs', current = true, modified = true },
                { id = fn.bufnr('test.c'), idx = 2, name = 'test.c', current = false, modified = false },
            }, tabuf.get_bufstatus(tids[3]))
        end)

        it('. cmd_switch_buffer', function()
            vim.cmd.normal('gt')
            local wid = _wids[1]['test.py']

            eq(fn.bufnr('test.py'), api.nvim_win_get_buf(wid))
            tabuf.cmd_switch_buffer(false, -2)
            eq(fn.bufnr('test.lua'), api.nvim_win_get_buf(wid))
            tabuf.cmd_switch_buffer(false, 1)
            eq(fn.bufnr('test.vim'), api.nvim_win_get_buf(wid))

            vim.cmd.split()
            api.nvim_win_set_buf(0, api.nvim_create_buf(false, true))
            tabuf.cmd_switch_buffer(false, 1)
            eq(fn.bufnr('test.vim'), api.nvim_win_get_buf(wid))
            tabuf.cmd_switch_buffer(true, 1)
            eq(fn.bufnr('test.py'), api.nvim_win_get_buf(wid))
        end)

        it('. cmd_close_buffer', function()
            local fns = { { vim.fn, 'input', 'getcharstr' } }
            local mocked = helper.mock(fns)

            vim.cmd.normal('gt')
            local wid = _wids[1]['test.py']

            eq(fn.bufnr('test.py'), api.nvim_win_get_buf(wid))
            api.nvim_win_set_buf(wid, fn.bufnr('test.lua'))
            api.nvim_win_set_buf(wid, fn.bufnr('#'))

            helper.override_input('N')
            tabuf.cmd_close_buffer()
            eq(fn.bufnr('test.py'), api.nvim_win_get_buf(wid))

            helper.override_input('y')
            tabuf.cmd_close_buffer()
            eq(fn.bufnr('test.lua'), api.nvim_win_get_buf(wid))

            helper.override_input('y')
            tabuf.cmd_close_buffer()
            eq(fn.bufnr('test.vim'), api.nvim_win_get_buf(wid))

            helper.unmock(mocked, fns)
        end)
    end)

    describe('. panel', function()
        local _, u = require('popc.usermode').inspect()
        local uctx = u.ctx

        before_each(function()
            helper.override_getcharstr('a')
            tabuf.pop()
            uctx.pctx.root_dir = _wdir
        end)

        after_each(function()
            uctx.pctx.root_dir = nil
        end)

        it('. pop buffers/tabpages/tabpage_buffers', function()
            helper.override_getcharstr('j', 'l', 'h')
            tabuf.pop()
            eq({
                '  ▪+ test.rs ',
                ' ▫  test.c  ',
            }, uctx.lines)

            helper.override_getcharstr('h', 'l', 'j', 'j')
            tabuf.pop()
            eq({
                '   + [test.py]³  ',
                '     [test.cpp]² ',
                ' + [test.rs]²  ',
            }, uctx.lines)

            helper.override_getcharstr('h', 'k', 'a')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  ╰▪  test.cpp ',
                ' ┏▪+ test.rs  ',
                '  ┗▫  test.c   ',
            }, uctx.lines)

            helper.override_getcharstr('a', 'l', 'k')
            tabuf.pop()
            eq({
                '   + [test.py]³  ',
                '    [test.cpp]² ',
                '  + [test.rs]²  ',
            }, uctx.lines)
        end)

        it('. load/goto buffer/tabpage', function()
            helper.override_getcharstr('j', '<CR>')
            tabuf.pop()
            helper.override_getcharstr()
            tabuf.pop()
            eq({
                '   + test.rs ',
                ' ▪  test.c  ',
            }, uctx.lines)

            helper.override_getcharstr('l', 'j', '<Space>')
            tabuf.pop()
            eq({
                '   + [test.py]³  ',
                '   [test.cpp]² ',
                '   + [test.c]²   ',
            }, uctx.lines)

            helper.override_getcharstr('a', 'j', 'j', 'j', '<S-Space>')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  ╰▪  test.cpp ',
                '  ┏ + test.rs  ',
                ' ┗▪  test.c   ',
            }, uctx.lines)
        end)

        it('. focus_on_window', function()
            helper.override_getcharstr('j', 'f')
            tabuf.pop()
            eq({
                '  ▫+ test.rs ',
                ' ▪  test.c  ',
            }, uctx.lines)

            helper.override_getcharstr('a', 'k', 'f', 'k', 'k', 'f')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                ' ╭▪  test.c   ',
                '  ╰▫  test.cpp ',
                '  ┏▪+ test.rs  ',
                '  ┗▫  test.c   ',
            }, uctx.lines)
        end)

        it('. close buffers/tabpages', function()
            helper.override_getcharstr('a', 'C')
            helper.override_input('n')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  ╰▪  test.cpp ',
                ' ┏▪+ test.rs  ',
                '  ┗▫  test.c   ',
            }, uctx.lines)

            helper.override_getcharstr('l', 'j', 'c')
            tabuf.pop()
            eq({
                '   + [test.py]³ ',
                ' + [test.rs]² ',
            }, uctx.lines)

            local wid = _wids[3]['test.rs']
            helper.override_getcharstr('a', 'C')
            helper.override_input('y')
            tabuf.pop()
            local bid = tostring(api.nvim_win_get_buf(wid))
            local fill = (' '):rep(#bid - 1)
            eq({
                '  ╭   test.lua ' .. fill,
                '  │▫  test.vim ' .. fill,
                '  ╰▪+ test.py  ' .. fill,
                ' [▪  ' .. bid .. '.NoName ',
            }, uctx.lines)
        end)

        it('. close window', function()
            helper.override_getcharstr('a', 'j', 'D')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  ╰▪  test.cpp ',
                ' [▪+ test.rs  ',
            }, uctx.lines)

            helper.override_getcharstr('a', 'k', 'd')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▪  test.c   ',
                ' ╰   test.cpp ',
                '  [▪+ test.rs  ',
            }, uctx.lines)
        end)

        it('. move buffer/tabpage', function()
            helper.override_getcharstr('O')
            tabuf.pop()
            eq({
                '  ▫  test.c  ',
                ' ▪+ test.rs ',
            }, uctx.lines)

            helper.override_getcharstr('a', 'I')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  │▪  test.cpp ',
                ' ╰ + test.rs  ',
                '  [▪  test.c   ',
            }, uctx.lines)

            helper.override_getcharstr('l', 'O')
            tabuf.pop()
            eq({
                '   + [test.cpp]³ ',
                '  + [test.py]³  ',
                '    [test.c]¹   ',
            }, uctx.lines)

            local wid = _wids[3]['test.c']
            helper.override_getcharstr('a', 'I')
            tabuf.pop()
            local bid = tostring(api.nvim_win_get_buf(wid))
            local fill = (' '):rep(#bid - 1)
            eq({
                '  ╭▫  test.c   ' .. fill,
                '  │▪  test.cpp ' .. fill,
                '  ╰ + test.rs  ' .. fill,
                '  ╭   test.lua ' .. fill,
                '  │▫  test.vim ' .. fill,
                '  │▪+ test.py  ' .. fill,
                ' ╰   test.c   ' .. fill,
                '  [▪  ' .. bid .. '.NoName ',
            }, uctx.lines)
        end)

        it('. move out buffer/tabpage', function()
            helper.override_getcharstr('<M-o>')
            tabuf.pop()
            eq({
                ' ▫  test.c  ',
                '  ▪+ test.rs ',
            }, uctx.lines)

            helper.override_getcharstr('a', 'j', '<M-i>')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  │▪  test.cpp ',
                '  ╰ + test.rs  ',
                ' [▪  test.c   ', -- Still at pctx.index = 7
            }, uctx.lines)

            helper.override_getcharstr('l', '<M-o>')
            tabuf.pop()
            eq({
                '  + [test.cpp]³ ',
                '   + [test.py]³  ',
                '    [test.c]¹   ',
            }, uctx.lines)

            local wid = _wids[3]['test.c']
            helper.override_getcharstr('a', '<M-i>')
            tabuf.pop()
            local bid = tostring(api.nvim_win_get_buf(wid))
            local fill = (' '):rep(#bid - 1)
            eq({
                '  ╭▫  test.c   ' .. fill,
                '  │▪  test.cpp ' .. fill,
                '  ╰ + test.rs  ' .. fill,
                '  ╭   test.lua ' .. fill,
                '  │▫  test.vim ' .. fill,
                '  │▪+ test.py  ' .. fill,
                ' ╰   test.c   ' .. fill, -- Still at pctx.index = 7
                '  [▪  ' .. bid .. '.NoName ',
            }, uctx.lines)
        end)

        it('. check before_each', function()
            -- Before each testcase has following
            helper.override_getcharstr()
            tabuf.pop()
            eq({
                ' ▪+ test.rs ',
                '  ▫  test.c  ',
            }, uctx.lines)

            helper.override_getcharstr('a')
            tabuf.pop()
            eq({
                '  ╭   test.lua ',
                '  │▫  test.vim ',
                '  ╰▪+ test.py  ',
                '  ╭▫  test.c   ',
                '  ╰▪  test.cpp ',
                ' ┏▪+ test.rs  ',
                '  ┗▫  test.c   ',
            }, uctx.lines)

            helper.override_getcharstr('l')
            tabuf.pop()
            eq({
                '  + [test.py]³  ',
                '     [test.cpp]² ',
                '  + [test.rs]²  ',
            }, uctx.lines)
        end)
    end)
end)

require('popc').setup({})

local tabuf = require('popc.panel.tabuf')
local fn = vim.fn
local api = vim.api
local eq = assert.are.same

describe('tabuf', function()
    local _wdir = vim.fs.dirname(fn.tempname())
    local _wins = { {}, {}, {} }

    before_each(function()
        -- Will trigger tabuf.tab_callback and tabuf.buf_callback
        vim.cmd([[silent! execute 'tabonly!']])
        vim.cmd([[silent! execute '%bwipeout!']])
        vim.cmd.edit({ args = { _wdir .. '/test.lua' }, mods = { silent = true } })
        vim.cmd.edit({ args = { _wdir .. '/test.vim' }, mods = { silent = true } })
        _wins[1]['test.vim'] = api.nvim_get_current_win()
        vim.cmd.split({ args = { _wdir .. '/test.py' }, mods = { silent = true } })
        _wins[1]['test.py'] = api.nvim_get_current_win()
        fn.append(1, 'import os')

        vim.cmd.tabedit({ args = { _wdir .. '/test.c' }, mods = { silent = true } })
        _wins[2]['test.c'] = api.nvim_get_current_win()
        vim.cmd.split({ args = { _wdir .. '/test.cpp' }, mods = { silent = true } })
        _wins[2]['test.cpp'] = api.nvim_get_current_win()

        vim.cmd.tabedit({ args = { _wdir .. '/test.rs' }, mods = { silent = true } })
        fn.append(1, 'fn main() {}')
        vim.cmd.buffer({ count = fn.bufnr('test.c') })
        _wins[3]['test.c'] = api.nvim_get_current_win()
        vim.cmd.split()
        vim.cmd.buffer({ count = fn.bufnr('test.rs') })
        _wins[3]['test.rs'] = api.nvim_get_current_win()
    end)

    it('. tab_num/buf_num', function()
        local tids = api.nvim_list_tabpages()
        eq(3, tabuf.tab_num())
        eq(3, tabuf.buf_num(tids[1]))
        eq(2, tabuf.buf_num(tids[2]))
        eq(2, tabuf.buf_num(tids[3]))
    end)

    it('. del_tab', function()
        vim.cmd.tabclose('2')
        eq(2, tabuf.tab_num())
    end)

    it('. wipeout_buf', function()
        vim.cmd.bwipeout({ count = fn.bufnr('test.c') })
        local tids = api.nvim_list_tabpages()
        eq(1, tabuf.buf_num(tids[2]))
        eq(1, tabuf.buf_num(tids[3]))
    end)

    it('. get_modified_bufs', function()
        local tids = api.nvim_list_tabpages()
        eq({ fn.bufnr('test.py') }, tabuf.get_modified_bufs(tids[1]))
        eq({}, tabuf.get_modified_bufs(tids[2]))
        eq({ fn.bufnr('test.rs') }, tabuf.get_modified_bufs(tids[3]))
    end)

    it('. get_buf_wins', function()
        local tids = api.nvim_list_tabpages()
        eq({ _wins[1]['test.py'], _wins[1]['test.vim'] }, tabuf.get_buf_wins(tids[1], fn.bufnr('test.py')))
        eq({ _wins[2]['test.c'], _wins[2]['test.cpp'] }, tabuf.get_buf_wins(tids[2], fn.bufnr('test.c')))
        eq({ _wins[3]['test.rs'], _wins[3]['test.c'] }, tabuf.get_buf_wins(tids[3], fn.bufnr('test.rs')))
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
            { '  ', _wdir .. '/test.lua' },
            { ' ▫ ', _wdir .. '/test.vim' },
            { ' ▫+', _wdir .. '/test.py' },
            -- Tab 2
            { '▫ ', _wdir .. '/test.c' },
            { ' ▫ ', _wdir .. '/test.cpp' },
            -- Tab 3
            { '▪+', _wdir .. '/test.rs' },
            { '│▫ ', _wdir .. '/test.c' },
        }, tabuf.get_state_items(tabuf.State.Alltab))
    end)

    it('. get_tabstatus/get_bufstatus', function()
        local tids = api.nvim_list_tabpages()
        eq({
            { tid = tids[1], name = 'test.py³', current = false, modified = true },
            { tid = tids[2], name = 'test.cpp²', current = false, modified = false },
            { tid = tids[3], name = 'test.rs²', current = true, modified = true },
        }, tabuf.get_tabstatus())

        eq({
            { bid = fn.bufnr('test.lua'), name = 'test.lua', current = false, modified = false },
            { bid = fn.bufnr('test.vim'), name = 'test.vim', current = false, modified = false },
            { bid = fn.bufnr('test.py'), name = 'test.py', current = false, modified = true },
        }, tabuf.get_bufstatus(tids[1]))
        eq({
            { bid = fn.bufnr('test.c'), name = 'test.c', current = false, modified = false },
            { bid = fn.bufnr('test.cpp'), name = 'test.cpp', current = false, modified = false },
        }, tabuf.get_bufstatus(tids[2]))
        eq({
            { bid = fn.bufnr('test.rs'), name = 'test.rs', current = true, modified = true },
            { bid = fn.bufnr('test.c'), name = 'test.c', current = false, modified = false },
        }, tabuf.get_bufstatus(tids[3]))
    end)
end)

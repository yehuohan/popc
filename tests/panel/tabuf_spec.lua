require('popc').setup({})

local tabuf = require('popc.panel.tabuf')
local eq = assert.are.same

describe('tabuf', function()
    local wdir = vim.fs.dirname(vim.fn.tempname())
    before_each(function()
        -- Will trigger tabuf.tab_callback and tabuf.buf_callback
        vim.cmd([[silent! execute 'tabonly!']])
        vim.cmd([[silent! execute '%bwipeout!']])
        vim.cmd.edit({ args = { wdir .. '/test.lua' }, mods = { silent = true } })
        vim.cmd.edit({ args = { wdir .. '/test.vim' }, mods = { silent = true } })
        vim.cmd.split({ args = { wdir .. '/test.py' }, mods = { silent = true } })
        vim.fn.append(1, 'import os')
        vim.cmd.tabedit({ args = { wdir .. '/test.c' }, mods = { silent = true } })
        vim.cmd.split({ args = { wdir .. '/test.cpp' }, mods = { silent = true } })
        vim.cmd.tabedit({ args = { wdir .. '/test.rs' }, mods = { silent = true } })
        vim.fn.append(1, 'fn main() {}')
        vim.cmd.buffer({ count = vim.fn.bufnr('test.c') })
        vim.cmd.split()
        vim.cmd.buffer({ count = vim.fn.bufnr('test.rs') })
    end)

    it('. tab_num/buf_num', function()
        local tids = vim.api.nvim_list_tabpages()
        eq(3, tabuf.tab_num())
        eq(3, tabuf.buf_num(tids[1]))
        eq(2, tabuf.buf_num(tids[2]))
        eq(2, tabuf.buf_num(tids[3]))
    end)

    it('. del_buf', function()
        local tids = vim.api.nvim_list_tabpages()
        tabuf.del_buf(tids[2], vim.fn.bufnr('test.c'))
        eq(1, tabuf.buf_num(tids[2]))
        eq(2, tabuf.buf_num(tids[3]))

        local bufs
        bufs = tabuf.get_bufstatus(tids[2])
        eq(1, #bufs)
        eq(vim.fn.bufnr('test.cpp'), bufs[1].bid)
        bufs = tabuf.get_bufstatus(tids[3])
        eq(2, #bufs)
        eq(vim.fn.bufnr('test.rs'), bufs[1].bid)
        eq(vim.fn.bufnr('test.c'), bufs[2].bid)
    end)

    it('. wipeout_buf', function()
        vim.cmd.bwipeout({ count = vim.fn.bufnr('test.c') })

        local tids = vim.api.nvim_list_tabpages()
        eq(1, tabuf.buf_num(tids[2]))
        eq(1, tabuf.buf_num(tids[3]))

        local bufs
        bufs = tabuf.get_bufstatus(tids[2])
        eq(1, #bufs)
        eq(vim.fn.bufnr('test.cpp'), bufs[1].bid)
        bufs = tabuf.get_bufstatus(tids[3])
        eq(1, #bufs)
        eq(vim.fn.bufnr('test.rs'), bufs[1].bid)
    end)

    it('. modified_bufs', function()
        local tids = vim.api.nvim_list_tabpages()
        local bufs
        bufs = tabuf.modified_bufs(tids[1])
        eq({ vim.fn.bufnr('test.py') }, bufs)
        bufs = tabuf.modified_bufs(tids[2])
        eq({}, bufs)
        bufs = tabuf.modified_bufs(tids[3])
        eq({ vim.fn.bufnr('test.rs') }, bufs)
    end)

    it('. get_tabstatus/get_bufstatus', function()
        local tids = vim.api.nvim_list_tabpages()
        local tabs = tabuf.get_tabstatus()
        eq(#tids, #tabs)
        eq({ tid = tids[1], name = 'test.py³', current = false, modified = true }, tabs[1])
        eq({ tid = tids[2], name = 'test.cpp²', current = false, modified = false }, tabs[2])
        eq({ tid = tids[3], name = 'test.rs²', current = true, modified = true }, tabs[3])

        local bufs
        bufs = tabuf.get_bufstatus(tids[1])
        eq({ bid = vim.fn.bufnr('test.lua'), name = 'test.lua', current = false, modified = false }, bufs[1])
        eq({ bid = vim.fn.bufnr('test.vim'), name = 'test.vim', current = false, modified = false }, bufs[2])
        eq({ bid = vim.fn.bufnr('test.py'), name = 'test.py', current = false, modified = true }, bufs[3])
        bufs = tabuf.get_bufstatus(tids[2])
        eq({ bid = vim.fn.bufnr('test.c'), name = 'test.c', current = false, modified = false }, bufs[1])
        eq({ bid = vim.fn.bufnr('test.cpp'), name = 'test.cpp', current = false, modified = false }, bufs[2])
        bufs = tabuf.get_bufstatus(tids[3])
        eq({ bid = vim.fn.bufnr('test.rs'), name = 'test.rs', current = true, modified = true }, bufs[1])
        eq({ bid = vim.fn.bufnr('test.c'), name = 'test.c', current = false, modified = false }, bufs[2])
    end)
end)

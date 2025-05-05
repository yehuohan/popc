require('popc').setup({})

local helper = require('popc.helper')
local umode = require('popc.usermode')
local eq = assert.are.same
local neq = function(a, b)
    -- Is it a BUG? `neq = assert.are_not.same` doesnt' work
    return assert.are_not.same(a, b)
end

describe('usermode', function()
    local fns = { { vim.fn, 'input', 'getcharstr' } }
    local mocked = helper.mock(fns)

    local pressed = {}
    --- @type PanelContext
    local pctx = {
        name = 'Test',
        text = 'spec',
        items = {},
        index = 1,
        keys = {
            ['<CR>'] = function(uctx)
                pressed[#pressed + 1] = '<CR>'
                uctx.pret = 'enter'
                uctx.state = umode.State.None
            end,
            ['<Space>'] = 'tst_space',
        },
        pkeys = {
            tst_space = function(uctx)
                pressed[#pressed + 1] = '<Space>'
                uctx.state = umode.State.ReDisp
            end,
        },
        on_quit = function(uctx, ukey)
            if ukey then
                uctx.pret = 'quit'
            end
        end,
    }

    --- @return UsermodeContext
    local _, u = umode.inspect()
    local uctx = u.ctx

    it('. pop', function()
        pctx.items = {}
        helper.override_getcharstr()
        umode.pop(pctx)
        eq({ ' Nothing to pop ' }, uctx.lines)

        pctx.items = { { 'Nothing' } }
        helper.override_getcharstr()
        umode.apop(pctx)
        eq({ ' Nothing ' }, uctx.lines)
    end)

    it('. help/back/quit', function()
        pctx.items = {}
        helper.override_getcharstr('?')
        eq(nil, pctx.helpctx)
        local res = umode.apop(pctx)
        neq(nil, pctx.helpctx)
        eq('quit', res)
        neq(nil, vim.trim(uctx.lines[2]):match('^<CR> .*popc/tests/usermode_spec.lua:L%d*$'))
        eq('<Space> tst_space', vim.trim(uctx.lines[3]))

        helper.override_getcharstr('?', 'q')
        umode.apop(pctx)
        eq({ ' Nothing to pop ' }, uctx.lines)
    end)

    it('. next/prev/next_page/prev_page', function()
        pctx.items = {
            { 'testca', 'se' },
            { 'us', 'ermode' },
        }
        helper.override_getcharstr('j', 'j', 'j')
        umode.apop(pctx)
        eq({
            '  testca se     ',
            ' us     ermode ',
        }, uctx.lines)

        helper.override_getcharstr('k', 'k', 'k')
        umode.apop(pctx)
        eq({
            ' testca se     ',
            '  us     ermode ',
        }, uctx.lines)

        helper.override_getcharstr('J', 'J')
        umode.apop(pctx)
        eq({
            '  testca se     ',
            ' us     ermode ',
        }, uctx.lines)

        helper.override_getcharstr('K', 'K')
        umode.apop(pctx)
        eq({
            ' testca se     ',
            '  us     ermode ',
        }, uctx.lines)
    end)

    it('. pkeys', function()
        helper.override_getcharstr('<Space>', '<CR>')
        local res = umode.apop(pctx)
        eq('enter', res)
        eq({ '<Space>', '<CR>' }, pressed)
    end)

    it('. input/confirm', function()
        helper.override_input('test')
        local res = umode.input()
        eq('test', res)

        helper.override_input('n')
        local ok = umode.confirm()
        eq(false, ok)
        helper.override_input('y')
        ok = umode.confirm()
        eq(true, ok)
    end)

    helper.unmock(mocked, fns)
end)

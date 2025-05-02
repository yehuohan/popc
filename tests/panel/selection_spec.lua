require('popc').setup({ selection = { enable = true } })

local helper = require('popc.helper')
local pop_selection = require('popc').pop_selection
local eq = assert.are.same

describe('selection', function()
    local fns = { { vim.fn, 'input', 'getcharstr' } }
    local mocked = helper.mock(fns)

    it('. pop_selection', function()
        local tst = {
            opt = '',
            dic = { abc = { lst = { 10, 20, 30 } } },
            lst = { 11, 22, 33, 'abc' },
            cur = 0,
            num = 0,
        }
        tst.cmd = function(_, sel)
            tst.num = tst.num + 1 + sel
            tst.cur = sel
        end
        tst.get = function()
            return tst.cur
        end
        tst.dic.abc.cmd = function(_, sel)
            tst.num = tst.num + 2 + sel
            tst.cur = sel
        end
        tst.dic.abc.get = function()
            return tst.cur
        end
        tst.evt = function(name)
            if 'onCR' == name then
                tst.opt = 'foo'
            elseif 'onQuit' == name then
                tst.opt = 'bar'
            end
        end

        helper.override_getcharstr('<Space>', 'j', '<Space>', 'j', '<Space>', 'p', '<S-CR>')
        tst.opt = 'FOO'
        tst.cur = 0
        tst.num = 0
        local res = pop_selection(tst)
        eq((1 + 11) + (1 + 22) + (1 + 33) + (1 + 22), tst.num)
        eq('foo', tst.opt)
        eq(true, res)

        helper.override_getcharstr('j', 'j', '<Space>', 'j', '<Space>', 'j', '<Space>', 'n', '<Esc>')
        tst.opt = nil
        tst.cur = 0
        tst.num = 0
        res = pop_selection(tst)
        eq((1 + 33) + (2 + 10) + (2 + 20), tst.num)
        eq('bar', tst.opt)
        eq(false, res)
        helper.override_getcharstr('<CR>')
        res = pop_selection(tst)
        eq((1 + 33) + (2 + 10) + (2 + 20) + (1 + 11), tst.num)
        eq('foo', tst.opt)
        eq(true, res)
    end)

    helper.unmock(mocked, fns)
end)

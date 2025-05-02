local M = {}

function M.mock(fns)
    local mocked = {}
    for _, fn in ipairs(fns) do
        for k = 2, #fn do
            mocked[fn[k]] = fn[1][fn[k]]
        end
    end
    return mocked
end

function M.unmock(mocked, fns)
    for _, fn in ipairs(fns) do
        for k = 2, #fn do
            fn[1][fn[k]] = mocked[fn[k]]
        end
    end
end

function M.override_input(...)
    local idx = 0
    local inps = { ... }
    vim.fn.input = function(args)
        idx = idx + 1
        return (args.default or '') .. inps[idx]
    end
end

function M.override_getcharstr(...)
    local idx = 0
    local chars = { ... }
    vim.fn.getcharstr = function()
        idx = idx + 1
        return vim.keycode(chars[idx] or '<Esc>')
    end
end

return M

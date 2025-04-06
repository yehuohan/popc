--- @class Popc.Log
local M = {}
local fn = vim.fn
local opts = require('popc.config').opts

--- @type table<string,string[]>
local log = {}

--- Get log function with tag
--- @param tag string
function M.get(tag)
    if not opts.debug then
        return function(...) end
    end

    if not log[tag] then
        log[tag] = {}
    end
    local ptr = log[tag]
    return function(text, ...)
        local time = string.format('[%s] ', fn.strftime('%M:%S'))
        ptr[#ptr + 1] = string.format(time .. text, ...)
    end
end

--- Get log tag list
function M.get_tags()
    return vim.tbl_keys(log)
end

function M.print(tag)
    local txt = ''
    if tag and log[tag] then
        txt = tag .. '\n    ' .. table.concat(log[tag], '\n    ')
    else
        txt = vim.iter(log)
            :map(function(t, lst)
                return t .. '\n    ' .. table.concat(lst, '\n    ')
            end)
            :join('')
    end
    vim.print(txt)
end

return M

--- @class Popc.Log
local M = {}
local fn = vim.fn
local copts = require('popc.config').opts

--- @type table<string,string[]>
local log = {}

--- Get log function with tag
--- @param tag string
function M.get(tag)
    if not copts.debug then
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
--- @return string[]
function M.get_tags()
    return vim.tbl_keys(log)
end

function M.get_logs(tag)
    local txt = ''
    if tag and log[tag] then
        txt = ('# %s\n    %s'):format(tag, table.concat(log[tag], '\n    '))
    else
        txt = vim.iter(log)
            :map(function(t, lst)
                return ('# %s\n    %s'):format(t, table.concat(lst, '\n    '))
            end)
            :join('\n')
    end
    return txt
end

return M

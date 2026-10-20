--- @class Popc.Log
local M = {}
local fn = vim.fn
local copts = require('popc.config').opts

--- @type table<string,string[]>
local log_tbl = {}

--- Get log function with tag
--- @param tag string
function M.get(tag)
    if not copts.debug then
        return function(...) end
    end

    if type(tag) ~= 'string' or tag == '' then
        error('Log tag must be a non-empty string')
    end
    if not log_tbl[tag] then
        log_tbl[tag] = {}
    end
    local ptr = log_tbl[tag]
    return function(text, ...)
        local time = string.format('[%s] ', fn.strftime('%M:%S'))
        ptr[#ptr + 1] = string.format(time .. text, ...)
    end
end

--- Get log tag list
--- @return string[]
function M.get_tags()
    return vim.tbl_keys(log_tbl)
end

function M.get_logs(tag)
    local txt = ''
    if tag and log_tbl[tag] then
        txt = ('# %s\n    %s'):format(tag, table.concat(log_tbl[tag], '\n    '))
    else
        txt = vim.iter(log_tbl)
            :map(function(t, lst)
                return ('# %s\n    %s'):format(t, table.concat(lst, '\n    '))
            end)
            :join('\n')
    end
    return txt
end

return M

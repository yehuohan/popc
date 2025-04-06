--- @class Popc.Config
local M = {}
local fn = vim.fn

M.opts = {
    debug = true,
    icons = {
        nums = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' },
        -- nums = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
    },
    tabuf = {
        exclude_buffer = function(bid)
            if vim.tbl_contains({ 'Popc' }, fn.getbufvar(bid, '&filetype')) then
                return true
            end
        end,
    },
}

return M

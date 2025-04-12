--- @class Popc.Config
local M = {}
local fn = vim.fn

M.opts = {
    debug = true,
    data_path = fn.stdpath('data'),
    icons = {
        popc = '󰯙',
        tabbuf = '',
        bookmark = '',
        workspace = '',
        tab = '',
        tab_focus = '',
        tab_scope = '│',
        win = '▫',
        win_focus = '▪',
        pointer = '󰜴',
        select = '',
        rank = '≡',
        dots = '…',
        seps = { '', '' },
        nums = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' },
    },
    usermode = {
        win = {
            border = 'rounded', -- 'none', 'single', 'double', 'rounded'
            number = true,
        },
        keys = {
            ['<Esc>'] = 'quit',
            ['q'] = 'back',
            ['?'] = 'help',
            ['j'] = 'next',
            ['k'] = 'prev',
            ['J'] = 'next_page',
            ['K'] = 'prev_page',
            ['h'] = function()
                require('popc.panel.tabuf').pop()
            end,
            -- ['b'] = function() require('popc.panel.bookmark').pop() end,
            -- ['w'] = function() require('popc.panel.workspace').pop() end,
        },
    },
    tabuf = {
        exclude_buffer = function(bid)
            if vim.tbl_contains({ 'Popc' }, fn.getbufvar(bid, '&filetype')) then
                return true
            end
        end,
        keys = {
            ['h'] = 'list_buffers',
            ['l'] = 'list_tabpages',
            ['a'] = 'list_tabpage_buffers',
        },
    },
}

function M.setup(opts)
    if opts then
        M.opts = vim.tbl_deep_extend('force', M.opts, opts)
    end
    opts = M.opts

    if vim.tbl_contains({ 'single', 'double', 'rounded' }, opts.usermode.win.border) then
        opts.usermode.win.highlight = 'NormalFloat:PopcFloat,FloatBorder:PopcFloatBorder'
        vim.api.nvim_set_hl(0, 'PopcFloat', { link = 'Normal' })
        vim.api.nvim_set_hl(0, 'PopcFloatBorder', { link = 'Normal' })

        vim.api.nvim_set_hl(0, 'PopcFloatTitle', { fg = '#ebdbb2', bg = '#504945' })
        vim.api.nvim_set_hl(0, 'PopcFloatTitleBar', { fg = '#32302f', bg = '#fe8019' })
        vim.api.nvim_set_hl(0, 'PopcFloatTitleBarSep', { fg = '#fe8019', bg = '#504945' })
        vim.api.nvim_set_hl(0, 'PopcFloatTitleBarPad', { fg = '#fe8019', bg = '#32302f' })
    else
        opts.usermode.win.border = { ' ', ' ', ' ', ' ', '', '', '', ' ' }
        opts.usermode.win.highlight = 'NormalFloat:PopcFloat,FloatBorder:Normal'
        vim.api.nvim_set_hl(0, 'PopcFloat', { link = 'Pmenu' })
        vim.api.nvim_set_hl(0, 'PopcFloatBorder', { link = 'Pmenu' })

        vim.api.nvim_set_hl(0, 'PopcFloatTitle', { fg = '#ebdbb2', bg = '#504945' })
        vim.api.nvim_set_hl(0, 'PopcFloatTitleBar', { fg = '#32302f', bg = '#fe8019' })
        vim.api.nvim_set_hl(0, 'PopcFloatTitleBarSep', { fg = '#fe8019', bg = '#504945' })
        vim.api.nvim_set_hl(0, 'PopcFloatTitleBarPad', { fg = '#fe8019', bg = '#504945' })
    end
    vim.api.nvim_set_hl(0, 'PopcFloatSelect', { link = 'CursorLineNr' })

    return M.opts
end

return M

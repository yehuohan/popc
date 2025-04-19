--- @class Popc.Config
local M = {}
local fn = vim.fn

M.opts = {
    debug = true,
    data_path = fn.stdpath('data'),
    icons = {
        popc = '󰯙',
        tabuf = '',
        bookmark = '',
        workspace = '',
        win = '▫',
        win_focus = '▪',
        tab_focus = '',
        tab_scope = { '(', '╭', '│', '╰' },
        tab_scope_focus = { '[', '┏', '┃', '┗' },
        pointer = '󰜴',
        select = '',
        dots = '…',
        seps = { '', '' },
        nums = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' },
    },
    usermode = {
        input = nil, -- 'snacks'
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
        enable = true,
        tabline = true,
        root_marker = { '.git' },
        exclude_buffer = function(bid)
            if vim.tbl_contains({ 'Popc', 'qf' }, fn.getbufvar(bid, '&filetype')) then
                return true
            end
        end,
        keys = {
            ['h'] = 'pop_buffers',
            ['l'] = 'pop_tabpages',
            ['a'] = 'pop_tabpage_buffers',
            ['<CR>'] = 'load_buffer_or_tabpage_quit', -- Load buffer into current window of current tabpage
            ['<Space>'] = 'load_buffer_or_tabpage',
            ['<S-CR>'] = 'goto_buffer_or_tabpage_quit', -- Goto buffer of corresponding window and tabpage
            ['<S-Space>'] = 'goto_buffer_or_tabpage',
            ['f'] = 'focus_on_window',
            ['s'] = 'split_buffer_quit',
            ['S'] = 'split_buffer',
            ['v'] = 'vsplit_buffer_quit',
            ['V'] = 'vsplit_buffer',
            ['t'] = 'tabnew_buffer_quit',
            ['T'] = 'tabnew_buffer',
            ['c'] = 'close_buffer_or_tabpage', -- Keep windows layout
            ['C'] = 'close_all_buffers_or_tabpages', -- Keep windows layout
            ['d'] = 'close_window', -- Only close window
            ['D'] = 'close_window_and_buffer', -- Also close window along with buffer
            ['i'] = 'switch_to_prev_tabpage',
            ['o'] = 'switch_to_next_tabpage',
            ['I'] = 'move_buffer_or_tabpage_to_prev', -- Select item index follows buffer
            ['O'] = 'move_buffer_or_tabpage_to_next',
            ['<M-i>'] = 'move_out_buffer_or_tabpage_to_prev', -- Select item index keeps unchanged
            ['<M-o>'] = 'move_out_buffer_or_tabpage_to_next',
            ['n'] = 'set_tabpage_label',
            ['r'] = 'set_tabpage_dir', -- Support expand environment variables
            ['p'] = 'toggle_fullpath',
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

--- @class Popc.Config
local M = {}

M.opts = {
    debug = false,
    data_path = vim.fn.stdpath('data'),
    auto_setup_highlights = true, -- Add ColorScheme event for highlights
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
        tlbuf = '', -- Tabline buffer icon
        tltab = '', -- Tabline tabpage icon
        pointer = '󰜴',
        select = '',
        dots = '…',
        pads = { '', '' },
        nums = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' },
    },
    usermode = {
        input = nil, -- 'snacks'
        win = {
            border = 'rounded', -- 'none', 'single', 'double', 'rounded'
            number = true,
        },
        keys = {
            -- Set false to disable key
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
            if vim.tbl_contains({ 'Popc', 'qf' }, vim.fn.getbufvar(bid, '&filetype')) then
                return true
            end
        end,
        keys = {
            -- Set false to disable key
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
            ['n'] = 'set_tabpage_label', -- Input empty string means delete label
            ['r'] = 'set_tabpage_dir', -- Support expand environment variables, input empty string means delete dir
            ['p'] = 'toggle_fullpath',
        },
    },
}

function M.setup_highlights()
    set_hl = vim.api.nvim_set_hl

    local hint = '#fe8019'
    local text = '#ebdcb4'
    local area = '#504945'
    local blank = '#32302f'
    if vim.tbl_contains({ 'single', 'double', 'rounded' }, M.opts.usermode.win.border) then
        M.opts.usermode.win.highlight = 'NormalFloat:PopcFloat,FloatBorder:PopcFloatBorder'
        set_hl(0, 'PopcFloat', { link = 'Normal' })
        set_hl(0, 'PopcFloatBorder', { link = 'Normal' })

        set_hl(0, 'PopcFloatTitle', { fg = text, bg = area })
        set_hl(0, 'PopcFloatTitleBar', { fg = blank, bg = hint })
        set_hl(0, 'PopcFloatTitleBarSep', { fg = hint, bg = area })
        set_hl(0, 'PopcFloatTitleBarPad', { fg = hint, bg = blank })
    else
        M.opts.usermode.win.border = { ' ', ' ', ' ', ' ', '', '', '', ' ' }
        M.opts.usermode.win.highlight = 'NormalFloat:PopcFloat,FloatBorder:Normal'
        set_hl(0, 'PopcFloat', { link = 'Pmenu' })
        set_hl(0, 'PopcFloatBorder', { link = 'Pmenu' })

        set_hl(0, 'PopcFloatTitle', { fg = text, bg = area })
        set_hl(0, 'PopcFloatTitleBar', { fg = blank, bg = hint })
        set_hl(0, 'PopcFloatTitleBarSep', { fg = hint, bg = area })
        set_hl(0, 'PopcFloatTitleBarPad', { fg = hint, bg = area })
    end
    set_hl(0, 'PopcFloatSelect', { link = 'CursorLineNr' })

    if M.opts.tabuf.tabline then
        local current = '#83a598'
        local modified = '#b8bb26'
        set_hl(0, 'PopcTlBar', { fg = blank, bg = hint })
        set_hl(0, 'PopcTlBarPad', { bg = blank, fg = hint })
        set_hl(0, 'PopcTlNormal', { fg = text, bg = area })
        set_hl(0, 'PopcTlNormalPad', { fg = area, bg = blank })
        set_hl(0, 'PopcTlCurrent', { fg = blank, bg = current })
        set_hl(0, 'PopcTlCurrentPad', { fg = current, bg = blank })
        set_hl(0, 'PopcTlModified', { fg = modified, bg = area })
        set_hl(0, 'PopcTlModifiedPad', { fg = area, bg = blank })
        set_hl(0, 'PopcTlCurrentModified', { fg = blank, bg = modified })
        set_hl(0, 'PopcTlCurrentModifiedPad', { fg = modified, bg = blank })
    end
end

function M.setup(opts)
    if opts then
        M.opts = vim.tbl_deep_extend('force', M.opts, opts)
    end
    opts = M.opts

    M.setup_highlights()
    if opts.auto_setup_highlights then
        vim.api.nvim_create_autocmd('ColorScheme', {
            group = vim.api.nvim_create_augroup('Popc.SetupHighlights', { clear = true }),
            callback = M.setup_highlights,
        })
    end

    return M.opts
end

return M

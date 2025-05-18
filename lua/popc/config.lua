--- @class Popc.Config
local M = {}

--- @class ConfigData
--- @field workspaces WorkspaceItem[]
--- @field bookmarks BookmarkItem[]

M.opts = {
    debug = false,
    data_path = vim.fn.stdpath('data'),
    auto_setup_highlights = true, -- Add ColorScheme event for highlights
    root_marker = { '.git' }, -- Detect root path for tabuf and workspace panel
    icons = {
        -- Require a nerd font by default
        popc = '󰯙',
        tabuf = '',
        bookmark = '',
        workspace = '',
        focus = '▪',
        win = '▫',
        tab = '',
        tab_scope = { '(', '╭', '│', '╰' },
        tab_focus = { '[', '┏', '┃', '┗' },
        tlbuf = '', -- Tabline buffer icon
        tltab = '', -- Tabline tabpage icon
        pointer = '󰜴',
        select = '',
        dots = '…',
        pads = { '', '' },
        nums = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' },
    },
    usermode = {
        input = nil, -- Support: 'snacks'
        win = {
            zindex = 1000,
            border = vim.o.winborder, -- Support: 'none', 'single', 'double', 'rounded'
            number = true,
        },
        keys_number = 'jump', -- Jump to the pressed number item (disable with false)
        keys = {
            -- Set false to disable key
            ['<Esc>'] = 'quit',
            ['q'] = 'back',
            ['?'] = 'help',
            ['j'] = 'next',
            ['k'] = 'prev',
            ['J'] = 'next_page',
            ['K'] = 'prev_page',
            ['h'] = 'pop_tabuf',
            ['b'] = 'pop_bookmark',
            ['w'] = 'pop_workspace',
        },
    },
    tabuf = {
        enable = true,
        tabline = true,
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
            ['<CR>'] = 'load_buffer_or_tabpage_quit', -- Load buffer into current window of current tabpage, then quit panel
            ['<Space>'] = 'load_buffer_or_tabpage',
            ['<S-CR>'] = 'goto_buffer_or_tabpage_quit', -- Goto buffer of corresponding window and tabpage, then quit panel
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
            ['I'] = 'move_buffer_or_tabpage_to_prev', -- Move buffer or tabpage to previous (the selected item index follows buffer)
            ['O'] = 'move_buffer_or_tabpage_to_next',
            ['<M-i>'] = 'move_out_buffer_or_tabpage_to_prev', -- Move buffer or tabpage to previous (the selected item index keeps unchanged)
            ['<M-o>'] = 'move_out_buffer_or_tabpage_to_next',
            ['n'] = 'set_tabpage_label', -- Set tabpage label (also show at tabline, input empty string means delete label)
            ['r'] = 'set_tabpage_dir', -- Set tabpage directory (input empty string means delete dir, support expand environment variables)
            ['p'] = 'toggle_fullpath', -- Show buffer fullpath or not
        },
    },
    bookmark = {
        enable = true,
        keys = {
            -- Set false to disable key
            ['<CR>'] = 'load_bookmark_quit',
            ['<Space>'] = 'load_bookmark',
            ['s'] = 'split_bookmark_quit',
            ['S'] = 'split_bookmark',
            ['v'] = 'vsplit_bookmark_quit',
            ['V'] = 'vsplit_bookmark',
            ['t'] = 'tabnew_bookmark_quit',
            ['T'] = 'tabnew_bookmark',
            ['a'] = 'append_bookmark', -- Append current buffer as bookmark
            ['d'] = 'delete_bookmark',
            ['g'] = 'sort_bookmark',
        },
    },
    workspace = {
        enable = true,
        keys = {
            -- Set false to disable key
            ['<CR>'] = 'open_workspace_quit', -- Open workspace: drop all original tabpages and buffers
            ['<S-CR>'] = 'open_workspace_quit_silent', -- Open workspace silently (also ignore errors)
            ['t'] = 'load_workspace_quit', -- Load workspace: keep original tabpages and buffers
            ['a'] = 'append_workspace', -- Append a new workspace
            ['d'] = 'delete_workspace', -- Delete the seleted  workspace
            ['s'] = 'save_workspace', -- Override the same workspace
            ['S'] = 'save_workspace_forcely', -- Override the seleted workspace forcely
            ['n'] = 'set_workspace_name',
            ['r'] = 'set_workspace_root',
            ['g'] = 'sort_workspace',
        },
    },
    selection = {
        enable = false,
        collect_builtin_colorscheme = true, -- `PopcSet` collects neovim builtin colorschemes or not
        keys = {
            -- Set false to disable key
            ['<CR>'] = 'execute_confirm', -- Execute 'cmd' then confirm with 'evt' callback
            ['<S-CR>'] = 'confirm', -- Confirm with 'evt' callback
            ['<Space>'] = 'execute', -- Execute 'cmd' or open/fold sub-selection
            ['<S-Space>'] = 'enter', -- Enter sub-selection or execute 'cmd'
            ['u'] = 'leave', -- Leave sub-selection and go back base selection
            ['f'] = 'fold_or_open', -- Fold or open sub-selection
            ['F'] = 'fold_always', -- Fold sub-selection always
            ['n'] = 'next_lst_item', -- Execute 'cmd' with next 'lst' item
            ['p'] = 'prev_lst_item', -- Execute 'cmd' with previous 'lst' item
            ['m'] = 'modify', -- Modify the selection value from `input()`
            ['M'] = 'modify_current', -- Modify the selection value from `input({ default = <current selection value> })`
        },
    },
}

--- Get a filepath under popc working directory
--- @param filename string
--- @return string
function M.get_wdir_file(filename)
    return vim.fs.joinpath(M.opts.data_path, 'popc', filename)
end

--- Load popc.json to table
--- @return ConfigData
function M.load_data()
    return vim.json.decode(table.concat(vim.fn.readfile(M.opts._data_json)))
end

--- Save table as popc.json
--- @param data ConfigData
function M.save_data(data)
    if type(data) == 'table' then
        vim.fn.writefile({ vim.json.encode(data) }, M.opts._data_json)
    end
end

function M.validate_data()
    local stat = vim.uv.fs_stat(M.opts._data_json)
    if stat and stat.type == 'file' then
        return
    end

    -- Validate M.opts._data_wdir
    stat = vim.uv.fs_stat(M.opts._data_wdir)
    if (not stat) or stat.type ~= 'directory' then
        vim.uv.fs_mkdir(M.opts._data_wdir, tonumber('666', 8))

        -- Port old data
        local old_popc_wdir = vim.fs.joinpath(M.opts.data_path, '.popc')
        stat = vim.uv.fs_stat(old_popc_wdir)
        if stat and stat.type == 'directory' then
            local fs = vim.uv.fs_scandir(old_popc_wdir)
            local copied = {}
            while fs do
                local name, type = vim.uv.fs_scandir_next(fs)
                if name and type then
                    if type == 'file' then
                        vim.uv.fs_copyfile(vim.fs.joinpath(old_popc_wdir, name), vim.fs.joinpath(M.opts._data_wdir, name))
                        table.insert(copied, name)
                    end
                else
                    if M.opts.debug then
                        vim.notify(vim.inspect(copied))
                    end
                    break
                end
            end
        end
    end

    -- Validate M.opts._data_json
    local old_popc_json = vim.fs.joinpath(M.opts.data_path, '.popc.json')
    stat = vim.uv.fs_stat(old_popc_json)
    if stat and stat.type == 'file' then
        vim.uv.fs_copyfile(old_popc_json, M.opts._data_json)
        local cfg_data = M.load_data()
        for _, wks in ipairs(cfg_data.workspaces) do
            wks.path = vim.fs.normalize(wks.path)
        end
        M.save_data(cfg_data)
    else
        M.save_data({ workspaces = {}, bookmarks = {} })
    end
end

function M.setup_highlights()
    local set_hl = vim.api.nvim_set_hl

    local hint = '#fe8019'
    local text = '#ebdcb4'
    local area = '#504945'
    local blank = vim.api.nvim_get_hl(0, { name = 'Normal', link = false, create = false }).bg
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
    opts.data_path = vim.fs.normalize(opts.data_path)
    opts._data_wdir = vim.fs.joinpath(opts.data_path, 'popc')
    opts._data_json = vim.fs.joinpath(opts.data_path, 'popc', 'popc.json')

    vim.schedule(M.validate_data)
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

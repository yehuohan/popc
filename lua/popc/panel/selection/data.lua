--- @class Popc.Panel.SelectionData Selection data for vim options
local M = {}
local fn = vim.fn
local copts = require('popc.config').opts

local sel_shortname = {}
local sel_option = {
    opt = 'options',
    lst = {},
    dic = {},
}

--- @param name string
--- @param shortname string?
--- @param sel PopSelection
local function append_option(name, shortname, sel)
    table.insert(sel_option.lst, name)
    sel_option.dic[name] = sel
    if shortname then
        sel_shortname[shortname] = name
    end
end

local function set_opt(sopt, arg)
    vim.opt_local[sopt] = arg
end

local function get_opt(sopt)
    return vim.opt_local[sopt]:get()
end

local sel_background = {
    opt = 'background',
    dic = {
        dark = 'dark background color',
        light = 'light background color',
    },
    lst = { 'dark', 'light' },
    dsr = 'Use color for the background',
    cmd = set_opt,
    get = get_opt,
}
append_option('background', 'bg', sel_background)

local sel_cmdheight = {
    opt = 'cmdheight',
    lst = { 0, 1, 2, 3, 4, 5 },
    dsr = 'Number of screen lines to use for the command-line',
    cmd = set_opt,
    get = get_opt,
}
append_option('cmdheight', 'ch', sel_cmdheight)

local sel_colorscheme = {
    opt = 'colorscheme',
    lst = function()
        local colors = fn.getcompletion('', 'color')
        if not copts.selection.collect_builtin_colorscheme then
            local builtin = {
                'blue',
                'darkblue',
                'default',
                'delek',
                'desert',
                'elflord',
                'evening',
                'habamax',
                'industry',
                'koehler',
                'lunaperche',
                'morning',
                'murphy',
                'pablo',
                'peachpuff',
                'quiet',
                'retrobox',
                'ron',
                'shine',
                'slate',
                'sorbet',
                'torte',
                'unokai',
                'vim',
                'wildcharm',
                'zaibatsu',
                'zellner',
            }
            colors = vim.tbl_filter(function(c)
                return not vim.tbl_contains(builtin, c)
            end, colors)
        end
        return colors
    end,
    dsr = 'Load color scheme',
    cmd = function(_, arg)
        vim.cmd.colorscheme(arg)
    end,
    get = function()
        return vim.g.colors_name
    end,
}
append_option('colorscheme', 'colo', sel_colorscheme)

local sel_conceallevel = {
    opt = 'conceallevel',
    dic = {
        [0] = 'Text is shown normally',
        [1] = 'Each block of concealed text is replaced with one character',
        [2] = 'Concealed text is completely hidden unless it has a custom replacement character defined',
        [3] = 'Concealed text is completely hidden',
    },
    dsr = 'Determine how text shown',
    lst = { 0, 1, 2, 3 },
    cmd = set_opt,
    get = get_opt,
}
append_option('conceallevel', 'cole', sel_conceallevel)

local sel_fileformat = {
    opt = 'fileformat',
    dic = {
        dos = 'set EOL to <CR><LF>',
        mac = 'set EOL to <CR>',
        unix = 'set EOL to <LF>',
    },
    lst = { 'dos', 'unix', 'mac' },
    dsr = 'Give the <EOL> of the current buffer',
    cmd = set_opt,
    get = get_opt,
}
append_option('fileformat', 'ff', sel_fileformat)

local sel_foldcolumn = {
    opt = 'foldcolumn',
    lst = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' },
    dsr = 'Column indicates open and closed folds',
    cmd = set_opt,
    get = get_opt,
}
append_option('foldcolumn', 'fdc', sel_foldcolumn)

local sel_foldmethod = {
    opt = 'foldmethod',
    dic = {
        diff = 'Fold text that is not changed',
        expr = '"foldexpr" gives the fold level of a line',
        indent = 'Lines with equal indent form a fold',
        manual = 'Folds are created manually',
        marker = 'Markers are used to specify folds',
        syntax = 'Syntax highlighting items specify folds',
    },
    lst = { 'manual', 'indent', 'expr', 'marker', 'syntax', 'diff' },
    dsr = 'The kind of folding used for the current window',
    cmd = set_opt,
    get = get_opt,
}
append_option('foldmethod', 'fdm', sel_foldmethod)

local sel_laststatus = {
    opt = 'laststatus',
    dic = {
        [0] = 'never',
        [1] = 'only if there are at least two windows',
        [2] = 'always',
        [3] = 'always and ONLY the last window',
    },
    lst = { 0, 1, 2, 3 },
    dsr = 'Determine when the last window will have a status line',
    cmd = set_opt,
    get = get_opt,
}
append_option('laststatus', 'ls', sel_laststatus)

local sel_linespace = {
    opt = 'linespace',
    lst = { -2, -1, 0, 1, 2, 3, 4, 5 },
    dsr = 'Number of pixel lines inserted between characters',
    cmd = set_opt,
    get = get_opt,
}
append_option('linespace', 'lsp', sel_linespace)

local sel_scrolloff = {
    opt = 'scrolloff',
    lst = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
    dsr = 'Minimal number of screen lines to keep above and below the cursor',
    cmd = set_opt,
    get = get_opt,
}
append_option('scrolloff', 'so', sel_scrolloff)

local sel_signcolumn = {
    opt = 'signcolumn',
    dic = {
        auto = 'only when there is a sign to display',
        no = 'never',
        yes = 'always',
        number = 'display signs in the number column',
    },
    lst = { 'auto', 'yes', 'no', 'number' },
    dsr = 'Whether or not to draw the signcolumn',
    cmd = set_opt,
    get = get_opt,
}
append_option('signcolumn', 'scl', sel_signcolumn)

local sel_shiftwidth = {
    opt = 'shiftwidth',
    lst = { 2, 3, 4, 8, 16 },
    dsr = 'Number of spaces to use for each step of (auto)indent',
    cmd = set_opt,
    get = get_opt,
}
append_option('shiftwidth', 'sw', sel_shiftwidth)

local sel_softtabstop = {
    opt = 'softtabstop',
    lst = { 2, 3, 4, 8, 16 },
    dsr = 'Number of spaces that a <Tab> counts for while performing editing operations',
    cmd = set_opt,
    get = get_opt,
}
append_option('softtabstop', 'sts', sel_softtabstop)

local sel_tabstop = {
    opt = 'tabstop',
    lst = { 2, 3, 4, 8, 16 },
    dsr = 'Number of spaces that a <Tab> in the file counts for',
    cmd = set_opt,
    get = get_opt,
}
append_option('tabstop', 'ts', sel_tabstop)

local sel_virtualedit = {
    opt = 'virtualedit',
    dic = {
        none = 'Default value',
        all = 'Allow virtual editing in all modes',
        block = 'Allow virtual editing in Visual block mode',
        insert = 'Allow virtual editing in Insert mode',
        onemore = 'Allow the cursor to move just past the end of the line',
    },
    lst = { 'none', 'block', 'insert', 'all', 'onemore' },
    dsr = 'Determine whether cursor can be positioned where there is no actual character',
    cmd = set_opt,
    get = get_opt,
}
append_option('virtualedit', 've', sel_virtualedit)

--- @param opt string?
--- @return PopSelection
function M.get_sel(opt)
    if opt then
        if sel_shortname[opt] then
            opt = sel_shortname[opt]
        end
        return sel_option.dic[opt]
    else
        return sel_option
    end
end

function M.get_complete(arglead)
    local filter = function(name)
        return name:match('^' .. arglead)
    end
    local clst = vim.tbl_filter(filter, vim.tbl_keys(sel_shortname))
    vim.list_extend(clst, vim.tbl_filter(filter, sel_option.lst))
    return clst
end

return M

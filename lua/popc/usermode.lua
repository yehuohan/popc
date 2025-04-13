--- @class Popc.Usermode Custom user mode panel
local M = {}
local fn = vim.fn
local api = vim.api
local opts = require('popc.config').opts

--- @class PanelContext
--- @field name string Panel name displayed at floating window title
--- @field title string Panel title displayed at floating window title
--- @field items string[][] Panel lines displayed at floating window
--- @field index integer Current selected index item of panel, 1-based
--- @field keys table<string, string|UserkeysHandler>
--- @field pkeys table<string, UserkeysHandler>

--- @class Usermode Custom user mode
--- @field ctx UsermodeContext
--- @field keys table<string, string|UserkeysHandler>
--- @field ns integer
--- @field buf integer?
--- @field win integer?
--- @field title string[][]?
--- @field lines string[]?
--- @field help_title string[][]?
--- @field help_lines string[]?

--- @class UsermodeContext Custom user mode context
--- @field pctx PanelContext?
--- @field state UsermodeState

--- @alias UserkeysHandler fun(uctx:UsermodeContext?, ukey:string?) Handle all keys from custom user mode

--- @enum UsermodeState
M.State = {
    None = 1, -- Request to quit custom user mode
    WaitKey = 2,
    Redraw = 3,
}

--- @type Usermode
local umode = {
    ctx = {
        state = M.State.None,
    },
    keys = opts.usermode.keys,
    ns = api.nvim_create_namespace('Popc.Usermode'),
}
--- Usermode keys handler
--- @type table<string, UserkeysHandler>
local ukeys = {}

local function validate()
    if (not umode.buf) or (not api.nvim_buf_is_valid(umode.buf)) then
        local buf = api.nvim_create_buf(false, true)
        vim.b[buf].swapfile = false
        vim.b[buf].buftype = 'nofile'
        vim.b[buf].bufhidden = 'hide'
        vim.b[buf].buflisted = false
        vim.b[buf].filetype = 'Popc'
        umode.buf = buf
        umode.ctx.state = M.State.None
    end

    if (not umode.win) or (not api.nvim_win_is_valid(umode.win)) then
        local win = api.nvim_open_win(umode.buf, false, {
            relative = 'editor',
            width = 1,
            height = 1,
            col = 1,
            row = 1,
            style = 'minimal',
            focusable = false,
        })
        vim.w[win].wrap = false
        vim.w[win].foldenable = false
        umode.win = win
        umode.ctx.state = M.State.None
    end
end

--- Create floating window title from popc panel title
--- @param pctx PanelContext
--- @param width integer The expected width of title
--- @return string[][] title
--- @return integer new_width The require floating window width
local function create_title(pctx, width)
    local title = {
        { opts.icons.seps[1], 'PopcFloatTitleBarPad' },
        { 'Popc', 'PopcFloatTitleBar' },
        { opts.icons.seps[2], 'PopcFloatTitleBarSep' },
        { pctx.title, 'PopcFloatTitle' },
        { opts.icons.seps[1], 'PopcFloatTitleBarSep' },
        { pctx.name, 'PopcFloatTitleBar' },
        { opts.icons.seps[2], 'PopcFloatTitleBarPad' },
    }
    local len = 0
    for _, t in ipairs(title) do
        len = len + fn.strdisplaywidth(t[1])
    end
    local fill = width - len - 2
    title[4][1] = (' %s%s '):format(pctx.title, (' '):rep(fill))
    return title, fill >= 0 and width or (width - fill)
end

--- Create floating window lines from popc panel items
---
--- The items will align according to string array:
--- ```text
--- {                        {
---     {'abc', 'def'},          'abc def',
---     {'ab', 'cdef'}, ===>     'ab  cdef',
---     {'a', 'bcdef'},          'a   bcdef',
--- }                        }
--- ```
--- @param pctx PanelContext
--- @return table lines
--- @return integer width
--- @return integer height
local function create_lines(pctx)
    if #pctx.items == 0 then
        local lines = { '  Nothing to pop ' }
        return lines, fn.strdisplaywidth(lines[1]), #lines
    end

    local maxs = {}
    for _, chunks in ipairs(pctx.items) do
        for k, chunk in ipairs(chunks) do
            local chunk_wid = fn.strdisplaywidth(chunk)
            if (not maxs[k]) or chunk_wid > maxs[k] then
                maxs[k] = chunk_wid
            end
        end
    end
    local fmt = '  '
        .. vim.iter(maxs)
            :map(function(m)
                return '%-' .. tostring(m) .. 'S'
            end)
            :join(' ')
        .. ' '
    local lines = vim.iter(pctx.items)
        :map(function(i)
            -- Note: string.format can't align in display cells
            return fn.printf(fmt, unpack(i))
        end)
        :totable()
    return lines, fn.strdisplaywidth(lines[1]), #lines
end

--- Switch the selected item
--- @param uctx UsermodeContext
local function switch_line(uctx, newidx)
    local win_row = #umode.lines
    local idx = math.max(1, math.min(uctx.pctx.index, win_row))
    newidx = math.max(1, math.min(newidx, win_row))
    umode.lines[idx] = ' ' .. fn.strcharpart(umode.lines[idx], 1)
    umode.lines[newidx] = opts.icons.select .. fn.strcharpart(umode.lines[newidx], 1)
    uctx.pctx.index = newidx
    api.nvim_buf_set_lines(umode.buf, idx - 1, idx, false, { umode.lines[idx] })
    api.nvim_buf_set_lines(umode.buf, newidx - 1, newidx, false, { umode.lines[newidx] })
    api.nvim_buf_set_extmark(umode.buf, umode.ns, newidx - 1, 0, {
        end_col = #umode.lines[newidx],
        hl_group = 'PopcFloatSelect',
    })
    api.nvim_win_set_cursor(umode.win, { newidx, 0 })
    vim.cmd.redraw()
end

--- @param uctx UsermodeContext
function ukeys.quit(uctx)
    uctx.state = M.State.None
end

function ukeys.back()
    vim.notify('TODO: usermode back')
end

function ukeys.help()
    vim.notify('TODO: usermode help')
end

--- @param uctx UsermodeContext
function ukeys.next(uctx)
    switch_line(uctx, uctx.pctx.index % #umode.lines + 1)
end

--- @param uctx UsermodeContext
function ukeys.prev(uctx)
    local idx = uctx.pctx.index
    switch_line(uctx, idx == 1 and #umode.lines or (idx - 1))
end

--- @param uctx UsermodeContext
function ukeys.next_page(uctx)
    switch_line(uctx, uctx.pctx.index + api.nvim_win_get_height(umode.win) - 1)
end

--- @param uctx UsermodeContext
function ukeys.prev_page(uctx)
    switch_line(uctx, uctx.pctx.index - api.nvim_win_get_height(umode.win) + 1)
end

--- @param pctx PanelContext
local function ok_key(pctx)
    umode.ctx.state = M.State.WaitKey
    vim.cmd.redraw()
    while true do
        if umode.ctx.state == M.State.Redraw then
            vim.cmd.redraw()
        elseif umode.ctx.state ~= M.State.WaitKey then
            break
        end

        -- Get key
        local ok, c = pcall(vim.fn.getcharstr, -1, { cursor = 'hide' })
        if not ok then -- Quit with <C-c>
            break
        end
        local k = fn.keytrans(c)

        -- Handle key
        if umode.keys[k] then
            local handler = umode.keys[k]
            handler = vim.is_callable(handler) and handler or ukeys[handler]
            handler(umode.ctx, k)
        elseif pctx.keys[k] then
            local handler = pctx.keys[k]
            handler = vim.is_callable(handler) and handler or pctx.pkeys[handler]
            handler(umode.ctx, k)
        else
            vim.notify(("No handler for key '%s'"):format(k))
        end
    end
    api.nvim_win_close(umode.win, false)
    umode.ctx.state = M.State.None
end

function M.__on_key()
    local ns = api.nvim_create_namespace('Popc.OnKey')
    -- Issue: Can't break omap key sequence
    vim.on_key(function(_, typed)
        if typed == vim.keycode('<Esc>') then
            vim.on_key(nil, ns)
        else
            if typed ~= '' then
                vim.notify(typed)
            end
            return ''
        end
    end, ns)
end

--- @param pctx PanelContext
function M.pop(pctx)
    umode.ctx.pctx = pctx

    -- Validate custom user mode's buffer and window
    validate()

    local num_wid = 1 -- numberwidth must >= 1
    local win_wid, win_hei
    umode.lines, win_wid, win_hei = create_lines(pctx)
    if opts.usermode.win.number then
        num_wid = math.floor(math.log10(win_hei)) + 1
        win_wid = win_wid + num_wid + 1
    end
    umode.title, win_wid = create_title(pctx, win_wid)
    win_wid = math.min(win_wid, math.floor(0.8 * vim.o.columns))
    win_hei = math.min(win_hei, math.floor(0.8 * vim.o.lines))

    api.nvim_buf_set_lines(umode.buf, 0, -1, false, umode.lines)
    api.nvim_win_set_config(umode.win, {
        title = umode.title,
        title_pos = 'center',
        relative = 'editor',
        height = win_hei,
        width = win_wid,
        row = math.floor((vim.o.lines - win_hei) / 2),
        col = math.floor((vim.o.columns - win_wid) / 2),
        border = opts.usermode.win.border,
    })
    vim.wo[umode.win].number = opts.usermode.win.number
    vim.wo[umode.win].numberwidth = num_wid
    vim.wo[umode.win].winhighlight = opts.usermode.win.highlight
    api.nvim_win_call(umode.win, function()
        fn.winrestview({ topline = 1 })
    end)

    switch_line(umode.ctx, pctx.index)
    if umode.ctx.state == M.State.None then
        ok_key(pctx)
    end
end

function M.inspect()
    return vim.inspect(umode)
end

return M

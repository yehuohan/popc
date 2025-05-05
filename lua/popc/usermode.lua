--- @class Popc.Usermode Custom user mode panel
local M = {}
local fn = vim.fn
local api = vim.api
local log = require('popc.log').get('usermode')
local copts = require('popc.config').opts

--- @class PanelContext
--- @field name string Panel name displayed at floating window title right
--- @field text string Panel text displayed at floating window title center
--- @field items string[][] Panel lines displayed at floating window
--- @field index integer Current selected index item of panel, 1-based
--- @field keys table<string, string|UserkeysHandler>
--- @field pkeys table<string, UserkeysHandler>
--- @field on_quit UserkeysHandler?
---        * ukey = '<Esc>' : Invoke to quit usermode when <Esc> was pressed
---        * ukey = nil     : Always invoke before quit `on_key`
--- @field helpctx PanelContext?

--- @class Usermode Custom user mode
--- @field ctx UsermodeContext
--- @field pctx PanelContext?
--- @field keys table<string, string|UserkeysHandler>
--- @field ns integer
--- @field buf integer?
--- @field win integer?

--- @class UsermodeContext Custom user mode context
--- @field pctx PanelContext?
--- @field pret any Return from panel (usually assign at PanelContext.on_quit)
--- @field state UsermodeState
--- @field title string[][]?
--- @field lines string[]?

--- @alias UserkeysHandler fun(uctx:UsermodeContext?, ukey:string?) Handle all keys from custom user mode

--- @enum UsermodeState
M.State = {
    None = 1, -- Request to quit custom user mode
    ReNew = 2, -- Request re-new usermode's buffer and window (for the case that panel deleted usermode's buffer)
    RePop = 3, -- Request re-pop panel at another tabpage
    ReDisp = 4, -- Request re-display panel at same tabpage
    ReDraw = 5, -- Request redraw at same tabpage
    WaitKey = 6,
}

--- Create floating window title from popc panel name and text
--- @param name string
--- @param text string
--- @param width integer The expected width of title
--- @return string[][] title
--- @return integer new_width The require floating window width
local function create_title(name, text, width)
    local title = {
        { copts.icons.pads[1], 'PopcFloatTitleBarPad' },
        { 'Popc', 'PopcFloatTitleBar' },
        { copts.icons.pads[2], 'PopcFloatTitleBarSep' },
        { text, 'PopcFloatTitle' },
        { copts.icons.pads[1], 'PopcFloatTitleBarSep' },
        { name, 'PopcFloatTitleBar' },
        { copts.icons.pads[2], 'PopcFloatTitleBarPad' },
    }
    local len = 0
    for _, t in ipairs(title) do
        len = len + fn.strdisplaywidth(t[1])
    end
    local fill = width - len - 2
    title[4][1] = (' %s%s '):format(text, (' '):rep(fill))
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
--- @param items string[][] PanelContext.items
--- @return table lines
--- @return integer width
--- @return integer height
local function create_lines(items)
    if #items == 0 then
        local lines = { '  Nothing to pop ' }
        return lines, fn.strdisplaywidth(lines[1]), #lines
    end

    local maxs = {}
    for _, chunks in ipairs(items) do
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
    local lines = vim.iter(items)
        :map(function(i)
            -- Note: string.format can't align in display cells
            return fn.printf(fmt, unpack(i))
        end)
        :totable()
    return lines, fn.strdisplaywidth(lines[1]), #lines
end

--- @type Usermode
local umode = {
    ctx = {
        state = M.State.None,
    },
    keys = copts.usermode.keys,
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
            zindex = copts.usermode.win.zindex,
        })
        vim.w[win].wrap = false
        vim.w[win].foldenable = false
        umode.win = win
        umode.ctx.state = M.State.None
    end
end

local function destroy()
    if api.nvim_win_is_valid(umode.win) then
        api.nvim_win_close(umode.win, false)
    end
    if api.nvim_buf_is_valid(umode.buf) then
        api.nvim_buf_delete(umode.buf, { force = true })
    end
    umode.buf = nil
    umode.win = nil
end

--- Switch the selected item
--- @param uctx UsermodeContext
local function switch(uctx, newidx)
    local win_row = #uctx.lines
    local idx = math.max(1, math.min(uctx.pctx.index, win_row))
    newidx = math.max(1, math.min(newidx, win_row))
    uctx.lines[idx] = ' ' .. fn.strcharpart(uctx.lines[idx], 1)
    uctx.lines[newidx] = copts.icons.select .. fn.strcharpart(uctx.lines[newidx], 1)
    uctx.pctx.index = newidx
    api.nvim_buf_set_lines(umode.buf, idx - 1, idx, false, { uctx.lines[idx] })
    api.nvim_buf_set_lines(umode.buf, newidx - 1, newidx, false, { uctx.lines[newidx] })
    api.nvim_buf_set_extmark(umode.buf, umode.ns, newidx - 1, 0, {
        end_col = #uctx.lines[newidx],
        hl_group = 'PopcFloatSelect',
    })
    api.nvim_win_set_cursor(umode.win, { newidx, 0 })
    vim.cmd.redraw()
end

--- Display panel items at floating window
--- @param uctx UsermodeContext
local function display(uctx)
    -- Validate custom user mode's buffer and window
    validate()

    -- Create title and lines
    local num_wid = 1 -- numberwidth must >= 1
    local win_wid, win_hei
    uctx.lines, win_wid, win_hei = create_lines(uctx.pctx.items)
    if copts.usermode.win.number then
        num_wid = math.floor(math.log10(win_hei)) + 1
        win_wid = win_wid + num_wid + 1
    end
    uctx.title, win_wid = create_title(uctx.pctx.name, uctx.pctx.text, win_wid)
    win_wid = math.min(win_wid, math.floor(0.8 * vim.o.columns))
    win_hei = math.min(win_hei, math.floor(0.8 * vim.o.lines))

    -- Display title and lines
    api.nvim_buf_set_lines(umode.buf, 0, -1, false, uctx.lines)
    api.nvim_win_set_config(umode.win, {
        title = uctx.title,
        title_pos = 'center',
        relative = 'editor',
        height = win_hei,
        width = win_wid,
        row = math.floor((vim.o.lines - win_hei) / 2),
        col = math.floor((vim.o.columns - win_wid) / 2),
        border = copts.usermode.win.border,
    })
    vim.wo[umode.win].number = copts.usermode.win.number
    vim.wo[umode.win].numberwidth = num_wid
    vim.wo[umode.win].winhighlight = copts.usermode.win.highlight
    api.nvim_win_call(umode.win, function()
        fn.winrestview({ topline = 1 })
    end)
    switch(uctx, uctx.pctx.index)
end

function ukeys.quit(uctx, ukey)
    -- Always invoke `on_quit` of panel, but not panel help
    if umode.pctx.on_quit then
        umode.pctx.on_quit(uctx, ukey)
    end
    uctx.state = M.State.None
end

function ukeys.back(uctx)
    if uctx.pctx == umode.pctx then
        return
    end
    uctx.pctx = umode.pctx
    uctx.state = M.State.ReDisp
end

function ukeys.help(uctx)
    if uctx.pctx == umode.pctx.helpctx then
        return
    end
    if not umode.pctx.helpctx then
        local items = {}

        local keys2items = function(keys)
            for _, k in ipairs(fn.sort(vim.tbl_keys(keys), 'i')) do
                local f = keys[k]
                if type(f) == 'function' then
                    local info = debug.getinfo(f, 'S')
                    f = ('%s:L%d'):format(info.short_src, info.linedefined)
                end
                table.insert(items, { ('%10s %s'):format(k, f) })
            end
        end

        table.insert(items, { '# Panel' })
        keys2items(umode.pctx.keys)
        table.insert(items, { '# Usermode' })
        keys2items(umode.keys)
        umode.pctx.helpctx = { name = umode.pctx.name, text = 'Help', items = items, index = 1, keys = {}, pkeys = {} }
    end
    uctx.pctx = umode.pctx.helpctx
    uctx.state = M.State.ReDisp
end

function ukeys.next(uctx)
    switch(uctx, uctx.pctx.index % #uctx.lines + 1)
end

function ukeys.prev(uctx)
    switch(uctx, (uctx.pctx.index - 2) % #uctx.lines + 1)
end

function ukeys.next_page(uctx)
    switch(uctx, uctx.pctx.index + api.nvim_win_get_height(umode.win) - 1)
end

function ukeys.prev_page(uctx)
    switch(uctx, uctx.pctx.index - api.nvim_win_get_height(umode.win) + 1)
end

function ukeys.pop_tabuf()
    require('popc.panel.tabuf').pop()
end

function ukeys.pop_bookmark()
    require('popc.panel.bookmark').pop()
end

function ukeys.pop_workspace()
    require('popc.panel.workspace').pop()
end

--- @param uctx UsermodeContext
--- @return any
local function on_key(uctx)
    uctx.state = M.State.WaitKey
    vim.cmd.redraw()

    while true do
        -- Handle state
        if uctx.state == M.State.None then
            break
        elseif uctx.state == M.State.ReNew then
            destroy()
            display(uctx)
        elseif uctx.state == M.State.RePop then
            if api.nvim_win_is_valid(umode.win) then
                api.nvim_win_close(umode.win, false)
            end
            display(uctx)
        elseif uctx.state == M.State.ReDisp then
            display(uctx)
        elseif uctx.state == M.State.ReDraw then
            vim.cmd.redraw()
        end
        uctx.state = M.State.WaitKey

        -- Get key
        local ok, c = pcall(vim.fn.getcharstr, -1, { cursor = 'hide' })
        if not ok then -- Quit with <C-c>
            break
        end
        local ukey = fn.keytrans(c)

        -- Handle key
        if umode.keys[ukey] then
            local handler = umode.keys[ukey]
            handler = vim.is_callable(handler) and handler or ukeys[handler]
            handler(uctx, ukey)
        elseif uctx.pctx.keys[ukey] then
            local handler = uctx.pctx.keys[ukey]
            handler = vim.is_callable(handler) and handler or uctx.pctx.pkeys[handler]
            handler(uctx, ukey)
        else
            vim.notify(("No handler for key '%s'"):format(ukey))
        end
    end

    if umode.pctx.on_quit then
        umode.pctx.on_quit(uctx, nil)
    end

    destroy()
    uctx.state = M.State.None
    return uctx.pret
end

local function __on_key()
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

--- Pop out panel
--- @param pctx PanelContext
--- @return any?
function M.pop(pctx)
    umode.pctx = pctx
    umode.ctx.pctx = pctx
    umode.ctx.pret = nil
    display(umode.ctx)
    if umode.ctx.state == M.State.None then
        -- M.notify(('Enter usermode with %s panel'):format(pctx.name))
        log('Enter usermode')
        local res = on_key(umode.ctx)
        log('Level usermode')
        return res
    end
end

--- Async pop out panel
--- @param pctx PanelContext
--- @return any?
function M.apop(pctx)
    return coroutine.wrap(M.pop)(pctx)
end

--- Notify message
function M.notify(message, level)
    vim.notify((' %s %s'):format(copts.icons.popc, message), level)
end

--- Input text
--- @param opts table? vim.ui.input.Opts
--- @return string?
function M.input(opts)
    opts = opts or {}
    opts.prompt = ' ' .. copts.icons.popc .. ' ' .. (opts.prompt or '')
    opts.cancelreturn = vim.NIL
    if copts.usermode.input == 'snacks' then
        return coroutine.yield((function()
            local caller = coroutine.running()
            require('snacks').input(opts, function(inp)
                coroutine.resume(caller, inp ~= vim.NIL and inp or nil)
            end)
        end)())
    else
        local res = fn.input(opts)
        return res ~= vim.NIL and res or nil
    end
end

--- @param prompt string?
--- @return boolean
function M.confirm(prompt)
    return 'y' == M.input({ prompt = (prompt or '') .. ' (yN): ' })
end

function M.inspect()
    return vim.inspect(umode), umode
end

return M

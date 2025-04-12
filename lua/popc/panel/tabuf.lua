--- @class Popc.Panel.Tabuf Buffers scoped under tabpage
local M = {}
local fn = vim.fn
local api = vim.api
local log = require('popc.log').get('tabuf')
local opts = require('popc.config').opts
local umode = require('popc.usermode')

--- @alias TabID integer A valid tabpage ID (nvim_buf_is_valid() = true)
--- @alias BufID integer A valid buffer ID (nvim_tabpage_is_valid() = true)

--- @class TabContext
--- @field name string Tabpage name
--- @field bufs BufID[] Buffers scoped under tabpage
--- @field tdir string? Tabpage working directory

--- @class BufContext
--- @field cnt integer cnt = 0 means buffer is closed but not wiped out

--- @type table<TabID, TabContext>
local tabctx = {}
--- @type table<BufID, BufContext>
local bufctx = {}

--- Get then list index of value
--- @param lst any[]
--- @param val any
--- @return integer?
local function list_index(lst, val)
    return table.foreachi(
        lst,
        --- @return integer?
        function(k, v)
            if v == val then
                return k
            end
        end
    )
end

--- Convert number to string
--- @param num integer
--- @return string
local function num2str(num)
    local res = ''
    for _, n in ipairs(vim.split(tostring(num), '')) do
        res = res .. opts.icons.nums[tonumber(n) + 1]
    end
    return res
end

--- Get tabage number
--- @return integer
function M.tab_num()
    return vim.tbl_count(tabctx)
end

--- Get tabpage's buffer number
--- @param tid TabID
--- @return integer
function M.buf_num(tid)
    return tabctx[tid] and #tabctx[tid].bufs or 0
end

--- Add a tabpage
--- @param tid TabID
function M.add_tab(tid)
    tabctx[tid] = { name = '', bufs = {} }
end

--- Delete a tabpage
--- @param tid TabID
function M.del_tab(tid)
    if not tabctx[tid] then
        return
    end
    for _, bid in ipairs(tabctx[tid].bufs) do
        bufctx[bid].cnt = math.max(bufctx[bid].cnt - 1, 0)
    end
    tabctx[tid] = nil
end

--- Add a buffer into a tabpage
--- @param tid TabID
--- @param bid BufID
function M.add_buf(tid, bid)
    if not tabctx[tid] then
        return
    end

    local info = fn.getbufinfo(bid)[1]
    if not info then
        return
    end
    if info.listed == 0 then
        return
    end
    if opts.tabuf.exclude_buffer(bid) then
        return
    end

    local tnr = api.nvim_tabpage_get_number(tid)
    local tab = tabctx[tid]
    if vim.list_contains(tab.bufs, bid) then
        log('switch buffer: tid = %d, tnr = %d, bid = %d, name = %s', tid, tnr, bid, info.name)
    else
        table.insert(tab.bufs, bid)
        if bufctx[bid] then
            bufctx[bid].cnt = bufctx[bid].cnt + 1
        else
            bufctx[bid] = { cnt = 1 }
        end
        log('append buffer: tid = %d, tnr = %d, bid = %d, name = %s', tid, tnr, bid, info.name)
    end
    tab.name = info.name == '' and tostring(bid) .. 'NoName' or vim.fs.basename(info.name)
end

--- Delete a buffer from a tabpage
--- @param tid TabID
--- @param bid BufID
function M.del_buf(tid, bid)
    if not tabctx[tid] then
        return
    end
    local idx = list_index(tabctx[tid].bufs, bid)
    if idx then
        table.remove(tabctx[tid].bufs, idx)
        bufctx[bid].cnt = math.max(bufctx[bid].cnt - 1, 0)
    end
end

--- Wipeout buffer from all tabpages
--- @param bid BufID
function M.wipeout_buf(bid)
    for _, tid in ipairs(api.nvim_list_tabpages()) do
        M.del_buf(tid, bid)
    end
end

--- Get tabpage's modified buffers
--- @param tid TabID
--- @param check boolean? Only check has modified buffer or not
function M.modified_bufs(tid, check)
    if not tabctx[tid] then
        return {}
    end
    local res = {}
    for _, bid in ipairs(tabctx[tid].bufs) do
        if fn.getbufvar(bid, '&modified') == 1 then
            table.insert(res, bid)
            if check then
                break
            end
        end
    end
    return res
end

--- Get tabpage's status for tabline
function M.get_tabstatus()
    local cur_tid = api.nvim_get_current_tabpage()
    local res = {}
    for _, tid in ipairs(api.nvim_list_tabpages()) do
        res[#res + 1] = {
            tid = tid,
            name = tabctx[tid].name .. num2str(M.buf_num(tid)),
            current = tid == cur_tid,
            modified = #M.modified_bufs(tid, true) > 0,
        }
    end
    return res
end

--- Get tabpage's buffers status for tabline
--- @param tid TabID? nil for nvim_get_current_tabpage()
function M.get_bufstatus(tid)
    local cur_tid = tid or api.nvim_get_current_tabpage()
    if not tabctx[cur_tid] then
        return {}
    end
    local cur_bid = api.nvim_get_current_buf()
    local res = {}
    for _, bid in ipairs(tabctx[cur_tid].bufs) do
        res[#res + 1] = {
            bid = bid,
            name = vim.fs.basename(fn.bufname(bid)),
            current = bid == cur_bid,
            modified = fn.getbufvar(bid, '&modified') == 1,
        }
    end
    return res
end

--- Tabpage events
function M.tab_callback(args)
    log('tab_callback: event = %s', args.event)
    if args.event == 'TabNew' then
        local cur_tid = api.nvim_get_current_tabpage()
        M.add_tab(cur_tid)
    elseif args.event == 'TabClosed' then
        log('closed tabpage: number = %d', args.file) -- <afile>
        local tids = vim.tbl_map(function()
            return true
        end, tabctx)
        for _, t in ipairs(api.nvim_list_tabpages()) do
            tids[t] = nil
        end
        for t, _ in pairs(tids) do
            log('closed tabpage: tid = %d', t)
            M.del_tab(t)
        end
    end
end

--- Buffer events
function M.buf_callback(args)
    log('buf_callback: ' .. args.event)
    local cur_tid = api.nvim_get_current_tabpage()
    if args.event == 'BufEnter' then
        if M.tab_num() == 0 then
            M.add_tab(api.nvim_get_current_tabpage())
        end
        M.add_buf(cur_tid, api.nvim_get_current_buf())
    elseif args.event == 'BufWipeout' then
        local bid = args.buf -- <abuf>
        if bufctx[bid] then
            M.wipeout_buf(bid)
            bufctx[bid] = nil
            local tnr = api.nvim_tabpage_get_number(cur_tid)
            log('wipeout buffer: tid = %d, tnr = %d, bid = %d, afile = %s', cur_tid, tnr, bid, args.file)
        end
    elseif args.event == 'VimEnter' then
        if M.tab_num() == 0 then
            M.add_tab(api.nvim_get_current_tabpage())
        end
        --- @diagnostic disable-next-line: param-type-mismatch
        for _, arg in ipairs(fn.argv()) do
            log('append arg file: %s', arg)
            M.add_buf(cur_tid, fn.bufnr(arg))
        end
    end
end

function M.setup()
    api.nvim_create_augroup('Popc.Panel.Tabuf', { clear = true })
    api.nvim_create_autocmd(
        { 'TabNew', 'TabClosed' },
        { group = 'Popc.Panel.Tabuf', pattern = { '*' }, callback = M.tab_callback }
    )
    api.nvim_create_autocmd(
        { 'BufEnter', 'BufWipeout', (not vim.v.vim_did_enter) and 'VimEnter' or nil },
        { group = 'Popc.Panel.Tabuf', pattern = { '*' }, callback = M.buf_callback }
    )
    if vim.v.vim_did_enter then
        M.buf_callback({ event = 'VimEnter' })
    end
end

function M.inspect()
    local tids = api.nvim_list_tabpages()
    local txt = 'tabids = ' .. vim.inspect(tids)
    txt = txt
        .. '\ntabctx = [\n  '
        .. vim.iter(tids)
            :map(function(tid)
                return vim.split(('[%d] = %s,'):format(tid, vim.inspect(tabctx[tid])), '\n')
            end)
            :flatten()
            :join('\n  ')
        .. '\n]'
    txt = txt
        .. '\nbufctx = [\n  '
        .. vim.iter(vim.iter(pairs(bufctx))
            :map(function(bid, buf)
                return vim.split(('[%d] = %s,'):format(bid, vim.inspect(buf)), '\n')
            end)
            :totable())
            :flatten()
            :join('\n  ')
        .. '\n]'
    return txt
end

local State = { Sigtab = 1, Alltab = 2, Listab = 3 }

--- Tabuf panel context
--- @type PanelContext
local pctx = {
    name = 'Tabuf',
    title = opts.icons.tabbuf,
    items = {},
    index = 1,
    keys = opts.tabuf.keys,
    pkeys = {},
    -- Specified panel data
    state = State.Sigtab,
    state_indices = {
        [State.Sigtab] = 1,
        [State.Alltab] = 1,
        [State.Listab] = 1,
    },
}
--- Panel keys handler
local pkeys = pctx.pkeys

function pkeys.list_buffers()
    local cur_tid = api.nvim_get_current_tabpage()
    local cur_bid = api.nvim_get_current_buf()
    local tab_winbufs = vim.tbl_map(api.nvim_win_get_buf, api.nvim_tabpage_list_wins(cur_tid))

    pctx.items = {}
    for _, bid in ipairs(tabctx[cur_tid].bufs) do
        table.insert(pctx.items, {
            (bid == cur_bid and opts.icons.win_focus or (vim.tbl_contains(tab_winbufs, bid) and opts.icons.win or ' '))
                .. (fn.getbufvar(bid, '&modified') == 1 and '+' or ' '),
            fn.bufname(bid),
        })
    end
    pctx.state_indices[pctx.state] = pctx.index
    pctx.state = State.Sigtab
    pctx.index = pctx.state_indices[pctx.state]
    umode.pop(pctx)
end

function pkeys.list_tabpages()
    local cur_tid = api.nvim_get_current_tabpage()

    pctx.items = {}
    for _, tid in ipairs(api.nvim_list_tabpages()) do
        table.insert(pctx.items, {
            (tid == cur_tid and opts.icons.tab_focus or ' ') .. (#M.modified_bufs(tid, true) > 0 and '+' or ' '),
            '[' .. tabctx[tid].name .. ']' .. num2str(M.buf_num(tid)),
        })
    end
    if pctx.state == State.Alltab then
        pctx.index = list_index(api.nvim_list_tabpages(), cur_tid) or 1
    end
    pctx.state_indices[pctx.state] = pctx.index
    pctx.state = State.Listab
    pctx.index = pctx.state_indices[pctx.state]
    umode.pop(pctx)
end

function pkeys.list_tabpage_buffers()
    local cur_tid = api.nvim_get_current_tabpage()
    local cur_bid = api.nvim_get_current_buf()
    local tab_winbufs = vim.tbl_map(api.nvim_win_get_buf, api.nvim_tabpage_list_wins(cur_tid))

    pctx.items = {}
    for _, tid in ipairs(api.nvim_list_tabpages()) do
        for k, bid in ipairs(tabctx[tid].bufs) do
            table.insert(pctx.items, {
                (
                    tid == cur_tid and (k == 1 and opts.icons.tab_focus or opts.icons.tab_scope)
                    or (k == 1 and opts.icons.tab or ' ')
                )
                    .. (bid == cur_bid and opts.icons.win_focus or (vim.tbl_contains(tab_winbufs, bid) and opts.icons.win or ' '))
                    .. (fn.getbufvar(bid, '&modified') == 1 and '+' or ' '),
                fn.bufname(bid),
            })
        end
    end
    pctx.state_indices[pctx.state] = pctx.index
    pctx.state = State.Alltab
    pctx.index = pctx.state_indices[pctx.state]
    umode.pop(pctx)
end

function M.pop()
    pkeys.list_buffers()
end

return M

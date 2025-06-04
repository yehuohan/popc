--- @class Popc.Panel.Tabuf Buffers scoped under tabpage
local M = {}
local fn = vim.fn
local api = vim.api
local log = require('popc.log').get('tabuf')
local copts = require('popc.config').opts
local umode = require('popc.usermode')

--- @alias TabID integer A tabpage ID
--- @alias BufID integer A buffer ID
--- @alias WinID integer A window ID

--- @class TabContext
--- @field label string? A label for tabpage
--- @field tdir string? Tabpage directory as base directory for buffer filename
--- @field bufs BufID[] Buffers scoped under tabpage
--- @field icur integer The current buffer index of `TabContext.bufs`
--- @field istt integer The state item index for the tabpage

--- @class BufContext
--- @field cnt integer cnt = 0 means buffer is closed but not wiped out

--- @class TabufStatus
--- @field id TabID|BufID
--- @field idx integer The index of tabpage or tabpage buffer
--- @field name string
--- @field current boolean
--- @field modified boolean

--- @enum TabufState
M.State = { Sigtab = 1, Alltab = 2, Listab = 3 }

--- @class TabufStateItem
--- @field tid TabID
--- @field bid BufID?
--- @field wid WinID?
--- @field idx integer? The state item index for buffer

--- @type table<TabID, TabContext>
local tabctx = {}
--- @type table<BufID, BufContext>
local bufctx = {}
--- Tabuf panel context
--- @type PanelContext
local pctx = {
    name = 'Tabuf',
    text = copts.icons.tabuf,
    items = {},
    index = 1,
    keys = copts.tabuf.keys,
    pkeys = {},
    on_quit = nil,
    -- Specified panel data
    state = M.State.Sigtab,
    state_check = false,
    --- @type TabufStateItem[]
    state_items = {},
    state_index = {
        [M.State.Sigtab] = 1,
        [M.State.Alltab] = 1,
        [M.State.Listab] = 1,
    },
    root_dir = nil,
    fullpath = false,
}

--- Get the list index of value
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
        res = res .. copts.icons.nums[tonumber(n) + 1]
    end
    return res
end

--- Get tabage number
--- @return integer
function M.tab_num()
    return vim.tbl_count(tabctx)
end

--- Get tabpage name
--- @param tid TabID
--- @param pad boolean?
function M.tab_name(tid, pad)
    if not tabctx[tid] then
        return 'None'
    end
    local name = tabctx[tid].label
    if not name then
        local cur_bid = api.nvim_win_get_buf(api.nvim_tabpage_get_win(tid))
        name = fn.bufname(cur_bid)
        name = name == '' and fn.getbufvar(cur_bid, '&filetype') or vim.fs.basename(name)
        name = name == '' and ('%d.NoName'):format(cur_bid) or name
    end
    if pad then
        name = '[' .. name .. ']'
    end
    return name .. num2str(M.buf_num(tid))
end

--- Get tabpage's buffer number
--- @param tid TabID
--- @return integer
function M.buf_num(tid)
    return tabctx[tid] and #tabctx[tid].bufs or 0
end

--- Get tabpage's buffer index
--- @param tid TabID
--- @param bid BufID
--- @return integer?
function M.buf_idx(tid, bid)
    return tabctx[tid] and list_index(tabctx[tid].bufs, bid)
end

--- Get buffer name
--- @param tid TabID
--- @param bid BufID
--- @return string
function M.buf_name(tid, bid, base)
    local name = api.nvim_buf_get_name(bid)

    -- Need base name
    if base then
        name = name == '' and fn.getbufvar(bid, '&filetype') or vim.fs.basename(name)
        return name == '' and ('%d.NoName'):format(bid) or name
    end

    -- Need full name
    name = vim.fs.normalize(name)
    if not pctx.fullpath then
        local base_dir
        if tabctx[tid] then
            base_dir = tabctx[tid].tdir
        end
        if not base_dir then
            base_dir = pctx.root_dir
        end
        if not base_dir then
            base_dir = vim.fs.normalize(fn.getcwd(-1, api.nvim_tabpage_get_number(tid)))
        end
        -- Prefer `vim.startswith` to avoid pattern with `string.gsub`
        if vim.startswith(name, base_dir) then
            name = string.sub(name, string.len(base_dir) + 2)
        end
    end
    name = name == '' and fn.getbufvar(bid, '&filetype') or name
    return name == '' and ('%d.NoName'):format(bid) or name
end

--- Get tabpage's modified buffers
--- @param tid TabID
--- @param check boolean? Only check has modified buffer or not
function M.get_modified_bufs(tid, check)
    if not tabctx[tid] then
        return {}
    end
    local bids = {}
    for _, bid in ipairs(tabctx[tid].bufs) do
        if fn.getbufvar(bid, '&modified') == 1 then
            table.insert(bids, bid)
            if check then
                break
            end
        end
    end
    return bids
end

--- Get target windows that contain tabpage's buffers
--- @param tid TabID
--- @param order boolean? Try make wins[1] = focused or last accessed window
--- @return WinID[] wins
function M.get_target_wins(tid, order)
    if not tabctx[tid] then
        return {}
    end
    local wids = vim.tbl_filter(function(wid)
        return vim.tbl_contains(tabctx[tid].bufs, api.nvim_win_get_buf(wid))
    end, api.nvim_tabpage_list_wins(tid))

    if order then
        -- Make wids[1] = tabpage focused window
        local cur_wid = api.nvim_tabpage_get_win(tid)
        for k, wid in ipairs(wids) do
            if wid == cur_wid then
                wids[1], wids[k] = wids[k], wids[1]
                return wids
            end
        end

        -- Make wids[1] = tabpage last accessed window
        local alt_wnr = api.nvim_win_call(cur_wid, function()
            return vim.fn.winnr('#')
        end)
        if alt_wnr ~= 0 then
            local alt_wid = vim.fn.win_getid(alt_wnr, api.nvim_tabpage_get_number(tid))
            for k, wid in ipairs(wids) do
                if wid == alt_wid then
                    wids[1], wids[k] = wids[k], wids[1]
                    return wids
                end
            end
        end
    end

    return wids
end

--- Get buffer or tabpage's items according to tabuf state
--- @param state TabufState
--- @return string[][] items
--- @return table[] state_items
function M.get_state_items(state)
    local cur_tid = api.nvim_get_current_tabpage()

    local tab_icon = function(tid)
        return (tid == cur_tid and copts.icons.tab or ' ') .. (#M.get_modified_bufs(tid, true) > 0 and '+' or ' ')
    end
    local alltab_icon = function(tid, idx, num)
        local s = copts.icons.tab_scope
        local f = copts.icons.tab_focus
        return tid == cur_tid and (idx == 1 and (num == 1 and f[1] or f[2]) or (idx == num and f[4] or f[3]))
            or (idx == 1 and (num == 1 and s[1] or s[2]) or (idx == num and s[4] or s[3]))
    end
    local buf_icon = function(bid, cur_bid, bid2wid)
        return (bid == cur_bid and copts.icons.focus or bid2wid[bid] and copts.icons.win or ' ')
            .. (fn.getbufvar(bid, '&modified') == 1 and '+' or ' ')
    end
    local lookup = function(wids)
        local bid2wid = {}
        for _, wid in ipairs(wids) do
            bid2wid[api.nvim_win_get_buf(wid)] = wid
        end
        return bid2wid
    end

    local items = {}
    local state_items = {}
    if state == M.State.Sigtab then
        local bid2wid = lookup(M.get_target_wins(cur_tid))
        for k, bid in ipairs(tabctx[cur_tid].bufs) do
            table.insert(items, {
                buf_icon(bid, api.nvim_get_current_buf(), bid2wid),
                M.buf_name(cur_tid, bid),
            })
            table.insert(state_items, { tid = cur_tid, bid = bid, wid = bid2wid[bid], idx = k })
        end
    elseif state == M.State.Alltab then
        for _, tid in ipairs(api.nvim_list_tabpages()) do
            local num = M.buf_num(tid)
            local bid2wid = lookup(M.get_target_wins(tid))
            for k, bid in ipairs(tabctx[tid].bufs) do
                table.insert(items, {
                    alltab_icon(tid, k, num) .. buf_icon(bid, api.nvim_win_get_buf(api.nvim_tabpage_get_win(tid)), bid2wid),
                    M.buf_name(tid, bid),
                })
                table.insert(state_items, { tid = tid, bid = bid, wid = bid2wid[bid], idx = k })
            end
        end
    elseif state == M.State.Listab then
        for _, tid in ipairs(api.nvim_list_tabpages()) do
            table.insert(items, { tab_icon(tid), M.tab_name(tid, true) })
            table.insert(state_items, { tid = tid })
        end
    end

    return items, state_items
end

--- Get tabpage's status for tabline
--- @return TabufStatus[]
function M.get_tabstatus()
    local cur_tid = api.nvim_get_current_tabpage()
    --- @type TabufStatus[]
    local res = {}
    for k, tid in ipairs(api.nvim_list_tabpages()) do
        res[#res + 1] = {
            id = tid,
            idx = k,
            name = M.tab_name(tid),
            current = tid == cur_tid,
            modified = #M.get_modified_bufs(tid, true) > 0,
        }
    end
    return res
end

--- Get tabpage's buffers status for tabline
--- @param tid TabID? nil for nvim_get_current_tabpage()
--- @return TabufStatus[]
function M.get_bufstatus(tid)
    local cur_tid = tid or api.nvim_get_current_tabpage()
    if not tabctx[cur_tid] then
        return {}
    end
    local cur_bid = api.nvim_win_get_buf(api.nvim_tabpage_get_win(cur_tid))
    if not M.buf_idx(cur_tid, cur_bid) then
        cur_bid = tabctx[cur_tid].bufs[tabctx[cur_tid].icur]
    end
    --- @type TabufStatus[]
    local res = {}
    for k, bid in ipairs(tabctx[cur_tid].bufs) do
        res[#res + 1] = {
            id = bid,
            idx = k,
            name = M.buf_name(cur_tid, bid, true),
            current = bid == cur_bid,
            modified = fn.getbufvar(bid, '&modified') == 1,
        }
    end
    return res
end

--- Add a tabpage (mainly for M.tab_callback)
--- @param tid TabID
function M._add_tab(tid)
    tabctx[tid] = { bufs = {}, icur = 1, istt = 1 }
    log('append tabpage: tid = %d, tnr = %d', tid, api.nvim_tabpage_get_number(tid))
end

--- Delete a tabpage (mainly for M.tab_callback)
--- @param tid TabID
function M._del_tab(tid)
    if not tabctx[tid] then
        return
    end
    for _, bid in ipairs(tabctx[tid].bufs) do
        bufctx[bid].cnt = math.max(bufctx[bid].cnt - 1, 0)
    end
    tabctx[tid] = nil
end

--- Add a buffer into a tabpage (mainly for M.buf_callback)
--- @param tid TabID
--- @param bid BufID
function M._add_buf(tid, bid)
    if not tabctx[tid] then
        return
    end
    local tnr = api.nvim_tabpage_get_number(tid)

    local info = fn.getbufinfo(bid)[1]
    if not info then
        log('catch an invalid buffer: tid = %d, tnr = %d, bid = %d', tid, tnr, bid)
        return
    end
    if info.listed == 0 and not bufctx[bid] then
        log('catch an unlisted buffer: tid = %d, tnr = %d, bid = %d, name = %s', tid, tnr, bid, info.name)
        return
    end
    if copts.tabuf.exclude_buffer(bid) then
        log('catch an excluded buffer: tid = %d, tnr = %d, bid = %d, name = %s', tid, tnr, bid, info.name)
        return
    end

    local tab = tabctx[tid]
    local bid_idx = M.buf_idx(tid, bid)
    if bid_idx then
        tab.icur = bid_idx
        log('switch buffer: tid = %d, tnr = %d, bid = %d, name = %s', tid, tnr, bid, info.name)
    else
        table.insert(tab.bufs, bid)
        tab.icur = #tab.bufs
        if bufctx[bid] then
            bufctx[bid].cnt = bufctx[bid].cnt + 1
        else
            bufctx[bid] = { cnt = 1 }
        end
        log('append buffer: tid = %d, tnr = %d, bid = %d, name = %s', tid, tnr, bid, info.name)
    end
end

--- Delete a buffer from a tabpage (mainly for M.buf_callback)
--- @param tid TabID
--- @param bid BufID
function M._del_buf(tid, bid)
    if not tabctx[tid] then
        return
    end
    local idx = M.buf_idx(tid, bid)
    if idx then
        table.remove(tabctx[tid].bufs, idx)
        bufctx[bid].cnt = math.max(bufctx[bid].cnt - 1, 0)
    end
end

--- Tabpage events
function M.tab_callback(args)
    log('tab_callback: event = %s', args.event)
    if args.event == 'TabNew' then
        local cur_tid = api.nvim_get_current_tabpage()
        M._add_tab(cur_tid)
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
            M._del_tab(t)
        end
    end
end

--- Buffer events
function M.buf_callback(args)
    log('buf_callback: ' .. args.event)
    local cur_tid = api.nvim_get_current_tabpage()
    if args.event == 'BufNew' then
        if not pctx.root_dir then
            pctx.root_dir = vim.fs.root(args.file, copts.root_marker)
            if pctx.root_dir then
                pctx.root_dir = vim.fs.normalize(pctx.root_dir)
            end
        end
    elseif args.event == 'BufEnter' then
        -- Update context for `nvim_get_current_win()`
        local bid_idx = M.buf_idx(cur_tid, api.nvim_get_current_buf())
        if bid_idx then
            tabctx[cur_tid].icur = bid_idx
        end
    elseif args.event == 'OptionSet' then
        -- Sometime 'BufWinEnter' happened before 'OptionSet buflisted=true'
        local bid = api.nvim_get_current_buf()
        if vim.v.option_new and not bufctx[bid] then
            M._add_buf(cur_tid, bid)
        end
    elseif args.event == 'BufWinEnter' then
        M._add_buf(cur_tid, api.nvim_get_current_buf())
    elseif args.event == 'BufWipeout' then
        --- Wipeout buffers from all tabpages
        local bid = args.buf -- <abuf>
        if bufctx[bid] then
            for _, tid in ipairs(api.nvim_list_tabpages()) do
                M._del_buf(tid, bid)
            end
            bufctx[bid] = nil
            local tnr = api.nvim_tabpage_get_number(cur_tid)
            log('wipeout buffer: tid = %d, tnr = %d, bid = %d, afile = %s', cur_tid, tnr, bid, args.file)
        end
    elseif args.event == 'VimEnter' then
        if M.tab_num() == 0 then
            M._add_tab(cur_tid)
        end
        --- @diagnostic disable-next-line: param-type-mismatch
        for _, arg in ipairs(fn.argv()) do
            log('append arg file: %s', arg)
            M._add_buf(cur_tid, fn.bufnr(arg))
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
        { 'OptionSet' },
        { group = 'Popc.Panel.Tabuf', pattern = { 'buflisted' }, callback = M.buf_callback }
    )
    api.nvim_create_autocmd(
        { 'BufNew', 'BufEnter', 'BufWinEnter', 'BufWipeout', (not vim.v.vim_did_enter) and 'VimEnter' or nil },
        { group = 'Popc.Panel.Tabuf', pattern = { '*' }, callback = M.buf_callback }
    )
    if vim.v.vim_did_enter then
        M.buf_callback({ event = 'VimEnter' })
    end

    local reset_tabline = function()
        vim.o.showtabline = 2
        vim.o.tabline = '%{%v:lua.require("popc.panel.tabuf.tabline").eval()%}'
    end
    if copts.tabuf.tabline then
        reset_tabline()
    end
    api.nvim_create_user_command('PopcTabuf', M.pop, { nargs = 0 })
    api.nvim_create_user_command('PopcTabufResetTabline', reset_tabline, { nargs = 0 })

    local buffer_switch_left = function(args)
        M.cmd_switch_buffer(args.bang, -(args.count == 0 and 1 or args.count))
    end
    local buffer_switch_right = function(args)
        M.cmd_switch_buffer(args.bang, args.count == 0 and 1 or args.count)
    end
    local buffer_jump_prev = function(args)
        M.cmd_jump_inside_buffer(-(args.count == 0 and 1 or args.count))
    end
    local buffer_jump_next = function(args)
        M.cmd_jump_inside_buffer(args.count == 0 and 1 or args.count)
    end
    api.nvim_create_user_command('PopcBufferSwitchLeft', buffer_switch_left, { bang = true, nargs = 0, count = true })
    api.nvim_create_user_command('PopcBufferSwitchRight', buffer_switch_right, { bang = true, nargs = 0, count = true })
    api.nvim_create_user_command('PopcBufferJumpPrev', buffer_jump_prev, { nargs = 0, count = true })
    api.nvim_create_user_command('PopcBufferJumpNext', buffer_jump_next, { nargs = 0, count = true })
    api.nvim_create_user_command('PopcBufferClose', M.cmd_close_buffer, { nargs = 0 })
end

function M.inspect()
    local tids = api.nvim_list_tabpages()
    local txt = 'tabids = ' .. vim.inspect(tids)
    txt = txt
        .. '\ntabctx = {\n  '
        .. vim.iter(tids)
            :map(function(tid)
                local res = vim.inspect(tabctx[tid]):gsub('\n ?', ''):gsub('}$', ' }')
                return ('[%d] = %s,'):format(tid, res)
            end)
            :flatten()
            :join('\n  ')
        .. '\n}'
    txt = txt
        .. '\nbufctx = {\n  '
        .. vim.iter(vim.iter(pairs(bufctx))
            :map(function(bid, buf)
                local res = vim.inspect(buf):gsub('\n ?', ''):gsub('}$', ' }')
                return ('[%d] = %s,'):format(bid, res)
            end)
            :totable())
            :flatten()
            :join('\n  ')
        .. '\n}'
    txt = txt
        .. ('\npctx = {\n  index = %d,\n  root_dir = %s,\n  items = {\n%s\n  },\n}'):format(
            vim.inspect(pctx.index),
            vim.inspect(pctx.root_dir),
            vim.iter(pctx.items)
                :map(function(item)
                    return ('    %s,'):format(vim.inspect(item))
                end)
                :join('\n')
        )
    return txt, tabctx, bufctx, pctx
end

pctx.on_quit = function(_, ukey)
    if ukey == nil then
        pctx.state_check = true
        pctx.state_index[pctx.state] = pctx.index
    end
end

--- Panel keys handler
local pkeys = pctx.pkeys

--- Transit from pctx.state to state
--- @param state TabufState?
local function transit_state(state)
    local item = pctx.state_items[pctx.index]
    if item then
        -- Store tabpage state item index
        if pctx.state ~= M.State.Listab then
            tabctx[item.tid].istt = item.idx
        end
        pctx.state_index[pctx.state] = pctx.index

        -- Update state item index
        if state then
            if pctx.state == M.State.Sigtab and state == M.State.Alltab then
                for _, tid in ipairs(api.nvim_list_tabpages()) do
                    if tid == item.tid then
                        break
                    end
                    pctx.index = pctx.index + M.buf_num(tid)
                end
            elseif pctx.state == M.State.Alltab and state == M.State.Sigtab then
                pctx.index = item.idx
            elseif pctx.state ~= M.State.Listab and state == M.State.Listab then
                pctx.index = pctx.state_index[state]
            elseif pctx.state == M.State.Listab and state == M.State.Sigtab then
                pctx.index = tabctx[api.nvim_get_current_tabpage()].istt
            elseif pctx.state == M.State.Listab and state == M.State.Alltab then
                pctx.index = pctx.state_index[state]
            end
        end
    end
    if state then
        pctx.state = state
    end
    pctx.items, pctx.state_items = M.get_state_items(pctx.state)
end

function pkeys.pop_buffers(uctx)
    pctx.text = copts.icons.tabuf .. ' Buffers'
    transit_state(M.State.Sigtab)
    uctx.state = umode.State.ReDisp
end

function pkeys.pop_tabpages(uctx)
    pctx.text = copts.icons.tabuf .. ' Tabpages'
    transit_state(M.State.Listab)
    uctx.state = umode.State.ReDisp
end

function pkeys.pop_tabpage_buffers(uctx)
    pctx.text = copts.icons.tabuf .. ' All tabpage buffers'
    transit_state(M.State.Alltab)
    uctx.state = umode.State.ReDisp
end

function pkeys.load_buffer_or_tabpage(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state == M.State.Listab then
        api.nvim_set_current_tabpage(item.tid)
        uctx.state = umode.State.RePop
    else
        local wid = M.get_target_wins(api.nvim_get_current_tabpage(), true)[1] or 0
        api.nvim_win_set_buf(wid, item.bid)
        uctx.state = umode.State.ReDisp
    end
    transit_state()
end

function pkeys.load_buffer_or_tabpage_quit(uctx)
    pkeys.load_buffer_or_tabpage(uctx)
    uctx.state = umode.State.None
end

function pkeys.goto_buffer_or_tabpage(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    local cur_tid = api.nvim_get_current_tabpage()

    uctx.state = umode.State.ReDisp
    if item.tid ~= cur_tid then
        api.nvim_set_current_tabpage(item.tid)
        uctx.state = umode.State.RePop
    end
    if pctx.state ~= M.State.Listab then
        local wid = M.get_target_wins(item.tid, true)[1] or 0
        api.nvim_win_set_buf(wid, item.bid)
    end

    transit_state()
end

function pkeys.goto_buffer_or_tabpage_quit(uctx)
    pkeys.goto_buffer_or_tabpage(uctx)
    uctx.state = umode.State.None
end

function pkeys.focus_on_window(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state == M.State.Listab then
        umode.notify("Can't focus window on tabpage list")
        return
    end

    if item.wid then
        api.nvim_tabpage_set_win(item.tid, item.wid)
        transit_state()
        uctx.state = umode.State.ReDisp
    else
        umode.notify("This buffer isn't displayed inside a window")
    end
end

function pkeys.split_buffer(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state == M.State.Listab then
        umode.notify("Can't split tabpage")
        return
    end

    local cur_tid = api.nvim_get_current_tabpage()
    local wid = M.get_target_wins(cur_tid, true)[1] or 0
    api.nvim_win_call(wid, vim.cmd.split)
    api.nvim_win_set_buf(wid, item.bid)

    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.split_buffer_quit(uctx)
    pkeys.split_buffer(uctx)
    uctx.state = umode.State.None
end

function pkeys.vsplit_buffer(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state == M.State.Listab then
        umode.notify("Can't vsplit tabpage")
        return
    end

    local cur_tid = api.nvim_get_current_tabpage()
    local wid = M.get_target_wins(cur_tid, true)[1] or 0
    api.nvim_win_call(wid, vim.cmd.vsplit)
    api.nvim_win_set_buf(wid, item.bid)

    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.vsplit_buffer_quit(uctx)
    pkeys.vsplit_buffer(uctx)
    uctx.state = umode.State.None
end

function pkeys.tabnew_buffer(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state == M.State.Listab then
        umode.notify("Can't tabnew tabpage")
        return
    end

    vim.opt.eventignore:append('BufWinEnter')
    vim.cmd.tabnew()
    vim.opt.eventignore:remove('BufWinEnter')
    api.nvim_win_set_buf(api.nvim_get_current_win(), item.bid)

    transit_state()
    uctx.state = umode.State.RePop
end

function pkeys.tabnew_buffer_quit(uctx)
    pkeys.tabnew_buffer(uctx)
    uctx.state = umode.State.None
end

--- Hide buffer and keep buffer window
local function hide_buffer(index)
    local item = pctx.state_items[index]
    if not item then
        return
    end

    local wids = M.get_target_wins(item.tid, false)
    if M.buf_num(item.tid) > 1 then
        for _, wid in ipairs(wids) do
            if item.bid == api.nvim_win_get_buf(wid) then
                local prev = pctx.state_items[index - 1]
                local next = pctx.state_items[index + 1]
                if next and next.tid == item.tid then
                    api.nvim_win_set_buf(wid, next.bid)
                elseif prev and prev.tid == item.tid then
                    api.nvim_win_set_buf(wid, prev.bid)
                end
            end
        end
    else
        local tmp_bid = api.nvim_create_buf(true, true)
        for _, wid in ipairs(wids) do
            api.nvim_win_set_buf(wid, tmp_bid)
        end
    end
end

--- Delete buffer and keep buffer window
local function delete_buffer(index)
    local item = pctx.state_items[index]
    if not item then
        return
    end

    hide_buffer(index)
    M._del_buf(item.tid, item.bid)

    -- Hide buffer may result BufWipeout, so check bufctx[item.bid] first
    if bufctx[item.bid] and bufctx[item.bid].cnt == 0 then
        vim.cmd.bdelete({ bang = true, count = item.bid, mods = { silent = true } })
    end
end

function pkeys.close_buffer(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state ~= M.State.Sigtab and pctx.state ~= M.State.Alltab then
        return
    end

    -- Unsaved changes
    if
        bufctx[item.bid].cnt == 1
        and fn.getbufvar(item.bid, '&modified') == 1
        and (not umode.confirm(("This buffer '%s' contains unsaved changes. Continue anyway?"):format(fn.bufname(item.bid))))
    then
        return
    end

    delete_buffer(pctx.index)

    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.close_tabpage(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state ~= M.State.Listab then
        return
    end

    -- Unsaved changes
    if
        #M.get_modified_bufs(item.tid, true) > 0
        and (not umode.confirm('This tabpage contains unsaved modified buffer. Continue anyway?'))
    then
        return
    end

    -- Switch to another tabpage
    uctx.state = umode.State.ReDisp
    if item.tid == api.nvim_get_current_tabpage() then
        local prev = pctx.state_items[pctx.index - 1]
        local next = pctx.state_items[pctx.index + 1]
        if next and next.tid == item.tid then
            api.nvim_set_current_tabpage(next.tid)
            uctx.state = umode.State.RePop
        elseif prev and prev.tid == item.tid then
            api.nvim_set_current_tabpage(prev.tid)
            uctx.state = umode.State.RePop
        end
    end

    -- Close tabpage
    for _, bid in ipairs(vim.deepcopy(tabctx[item.tid].bufs)) do
        -- deepcopy: tabctx[].bufs may changes resulted from bdelete
        M._del_buf(item.tid, bid)
        if bufctx[bid].cnt == 0 then
            vim.cmd.bdelete({ bang = true, count = bid, mods = { silent = true } })
        end
    end
    if #api.nvim_list_tabpages() > 1 and api.nvim_tabpage_is_valid(item.tid) then
        vim.cmd.tabclose({ args = { tostring(api.nvim_tabpage_get_number(item.tid)) } })
    end

    transit_state()
end

function pkeys.close_buffer_or_tabpage(uctx)
    pkeys.close_buffer(uctx)
    pkeys.close_tabpage(uctx)
end

function pkeys.close_all_buffers(uctx)
    local item = pctx.state_items[pctx.index]
    if not item then
        return
    end
    if pctx.state ~= M.State.Sigtab and pctx.state ~= M.State.Alltab then
        return
    end

    -- Unsaved changes
    if
        #M.get_modified_bufs(item.tid, true) > 0
        and (not umode.confirm('This tabpage contains unsaved modified buffer. Continue anyway?'))
    then
        return
    end

    -- Close all tabpage's buffers
    local bids = vim.deepcopy(tabctx[item.tid].bufs)
    local wids = M.get_target_wins(item.tid, false)
    local tmp_bid = api.nvim_create_buf(true, true)
    for _, wid in ipairs(wids) do
        api.nvim_win_set_buf(wid, tmp_bid)
    end
    for _, bid in ipairs(bids) do
        M._del_buf(item.tid, bid)
        if bufctx[bid].cnt == 0 then
            vim.cmd.bdelete({ bang = true, count = bid, mods = { silent = true } })
        end
    end

    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.close_all_tabpages(uctx)
    if pctx.state ~= M.State.Listab then
        return
    end
    if M.cmd_clear_all() then
        transit_state(M.State.Sigtab)
        uctx.state = umode.State.ReNew
    end
end

function pkeys.close_all_buffers_or_tabpages(uctx)
    pkeys.close_all_buffers(uctx)
    pkeys.close_all_tabpages(uctx)
end

local function close_window(index, also_buffer)
    if pctx.state == M.State.Listab then
        umode.notify("Can't close window on tabpage")
        return false
    end
    local item = pctx.state_items[index]
    if not item then
        return
    end

    if item.wid then
        local wids = M.get_target_wins(item.tid, false)
        if #wids == 1 then
            umode.notify("Can't close the only one window")
        else
            if also_buffer then
                delete_buffer(index)
            end
            api.nvim_win_close(item.wid, false)
            return true
        end
    else
        umode.notify('This item is not a window')
    end
end

function pkeys.close_window(uctx)
    if close_window(pctx.index, false) then
        transit_state()
        uctx.state = umode.State.ReDisp
    end
end

function pkeys.close_window_and_buffer(uctx)
    if close_window(pctx.index, true) then
        transit_state()
        uctx.state = umode.State.ReDisp
    end
end

function pkeys.switch_to_prev_tabpage(uctx)
    vim.cmd.normal({ bang = true, args = { 'gT' }, mods = { silent = true } })
    transit_state()
    uctx.state = umode.State.RePop
end

function pkeys.switch_to_next_tabpage(uctx)
    vim.cmd.normal({ bang = true, args = { 'gt' }, mods = { silent = true } })
    transit_state()
    uctx.state = umode.State.RePop
end

--- @param direction integer +1 for next, -1 for prev
--- @return integer new_index
local function move_buffer(index, direction)
    local item = pctx.state_items[index]
    if not item then
        return index
    end
    local move = (index + direction - 1) % #pctx.state_items + 1
    local bids = tabctx[item.tid].bufs
    bids[index], bids[move] = bids[move], bids[index]
    return move
end

--- @param direction integer +1 for next, -1 for prev
--- @return integer new_index
local function move_tabpage(index, direction)
    local item = pctx.state_items[index]
    if not item then
        return index
    end
    local move = (index + direction - 1) % #pctx.state_items + 1
    api.nvim_win_call(api.nvim_tabpage_get_win(item.tid), function()
        if direction == -1 then
            vim.cmd.tabmove({ args = { index == 1 and '$' or '-' } })
        elseif direction == 1 then
            vim.cmd.tabmove({ args = { index == #pctx.state_items and '0' or '+' } })
        end
    end)
    return move
end

--- Move Buffer to next or prev tabpage
--- @param direction integer +1 for next, -1 for prev
--- @return integer? new_index The new pctx.index
local function move_buffer_to_tabpage(index, direction)
    local item = pctx.state_items[index]
    if not item then
        return
    end
    if M.tab_num() == 1 then
        umode.notify("There's no another tabpage to place moved buffer")
        return
    end

    local tids = api.nvim_list_tabpages()
    local tid_idx = list_index(tids, item.tid)
    if tid_idx then
        -- Get the new tabpage
        local newtid_idx = (tid_idx + direction - 1) % #tids + 1
        local newtid = tids[newtid_idx]

        -- Move out the target buffer from old tabpage to new tabpage
        local bid_idx = M.buf_idx(item.tid, item.bid)
        if bid_idx then
            hide_buffer(index)
            table.remove(tabctx[item.tid].bufs, bid_idx)
            table.insert(tabctx[newtid].bufs, item.bid)

            -- Get new index for the target buffer
            local new_index = 0
            for k = 1, newtid_idx do
                new_index = new_index + M.buf_num(tids[k])
            end
            return new_index
        else
            log('Try to move an invalid buffer: tid = %d, bid = %d', item.tid, item.bid)
        end
    else
        log('Try to move buffer into an invalid tabpage: tid = %d, bid = %d', item.tid, item.bid)
    end
end

function pkeys.move_buffer_or_tabpage_to_prev(uctx)
    if pctx.state == M.State.Sigtab then
        pctx.index = move_buffer(pctx.index, -1)
    elseif pctx.state == M.State.Alltab then
        local new_index = move_buffer_to_tabpage(pctx.index, -1)
        if not new_index then
            return
        end
        pctx.index = new_index
    else
        pctx.index = move_tabpage(pctx.index, -1)
    end
    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.move_buffer_or_tabpage_to_next(uctx)
    if pctx.state == M.State.Sigtab then
        pctx.index = move_buffer(pctx.index, 1)
    elseif pctx.state == M.State.Alltab then
        local new_index = move_buffer_to_tabpage(pctx.index, 1)
        if not new_index then
            return
        end
        pctx.index = new_index
    else
        pctx.index = move_tabpage(pctx.index, 1)
    end
    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.move_out_buffer_or_tabpage_to_prev(uctx)
    if pctx.state == M.State.Sigtab then
        move_buffer(pctx.index, -1)
    elseif pctx.state == M.State.Alltab then
        if not move_buffer_to_tabpage(pctx.index, -1) then
            return
        end
    else
        move_tabpage(pctx.index, -1)
    end
    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.move_out_buffer_or_tabpage_to_next(uctx)
    if pctx.state == M.State.Sigtab then
        move_buffer(pctx.index, 1)
    elseif pctx.state == M.State.Alltab then
        if not move_buffer_to_tabpage(pctx.index, 1) then
            return
        end
    else
        move_tabpage(pctx.index, 1)
    end
    transit_state()
    uctx.state = umode.State.ReDisp
end

function pkeys.set_tabpage_label(uctx)
    local label = umode.input({ prompt = 'Set tabpage label: ' })
    if label then
        local item = pctx.state_items[pctx.index]
        if not item then
            return
        end
        if label == '' then
            tabctx[item.tid].label = nil
        else
            tabctx[item.tid].label = label
        end
        transit_state()
        uctx.state = umode.State.ReDisp
    end
end

function pkeys.set_tabpage_dir(uctx)
    local tdir = umode.input({ prompt = 'Set tabpage base directory: ', completion = 'file' })
    if tdir then
        local item = pctx.state_items[pctx.index]
        if not item then
            return
        end
        if tdir == '' then
            tabctx[item.tid].tdir = nil
        else
            tdir = fn.fnamemodify(tdir, ':p')
            tabctx[item.tid].tdir = vim.fs.normalize(tdir, { expand_env = true })
        end
        transit_state()
        uctx.state = umode.State.ReDisp
    end
end

function pkeys.toggle_fullpath(uctx)
    pctx.fullpath = not pctx.fullpath
    transit_state()
    uctx.state = umode.State.ReDisp
end

function M.pop()
    pctx.text = copts.icons.tabuf .. ' Buffers'
    -- Re-get state items before transit state, in case of there's buffer or tabpage changes of `pctx.state`
    if pctx.state_check then
        pctx.items, pctx.state_items = M.get_state_items(pctx.state)
        pctx.state_check = false
    end
    transit_state(M.State.Sigtab)
    umode.apop(pctx)
end

--- @return table<TabID, TabContext>
function M.cmd_get_tabctx()
    return tabctx
end

--- @param tid TabID
--- @param attr TabContext
function M.cmd_set_tabctx(tid, attr)
    if tabctx[tid] then
        tabctx[tid] = vim.tbl_deep_extend('force', tabctx[tid], attr)
    end
end

--- @return table<BufID, BufContext>
function M.cmd_get_bufctx()
    return bufctx
end

--- @param bid BufID
--- @param attr BufContext
function M.cmd_set_bufctx(bid, attr)
    if bufctx[bid] then
        bufctx[bid] = vim.tbl_deep_extend('force', bufctx[bid], attr)
    end
end

--- @param root_dir string?
function M.cmd_set_root(root_dir)
    pctx.root_dir = root_dir
end

--- Switch target window's buffer to another buffer
--- @param bang boolean true to switch from target window buffer, false to switch from current buffer
--- @param direction integer +n for next, -n for prev
function M.cmd_switch_buffer(bang, direction)
    local cur_tid = api.nvim_get_current_tabpage()
    local num = M.buf_num(cur_tid)
    if num <= 1 then
        return
    end

    local wid = M.get_target_wins(cur_tid, true)[1] or 0
    local bid = bang and api.nvim_win_get_buf(wid) or api.nvim_get_current_buf()
    local idx = M.buf_idx(cur_tid, bid)
    if idx then
        idx = (idx + direction - 1) % num + 1
        api.nvim_win_set_buf(wid, tabctx[cur_tid].bufs[idx])
    else
        umode.notify("Can't switch from this buffer for it's out of Popc.Tabuf")
    end
end

--- Jump inside current buffer according to jumplist
--- @param direction integer +n for next, -n for prev
function M.cmd_jump_inside_buffer(direction)
    local jumplist = fn.getjumplist()
    local lst, idx = jumplist[1], jumplist[2] + 1
    local cur_bid = api.nvim_get_current_buf()

    local cmd
    local step
    local stop
    if direction < 0 then
        cmd = '%d<C-o>'
        step, stop = -1, 1
    elseif direction > 0 then
        cmd = '%d<C-i>'
        step, stop = 1, #lst
    end
    if cmd then
        local cnt = 0
        local num = math.abs(direction)
        for k = idx + step, stop, step do
            if lst[k].bufnr == cur_bid then
                cnt = cnt + 1
                if cnt == num then
                    -- Why '<C-i/o>' only work with `nvim_feedkeys` with lua, buf not with `vim.cmd.normal`?
                    api.nvim_feedkeys(vim.keycode(cmd:format(math.abs(k - idx))), 'n', false)
                    break
                end
            end
        end
    end
end

--- Close current window's buffer
function M.cmd_close_buffer()
    local cur_tid = api.nvim_get_current_tabpage()
    local cur_bid = api.nvim_get_current_buf()
    local cur_bid_idx = M.buf_idx(cur_tid, cur_bid)
    if not cur_bid_idx then
        umode.notify("Can't close this buffer for it's out of Popc.Tabuf")
        return
    end
    if
        bufctx[cur_bid].cnt == 1
        and fn.getbufvar(cur_bid, '&modified') == 1
        and (not umode.confirm(("This buffer '%s' contains unsaved changes. Continue anyway?"):format(fn.bufname(cur_bid))))
    then
        return
    end

    local wids = M.get_target_wins(cur_tid)
    local num = M.buf_num(cur_tid)
    if num > 1 then
        -- Try switch to the last accessed buffer
        local alt_bid = fn.bufnr('#')
        if not M.buf_idx(cur_tid, alt_bid) then
            alt_bid = tabctx[cur_tid].bufs[cur_bid_idx == num and (cur_bid_idx - 1) or (cur_bid_idx + 1)]
        end

        -- Close buffer
        for _, wid in ipairs(wids) do
            if cur_bid == api.nvim_win_get_buf(wid) then
                api.nvim_win_set_buf(wid, alt_bid)
            end
        end
    else
        local tmp_bid = api.nvim_create_buf(true, true)
        for _, wid in ipairs(wids) do
            api.nvim_win_set_buf(wid, tmp_bid)
        end
    end
    M._del_buf(cur_tid, cur_bid)
    if bufctx[cur_bid].cnt == 0 then
        vim.cmd.bdelete({ bang = true, count = cur_bid, mods = { silent = true } })
    end
end

--- Clear all tabpages and buffers
--- @return boolean
function M.cmd_clear_all()
    -- Unsaved changes
    local has_modified = false
    for _, tid in ipairs(api.nvim_list_tabpages()) do
        if #M.get_modified_bufs(tid, true) > 0 then
            has_modified = true
            break
        end
    end
    if has_modified and (not umode.confirm('There are unsaved modified buffers. Continue anyway?')) then
        return false
    end

    -- Close all tabpages and all buffers
    tabctx = {}
    bufctx = {}
    pctx.index = 1
    pctx.state = M.State.Sigtab
    pctx.state_index = {
        [M.State.Sigtab] = 1,
        [M.State.Alltab] = 1,
        [M.State.Listab] = 1,
    }
    vim.cmd.tabonly({ bang = true, mods = { noautocmd = true, silent = true } })
    vim.cmd('silent! %bdelete!')
    -- vim.cmd('silent! %bwipeout!') -- TODO: Some dangerous?
    M._add_tab(api.nvim_get_current_tabpage())
    return true
end

return M

--- @class Popc.Panel.TabufTablie
local M = {}
local fn = vim.fn
local api = vim.api
local copts = require('popc.config').opts

local PadL = copts.icons.pads[1]
local PadR = copts.icons.pads[2]
local PrevIdx = 0 -- Prev index
local NextIdx = 0xfffffff -- Next index
local HlMap = {
    [false] = { [false] = 'PopcTlNormal', [true] = 'PopcTlModified' },
    [true] = { [false] = 'PopcTlCurrent', [true] = 'PopcTlCurrentModified' },
}

--- Switch buffer via click on tabline
--- @param bid BufID
--- @param clicks integer
--- @param button string 'l', 'r' or 'm' for mouse button
--- @param modifiers string 'c', 's' or 'm' for pressed modifiers
_G.popc_tabuf_tabline_switch_buffer = function(bid, clicks, button, modifiers)
    if clicks == 1 and button == 'l' and (not modifiers:match('[csm]')) then
        if bid == PrevIdx then
            require('popc.panel.tabuf').cmd_switch_buffer(true, -1)
        elseif bid == NextIdx then
            require('popc.panel.tabuf').cmd_switch_buffer(true, 1)
        else
            local cur_tid = api.nvim_get_current_tabpage()
            local wid = require('popc.panel.tabuf').get_target_wins(cur_tid, true)[1] or 0
            api.nvim_win_set_buf(wid, bid)
        end
    end
end

--- Switch tabpage via click on tabline
--- @param tid TabID
--- @param clicks integer
--- @param button string 'l', 'r' or 'm' for mouse button
--- @param modifiers string 'c', 's' or 'm' for pressed modifiers
_G.popc_tabuf_tabline_switch_tabpage = function(tid, clicks, button, modifiers)
    if clicks == 1 and button == 'l' and (not modifiers:match('[csm]')) then
        if tid == PrevIdx then
            vim.cmd.normal({ bang = true, args = { 'gT' }, mods = { silent = true } })
        elseif tid == NextIdx then
            vim.cmd.normal({ bang = true, args = { 'gt' }, mods = { silent = true } })
        else
            api.nvim_set_current_tabpage(tid)
        end
    end
end

M.switch_buffer = 'v:lua.popc_tabuf_tabline_switch_buffer'

M.switch_tabpage = 'v:lua.popc_tabuf_tabline_switch_tabpage'

--- Adjust buffer and tabpage status elements
--- @param buflst TabufStatus[]
--- @param tablst TabufStatus[]
--- @param padwid integer The pad display width for each status element
--- @param maxwid integer The max display width for buffer and tabpage elements
--- @return TabufStatus[] newbuflst
--- @return TabufStatus[] newtablst
function M.adjust(buflst, tablst, padwid, maxwid)
    local pnwid = padwid + fn.strdisplaywidth(copts.icons.dots) -- Prev/Next element width

    --- @param lst TabufStatus[]
    local function get_attr(lst)
        local attr = {
            si = 0, -- Start index
            ei = 0, -- End index
            cur = 0, -- Current index
            num = #lst, -- Number of elements
            wid = {}, -- Width list
        }
        local sum = 0
        for k, stt in ipairs(lst) do
            if stt.current then
                attr.cur = k
            end
            local stt_wid = padwid + fn.strdisplaywidth(stt.name) + (stt.modified and 1 or 0)
            table.insert(attr.wid, stt_wid)
            sum = sum + stt_wid
        end
        return attr, sum
    end

    local function get_siei(attr, extsum)
        local sum = attr.wid[attr.cur] + extsum
        local si = attr.cur
        local ei = attr.cur
        while ei - si + 1 < attr.num do
            if ei + 1 <= attr.num then
                ei = ei + 1
                if sum + attr.wid[ei] + (si > 1 and pnwid or 0) + (ei < attr.num and pnwid or 0) < maxwid then
                    sum = sum + attr.wid[ei]
                else
                    ei = ei - 1
                    break
                end
            end
            if si - 1 >= 1 then
                si = si - 1
                if sum + attr.wid[si] + (si > 1 and pnwid or 0) + (ei < attr.num and pnwid or 0) < maxwid then
                    sum = sum + attr.wid[si]
                else
                    si = si + 1
                    break
                end
            end
        end
        attr.si = si
        attr.ei = ei
        return sum
    end

    --- @param lst TabufStatus[]
    --- @return TabufStatus[] newlst
    local function get_status(lst, attr)
        local newlst = {}
        if attr.si > 1 then
            table.insert(newlst, {
                id = PrevIdx,
                idx = PrevIdx,
                name = copts.icons.dots,
                current = false,
                modified = false,
            })
        end
        for k = attr.si, attr.ei do
            table.insert(newlst, lst[k])
        end
        if attr.ei < attr.num then
            table.insert(newlst, {
                id = NextIdx,
                idx = NextIdx,
                name = copts.icons.dots,
                current = false,
                modified = false,
            })
        end
        return newlst
    end

    local bufattr, bufsum = get_attr(buflst)
    local tabattr, tabsum = get_attr(tablst)
    if bufsum + tabsum < maxwid then
        -- No need adjust
        return buflst, tablst
    end

    -- Need adjust
    local newbuflst, newtablst
    tabsum = tabattr.wid[tabattr.cur] + (tabattr.cur > 1 and pnwid or 0) + (tabattr.cur < tabattr.num and pnwid or 0)
    if bufsum + tabsum < maxwid then
        -- Need adjust tabpage status elements only
        newbuflst = buflst
        get_siei(tabattr, bufsum)
        newtablst = get_status(tablst, tabattr)
    else
        -- Need adjust both buffer and tabpage status elements
        get_siei(bufattr, tabsum)
        newbuflst = get_status(buflst, bufattr)
        tabattr.si = tabattr.cur
        tabattr.ei = tabattr.cur
        newtablst = get_status(tablst, tabattr)
    end
    return newbuflst, newtablst
end

--- Evaluate status item for tabline
--- @param stt TabufStatus
--- @param on_click string
function M.eval_status_item(stt, on_click)
    local hlname = HlMap[stt.current][stt.modified]
    local hlpad = hlname .. 'Pad'
    return ('%%%d@%s@' .. '%%#%s#%s' .. '%%#%s#%s' .. '%%#%s#%s' .. '%%T'):format(
        stt.id,
        on_click,
        hlpad,
        PadL,
        hlname,
        stt.name .. (stt.modified and '+' or ''),
        hlpad,
        PadR
    )
end

--- Evaluate tabline
function M.eval()
    local buflst, tablst = M.adjust(
        require('popc.panel.tabuf').get_bufstatus(api.nvim_get_current_tabpage()),
        require('popc.panel.tabuf').get_tabstatus(),
        2,
        vim.o.columns - 4
    )

    local expr = ('%%#%s#%s' .. '%%#%s#%s'):format('PopcTlBar', copts.icons.tlbuf, 'PopcTlBarPad', PadR)
    for _, buf in ipairs(buflst) do
        expr = expr .. M.eval_status_item(buf, M.switch_buffer)
    end
    expr = expr .. '%='
    for _, tab in ipairs(tablst) do
        expr = expr .. M.eval_status_item(tab, M.switch_tabpage)
    end
    expr = expr .. ('%%#%s#%s' .. '%%#%s#%s'):format('PopcTlBarPad', PadL, 'PopcTlBar', copts.icons.tltab)
    return expr
end

return M

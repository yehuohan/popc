--- @class Popc.Panel.Selection
local M = {}
local api = vim.api
local copts = require('popc.config').opts
local umode = require('popc.usermode')

--- @class PopSelection
--- @field opt nil|string|fun():string Option name
--- @field dic nil|table<string,string|PopSelection>|fun(opt:string):table<string,string|PopSelection>
---             * table<string, string>       : 'lst' desctiption
---             * table<string, PopSelection> : sub-selection
--- @field lst nil|any[]|fun(opt:string):any[]
---             * any[]    : Selection item list
---             * string[] : Key index list of 'dic'
--- @field dsr nil|string|fun(opt:string):string 'opt' description
--- @field cpl nil|string|fun(opt:string):string 'completion' of `input()`
--- @field cmd nil|fun(opt:string, sel) Command executed with selected item of 'lst'
--- @field get nil|fun(opt:string):any Get the selected item of 'opt'
--- @field evt nil|fun(event:string) Selection event callback
---            * 'onCR'   : called at `pkeys.confirm` (called after executed 'cmd')
---            * 'onQuit' : called at `pctx.on_quit`
--- @field sub nil|table<string,any|fun(...):any>|fun(opt:string):table<string,any|fun(...):any>
---            Shared 'lst', 'dsr', 'cpl', 'cmd', 'get', 'evt' for 'dic' sub-selection

--- @class ResolvedSelection
--- @field opt string
--- @field dic table<string,string>|table<string,PopSelection>
--- @field lst any[]
--- @field dsr string
--- @field cpl string?
--- @field cmd fun(opt, sel)
--- @field get fun(opt):any
--- @field sub table<string,string|fun()>
--- @field is_rsv boolean Is a resolved node
--- @field is_base boolean Is a base node (has sub-selection)
--- @field is_open boolean Base node is opened or folded

--- @param node PopSelection
--- @param base ResolvedSelection?
--- @param opt string? Use 'base.lst' item as a fullback sub-selection 'opt'
--- @return ResolvedSelection
local function resolve(node, base, opt)
    local try_call = function(fn, ...)
        return vim.is_callable(fn) and fn(...) or fn
    end

    local sub = base and base.sub or {}
    local sel = {}
    sel.opt = node.opt and try_call(node.opt) or opt or ''
    sel.dic = node.dic and try_call(node.dic, sel.opt) or vim.empty_dict()
    sel.lst = try_call(node.lst or sub.lst, sel.opt) or vim.tbl_keys(sel.dic)
    sel.dsr = try_call(node.dsr or sub.dsr, sel.opt) or ''
    sel.cpl = try_call(node.cpl or sub.cpl, sel.opt)
    sel.cmd = node.cmd or sub.cmd or function()
        umode.notify("No 'cmd' to execute")
    end
    sel.get = node.get or sub.get or function()
        return nil
    end
    sel.sub = try_call(node.sub) or {}
    sel.is_rsv = true
    sel.is_base = false
    sel.is_open = false

    -- Check sub-selection
    for _, val in ipairs(sel.lst) do
        local val_type = type(sel.dic[val])
        if val_type == 'table' then
            sel.is_base = true
        elseif val_type ~= 'string' and val_type ~= 'nil' then
            umode.notify(
                ('PopSelection.dic values must be table|string|nil:\ndic[%s] = %s'):format(
                    vim.inspect(val),
                    vim.inspect(sel.dic[val])
                )
            )
        end
    end

    return sel
end

--- @param node PopSelection|ResolvedSelection
--- @param base ResolvedSelection?
--- @return string[][] items
--- @return ResolvedSelection sel_root
--- @return table[] sel_items
local function get_sel_items(node, base)
    local items = {}
    local sel_items = {}

    local function add_sel_items(level, rsv_node)
        local indent = (' '):rep(2 * level)

        for idx, val in ipairs(rsv_node.lst) do
            local subrsv_node = rsv_node.dic[val]
            if type(subrsv_node) == 'table' then
                -- Ensure resovled sub-selection
                if not subrsv_node.is_rsv then
                    subrsv_node = resolve(subrsv_node, rsv_node, val)
                    rsv_node.dic[val] = subrsv_node
                end

                -- Get sub-selection description
                local dsr = subrsv_node.dsr
                local out = nil -- The output result of sub-selection
                local is_out = false
                if not subrsv_node.is_base then
                    out = subrsv_node.get(subrsv_node.opt)
                    dsr = type(out) == 'string' and out or vim.inspect(out)
                    is_out = true
                end
                table.insert(items, { indent .. val, dsr == '' and '' or ':', dsr })
                table.insert(sel_items, { node = subrsv_node, is_base = true, is_out = is_out, out = out })

                -- Get items recursively
                if subrsv_node.is_open then
                    add_sel_items(level + 1, subrsv_node)
                end
            else
                -- Get selection item description
                local dsr = rsv_node.dic[val] or ''
                local out = rsv_node.get(rsv_node.opt)
                local icon = ''
                if not rsv_node.is_base then
                    -- Only non-base selection need indicate the output result
                    icon = (out == val and copts.icons.focus or ' ') .. ' '
                end
                table.insert(items, { ('%s%s%s'):format(indent, icon, tostring(val)), dsr == '' and '' or ':', dsr })
                table.insert(sel_items, { node = rsv_node, is_base = false, is_out = true, out = out, idx = idx })
            end
        end
    end

    --- @type ResolvedSelection
    --- @diagnostic disable-next-line: assign-type-mismatch, param-type-mismatch
    local sel_root = node.is_rsv and node or resolve(node, base)
    add_sel_items(0, sel_root)

    return items, sel_root, sel_items
end

--- Selection panel context
--- @type PanelContext
local pctx = {
    name = 'Selection',
    text = '',
    items = {},
    index = 1,
    keys = copts.selection.keys,
    pkeys = {},
    on_quit = nil,
    -- Specified panel data
    --- @type PopSelection
    sel = nil,
    sel_root = nil, -- Resolved root selection node
    sel_items = nil,
}

--- Setup selection root and items
--- @return boolean? Success or not
local function setup_sel_items()
    local items, sel_root, sel_items = get_sel_items(pctx.sel_root or pctx.sel)
    pctx.text = sel_root.opt
    pctx.items = items
    pctx.sel_root = sel_root
    pctx.sel_items = sel_items
end

function M.setup()
    api.nvim_create_user_command('PopcSet', M.pop, { nargs = 0 })
end

function M.inspect()
    return vim.inspect(pctx), pctx
end

pctx.on_quit = function(uctx)
    if pctx.sel.evt then
        pctx.sel.evt('onQuit')
    end
    uctx.pret = false
end

--- Panel keys handler
local pkeys = pctx.pkeys

function pkeys.confirm(uctx)
    if pctx.sel.evt then
        pctx.sel.evt('onCR')
    end
    uctx.pret = true
    uctx.state = umode.State.None
end

function pkeys.execute_confirm(uctx)
    local item = pctx.sel_items[pctx.index]
    if item and not item.is_base then
        item.node.cmd(item.node.opt, item.node.lst[item.idx])
    end

    pkeys.confirm(uctx)
end

function pkeys.execute(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.is_base then
        item.node.is_open = not item.node.is_open
    else
        item.node.cmd(item.node.opt, item.node.lst[item.idx])
    end
    setup_sel_items()
    uctx.state = umode.State.ReDisp
end

function pkeys.next_lst_item(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.is_out then
        local cur = table.foreachi(item.node.lst, function(k, v)
            return v == item.out and k or nil
        end) or 0
        item.node.cmd(item.node.opt, item.node.lst[cur % #item.node.lst + 1])
        setup_sel_items()
        uctx.state = umode.State.ReDisp
    else
        umode.notify("This selection has sub-selections and can't be modified")
    end
end

function pkeys.prev_lst_item(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.is_out then
        local cur = table.foreachi(item.node.lst, function(k, v)
            return v == item.out and k or nil
        end) or 1
        item.node.cmd(item.node.opt, item.node.lst[(cur - 2) % #item.node.lst + 1])
        setup_sel_items()
        uctx.state = umode.State.ReDisp
    else
        umode.notify("This selection has sub-selections and can't be modified")
    end
end

function pkeys.modify(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.is_out then
        local val = umode.input({ prompt = 'Modify: ', completion = item.node.cpl })
        if val then
            item.node.cmd(item.node.opt, val)
            setup_sel_items()
            uctx.state = umode.State.ReDisp
        end
    else
        umode.notify("This selection has sub-selections and can't be modified")
    end
end

function pkeys.modify_current(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.is_out then
        local val = umode.input({ prompt = 'Modify: ', default = item.out, completion = item.node.cpl })
        if val then
            item.node.cmd(item.node.opt, val)
            setup_sel_items()
            uctx.state = umode.State.ReDisp
        end
    else
        umode.notify("This selection has sub-selections and can't be modified")
    end
end

--- Pop out selection panel of custom selections
--- @param sel PopSelection
function M.pop_selection(sel)
    pctx.index = 1
    pctx.sel = sel
    pctx.sel_root = nil
    pctx.sel_items = nil
    setup_sel_items()
    return umode.pop(pctx)
end

--- Pop out selection panel of vim options
function M.pop()
    setup_sel_items()
    return umode.pop(pctx)
end

return M

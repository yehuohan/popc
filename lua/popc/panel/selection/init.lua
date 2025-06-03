--- @class Popc.Panel.Selection
local M = {}
local api = vim.api
local copts = require('popc.config').opts
local umode = require('popc.usermode')

--- @class PopSelection
--- @field opt nil|string|fun():string
---        Option name
--- @field dic nil|table<string,string|PopSelection>|fun(opt:string):table<string,string|PopSelection>
---        * table<string, string>       : 'lst' desctiption
---        * table<string, PopSelection> : sub-selection
--- @field lst nil|any[]|fun(opt:string):any[]
---        * any[]    : Selection item list
---        * string[] : Key index list of 'dic'
--- @field dsr nil|string|fun(opt:string):string
---        'opt' description
--- @field cpl nil|string|fun(opt:string):string
---        'completion' of `input()` to modify selection value
--- @field cmd nil|fun(opt:string, sel)
---        Command executed with selected item of 'lst'
--- @field get nil|fun(opt:string):any
---        Get the selected item of 'opt'
--- @field evt nil|fun(event:string)
---        Selection event callback
---        * 'onCR'   : called at `pkeys.confirm` (called after executed 'cmd')
---        * 'onQuit' : called at `pctx.on_quit`
--- @field sub nil|table<string,any|fun(...):any>|fun(opt:string):table<string,any|fun(...):any>
---        Shared 'lst', 'dsr', 'cpl', 'cmd', 'get' for 'dic' sub-selection

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
--- @field saved_index integer Saved `PanelContext.index`

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
        local base_idx = #sel_items -- The base node index
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
                if not subrsv_node.is_base then
                    out = subrsv_node.get(subrsv_node.opt)
                    -- pctx.items can't contain '\n' or it will failed to display
                    dsr = type(out) == 'string' and out or vim.inspect(out):gsub('\n', '')
                end
                table.insert(items, { indent .. val, dsr == '' and '' or ':', dsr })
                table.insert(sel_items, {
                    level = level,
                    base_node = rsv_node,
                    base_idx = base_idx,
                    node = subrsv_node,
                    idx = #sel_items + 1,
                    out = out, -- Valid when `not node.is_base = true` or `node = nil`
                })

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
                table.insert(sel_items, {
                    level = level,
                    base_node = rsv_node,
                    base_idx = base_idx,
                    node = nil,
                    idx = idx,
                    out = out, -- Valid when `not node.is_base = true` or `node = nil`
                })
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
    --- @type ResolvedSelection[]
    sel_stack = {}, -- Resolved root selection nodes
    sel_items = nil,
}

--- Setup selection root and items
--- @return boolean? Success or not
local function setup_sel_items()
    local num = #pctx.sel_stack
    local items, sel_root, sel_items = get_sel_items(pctx.sel_stack[num])
    pctx.items = items
    pctx.sel_stack[num] = sel_root
    pctx.sel_items = sel_items

    pctx.text = pctx.sel_stack[1].opt
    for k = 2, num do
        pctx.text = pctx.text .. string.format(' %s %s', copts.icons.pointer, pctx.sel_stack[k].opt)
    end
end

function M.setup()
    api.nvim_create_user_command('PopcSet', function(args)
        M.pop(args.fargs[1])
    end, {
        nargs = '?',
        complete = require('popc.panel.selection.data').get_complete,
    })
end

function M.inspect()
    return vim.inspect(pctx), pctx
end

pctx.on_quit = function(uctx, ukey)
    if ukey then
        if pctx.sel.evt then
            pctx.sel.evt('onQuit')
        end
        uctx.pret = false
    end
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
    if item and not item.node then
        item.base_node.cmd(item.base_node.opt, item.base_node.lst[item.idx])
    end

    pkeys.confirm(uctx)
end

function pkeys.execute(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.node then
        item.node.is_open = not item.node.is_open
    else
        item.base_node.cmd(item.base_node.opt, item.base_node.lst[item.idx])
    end
    setup_sel_items()
    uctx.state = umode.State.ReDisp
end

function pkeys.enter(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.node then
        pctx.sel_stack[#pctx.sel_stack].saved_index = pctx.index
        pctx.index = 1
        table.insert(pctx.sel_stack, item.node)
    else
        item.base_node.cmd(item.base_node.opt, item.base_node.lst[item.idx])
    end
    setup_sel_items()
    uctx.state = umode.State.ReDisp
end

function pkeys.leave(uctx)
    local num = #pctx.sel_stack
    if num > 1 then
        table.remove(pctx.sel_stack, num)
        pctx.index = pctx.sel_stack[#pctx.sel_stack].saved_index
        setup_sel_items()
        uctx.state = umode.State.ReDisp
    end
end

function pkeys.fold_or_open(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if item.node then
        item.node.is_open = not item.node.is_open
    else
        item.base_node.is_open = not item.base_node.is_open
        pctx.index = item.base_idx
    end
    setup_sel_items()
    uctx.state = umode.State.ReDisp
end

function pkeys.fold_always(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    item.base_node.is_open = false
    if item.level > 0 then
        pctx.index = item.base_idx
    end
    setup_sel_items()
    uctx.state = umode.State.ReDisp
end

function pkeys.next_lst_item(uctx)
    local item = pctx.sel_items[pctx.index]
    if not item then
        return
    end

    if (not item.node) or not item.node.is_base then
        local node = item.node or item.base_node
        local cur = table.foreachi(node.lst, function(k, v)
            return v == item.out and k or nil
        end) or 0
        node.cmd(node.opt, node.lst[cur % #node.lst + 1])
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

    if (not item.node) or not item.node.is_base then
        local node = item.node or item.base_node
        local cur = table.foreachi(node.lst, function(k, v)
            return v == item.out and k or nil
        end) or 1
        node.cmd(node.opt, node.lst[(cur - 2) % #node.lst + 1])
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

    if (not item.node) or not item.node.is_base then
        local node = item.node or item.base_node
        local val = umode.input({ prompt = 'Modify: ', completion = node.cpl })
        if val then
            node.cmd(node.opt, val)
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

    if (not item.node) or not item.node.is_base then
        local node = item.node or item.base_node
        local val = umode.input({ prompt = 'Modify: ', default = item.out, completion = node.cpl })
        if val then
            node.cmd(node.opt, val)
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
    pctx.sel = sel or {}
    pctx.sel_stack = { pctx.sel }
    pctx.sel_items = nil
    setup_sel_items()
    return umode.pop(pctx)
end

--- Pop out selection panel of vim options
--- @param opt string?
function M.pop(opt)
    return M.pop_selection(require('popc.panel.selection.data').get_sel(opt))
end

return M
